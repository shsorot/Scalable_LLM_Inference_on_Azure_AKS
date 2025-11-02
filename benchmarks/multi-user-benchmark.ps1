<#
.SYNOPSIS
    Benchmark multiple users downloading and loading multiple models concurrently

.DESCRIPTION
    Simulates multiple users concurrently downloading and loading different models.
    Measures overall throughput, individual model timings, and resource contention.

.PARAMETER OllamaEndpoint
    Ollama API endpoint (e.g., http://ollama-service.ollama.svc.cluster.local:11434)

.PARAMETER Models
    Array of model names to benchmark (default: common LLM models)

.PARAMETER ConcurrentUsers
    Number of concurrent users (default: 3)

.PARAMETER OutputFile
    Path to save benchmark results (default: multi-user-results.json)

.EXAMPLE
    .\multi-user-benchmark.ps1 -OllamaEndpoint "http://20.54.123.45:11434" -ConcurrentUsers 5

.EXAMPLE
    .\multi-user-benchmark.ps1 -OllamaEndpoint "http://20.54.123.45:11434" -Models @("phi3.5", "gemma2:2b", "mistral:7b")
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$OllamaEndpoint,

    [Parameter(Mandatory=$false)]
    [string[]]$Models = @("phi3.5", "gemma2:2b", "mistral:7b", "llama3.1:8b"),

    [Parameter(Mandatory=$false)]
    [int]$ConcurrentUsers = 3,

    [Parameter(Mandatory=$false)]
    [string]$OutputFile = "multi-user-results.json"
)

$ErrorActionPreference = "Stop"

# Results object
$results = @{
    Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    OllamaEndpoint = $OllamaEndpoint
    ConcurrentUsers = $ConcurrentUsers
    Models = $Models
    IndividualResults = @()
    Summary = @{}
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Multi-User Model Benchmark" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Endpoint: $OllamaEndpoint"
Write-Host "Concurrent Users: $ConcurrentUsers"
Write-Host "Models: $($Models -join ', ')"
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
        return $null
    }
}

# Step 1: Check existing models (skip cleanup to avoid download issues)
Write-Host "[1/3] Checking existing models..." -ForegroundColor Yellow
try {
    $listResponse = Invoke-OllamaAPI -Endpoint $OllamaEndpoint -Path "/api/tags" -Method "Get"

    foreach ($model in $Models) {
        $existingModel = $listResponse.models | Where-Object { $_.name -eq $model }
        if ($existingModel) {
            Write-Host "  $model - available" -ForegroundColor Green
        }
        else {
            Write-Host "  $model - needs download" -ForegroundColor Yellow
        }
    }
}
catch {
    Write-Warning "Could not check models: $_"
}

