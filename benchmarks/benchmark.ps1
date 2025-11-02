<#
.SYNOPSIS
    Comprehensive LLM Benchmark Suite for Ollama

.DESCRIPTION
    All-in-one benchmark script that can:
    - Test single model performance (cold/warm start, throughput)
    - Test all models automatically
    - Run multi-user concurrent tests
    - Test connection
    - Generate HTML reports
    - Compare results

.PARAMETER Mode
    Benchmark mode: SingleModel, AllModels, MultiUser, Connection, Report, Compare

.PARAMETER Model
    Model name for SingleModel mode (e.g., "mistral:7b")

.PARAMETER OllamaEndpoint
    Ollama API endpoint (default: http://localhost:11434)

.PARAMETER Users
    Number of concurrent users for MultiUser mode (default: 3)

.PARAMETER ResultsDir
    Compare results from specific directory (for Compare mode)

.EXAMPLE
    .\benchmark.ps1 -Mode Connection -OllamaEndpoint "http://localhost:11434"
    Test connection to Ollama

.EXAMPLE
    .\benchmark.ps1 -Mode SingleModel -Model "mistral:7b" -OllamaEndpoint "http://localhost:11434"
    Benchmark a single model

.EXAMPLE
    .\benchmark.ps1 -Mode AllModels -OllamaEndpoint "http://localhost:11434"
    Benchmark all available models

.EXAMPLE
    .\benchmark.ps1 -Mode MultiUser -Model "mistral:7b" -Users 5 -OllamaEndpoint "http://localhost:11434"
    Run multi-user concurrent test

.EXAMPLE
    .\benchmark.ps1 -Mode Report
    Generate HTML report from all results

.EXAMPLE
    .\benchmark.ps1 -Mode Compare -ResultsDir "results-20251102-192535"
    Compare results from specific directory
#>

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("SingleModel", "AllModels", "MultiUser", "Connection", "Report", "Compare")]
    [string]$Mode,

    [Parameter(Mandatory=$false)]
    [string]$Model = "",

    [Parameter(Mandatory=$false)]
    [string]$OllamaEndpoint = "http://localhost:11434",

    [Parameter(Mandatory=$false)]
    [int]$Users = 3,

    [Parameter(Mandatory=$false)]
    [string]$ResultsDir = ""
)

$ErrorActionPreference = "Stop"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

#region Helper Functions

function Write-Header {
    param([string]$Text)
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host $Text -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
}

function Test-OllamaConnection {
    param(
        [string]$Endpoint,
        [int]$MaxRetries = 3,
        [int]$RetryDelay = 3
    )

    for ($i = 1; $i -le $MaxRetries; $i++) {
        try {
            $response = Invoke-RestMethod -Uri "$Endpoint/api/tags" -Method GET -TimeoutSec 5 -ErrorAction Stop
            return $true
        }
        catch {
            Write-Host "  Connection attempt $i/$MaxRetries failed" -ForegroundColor Yellow
            if ($i -lt $MaxRetries) {
                Write-Host "  Waiting $RetryDelay seconds before retry..." -ForegroundColor Yellow
                Start-Sleep -Seconds $RetryDelay
            }
        }
    }
    return $false
}

function Get-AvailableModels {
    param([string]$Endpoint)

    $models = @()
    try {
        $modelList = kubectl exec -n ollama ollama-0 -- ollama list 2>&1
        $lines = $modelList -split "`n"

        foreach ($line in $lines | Select-Object -Skip 1) {
            if ($line -match '^(\S+)\s+') {
                $modelName = $matches[1]
                if ($modelName -ne "NAME") {
                    $models += $modelName
                }
            }
        }
    }
    catch {
        Write-Host "Failed to get model list: $_" -ForegroundColor Red
    }
    return $models
}

