<#
.SYNOPSIS
    Pre-load multiple LLM models into Ollama server

.DESCRIPTION
    Downloads multiple models to demonstrate Azure Files storage efficiency.
    All models stored on single Azure Files Premium share.

.PARAMETER Namespace
    Kubernetes namespace where Ollama is deployed (default: ollama)

.PARAMETER Models
    Array of model names to preload

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
    [Parameter(Mandatory=$false)]
    [string]$Namespace = "ollama",

    [Parameter(Mandatory=$false)]
    [string[]]$Models = @(
        "phi3.5",           # 2.3GB - Fast, efficient model
        "llama3.1:8b",      # 4.7GB - Production-ready
        "mistral:7b",       # 4.1GB - Popular alternative
        "gemma2:2b",        # 1.6GB - Lightweight model
        "gpt-oss",          # ~13GB - GPT-like open source model
        "deepseek-r1"       # ~8GB - DeepSeek reasoning model
    ),

    [Parameter(Mandatory=$false)]
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'

# Load common functions
. (Join-Path $PSScriptRoot "Common.ps1")

# Model metadata
$modelSizes = @{
    "phi3.5"       = "2.3 GB"
    "llama3.1:8b"  = "4.7 GB"
    "mistral:7b"   = "4.1 GB"
    "gemma2:2b"    = "1.6 GB"
    "gpt-oss"      = "13 GB"
    "deepseek-r1"  = "8 GB"
}

#region Main Script

Write-StepHeader "Multi-Model Preloader"
if ($DryRun) {
    Write-Info "(DRY RUN MODE - No actual downloads)"
}

# Prerequisites
if (-not (Test-Prerequisites -Tools @('kubectl'))) {
    exit 1
}

if (-not (Test-KubernetesConnection)) {
    exit 1
}

# Calculate total size
Write-Info "Models to preload: $($Models.Count)"
$totalSize = 0
foreach ($model in $Models) {
    $size = $modelSizes[$model]
    if ($size) {
        Write-Host "  - $model ($size)" -ForegroundColor Gray
        $totalSize += [float]($size -replace '[^0-9.]', '')
    }
    else {
        Write-Host "  - $model (size unknown)" -ForegroundColor Gray
    }
}
if ($totalSize -gt 0) {
    Write-Info "Total: ~$([math]::Round($totalSize, 1)) GB on Azure Files Premium"
}

# Find Ollama pod
Write-Info "Finding Ollama pod..."
$podName = Get-PodName -Namespace $Namespace -LabelSelector "app=ollama"

if (-not $podName) {
    Write-ErrorMsg "Ollama pod not found in namespace '$Namespace'"
    exit 1
}
Write-Success "Found pod: $podName"

# Verify Ollama service
Write-Info "Verifying Ollama service..."
$maxRetries = 6
for ($i = 1; $i -le $maxRetries; $i++) {
    $testResult = kubectl exec -n $Namespace $podName -- ollama list 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Ollama service is responding"
        break
    }
    if ($i -eq $maxRetries) {
        Write-ErrorMsg "Ollama service not responding after $($maxRetries * 5) seconds"
        exit 1
    }
    Write-Host "  Waiting... (attempt $i/$maxRetries)" -ForegroundColor Gray
    Start-Sleep -Seconds 5
}

# Get existing models
Write-Info "Checking existing models..."
$existingModels = kubectl exec -n $Namespace $podName -- ollama list 2>&1
Write-Host $existingModels -ForegroundColor Gray

# Download models
$successCount = 0
$skipCount = 0
$failCount = 0
$downloadTimes = @()
$startOverall = Get-Date

foreach ($model in $Models) {
    Write-StepHeader "Model: $model"

    # Check if exists
    if ($existingModels -match $model) {
        Write-Info "Already exists. Skipping."
        $skipCount++
        continue
    }

    # Download
    $expectedSize = $modelSizes[$model]
    if ($expectedSize) {
        Write-Info "Downloading $expectedSize (may take several minutes)..."
    }
    else {
        Write-Info "Downloading (may take several minutes)..."
    }

    $startTime = Get-Date

    try {
        if ($DryRun) {
            Write-Info "[DRY RUN] Would execute: ollama pull $model"
            $skipCount++
            continue
        }

        # Pull model
        $pullOutput = kubectl exec -n $Namespace $podName -- ollama pull $model 2>&1
        $exitCode = $LASTEXITCODE

        # Show output for errors
        if ($exitCode -ne 0 -and $pullOutput) {
            Write-Host $pullOutput -ForegroundColor DarkGray
        }

        # Wait for sync
        Start-Sleep -Seconds 3

        if ($exitCode -eq 0) {
            # Verify
            $verifyList = kubectl exec -n $Namespace $podName -- ollama list 2>&1
            $modelBase = $model -replace ':.*$', ''
            $modelExists = ($verifyList -match $model) -or ($verifyList -match "$modelBase\s")

            if ($modelExists) {
                $duration = (Get-Date) - $startTime
                $downloadTimes += [PSCustomObject]@{
                    Model = $model
                    Duration = "$([math]::Round($duration.TotalSeconds, 1))s"
                    Size = if ($expectedSize) { $expectedSize } else { "Unknown" }
                }
                Write-Success "Downloaded in $([math]::Round($duration.TotalSeconds, 1)) seconds"
                $successCount++
            }
            else {
                Write-ErrorMsg "Model not found in ollama list after download"
                $failCount++
            }
        }
        else {
            Write-ErrorMsg "Failed to download (exit code: $exitCode)"
            $failCount++
        }
    }
    catch {
        Write-ErrorMsg "Exception: $($_.Exception.Message)"
        $failCount++
    }

    Write-Host ""
}

# Summary
$elapsedOverall = Get-ElapsedTime -StartTime $startOverall

Write-StepHeader "Download Complete"
Write-Host "Summary:" -ForegroundColor Yellow
Write-Host "  Downloaded: " -NoNewline; Write-Host "$successCount" -ForegroundColor Green
Write-Host "  Skipped: " -NoNewline; Write-Host "$skipCount" -ForegroundColor Gray
Write-Host "  Failed: " -NoNewline; Write-Host "$failCount" -ForegroundColor $(if ($failCount -gt 0) { "Red" } else { "Gray" })
Write-Host "  Total Time: " -NoNewline; Write-Host "$elapsedOverall" -ForegroundColor Cyan

if ($downloadTimes.Count -gt 0) {
    Write-Host "`nDownload Times:" -ForegroundColor Yellow
    $downloadTimes | Format-Table -AutoSize
}

# Final verification
Write-Info "Final model list:"
kubectl exec -n $Namespace $podName -- ollama list 2>&1 | Write-Host -ForegroundColor Gray

Write-Host "`nStorage Usage:" -ForegroundColor Yellow
kubectl exec -n $Namespace $podName -- df -h /root/.ollama 2>&1 | Write-Host -ForegroundColor Gray

Write-Success "Multi-Model Setup Complete!"
Write-Host "`nDemo Talking Points:" -ForegroundColor Cyan
Write-Host "  - All $($Models.Count) models on single Azure Files share" -ForegroundColor White
if ($totalSize -gt 0) {
    Write-Host "  - Total: ~$([math]::Round($totalSize, 1)) GB with no duplication" -ForegroundColor White
}
Write-Host "  - ReadWriteMany enables multiple pods" -ForegroundColor White
Write-Host "  - Models persist across pod restarts" -ForegroundColor White

#endregion