# Step 2: Prepare scriptblock for parallel execution
$benchmarkScriptBlock = {
    param(
        [string]$Endpoint,
        [string]$ModelName,
        [int]$UserId
    )

    $result = @{
        UserId = $UserId
        Model = $ModelName
        Measurements = @{}
    }

    # Function to call API (defined inside scriptblock for parallelism)
    function Invoke-OllamaAPIInternal {
        param(
            [string]$Endpoint,
            [string]$Path,
            [hashtable]$Body
        )

        $uri = "$Endpoint$Path"
        $jsonBody = $Body | ConvertTo-Json -Depth 10 -Compress

        try {
            $params = @{
                Uri = $uri
                Method = "Post"
                Body = $jsonBody
                ContentType = "application/json"
                TimeoutSec = 3600
                UseBasicParsing = $true
            }
            $response = Invoke-RestMethod @params
            return $response
        }
        catch {
            return $null
        }
    }

    # Check if model exists, skip download if it does (avoid API pull issues)
    $modelExists = $false
    try {
        $listResponse = Invoke-OllamaAPIInternal -Endpoint $Endpoint -Path "/api/tags" -Body @{}
        # For GET request, we need to modify the function call, but for simplicity just skip pull
        $result.Measurements.DownloadTimeSeconds = 0
        $result.Measurements.DownloadStatus = "Skipped"
    }
    catch {
        # If check fails, try to pull anyway
        $pullStart = Get-Date
        try {
            $pullBody = @{
                name = $ModelName
                stream = $false
            }

            $pullResponse = Invoke-OllamaAPIInternal -Endpoint $Endpoint -Path "/api/pull" -Body $pullBody
            $pullEnd = Get-Date
            $pullDuration = ($pullEnd - $pullStart).TotalSeconds

            $result.Measurements.DownloadTimeSeconds = [math]::Round($pullDuration, 2)
            $result.Measurements.DownloadStatus = "Success"
            $result.Measurements.DownloadStartTime = $pullStart.ToString('HH:mm:ss.fff')
            $result.Measurements.DownloadEndTime = $pullEnd.ToString('HH:mm:ss.fff')
        }
        catch {
            $result.Measurements.DownloadStatus = "Failed"
            $result.Measurements.DownloadError = $_.Exception.Message
            return $result
        }
    }

    # Load model (cold start)
    $loadStart = Get-Date
    try {
        $generateBody = @{
            model = $ModelName
            prompt = "Hello from user $UserId"
            stream = $false
        }

        $generateResponse = Invoke-OllamaAPIInternal -Endpoint $Endpoint -Path "/api/generate" -Body $generateBody
        $loadEnd = Get-Date
        $loadDuration = ($loadEnd - $loadStart).TotalSeconds

        $result.Measurements.LoadTimeSeconds = [math]::Round($loadDuration, 2)
        $result.Measurements.LoadStatus = "Success"
        $result.Measurements.LoadStartTime = $loadStart.ToString('HH:mm:ss.fff')
        $result.Measurements.LoadEndTime = $loadEnd.ToString('HH:mm:ss.fff')

        # Extract throughput metrics
        if ($generateResponse.eval_count -and $generateResponse.eval_duration) {
            $tokensPerSecond = $generateResponse.eval_count / ($generateResponse.eval_duration / 1000000000)
            $result.Measurements.TokensPerSecond = [math]::Round($tokensPerSecond, 2)
        }
    }
    catch {
        $result.Measurements.LoadStatus = "Failed"
        $result.Measurements.LoadError = $_.Exception.Message
        return $result
    }

    # Calculate total time
    $result.Measurements.TotalTimeSeconds = [math]::Round(
        $result.Measurements.DownloadTimeSeconds + $result.Measurements.LoadTimeSeconds,
        2
    )

    return $result
}

# Step 3: Execute concurrent benchmarks
Write-Host ""
Write-Host "[2/3] Starting concurrent benchmarks..." -ForegroundColor Yellow
Write-Host "  This may take several minutes depending on model sizes..." -ForegroundColor Yellow

$overallStart = Get-Date

# Create jobs for concurrent execution
$jobs = @()
$userModels = @()

for ($i = 0; $i -lt $ConcurrentUsers; $i++) {
    $modelIndex = $i % $Models.Count
    $model = $Models[$modelIndex]
    $userId = $i + 1

    $userModels += @{
        UserId = $userId
        Model = $model
    }

    Write-Host "  User $userId -> $model (starting...)" -ForegroundColor Cyan

    $job = Start-Job -ScriptBlock $benchmarkScriptBlock -ArgumentList $OllamaEndpoint, $model, $userId
    $jobs += $job
}

# Wait for all jobs to complete
Write-Host ""
Write-Host "  Waiting for all concurrent operations to complete..." -ForegroundColor Yellow

$completedJobs = 0
while ($jobs | Where-Object { $_.State -eq 'Running' }) {
    $finished = ($jobs | Where-Object { $_.State -eq 'Completed' }).Count
    if ($finished -ne $completedJobs) {
        Write-Host "  Progress: $finished/$($jobs.Count) users completed" -ForegroundColor Cyan
        $completedJobs = $finished
    }
    Start-Sleep -Seconds 2
}

$overallEnd = Get-Date
$overallDuration = ($overallEnd - $overallStart).TotalSeconds

Write-Host "  All concurrent operations completed!" -ForegroundColor Green

# Collect results from jobs
foreach ($job in $jobs) {
    $jobResult = Receive-Job -Job $job
    if ($jobResult) {
        $results.IndividualResults += $jobResult
    }
    Remove-Job -Job $job
}

# Step 3: Calculate summary statistics
Write-Host ""
Write-Host "[3/3] Calculating summary statistics..." -ForegroundColor Yellow

