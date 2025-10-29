<#
.SYNOPSIS
    Pre-load multiple LLM models into Ollama server for KubeCon demo
.DESCRIPTION
    Downloads multiple models to demonstrate Azure Files storage efficiency.
    All models stored on single Azure Files Premium share.
.PARAMETER Namespace
    Kubernetes namespace where Ollama is deployed
.PARAMETER Models
    Array of model names to preload. Defaults to demo set.
.PARAMETER DryRun
    Test script logic without actually downloading models
.EXAMPLE
    .\preload-multi-models.ps1
.EXAMPLE
    .\preload-multi-models.ps1 -Models @("phi3.5", "llama3.1:8b")
.EXAMPLE
    .\preload-multi-models.ps1 -DryRun
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$Namespace = "ollama",

    [Parameter(Mandatory = $false)]
    [string[]]$Models = @(
        "phi3.5"            # 2.3GB - Fast, efficient model
        # Commented out for fast deployment - uncomment to preload more models:
        # "llama3.1:8b",      # 4.7GB - Production-ready
        # "mistral:7b",       # 4.1GB - Popular alternative
        # "gemma2:2b",        # 1.6GB - Lightweight model
        # "gpt-oss",          # ~13GB - GPT-like open source model
        # "deepseek-r1"       # ~8GB - DeepSeek reasoning model
    ),

    [Parameter(Mandatory = $false)]
    [switch]$DryRun
)

# Don't treat stderr as errors - kubectl writes progress to stderr
$ErrorActionPreference = 'Continue'

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Multi-Model Preloader for KubeCon Demo" -ForegroundColor Cyan
if ($DryRun) {
    Write-Host "(DRY RUN MODE - No actual downloads)" -ForegroundColor Yellow
}
Write-Host "========================================`n" -ForegroundColor Cyan

# Validate kubectl is available
Write-Host "Checking prerequisites..." -ForegroundColor Gray
$kubectlExists = Get-Command kubectl -ErrorAction SilentlyContinue
if (-not $kubectlExists) {
    Write-Error "kubectl not found in PATH. Please install kubectl and ensure it's configured."
    exit 1
}
Write-Host "  kubectl: Found" -ForegroundColor Green

# Check kubectl connectivity
Write-Host "  Checking cluster connection..." -ForegroundColor Gray
$clusterCheck = kubectl cluster-info 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Error "Cannot connect to Kubernetes cluster. Ensure kubectl is configured correctly."
    Write-Host "Error: $clusterCheck" -ForegroundColor Red
    exit 1
}
Write-Host "  Cluster: Connected" -ForegroundColor Green

# Model size info
$modelSizes = @{
    "phi3.5"       = "2.3 GB"
    "llama3.1:8b"  = "4.7 GB"
    "mistral:7b"   = "4.1 GB"
    "gemma2:2b"    = "1.6 GB"
    "gpt-oss"      = "13 GB"
    "deepseek-r1"  = "8 GB"
}

Write-Host "Models to preload: $($Models.Count)" -ForegroundColor Yellow
$totalSize = 0
foreach ($model in $Models) {
    $size = $modelSizes[$model]
    if ($size) {
        Write-Host "  - $model ($size)" -ForegroundColor Gray
        try {
            $numericSize = [float]($size -replace '[^0-9.]', '')
            $totalSize += $numericSize
        } catch {
            Write-Host "    Warning: Could not parse size for total calculation" -ForegroundColor Yellow
        }
    } else {
        Write-Host "  - $model (size unknown)" -ForegroundColor Gray
    }
}
if ($totalSize -gt 0) {
    Write-Host "  Total: ~$([math]::Round($totalSize, 1)) GB on Azure Files Premium`n" -ForegroundColor Yellow
} else {
    Write-Host "  Total: Unknown (will be calculated during download)`n" -ForegroundColor Yellow
}

# Find Ollama pod
Write-Host "Finding Ollama pod..." -ForegroundColor Gray
$podName = kubectl get pod -n $Namespace -l app=ollama -o jsonpath='{.items[0].metadata.name}' 2>$null

if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($podName)) {
    throw "Ollama pod not found in namespace '$Namespace'. Is it running?"
}

Write-Host "  Found pod: $podName`n" -ForegroundColor Green

# Verify Ollama service is responding
Write-Host "Verifying Ollama service is ready..." -ForegroundColor Gray
$maxRetries = 6
$retryCount = 0
$ollamaReady = $false

while ($retryCount -lt $maxRetries) {
    $testResult = kubectl exec -n $Namespace $podName -- ollama list 2>&1
    if ($LASTEXITCODE -eq 0) {
        $ollamaReady = $true
        Write-Host "  Ollama service is responding" -ForegroundColor Green
        break
    }
    $retryCount++
    Write-Host "  Ollama not ready yet, waiting... (attempt $retryCount/$maxRetries)" -ForegroundColor Yellow
    Start-Sleep -Seconds 5
}

if (-not $ollamaReady) {
    throw "Ollama service is not responding after $($maxRetries * 5) seconds. Check pod logs: kubectl logs -n $Namespace $podName"
}

# Check disk space before starting
Write-Host "Checking available disk space..." -ForegroundColor Gray
$diskSpace = kubectl exec -n $Namespace $podName -- df -h /root/.ollama 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host "$diskSpace" -ForegroundColor Gray
} else {
    Write-Host "  Warning: Could not check disk space" -ForegroundColor Yellow
}

Write-Host ""

# Get existing models
Write-Host "Checking existing models..." -ForegroundColor Gray
$existingModels = kubectl exec -n $Namespace $podName -- ollama list 2>$null
Write-Host "$existingModels`n" -ForegroundColor Gray

