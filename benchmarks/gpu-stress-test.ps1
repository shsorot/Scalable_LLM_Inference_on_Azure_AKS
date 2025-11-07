# GPU Stress Test for Ollama
# This script runs concurrent inference requests to stress test GPU utilization

param(
    [int]$ConcurrentRequests = 5,
    [int]$DurationSeconds = 120,
    [string]$Model = "tinyllama",
    [string]$OllamaUrl = "http://localhost:11434"
)

Write-Host "=== Ollama GPU Stress Test ===" -ForegroundColor Cyan
Write-Host "Model: $Model" -ForegroundColor Yellow
Write-Host "Concurrent Requests: $ConcurrentRequests" -ForegroundColor Yellow
Write-Host "Duration: $DurationSeconds seconds" -ForegroundColor Yellow
Write-Host "Ollama URL: $OllamaUrl" -ForegroundColor Yellow
Write-Host ""

# Test prompts to use
$prompts = @(
    "Explain quantum computing in simple terms.",
    "Write a short story about a robot learning to paint.",
    "What are the key principles of software engineering?",
    "Describe the process of photosynthesis step by step.",
    "Explain the history of artificial intelligence.",
    "What makes a good leader? Provide examples.",
    "Describe how neural networks work.",
    "Write a poem about the ocean.",
    "Explain the theory of relativity.",
    "What are the benefits of renewable energy?"
)

# Stats tracking
$script:totalRequests = 0
$script:successfulRequests = 0
$script:failedRequests = 0
$script:totalTokens = 0
$script:totalDuration = 0
$script:mutex = New-Object System.Threading.Mutex($false, "StatsLock")

# Worker function
$workerScript = {
    param($OllamaUrl, $Model, $Prompts, $EndTime, $WorkerId, $StatsMutex)

    $requestCount = 0
    $random = New-Object System.Random

    while ([DateTime]::Now -lt $EndTime) {
        try {
            $prompt = $Prompts[$random.Next(0, $Prompts.Count)]

            $body = @{
                model = $Model
                prompt = $prompt
                stream = $false
                options = @{
                    num_predict = 150
                    temperature = 0.8
                }
            } | ConvertTo-Json

            $startTime = Get-Date
            $response = Invoke-RestMethod -Uri "$OllamaUrl/api/generate" -Method Post -Body $body -ContentType "application/json" -TimeoutSec 60
            $duration = ((Get-Date) - $startTime).TotalMilliseconds

            # Update stats
            $null = $StatsMutex.WaitOne()
            try {
                $script:totalRequests++
                $script:successfulRequests++
                $script:totalTokens += $response.eval_count
                $script:totalDuration += $duration
            }
            finally {
                $StatsMutex.ReleaseMutex()
            }

            $requestCount++

        }
        catch {
            $null = $StatsMutex.WaitOne()
            try {
                $script:totalRequests++
                $script:failedRequests++
            }
            finally {
                $StatsMutex.ReleaseMutex()
            }
        }
    }

    return $requestCount
}

Write-Host "Starting port-forward to Ollama service..." -ForegroundColor Green
$portForwardJob = Start-Job -ScriptBlock {
    kubectl port-forward -n ollama svc/ollama 11434:11434
}

Start-Sleep -Seconds 3

Write-Host "Testing connection to Ollama..." -ForegroundColor Green
try {
    $tags = Invoke-RestMethod -Uri "$OllamaUrl/api/tags" -Method Get -TimeoutSec 10
    Write-Host "[OK] Connected to Ollama" -ForegroundColor Green
    Write-Host "Available models: $($tags.models.name -join ', ')" -ForegroundColor Gray
}
catch {
    Write-Host "[FAIL] Failed to connect to Ollama. Make sure the service is running." -ForegroundColor Red
    $portForwardJob | Stop-Job | Remove-Job
    exit 1
}

Write-Host ""
Write-Host "Warming up GPU with model load..." -ForegroundColor Green
try {
    $warmupBody = @{
        model = $Model
        prompt = "Hello"
        stream = $false
    } | ConvertTo-Json
    $warmup = Invoke-RestMethod -Uri "$OllamaUrl/api/generate" -Method Post -Body $warmupBody -ContentType "application/json" -TimeoutSec 30
    Write-Host "[OK] Model loaded on GPU" -ForegroundColor Green
}
catch {
    Write-Host "[FAIL] Failed to load model: $_" -ForegroundColor Red
    $portForwardJob | Stop-Job | Remove-Job
    exit 1
}

