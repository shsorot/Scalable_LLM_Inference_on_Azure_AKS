<#
.SYNOPSIS
    Benchmark single user model download and load time

.DESCRIPTION
    Measures the time taken to download and load a single model in Ollama.
    Tests model pull time (download) and first inference time (load into memory).

.PARAMETER OllamaEndpoint
    Ollama API endpoint (e.g., http://ollama-service.ollama.svc.cluster.local:11434)

.PARAMETER Model
    Model name to benchmark (default: llama3.1:8b)

.PARAMETER OutputFile
    Path to save benchmark results (default: single-user-results.json)

.EXAMPLE
    .\single-user-benchmark.ps1 -OllamaEndpoint "http://20.54.123.45:11434" -Model "llama3.1:8b"
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$OllamaEndpoint,

    [Parameter(Mandatory=$false)]
    [string]$Model = "llama3.1:8b",

    [Parameter(Mandatory=$false)]
    [string]$OutputFile = "single-user-results.json"
)

$ErrorActionPreference = "Stop"

# Results object
$results = @{
    Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Model = $Model
    OllamaEndpoint = $OllamaEndpoint
    Measurements = @{}
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Single User Model Benchmark" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Model: $Model"
Write-Host "Endpoint: $OllamaEndpoint"
Write-Host ""

# Function to call Ollama API
function Invoke-OllamaAPI {
    param(
        [string]$Endpoint,
        [string]$Path,
        [hashtable]$Body = @{},
        [string]$Method = "Post"
    )

    $uri = "$Endpoint$Path"

    try {
        $params = @{
            Uri = $uri
            Method = $Method
            TimeoutSec = 3600
            UseBasicParsing = $true
        }

        # Add body for methods that support them
        if ($Method -in @("Post", "Delete") -and $Body -and $Body.Count -gt 0) {
            $jsonBody = $Body | ConvertTo-Json -Depth 10 -Compress
            $params.Body = $jsonBody
            $params.ContentType = "application/json"
        }

        $response = Invoke-RestMethod @params
        return $response
    }
    catch {
        Write-Error "API call failed: $_"
        throw
    }
}

# Step 1: Check if model already exists
Write-Host "[1/4] Checking if model exists..." -ForegroundColor Yellow
try {
    $listResponse = Invoke-OllamaAPI -Endpoint $OllamaEndpoint -Path "/api/tags" -Method "Get"
    $modelExists = $listResponse.models | Where-Object { $_.name -eq $Model }

    if ($modelExists) {
        Write-Host "  Model already exists. Deleting for clean benchmark..." -ForegroundColor Yellow
        # Delete model using DELETE method
        $deleteBody = @{ name = $Model }
        Invoke-OllamaAPI -Endpoint $OllamaEndpoint -Path "/api/delete" -Body $deleteBody -Method "Delete"
        Write-Host "  Model deleted." -ForegroundColor Green
        Start-Sleep -Seconds 5
    }
    else {
        Write-Host "  Model does not exist. Ready for benchmark." -ForegroundColor Green
    }
}
catch {
    Write-Warning "Could not check model existence: $_"
}

# Step 2: Measure model download time (pull)
Write-Host ""
Write-Host "[2/4] Measuring model download time..." -ForegroundColor Yellow

$pullStart = Get-Date
try {
    $pullBody = @{
        name = $Model
        stream = $false
    }

    Write-Host "  Starting pull at: $($pullStart.ToString('HH:mm:ss.fff'))"
    $pullResponse = Invoke-OllamaAPI -Endpoint $OllamaEndpoint -Path "/api/pull" -Body $pullBody
    $pullEnd = Get-Date
    $pullDuration = ($pullEnd - $pullStart).TotalSeconds

    Write-Host "  Pull completed at: $($pullEnd.ToString('HH:mm:ss.fff'))" -ForegroundColor Green
    Write-Host "  Download time: $([math]::Round($pullDuration, 2)) seconds" -ForegroundColor Green

    $results.Measurements.DownloadTimeSeconds = [math]::Round($pullDuration, 2)
    $results.Measurements.DownloadStatus = "Success"
}
catch {
    Write-Error "Model pull failed: $_"
    $results.Measurements.DownloadStatus = "Failed"
    $results.Measurements.DownloadError = $_.Exception.Message
    $results | ConvertTo-Json -Depth 10 | Out-File -FilePath $OutputFile -Encoding utf8
    exit 1
}

# Step 3: Measure first load time (cold start)
Write-Host ""
Write-Host "[3/4] Measuring model load time (cold start)..." -ForegroundColor Yellow

$loadStart = Get-Date
try {
    $generateBody = @{
        model = $Model
        prompt = "Say hello"
        stream = $false
    }

    Write-Host "  Starting generation at: $($loadStart.ToString('HH:mm:ss.fff'))"
    $generateResponse = Invoke-OllamaAPI -Endpoint $OllamaEndpoint -Path "/api/generate" -Body $generateBody
    $loadEnd = Get-Date
    $loadDuration = ($loadEnd - $loadStart).TotalSeconds

    Write-Host "  Generation completed at: $($loadEnd.ToString('HH:mm:ss.fff'))" -ForegroundColor Green
    Write-Host "  Load time (cold): $([math]::Round($loadDuration, 2)) seconds" -ForegroundColor Green

    $results.Measurements.LoadTimeColdSeconds = [math]::Round($loadDuration, 2)
    $results.Measurements.LoadStatus = "Success"

    # Extract metrics from response
    if ($generateResponse.eval_count -and $generateResponse.eval_duration) {
        $tokensPerSecond = $generateResponse.eval_count / ($generateResponse.eval_duration / 1000000000)
        $results.Measurements.TokensPerSecond = [math]::Round($tokensPerSecond, 2)
        Write-Host "  Throughput: $([math]::Round($tokensPerSecond, 2)) tokens/second"
    }
}
catch {
    Write-Error "Model load failed: $_"
    $results.Measurements.LoadStatus = "Failed"
    $results.Measurements.LoadError = $_.Exception.Message
    $results | ConvertTo-Json -Depth 10 | Out-File -FilePath $OutputFile -Encoding utf8
    exit 1
}

# Step 4: Measure warm start time
Write-Host ""
Write-Host "[4/4] Measuring model load time (warm start)..." -ForegroundColor Yellow

Start-Sleep -Seconds 2

$warmStart = Get-Date
try {
    $generateBody = @{
        model = $Model
        prompt = "Say goodbye"
        stream = $false
    }

    Write-Host "  Starting generation at: $($warmStart.ToString('HH:mm:ss.fff'))"
    $generateResponse = Invoke-OllamaAPI -Endpoint $OllamaEndpoint -Path "/api/generate" -Body $generateBody
    $warmEnd = Get-Date
    $warmDuration = ($warmEnd - $warmStart).TotalSeconds

    Write-Host "  Generation completed at: $($warmEnd.ToString('HH:mm:ss.fff'))" -ForegroundColor Green
    Write-Host "  Load time (warm): $([math]::Round($warmDuration, 2)) seconds" -ForegroundColor Green

    $results.Measurements.LoadTimeWarmSeconds = [math]::Round($warmDuration, 2)
}
catch {
    Write-Warning "Warm start measurement failed: $_"
}

# Calculate total time
$results.Measurements.TotalTimeSeconds = [math]::Round(
    $results.Measurements.DownloadTimeSeconds + $results.Measurements.LoadTimeColdSeconds,
    2
)

# Summary
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Benchmark Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Model: $Model" -ForegroundColor White
Write-Host "Download time: $($results.Measurements.DownloadTimeSeconds)s" -ForegroundColor Green
Write-Host "Load time (cold): $($results.Measurements.LoadTimeColdSeconds)s" -ForegroundColor Green
Write-Host "Load time (warm): $($results.Measurements.LoadTimeWarmSeconds)s" -ForegroundColor Green
Write-Host "Total time: $($results.Measurements.TotalTimeSeconds)s" -ForegroundColor Green
if ($results.Measurements.TokensPerSecond) {
    Write-Host "Throughput: $($results.Measurements.TokensPerSecond) tokens/s" -ForegroundColor Green
}
Write-Host ""

# Save results
$results | ConvertTo-Json -Depth 10 | Out-File -FilePath $OutputFile -Encoding utf8
Write-Host "Results saved to: $OutputFile" -ForegroundColor Cyan