# Download models
$successCount = 0
$skipCount = 0
$failCount = 0
$downloadTimes = @()

foreach ($model in $Models) {
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "Model: $model" -ForegroundColor White
    Write-Host "========================================" -ForegroundColor Cyan

    # Check if already exists
    if ($existingModels -match $model) {
        Write-Host "  Already exists. Skipping." -ForegroundColor Yellow
        $skipCount++
        Write-Host ""
        continue
    }

    # Download model
    $expectedSize = $modelSizes[$model]
    if ($expectedSize) {
        Write-Host "  Downloading $expectedSize (this may take several minutes)..." -ForegroundColor Gray
    } else {
        Write-Host "  Downloading (this may take several minutes)..." -ForegroundColor Gray
    }

    $startTime = Get-Date

    try {
        # In DryRun mode, skip actual download
        if ($DryRun) {
            Write-Host "  [DRY RUN] Would execute: ollama pull $model" -ForegroundColor Cyan
            Write-Host "  Skipping actual download in dry-run mode" -ForegroundColor Cyan
            $skipCount++
            Write-Host ""
            continue
        }

        # Run ollama pull - this will block until complete
        Write-Host "  Executing: ollama pull $model" -ForegroundColor DarkGray
        Write-Host "  (This may take 5-15 minutes depending on model size and network speed)`n" -ForegroundColor Gray

        # Execute the pull command and capture output
        $pullOutput = kubectl exec -n $Namespace $podName -- ollama pull $model 2>&1
        $exitCode = $LASTEXITCODE

        # Display output
        if ($pullOutput) {
            Write-Host "  Download output:" -ForegroundColor DarkGray
            $pullOutput | ForEach-Object {
                if ($_ -match "error|failed|fatal") {
                    Write-Host "    $_" -ForegroundColor Red
                } else {
                    Write-Host "    $_" -ForegroundColor DarkGray
                }
            }
        }

        # Wait for file system sync
        Write-Host "`n  Waiting for file system sync..." -ForegroundColor Gray
        Start-Sleep -Seconds 3

        if ($exitCode -eq 0) {
            # Verify the model was actually downloaded by checking ollama list
            Write-Host "  Verifying model registration..." -ForegroundColor Gray
            $verifyList = kubectl exec -n $Namespace $podName -- ollama list 2>&1

            # More flexible model matching (handle version tags)
            $modelBase = $model -replace ':.*$', ''  # Remove tag if present
            $modelExists = ($verifyList -match $model) -or ($verifyList -match "$modelBase\s")

            if ($modelExists) {
                $duration = (Get-Date) - $startTime
                $downloadTimes += [PSCustomObject]@{
                    Model = $model
                    Duration = [math]::Round($duration.TotalSeconds, 1)
                    Size = if ($expectedSize) { $expectedSize } else { "Unknown" }
                }
                Write-Host "  [OK] Successfully downloaded and verified in $([math]::Round($duration.TotalSeconds, 1)) seconds" -ForegroundColor Green
                $successCount++
            } else {
                Write-Host "  [FAIL] Exit code 0 but model not found in ollama list" -ForegroundColor Red
                Write-Host "  Current models:" -ForegroundColor Yellow
                $verifyList | ForEach-Object { Write-Host "    $_" -ForegroundColor DarkGray }
                $failCount++
            }
        } else {
            Write-Host "  [FAIL] Failed to download (exit code: $exitCode)" -ForegroundColor Red
            Write-Host "  Check network connectivity and disk space" -ForegroundColor Yellow
            $failCount++
        }
    } catch {
        Write-Host "  [FAIL] Exception during download: $_" -ForegroundColor Red
        Write-Host "  Stack trace: $($_.ScriptStackTrace)" -ForegroundColor DarkGray
        $failCount++
    }

    # Ensure we've processed this model before moving to the next
    Write-Host ""
}

# Summary
Write-Host "`n========================================" -ForegroundColor Green
Write-Host "Download Complete!" -ForegroundColor Green
Write-Host "========================================`n" -ForegroundColor Green

Write-Host "Summary:" -ForegroundColor Yellow
Write-Host "  Downloaded: $successCount" -ForegroundColor Green
Write-Host "  Skipped: $skipCount" -ForegroundColor Gray
Write-Host "  Failed: $failCount" -ForegroundColor $(if ($failCount -gt 0) { "Red" } else { "Gray" })

if ($downloadTimes.Count -gt 0) {
    Write-Host "`nDownload Times:" -ForegroundColor Yellow
    $downloadTimes | Format-Table -AutoSize
}

# Verify all models
Write-Host "`nVerifying models in Ollama..." -ForegroundColor Yellow
$finalModels = kubectl exec -n $Namespace $podName -- ollama list 2>$null
Write-Host "$finalModels" -ForegroundColor Gray

# Storage usage
Write-Host "`nStorage Usage (Azure Files Premium):" -ForegroundColor Yellow
kubectl exec -n $Namespace $podName -- df -h /root/.ollama 2>$null | Write-Host -ForegroundColor Gray

Write-Host "`n========================================" -ForegroundColor Green
Write-Host "Multi-Model Setup Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host "Demo Talking Points:" -ForegroundColor Cyan
Write-Host "  - All $($Models.Count) models stored on single Azure Files share" -ForegroundColor White
if ($totalSize -gt 0) {
    Write-Host "  - Total: ~$([math]::Round($totalSize, 1)) GB with no duplication" -ForegroundColor White
}
Write-Host "  - ReadWriteMany allows multiple pods to access" -ForegroundColor White
Write-Host "  - Models persist across pod restarts" -ForegroundColor White
Write-Host ""
Write-Host "Next: Open WebUI and switch between models!" -ForegroundColor Yellow
Write-Host ""