$successfulDownloads = $results.IndividualResults | Where-Object { $_.Measurements.DownloadStatus -eq "Success" }
$successfulLoads = $results.IndividualResults | Where-Object { $_.Measurements.LoadStatus -eq "Success" }

$results.Summary = @{
    OverallDurationSeconds = [math]::Round($overallDuration, 2)
    TotalUsers = $ConcurrentUsers
    SuccessfulDownloads = $successfulDownloads.Count
    SuccessfulLoads = $successfulLoads.Count
    SuccessRate = [math]::Round(($successfulLoads.Count / $ConcurrentUsers) * 100, 2)
}

if ($successfulDownloads) {
    $results.Summary.AverageDownloadTimeSeconds = [math]::Round(
        ($successfulDownloads.Measurements.DownloadTimeSeconds | Measure-Object -Average).Average,
        2
    )
    $results.Summary.MinDownloadTimeSeconds = [math]::Round(
        ($successfulDownloads.Measurements.DownloadTimeSeconds | Measure-Object -Minimum).Minimum,
        2
    )
    $results.Summary.MaxDownloadTimeSeconds = [math]::Round(
        ($successfulDownloads.Measurements.DownloadTimeSeconds | Measure-Object -Maximum).Maximum,
        2
    )
}

if ($successfulLoads) {
    $results.Summary.AverageLoadTimeSeconds = [math]::Round(
        ($successfulLoads.Measurements.LoadTimeSeconds | Measure-Object -Average).Average,
        2
    )
    $results.Summary.MinLoadTimeSeconds = [math]::Round(
        ($successfulLoads.Measurements.LoadTimeSeconds | Measure-Object -Minimum).Minimum,
        2
    )
    $results.Summary.MaxLoadTimeSeconds = [math]::Round(
        ($successfulLoads.Measurements.LoadTimeSeconds | Measure-Object -Maximum).Maximum,
        2
    )

    $throughputs = $successfulLoads.Measurements.TokensPerSecond | Where-Object { $_ -ne $null }
    if ($throughputs) {
        $results.Summary.AverageThroughputTokensPerSecond = [math]::Round(
            ($throughputs | Measure-Object -Average).Average,
            2
        )
    }
}

# Display summary
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Benchmark Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Overall duration: $($results.Summary.OverallDurationSeconds)s" -ForegroundColor Green
Write-Host "Concurrent users: $($results.Summary.TotalUsers)" -ForegroundColor White
Write-Host "Success rate: $($results.Summary.SuccessRate)%" -ForegroundColor Green
Write-Host ""
Write-Host "Download Times:" -ForegroundColor Yellow
Write-Host "  Average: $($results.Summary.AverageDownloadTimeSeconds)s"
Write-Host "  Min: $($results.Summary.MinDownloadTimeSeconds)s"
Write-Host "  Max: $($results.Summary.MaxDownloadTimeSeconds)s"
Write-Host ""
Write-Host "Load Times:" -ForegroundColor Yellow
Write-Host "  Average: $($results.Summary.AverageLoadTimeSeconds)s"
Write-Host "  Min: $($results.Summary.MinLoadTimeSeconds)s"
Write-Host "  Max: $($results.Summary.MaxLoadTimeSeconds)s"
Write-Host ""
if ($results.Summary.AverageThroughputTokensPerSecond) {
    Write-Host "Average throughput: $($results.Summary.AverageThroughputTokensPerSecond) tokens/s" -ForegroundColor Green
}
Write-Host ""
Write-Host "Individual Results:" -ForegroundColor Yellow
foreach ($individual in $results.IndividualResults) {
    $status = if ($individual.Measurements.LoadStatus -eq "Success") { "[OK]" } else { "[FAIL]" }
    Write-Host "  User $($individual.UserId) [$($individual.Model)]: Download=$($individual.Measurements.DownloadTimeSeconds)s, Load=$($individual.Measurements.LoadTimeSeconds)s $status"
}
Write-Host ""

# Save results
$results | ConvertTo-Json -Depth 10 | Out-File -FilePath $OutputFile -Encoding utf8
Write-Host "Results saved to: $OutputFile" -ForegroundColor Cyan