function Test-SingleModel {
    param(
        [string]$ModelName,
        [string]$Endpoint,
        [string]$OutputDir
    )

    Write-Host "Testing model: $ModelName" -ForegroundColor Cyan
    Write-Host ""

    $result = @{
        Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Model = $ModelName
        OllamaEndpoint = $Endpoint
        Measurements = @{
            DownloadTimeSeconds = 0
            DownloadStatus = "Skipped"
        }
    }

    # Test cold start
    Write-Host "[1/2] Measuring cold start..." -ForegroundColor Yellow
    $coldStart = Get-Date
    try {
        $body = @{
            model = $ModelName
            prompt = "Say hello"
            stream = $false
        } | ConvertTo-Json

        $response = Invoke-RestMethod -Uri "$Endpoint/api/generate" -Method Post -Body $body -ContentType "application/json" -TimeoutSec 120
        $coldEnd = Get-Date
        $coldDuration = ($coldEnd - $coldStart).TotalSeconds

        $result.Measurements.LoadTimeColdSeconds = [math]::Round($coldDuration, 2)
        $result.Measurements.LoadStatus = "Success"

        if ($response.eval_count -and $response.eval_duration) {
            $tokensPerSecond = $response.eval_count / ($response.eval_duration / 1000000000)
            $result.Measurements.TokensPerSecond = [math]::Round($tokensPerSecond, 2)
        }

        Write-Host "  Cold start: $($result.Measurements.LoadTimeColdSeconds)s" -ForegroundColor Green
        Write-Host "  Throughput: $($result.Measurements.TokensPerSecond) tok/s" -ForegroundColor Green
    }
    catch {
        Write-Host "  Cold start failed: $_" -ForegroundColor Red
        $result.Measurements.LoadStatus = "Failed"
        return $result
    }

    # Test warm start
    Write-Host "[2/2] Measuring warm start..." -ForegroundColor Yellow
    Start-Sleep -Seconds 2

    $warmStart = Get-Date
    try {
        $body = @{
            model = $ModelName
            prompt = "Say goodbye"
            stream = $false
        } | ConvertTo-Json

        $response = Invoke-RestMethod -Uri "$Endpoint/api/generate" -Method Post -Body $body -ContentType "application/json" -TimeoutSec 120
        $warmEnd = Get-Date
        $warmDuration = ($warmEnd - $warmStart).TotalSeconds

        $result.Measurements.LoadTimeWarmSeconds = [math]::Round($warmDuration, 2)
        Write-Host "  Warm start: $($result.Measurements.LoadTimeWarmSeconds)s" -ForegroundColor Green
    }
    catch {
        Write-Host "  Warm start failed: $_" -ForegroundColor Red
    }

    $result.Measurements.TotalTimeSeconds = $result.Measurements.LoadTimeColdSeconds

    # Save result
    if ($OutputDir) {
        $outputFile = Join-Path $OutputDir "$($ModelName -replace ':', '-').json"
        $result | ConvertTo-Json -Depth 10 | Out-File -FilePath $outputFile -Encoding utf8
    }

    return $result
}

