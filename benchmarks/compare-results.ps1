<#
.SYNOPSIS
    Compare benchmark results from multiple runs

.DESCRIPTION
    Analyzes and compares benchmark results across different runs.
    Useful for comparing storage configurations, scaling behavior, etc.

.PARAMETER ResultFiles
    Array of JSON result files to compare

.PARAMETER OutputFile
    Path to save comparison report (optional)

.EXAMPLE
    .\compare-results.ps1 -ResultFiles @("results-20251031-120000\single-user.json", "results-20251031-130000\single-user.json")

.EXAMPLE
    .\compare-results.ps1 -ResultFiles (Get-ChildItem -Path results-* -Filter "single-user.json" -Recurse).FullName
#>

param(
    [Parameter(Mandatory=$true)]
    [string[]]$ResultFiles,

    [Parameter(Mandatory=$false)]
    [string]$OutputFile = ""
)

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Benchmark Results Comparison" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Load all result files
$results = @()
foreach ($file in $ResultFiles) {
    if (Test-Path $file) {
        try {
            $content = Get-Content -Path $file -Raw | ConvertFrom-Json
            $results += @{
                File = (Get-Item $file).Name
                Path = $file
                Data = $content
            }
            Write-Host "✓ Loaded: $file" -ForegroundColor Green
        }
        catch {
            Write-Warning "✗ Failed to load: $file ($_)"
        }
    }
    else {
        Write-Warning "✗ File not found: $file"
    }
}

if ($results.Count -eq 0) {
    Write-Error "No valid result files loaded."
    exit 1
}

Write-Host ""
Write-Host "Loaded $($results.Count) result files" -ForegroundColor Cyan
Write-Host ""

# Determine result type
$firstResult = $results[0].Data
$isSingleUser = $firstResult.Measurements -ne $null
$isMultiUser = $firstResult.Summary -ne $null

