# Simple GPU Stress Test for Ollama
# Runs multiple concurrent inference requests

param(
    [int]$Concurrent = 5,
    [int]$TotalRequests = 100,
    [string]$Model = "tinyllama",
    [string]$OllamaUrl = "http://localhost:11434"
)

Write-Host "=== Ollama GPU Stress Test ===" -ForegroundColor Cyan
Write-Host "Model: $Model" -ForegroundColor Yellow
Write-Host "Concurrent Requests: $Concurrent" -ForegroundColor Yellow
Write-Host "Total Requests: $TotalRequests" -ForegroundColor Yellow
Write-Host ""

# Start port-forward
Write-Host "Starting port-forward..." -ForegroundColor Green
$portForward = Start-Job -ScriptBlock {
    kubectl port-forward -n ollama svc/ollama 11434:11434
}
Start-Sleep -Seconds 3

# Test prompts
$prompts = @(
    "Explain quantum computing in detail with examples.",
    "Write a creative story about a robot learning emotions.",
    "What are the fundamental principles of machine learning?",
    "Describe the complete photosynthesis process.",
    "Explain the entire history of artificial intelligence.",
    "What makes an effective leader? Provide detailed examples.",
    "Describe neural networks architecture in depth.",
    "Write an extended poem about nature and technology.",
    "Explain Einstein's theory of relativity thoroughly.",
    "Discuss renewable energy benefits and challenges."
)

# Test connection
try {
    $null = Invoke-RestMethod -Uri "$OllamaUrl/api/tags" -Method Get -TimeoutSec 5
    Write-Host "[OK] Connected to Ollama" -ForegroundColor Green
}
catch {
    Write-Host "[FAIL] Cannot connect to Ollama" -ForegroundColor Red
    $portForward | Stop-Job | Remove-Job
    exit 1
}

# Warmup
Write-Host "Warming up..." -ForegroundColor Green
$warmupBody = @{ model = $Model; prompt = "Test"; stream = $false } | ConvertTo-Json
try {
    $null = Invoke-RestMethod -Uri "$OllamaUrl/api/generate" -Method Post -Body $warmupBody -ContentType "application/json" -TimeoutSec 30
    Write-Host "[OK] Model loaded" -ForegroundColor Green
}
catch {
    Write-Host "[FAIL] Failed to load model" -ForegroundColor Red
    $portForward | Stop-Job | Remove-Job
    exit 1
}

Write-Host ""
Write-Host "=== Starting Load Test ===" -ForegroundColor Cyan
Write-Host "Monitor your Grafana dashboard now!" -ForegroundColor Yellow
Write-Host ""

$global:completed = 0
$global:failed = 0
$global:totalTokens = 0
$startTime = Get-Date

# Function to make request
function Invoke-InferenceRequest {
    param($Url, $Model, $Prompt, $Index)

    try {
        $body = @{
            model = $Model
            prompt = $Prompt
            stream = $false
            options = @{
                num_predict = 200
                temperature = 0.8
            }
        } | ConvertTo-Json

        $response = Invoke-RestMethod -Uri "$Url/api/generate" -Method Post -Body $body -ContentType "application/json" -TimeoutSec 120

        return @{
            Success = $true
            Tokens = $response.eval_count
            Duration = $response.total_duration / 1000000
        }
    }
    catch {
        return @{
            Success = $false
            Error = $_.Exception.Message
        }
    }
}

# Run requests in batches
$batchSize = $Concurrent
$totalBatches = [Math]::Ceiling($TotalRequests / $batchSize)

for ($batch = 0; $batch -lt $totalBatches; $batch++) {
    $batchStart = $batch * $batchSize
    $batchEnd = [Math]::Min($batchStart + $batchSize, $TotalRequests)
    $batchCount = $batchEnd - $batchStart

    Write-Host "Batch $($batch + 1)/$totalBatches (Requests $batchStart-$($batchEnd-1))..." -ForegroundColor Cyan

    # Create jobs for this batch
    $jobs = @()
    for ($i = 0; $i -lt $batchCount; $i++) {
        $requestIndex = $batchStart + $i
        $prompt = $prompts[$requestIndex % $prompts.Count]

        $jobs += Start-Job -ScriptBlock ${function:Invoke-InferenceRequest} -ArgumentList $OllamaUrl, $Model, $prompt, $requestIndex
    }

    # Wait for batch to complete
    $jobs | Wait-Job | Out-Null

    # Collect results
    foreach ($job in $jobs) {
        $result = Receive-Job -Job $job
        if ($result.Success) {
            $global:completed++
            $global:totalTokens += $result.Tokens
            Write-Host "  [$global:completed/$TotalRequests] OK - $($result.Tokens) tokens, $([Math]::Round($result.Duration, 0))ms" -ForegroundColor Green
        }
        else {
            $global:failed++
            Write-Host "  [FAILED] $($result.Error)" -ForegroundColor Red
        }
    }

    # Cleanup jobs
    $jobs | Remove-Job -Force

    # Show progress
    $elapsed = ((Get-Date) - $startTime).TotalSeconds
    $rate = if ($elapsed -gt 0) { [Math]::Round($global:completed / $elapsed, 2) } else { 0 }
    $tokRate = if ($elapsed -gt 0 -and $global:totalTokens -gt 0) { [Math]::Round($global:totalTokens / $elapsed, 1) } else { 0 }

    Write-Host "  Progress: $global:completed/$TotalRequests completed, $global:failed failed | Rate: $rate req/s, $tokRate tok/s" -ForegroundColor Yellow
    Write-Host ""
}

# Final stats
$totalTime = ((Get-Date) - $startTime).TotalSeconds

Write-Host ""
Write-Host "=== Final Results ===" -ForegroundColor Cyan
Write-Host "Completed: $global:completed" -ForegroundColor Green
Write-Host "Failed: $global:failed" -ForegroundColor $(if ($global:failed -gt 0) { "Red" } else { "Green" })
Write-Host "Total Tokens: $global:totalTokens" -ForegroundColor White
Write-Host "Total Time: $([Math]::Round($totalTime, 2))s" -ForegroundColor White
Write-Host "Avg Rate: $([Math]::Round($global:completed / $totalTime, 2)) req/s" -ForegroundColor White
Write-Host "Avg Token Rate: $([Math]::Round($global:totalTokens / $totalTime, 1)) tok/s" -ForegroundColor White

# Cleanup
Write-Host ""
Write-Host "Cleaning up..." -ForegroundColor Yellow
$portForward | Stop-Job | Remove-Job -Force

Write-Host ""
Write-Host "=== Test Complete ===" -ForegroundColor Green
Write-Host "Check GPU usage with: kubectl exec -n ollama ollama-0 -- nvidia-smi" -ForegroundColor Gray