function Test-MultiUser {
    param(
        [string]$ModelName,
        [string]$Endpoint,
        [int]$UserCount,
        [string]$OutputDir
    )

    Write-Header "Multi-User Test: $UserCount concurrent users"

    $result = @{
        Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Model = $ModelName
        OllamaEndpoint = $Endpoint
        ConcurrentUsers = $UserCount
        Measurements = @{}
    }

    # Check model availability
    Write-Host "Checking model availability..." -ForegroundColor Yellow
    try {
        $modelList = Invoke-RestMethod -Uri "$Endpoint/api/tags" -Method GET -TimeoutSec 10
        $modelExists = $modelList.models | Where-Object { $_.name -eq $ModelName }

        if (-not $modelExists) {
            Write-Host "Model $ModelName not found!" -ForegroundColor Red
            $result.Measurements.Status = "Failed"
            $result.Measurements.Error = "Model not found"
            return $result
        }
        Write-Host "Model found: $ModelName" -ForegroundColor Green
    }
    catch {
        Write-Host "Failed to check models: $_" -ForegroundColor Red
        $result.Measurements.Status = "Failed"
        return $result
    }

    Write-Host ""
    Write-Host "Starting $UserCount concurrent requests..." -ForegroundColor Cyan

    $jobs = @()
    $startTime = Get-Date

    # Start concurrent jobs
    for ($i = 1; $i -le $UserCount; $i++) {
        $job = Start-Job -ScriptBlock {
            param($endpoint, $model, $userId)

            $body = @{
                model = $model
                prompt = "User ${userId}: Tell me a short story about AI."
                stream = $false
            } | ConvertTo-Json

            $start = Get-Date
            try {
                $response = Invoke-RestMethod -Uri "$endpoint/api/generate" -Method Post -Body $body -ContentType "application/json" -TimeoutSec 120
                $duration = ((Get-Date) - $start).TotalSeconds

                return @{
                    UserId = $userId
                    Success = $true
                    Duration = $duration
                    TokensGenerated = $response.eval_count
                    TokensPerSecond = $response.eval_count / ($response.eval_duration / 1000000000)
                }
            }
            catch {
                return @{
                    UserId = $userId
                    Success = $false
                    Error = $_.Exception.Message
                }
            }
        } -ArgumentList $Endpoint, $ModelName, $i

        $jobs += $job
        Write-Host "  Started request for User $i" -ForegroundColor Gray
    }

    # Wait for all jobs
    Write-Host ""
    Write-Host "Waiting for all requests to complete..." -ForegroundColor Yellow
    $jobs | Wait-Job | Out-Null
    $endTime = Get-Date
    $totalDuration = ($endTime - $startTime).TotalSeconds

    # Collect results
    $userResults = @()
    $successCount = 0
    foreach ($job in $jobs) {
        $jobResult = Receive-Job -Job $job
        Remove-Job -Job $job

        $userResults += $jobResult
        if ($jobResult.Success) {
            $successCount++
            Write-Host "  User $($jobResult.UserId): $([math]::Round($jobResult.Duration, 2))s, $([math]::Round($jobResult.TokensPerSecond, 2)) tok/s" -ForegroundColor Green
        }
        else {
            Write-Host "  User $($jobResult.UserId): FAILED - $($jobResult.Error)" -ForegroundColor Red
        }
    }

    # Calculate statistics
    $successfulResults = $userResults | Where-Object { $_.Success }
    if ($successfulResults.Count -gt 0) {
        $durations = $successfulResults | ForEach-Object { $_.Duration }
        $throughputs = $successfulResults | ForEach-Object { $_.TokensPerSecond }
        $avgDuration = ($durations | Measure-Object -Average).Average
        $avgThroughput = ($throughputs | Measure-Object -Average).Average

        $result.Measurements.TotalDurationSeconds = [math]::Round($totalDuration, 2)
        $result.Measurements.SuccessfulRequests = $successCount
        $result.Measurements.FailedRequests = $UserCount - $successCount
        $result.Measurements.AverageDurationSeconds = [math]::Round($avgDuration, 2)
        $result.Measurements.AverageTokensPerSecond = [math]::Round($avgThroughput, 2)
        $result.Measurements.Status = "Success"
    }
    else {
        $result.Measurements.Status = "Failed"
        $result.Measurements.Error = "All requests failed"
    }

    $result.UserResults = $userResults

    # Save result
    if ($OutputDir) {
        $outputFile = Join-Path $OutputDir "multi-user-$UserCount.json"
        $result | ConvertTo-Json -Depth 10 | Out-File -FilePath $outputFile -Encoding utf8
    }

    Write-Host ""
    Write-Host "Summary:" -ForegroundColor Cyan
    Write-Host "  Total time: $([math]::Round($totalDuration, 2))s" -ForegroundColor White
    Write-Host "  Successful: $successCount/$UserCount" -ForegroundColor White
    Write-Host "  Avg duration: $([math]::Round($avgDuration, 2))s" -ForegroundColor White
    Write-Host "  Avg throughput: $([math]::Round($avgThroughput, 2)) tok/s" -ForegroundColor White

    return $result
}