Write-Host ""
Write-Host "=== Starting GPU Stress Test ===" -ForegroundColor Cyan
Write-Host "Monitor your Grafana dashboard now!" -ForegroundColor Yellow
Write-Host ""

$endTime = (Get-Date).AddSeconds($DurationSeconds)
$jobs = @()

# Start worker jobs
for ($i = 1; $i -le $ConcurrentRequests; $i++) {
    $jobs += Start-Job -ScriptBlock $workerScript -ArgumentList $OllamaUrl, $Model, $prompts, $endTime, $i, $script:mutex
}

# Monitor progress
$startTime = Get-Date
while ((Get-Date) -lt $endTime) {
    Start-Sleep -Seconds 5

    $elapsed = ((Get-Date) - $startTime).TotalSeconds
    $remaining = $DurationSeconds - $elapsed

    $script:mutex.WaitOne() | Out-Null
    $currentTotal = $script:totalRequests
    $currentSuccess = $script:successfulRequests
    $currentFailed = $script:failedRequests
    $currentTokens = $script:totalTokens
    $currentDuration = $script:totalDuration
    $script:mutex.ReleaseMutex()

    $avgDuration = if ($currentSuccess -gt 0) { [math]::Round($currentDuration / $currentSuccess, 2) } else { 0 }
    $tokensPerSec = if ($elapsed -gt 0 -and $currentTokens -gt 0) { [math]::Round($currentTokens / $elapsed, 2) } else { 0 }
    $reqPerSec = if ($elapsed -gt 0) { [math]::Round($currentSuccess / $elapsed, 2) } else { 0 }

    Write-Host ("[{0:mm\:ss}] Requests: {1} (OK:{2} FAIL:{3}) | Tokens: {4} | Avg: {5}ms | Rate: {6} req/s, {7} tok/s" -f `
        [TimeSpan]::FromSeconds($elapsed), $currentTotal, $currentSuccess, $currentFailed, $currentTokens, $avgDuration, $reqPerSec, $tokensPerSec) `
        -ForegroundColor Cyan
}

Write-Host ""
Write-Host "Waiting for workers to complete..." -ForegroundColor Yellow
$jobs | Wait-Job | Out-Null

Write-Host ""
Write-Host "=== Final Statistics ===" -ForegroundColor Cyan
Write-Host "Total Requests: $($script:totalRequests)" -ForegroundColor White
Write-Host "Successful: $($script:successfulRequests)" -ForegroundColor Green
Write-Host "Failed: $($script:failedRequests)" -ForegroundColor $(if($script:failedRequests -gt 0){"Red"}else{"Green"})
Write-Host "Total Tokens Generated: $($script:totalTokens)" -ForegroundColor White

$totalElapsed = ((Get-Date) - $startTime).TotalSeconds
$avgDuration = if ($script:successfulRequests -gt 0) { [math]::Round($script:totalDuration / $script:successfulRequests, 2) } else { 0 }
$tokensPerSec = if ($totalElapsed -gt 0 -and $script:totalTokens -gt 0) { [math]::Round($script:totalTokens / $totalElapsed, 2) } else { 0 }
$reqPerSec = if ($totalElapsed -gt 0) { [math]::Round($script:successfulRequests / $totalElapsed, 2) } else { 0 }

Write-Host "Average Request Duration: ${avgDuration}ms" -ForegroundColor White
Write-Host "Requests per Second: $reqPerSec" -ForegroundColor White
Write-Host "Tokens per Second: $tokensPerSec" -ForegroundColor White
Write-Host "Test Duration: $([math]::Round($totalElapsed, 2)) seconds" -ForegroundColor White

# Cleanup
Write-Host ""
Write-Host "Cleaning up..." -ForegroundColor Yellow
$jobs | Remove-Job -Force
$portForwardJob | Stop-Job | Remove-Job -Force

Write-Host ""
Write-Host "=== GPU Stress Test Complete ===" -ForegroundColor Green
Write-Host "Check nvidia-smi for GPU metrics:" -ForegroundColor Yellow
Write-Host "  kubectl exec -n ollama ollama-0 -- nvidia-smi" -ForegroundColor Gray