if ($isSingleUser) {
    Write-Host "Result Type: Single User Benchmarks" -ForegroundColor Yellow
    Write-Host ""

    # Create comparison table
    $comparisonTable = @()

    foreach ($result in $results) {
        $data = $result.Data
        $comparisonTable += [PSCustomObject]@{
            File = $result.File
            Timestamp = $data.Timestamp
            Model = $data.Model
            DownloadTime = "$($data.Measurements.DownloadTimeSeconds)s"
            LoadTimeCold = "$($data.Measurements.LoadTimeColdSeconds)s"
            LoadTimeWarm = "$($data.Measurements.LoadTimeWarmSeconds)s"
            TotalTime = "$($data.Measurements.TotalTimeSeconds)s"
            Throughput = "$($data.Measurements.TokensPerSecond) tok/s"
        }
    }

    $comparisonTable | Format-Table -AutoSize

    # Statistical summary
    Write-Host ""
    Write-Host "Statistical Summary:" -ForegroundColor Yellow

    $downloadTimes = $results | ForEach-Object { $_.Data.Measurements.DownloadTimeSeconds }
    $loadTimesCold = $results | ForEach-Object { $_.Data.Measurements.LoadTimeColdSeconds }
    $loadTimesWarm = $results | ForEach-Object { $_.Data.Measurements.LoadTimeWarmSeconds }
    $totalTimes = $results | ForEach-Object { $_.Data.Measurements.TotalTimeSeconds }

    Write-Host ""
    Write-Host "Download Times:" -ForegroundColor White
    Write-Host "  Average: $([math]::Round(($downloadTimes | Measure-Object -Average).Average, 2))s"
    Write-Host "  Min: $([math]::Round(($downloadTimes | Measure-Object -Minimum).Minimum, 2))s"
    Write-Host "  Max: $([math]::Round(($downloadTimes | Measure-Object -Maximum).Maximum, 2))s"
    Write-Host "  StdDev: $([math]::Round([Math]::Sqrt((($downloadTimes | ForEach-Object {[Math]::Pow(($_ - ($downloadTimes | Measure-Object -Average).Average), 2)} | Measure-Object -Sum).Sum / $downloadTimes.Count)), 2))s"

    Write-Host ""
    Write-Host "Load Times (Cold):" -ForegroundColor White
    Write-Host "  Average: $([math]::Round(($loadTimesCold | Measure-Object -Average).Average, 2))s"
    Write-Host "  Min: $([math]::Round(($loadTimesCold | Measure-Object -Minimum).Minimum, 2))s"
    Write-Host "  Max: $([math]::Round(($loadTimesCold | Measure-Object -Maximum).Maximum, 2))s"
    Write-Host "  StdDev: $([math]::Round([Math]::Sqrt((($loadTimesCold | ForEach-Object {[Math]::Pow(($_ - ($loadTimesCold | Measure-Object -Average).Average), 2)} | Measure-Object -Sum).Sum / $loadTimesCold.Count)), 2))s"

    Write-Host ""
    Write-Host "Total Times:" -ForegroundColor White
    Write-Host "  Average: $([math]::Round(($totalTimes | Measure-Object -Average).Average, 2))s"
    Write-Host "  Min: $([math]::Round(($totalTimes | Measure-Object -Minimum).Minimum, 2))s"
    Write-Host "  Max: $([math]::Round(($totalTimes | Measure-Object -Maximum).Maximum, 2))s"
    Write-Host "  StdDev: $([math]::Round([Math]::Sqrt((($totalTimes | ForEach-Object {[Math]::Pow(($_ - ($totalTimes | Measure-Object -Average).Average), 2)} | Measure-Object -Sum).Sum / $totalTimes.Count)), 2))s"
}
elseif ($isMultiUser) {
    Write-Host "Result Type: Multi-User Benchmarks" -ForegroundColor Yellow
    Write-Host ""

    # Create comparison table
    $comparisonTable = @()

    foreach ($result in $results) {
        $data = $result.Data
        $comparisonTable += [PSCustomObject]@{
            File = $result.File
            Timestamp = $data.Timestamp
            ConcurrentUsers = $data.ConcurrentUsers
            OverallDuration = "$($data.Summary.OverallDurationSeconds)s"
            SuccessRate = "$($data.Summary.SuccessRate)%"
            AvgDownload = "$($data.Summary.AverageDownloadTimeSeconds)s"
            AvgLoad = "$($data.Summary.AverageLoadTimeSeconds)s"
            AvgThroughput = "$($data.Summary.AverageThroughputTokensPerSecond) tok/s"
        }
    }

    $comparisonTable | Format-Table -AutoSize

    # Statistical summary
    Write-Host ""
    Write-Host "Statistical Summary:" -ForegroundColor Yellow

    $overallDurations = $results | ForEach-Object { $_.Data.Summary.OverallDurationSeconds }
    $avgDownloadTimes = $results | ForEach-Object { $_.Data.Summary.AverageDownloadTimeSeconds }
    $avgLoadTimes = $results | ForEach-Object { $_.Data.Summary.AverageLoadTimeSeconds }

    Write-Host ""
    Write-Host "Overall Duration:" -ForegroundColor White
    Write-Host "  Average: $([math]::Round(($overallDurations | Measure-Object -Average).Average, 2))s"
    Write-Host "  Min: $([math]::Round(($overallDurations | Measure-Object -Minimum).Minimum, 2))s"
    Write-Host "  Max: $([math]::Round(($overallDurations | Measure-Object -Maximum).Maximum, 2))s"

    Write-Host ""
    Write-Host "Average Download Times:" -ForegroundColor White
    Write-Host "  Average: $([math]::Round(($avgDownloadTimes | Measure-Object -Average).Average, 2))s"
    Write-Host "  Min: $([math]::Round(($avgDownloadTimes | Measure-Object -Minimum).Minimum, 2))s"
    Write-Host "  Max: $([math]::Round(($avgDownloadTimes | Measure-Object -Maximum).Maximum, 2))s"

    Write-Host ""
    Write-Host "Average Load Times:" -ForegroundColor White
    Write-Host "  Average: $([math]::Round(($avgLoadTimes | Measure-Object -Average).Average, 2))s"
    Write-Host "  Min: $([math]::Round(($avgLoadTimes | Measure-Object -Minimum).Minimum, 2))s"
    Write-Host "  Max: $([math]::Round(($avgLoadTimes | Measure-Object -Maximum).Maximum, 2))s"

    # Scaling efficiency
    if ($results.Count -gt 1) {
        Write-Host ""
        Write-Host "Scaling Analysis:" -ForegroundColor Yellow

        # Sort by concurrent users
        $sorted = $results | Sort-Object { $_.Data.ConcurrentUsers }

        for ($i = 1; $i -lt $sorted.Count; $i++) {
            $prev = $sorted[$i-1].Data
            $curr = $sorted[$i].Data

            $userRatio = $curr.ConcurrentUsers / $prev.ConcurrentUsers
            $timeRatio = $curr.Summary.OverallDurationSeconds / $prev.Summary.OverallDurationSeconds
            $efficiency = ($userRatio / $timeRatio) * 100

            Write-Host ""
            Write-Host "  $($prev.ConcurrentUsers) → $($curr.ConcurrentUsers) users:"
            Write-Host "    Time increase: $([math]::Round($timeRatio, 2))x"
            Write-Host "    Scaling efficiency: $([math]::Round($efficiency, 1))%"

            if ($efficiency -gt 80) {
                Write-Host "    Assessment: Excellent scaling" -ForegroundColor Green
            }
            elseif ($efficiency -gt 60) {
                Write-Host "    Assessment: Good scaling" -ForegroundColor Yellow
            }
            else {
                Write-Host "    Assessment: Resource contention detected" -ForegroundColor Red
            }
        }
    }
}

# Save comparison if output file specified
if (-not [string]::IsNullOrEmpty($OutputFile)) {
    $comparison = @{
        Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        ResultType = if ($isSingleUser) { "SingleUser" } else { "MultiUser" }
        FilesCompared = $results.Count
        ComparisonTable = $comparisonTable
    }

    $comparison | ConvertTo-Json -Depth 10 | Out-File -FilePath $OutputFile -Encoding utf8
    Write-Host ""
    Write-Host "Comparison saved to: $OutputFile" -ForegroundColor Cyan
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