function New-HtmlReport {
    Write-Header "Generating HTML Report"

    # Find all result directories
    $resultDirs = Get-ChildItem -Path $scriptDir -Directory -Filter "results-*" | Sort-Object Name -Descending

    if ($resultDirs.Count -eq 0) {
        Write-Host "No benchmark results found!" -ForegroundColor Yellow
        return
    }

    Write-Host "Found $($resultDirs.Count) benchmark result sets" -ForegroundColor Green
    Write-Host ""

    # Collect all results
    $allResults = @{
        SingleUser = @()
        MultiUser = @()
    }

    foreach ($dir in $resultDirs) {
        # Single user results
        $singleUserFiles = Get-ChildItem -Path $dir.FullName -Filter "*.json" -Exclude "multi-user-*.json","summary.json"
        foreach ($file in $singleUserFiles) {
            $content = Get-Content $file.FullName -Raw | ConvertFrom-Json
            $allResults.SingleUser += $content
        }

        # Multi-user results
        $multiUserFiles = Get-ChildItem -Path $dir.FullName -Filter "multi-user-*.json"
        foreach ($file in $multiUserFiles) {
            $content = Get-Content $file.FullName -Raw | ConvertFrom-Json
            $allResults.MultiUser += $content
        }
    }

    # Generate HTML
    $reportPath = Join-Path $scriptDir "benchmark-report.html"

    $html = @"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>LLM Benchmark Results</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); padding: 20px; }
        .container { max-width: 1400px; margin: 0 auto; background: white; border-radius: 15px; box-shadow: 0 20px 60px rgba(0,0,0,0.3); overflow: hidden; }
        .header { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 40px; text-align: center; }
        .header h1 { font-size: 2.5em; margin-bottom: 10px; }
        .header p { font-size: 1.1em; opacity: 0.9; }
        .content { padding: 40px; }
        .summary { display: grid; grid-template-columns: repeat(auto-fit, minmax(250px, 1fr)); gap: 20px; margin-bottom: 40px; }
        .summary-card { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 30px; border-radius: 10px; box-shadow: 0 4px 15px rgba(0,0,0,0.1); }
        .summary-card h3 { font-size: 1.1em; margin-bottom: 15px; opacity: 0.9; }
        .summary-card .value { font-size: 2.5em; font-weight: bold; margin-bottom: 5px; }
        .summary-card .label { font-size: 0.9em; opacity: 0.8; }
        .section { margin-bottom: 50px; }
        .section h2 { color: #667eea; margin-bottom: 20px; padding-bottom: 10px; border-bottom: 3px solid #667eea; }
        table { width: 100%; border-collapse: collapse; margin-top: 20px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        th { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 15px; text-align: left; font-weight: 600; }
        td { padding: 12px 15px; border-bottom: 1px solid #f0f0f0; }
        tr:hover { background-color: #f8f9ff; }
        .status-success { color: #10b981; font-weight: bold; }
        .status-failed { color: #ef4444; font-weight: bold; }
        .metric-good { color: #10b981; font-weight: 600; }
        .metric-medium { color: #f59e0b; font-weight: 600; }
        .metric-poor { color: #ef4444; font-weight: 600; }
        .footer { background: #f8f9fa; padding: 20px; text-align: center; color: #6c757d; font-size: 0.9em; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🚀 LLM Benchmark Results</h1>
            <p>Performance Analysis for Ollama Models</p>
            <p style="font-size: 0.9em; margin-top: 10px;">Generated: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")</p>
        </div>
        <div class="content">
            <div class="summary">
                <div class="summary-card">
                    <h3>Total Benchmarks</h3>
                    <div class="value">$($allResults.SingleUser.Count + $allResults.MultiUser.Count)</div>
                    <div class="label">Test Runs</div>
                </div>
                <div class="summary-card">
                    <h3>Models Tested</h3>
                    <div class="value">$(($allResults.SingleUser | Select-Object -Property Model -Unique).Count)</div>
                    <div class="label">Unique Models</div>
                </div>
                <div class="summary-card">
                    <h3>Avg Throughput</h3>
                    <div class="value">$(
                        $throughputs = $allResults.SingleUser | Where-Object { $null -ne $_.Measurements.TokensPerSecond -and $_.Measurements.TokensPerSecond -gt 0 } | ForEach-Object { $_.Measurements.TokensPerSecond }
                        if ($throughputs.Count -gt 0) { [math]::Round(($throughputs | Measure-Object -Average).Average, 1) } else { "N/A" }
                    )</div>
                    <div class="label">Tokens/Second</div>
                </div>
            </div>
"@

    # Add Single User Results
    if ($allResults.SingleUser.Count -gt 0) {
        $html += @"
            <div class="section">
                <h2>Single User Performance</h2>
                <table>
                    <thead>
                        <tr>
                            <th>Timestamp</th>
                            <th>Model</th>
                            <th>Cold Start (s)</th>
                            <th>Warm Start (s)</th>
                            <th>Throughput (tok/s)</th>
                            <th>Status</th>
                        </tr>
                    </thead>
                    <tbody>
"@
        foreach ($result in $allResults.SingleUser | Sort-Object Timestamp -Descending) {
            $coldClass = if ($result.Measurements.LoadTimeColdSeconds -lt 15) { "metric-good" } elseif ($result.Measurements.LoadTimeColdSeconds -lt 30) { "metric-medium" } else { "metric-poor" }
            $throughputClass = if ($result.Measurements.TokensPerSecond -gt 15) { "metric-good" } elseif ($result.Measurements.TokensPerSecond -gt 10) { "metric-medium" } else { "metric-poor" }
            $statusClass = if ($result.Measurements.LoadStatus -eq "Success") { "status-success" } else { "status-failed" }

            $html += @"
                        <tr>
                            <td>$($result.Timestamp)</td>
                            <td><strong>$($result.Model)</strong></td>
                            <td class="$coldClass">$($result.Measurements.LoadTimeColdSeconds)</td>
                            <td>$($result.Measurements.LoadTimeWarmSeconds)</td>
                            <td class="$throughputClass">$($result.Measurements.TokensPerSecond)</td>
                            <td class="$statusClass">$($result.Measurements.LoadStatus)</td>
                        </tr>
"@
        }
        $html += @"
                    </tbody>
                </table>
            </div>
"@
    }

    # Add Multi-User Results
    if ($allResults.MultiUser.Count -gt 0) {
        $html += @"
            <div class="section">
                <h2>Multi-User Concurrent Tests</h2>
                <table>
                    <thead>
                        <tr>
                            <th>Timestamp</th>
                            <th>Model</th>
                            <th>Users</th>
                            <th>Total Time (s)</th>
                            <th>Success Rate</th>
                            <th>Avg Duration (s)</th>
                            <th>Avg Throughput</th>
                        </tr>
                    </thead>
                    <tbody>
"@
        foreach ($result in $allResults.MultiUser | Sort-Object Timestamp -Descending) {
            $successRate = [math]::Round(($result.Measurements.SuccessfulRequests / $result.ConcurrentUsers) * 100, 1)
            $successClass = if ($successRate -eq 100) { "metric-good" } elseif ($successRate -gt 80) { "metric-medium" } else { "metric-poor" }

            $html += @"
                        <tr>
                            <td>$($result.Timestamp)</td>
                            <td><strong>$($result.Model)</strong></td>
                            <td>$($result.ConcurrentUsers)</td>
                            <td>$($result.Measurements.TotalDurationSeconds)</td>
                            <td class="$successClass">$successRate%</td>
                            <td>$($result.Measurements.AverageDurationSeconds)</td>
                            <td>$($result.Measurements.AverageTokensPerSecond)</td>
                        </tr>
"@
        }
        $html += @"
                    </tbody>
                </table>
            </div>
"@
    }

    $html += @"
        </div>
        <div class="footer">
            <p>Generated by Ollama Benchmark Suite | Results Directory: benchmarks/</p>
        </div>
    </div>
</body>
</html>
"@

    $html | Out-File -FilePath $reportPath -Encoding utf8

    Write-Host "✅ Report generated successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Report saved to: $reportPath" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "To view the report, open it in your browser:" -ForegroundColor Yellow
    Write-Host "  Invoke-Item '$reportPath'" -ForegroundColor Gray
}

function Compare-Results {
    param([string]$DirPath)

    Write-Header "Comparing Results: $DirPath"

    $fullPath = Join-Path $scriptDir $DirPath
    if (-not (Test-Path $fullPath)) {
        Write-Host "Directory not found: $fullPath" -ForegroundColor Red
        return
    }

    $jsonFiles = Get-ChildItem -Path $fullPath -Filter "*.json"
    if ($jsonFiles.Count -eq 0) {
        Write-Host "No JSON results found in directory" -ForegroundColor Yellow
        return
    }

    Write-Host "Found $($jsonFiles.Count) result files:" -ForegroundColor Green
    Write-Host ""

    foreach ($file in $jsonFiles) {
        $result = Get-Content $file.FullName -Raw | ConvertFrom-Json

        Write-Host "📄 $($file.Name)" -ForegroundColor Cyan
        Write-Host "  Model: $($result.Model)" -ForegroundColor White
        Write-Host "  Timestamp: $($result.Timestamp)" -ForegroundColor Gray

        if ($result.Measurements) {
            if ($result.Measurements.LoadTimeColdSeconds) {
                Write-Host "  Cold Start: $($result.Measurements.LoadTimeColdSeconds)s" -ForegroundColor Yellow
            }
            if ($result.Measurements.LoadTimeWarmSeconds) {
                Write-Host "  Warm Start: $($result.Measurements.LoadTimeWarmSeconds)s" -ForegroundColor Yellow
            }
            if ($result.Measurements.TokensPerSecond) {
                Write-Host "  Throughput: $($result.Measurements.TokensPerSecond) tok/s" -ForegroundColor Yellow
            }
            if ($result.ConcurrentUsers) {
                Write-Host "  Concurrent Users: $($result.ConcurrentUsers)" -ForegroundColor Yellow
                Write-Host "  Success Rate: $($result.Measurements.SuccessfulRequests)/$($result.ConcurrentUsers)" -ForegroundColor Yellow
            }
        }
        Write-Host ""
    }
}

#endregion

#region Main Execution

Write-Header "Ollama Benchmark Suite"

switch ($Mode) {
    "Connection" {
        Write-Host "Testing connection to: $OllamaEndpoint" -ForegroundColor Cyan
        Write-Host ""

        if (Test-OllamaConnection -Endpoint $OllamaEndpoint) {
            Write-Host "✅ Connection successful!" -ForegroundColor Green

            try {
                $models = Get-AvailableModels -Endpoint $OllamaEndpoint
                Write-Host ""
                Write-Host "Available models: $($models.Count)" -ForegroundColor Cyan
                $models | ForEach-Object { Write-Host "  - $_" -ForegroundColor White }
            }
            catch {
                Write-Host "Could not list models: $_" -ForegroundColor Yellow
            }
        }
        else {
            Write-Host "❌ Connection failed!" -ForegroundColor Red
            exit 1
        }
    }

    "SingleModel" {
        if (-not $Model) {
            Write-Host "Error: -Model parameter is required for SingleModel mode" -ForegroundColor Red
            exit 1
        }

        Write-Host "Verifying connection..." -ForegroundColor Yellow
        if (-not (Test-OllamaConnection -Endpoint $OllamaEndpoint)) {
            Write-Host "Failed to connect to Ollama API" -ForegroundColor Red
            exit 1
        }
        Write-Host "Connection OK" -ForegroundColor Green
        Write-Host ""

        $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
        $outputDir = Join-Path $scriptDir "results-$timestamp"
        New-Item -ItemType Directory -Path $outputDir -Force | Out-Null

        $result = Test-SingleModel -ModelName $Model -Endpoint $OllamaEndpoint -OutputDir $outputDir

        Write-Host ""
        Write-Host "Results saved to: $outputDir" -ForegroundColor Cyan
    }

    "AllModels" {
        Write-Host "Fetching available models..." -ForegroundColor Yellow
        $models = Get-AvailableModels -Endpoint $OllamaEndpoint

        if ($models.Count -eq 0) {
            Write-Host "No models found!" -ForegroundColor Red
            exit 1
        }

        Write-Host "Found $($models.Count) models:" -ForegroundColor Green
        $models | ForEach-Object { Write-Host "  - $_" -ForegroundColor White }
        Write-Host ""

        $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
        $outputDir = Join-Path $scriptDir "results-$timestamp"
        New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
        Write-Host "Results will be saved to: $outputDir" -ForegroundColor Cyan
        Write-Host ""

        $allResults = @()
        $modelNumber = 1

        foreach ($model in $models) {
            Write-Header "[$modelNumber/$($models.Count)] Testing: $model"

            if (-not (Test-OllamaConnection -Endpoint $OllamaEndpoint)) {
                Write-Host "Connection lost. Stopping tests." -ForegroundColor Red
                break
            }

            $result = Test-SingleModel -ModelName $model -Endpoint $OllamaEndpoint -OutputDir $outputDir
            $allResults += $result

            $modelNumber++

            if ($modelNumber -le $models.Count) {
                Write-Host "Waiting 10 seconds before next model..." -ForegroundColor Gray
                Start-Sleep -Seconds 10
            }
        }

        # Save summary
        $summaryFile = Join-Path $outputDir "summary.json"
        @{
            Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            TotalModels = $models.Count
            Results = $allResults
        } | ConvertTo-Json -Depth 10 | Out-File -FilePath $summaryFile -Encoding utf8

        Write-Header "All Models Benchmark Complete"
        Write-Host "Summary saved to: $summaryFile" -ForegroundColor Cyan
    }

    "MultiUser" {
        if (-not $Model) {
            Write-Host "Error: -Model parameter is required for MultiUser mode" -ForegroundColor Red
            exit 1
        }

        Write-Host "Verifying connection..." -ForegroundColor Yellow
        if (-not (Test-OllamaConnection -Endpoint $OllamaEndpoint)) {
            Write-Host "Failed to connect to Ollama API" -ForegroundColor Red
            exit 1
        }
        Write-Host "Connection OK" -ForegroundColor Green
        Write-Host ""

        $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
        $outputDir = Join-Path $scriptDir "results-$timestamp"
        New-Item -ItemType Directory -Path $outputDir -Force | Out-Null

        $result = Test-MultiUser -ModelName $Model -Endpoint $OllamaEndpoint -UserCount $Users -OutputDir $outputDir

        Write-Host ""
        Write-Host "Results saved to: $outputDir" -ForegroundColor Cyan
    }

    "Report" {
        New-HtmlReport
    }

    "Compare" {
        if (-not $ResultsDir) {
            Write-Host "Error: -ResultsDir parameter is required for Compare mode" -ForegroundColor Red
            exit 1
        }
        Compare-Results -DirPath $ResultsDir
    }
}

Write-Host ""
Write-Host "✅ Done!" -ForegroundColor Green
Write-Host ""

#endregion
