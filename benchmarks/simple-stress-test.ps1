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

# GPU metrics tracking
$global:peakGpuMemory = 0
$global:peakGpuUtil = 0
$global:peakPower = 0
$global:peakTemp = 0
$global:gpuMetricsSamples = 0

function Get-GPUMetrics {
    param([string]$Namespace, [string]$PodName)

    try {
        $gpuQuery = "nvidia-smi --query-gpu=memory.used,utilization.gpu,power.draw,temperature.gpu --format=csv,noheader,nounits"
        $output = kubectl exec -n $Namespace $PodName -- sh -c $gpuQuery 2>$null

        if ($output) {
            $parts = $output -split ','
            if ($parts.Count -eq 4) {
                return @{
                    MemoryMB = [double]$parts[0].Trim()
                    Utilization = [double]$parts[1].Trim()
                    Power = [double]$parts[2].Trim()
                    Temperature = [double]$parts[3].Trim()
                }
            }
        }
    }
    catch { }
    return $null
}

function Start-GPUMonitoring {
    param([string]$Namespace, [string]$PodName, [int]$IntervalSeconds = 5)

    $monitorScript = {
        param($ns, $pod, $interval)

        function Get-Metrics {
            param($ns, $pod)
            try {
                $query = "nvidia-smi --query-gpu=memory.used,utilization.gpu,power.draw,temperature.gpu --format=csv,noheader,nounits"
                $output = kubectl exec -n $ns $pod -- sh -c $query 2>$null
                if ($output) {
                    $parts = $output -split ','
                    if ($parts.Count -eq 4) {
                        return @{
                            MemoryMB = [double]$parts[0].Trim()
                            Utilization = [double]$parts[1].Trim()
                            Power = [double]$parts[2].Trim()
                            Temperature = [double]$parts[3].Trim()
                        }
                    }
                }
            }
            catch { }
            return $null
        }

        while ($true) {
            $metrics = Get-Metrics -ns $ns -pod $pod
            if ($metrics) {
                [PSCustomObject]$metrics | Export-Clixml -Path "$env:TEMP\gpu-metrics-simple.xml" -Force
            }
            Start-Sleep -Seconds $interval
        }
    }

    return Start-Job -ScriptBlock $monitorScript -ArgumentList $Namespace, $PodName, $IntervalSeconds
}

function Stop-GPUMonitoring {
    param([System.Management.Automation.Job]$Job)

    if ($Job) {
        Stop-Job -Job $Job
        Remove-Job -Job $Job
    }
}

function Update-PeakGPUMetrics {
    try {
        $metricsFile = "$env:TEMP\gpu-metrics-simple.xml"
        if (Test-Path $metricsFile) {
            $metrics = Import-Clixml -Path $metricsFile

            $global:peakGpuMemory = [Math]::Max($global:peakGpuMemory, $metrics.MemoryMB)
            $global:peakGpuUtil = [Math]::Max($global:peakGpuUtil, $metrics.Utilization)
            $global:peakPower = [Math]::Max($global:peakPower, $metrics.Power)
            $global:peakTemp = [Math]::Max($global:peakTemp, $metrics.Temperature)
            $global:gpuMetricsSamples++
        }
    }
    catch { }
}

# Start port-forward
Write-Host "Starting port-forward..." -ForegroundColor Green
$portForward = Start-Job -ScriptBlock {
    kubectl port-forward -n ollama svc/ollama 11434:11434
}
Start-Sleep -Seconds 3

# Start GPU monitoring
Write-Host "Starting GPU metrics collection..." -ForegroundColor Green
$ollamaPods = kubectl get pods -n ollama -l app=ollama -o json | ConvertFrom-Json
$ollamaPod = $null
if ($ollamaPods.items -and $ollamaPods.items.Count -gt 0) {
    $ollamaPod = $ollamaPods.items[0].metadata.name
    Write-Host "Monitoring GPU metrics from pod: $ollamaPod" -ForegroundColor Gray
}

$gpuMonitorJob = $null
if ($ollamaPod) {
    $gpuMonitorJob = Start-GPUMonitoring -Namespace "ollama" -PodName $ollamaPod -IntervalSeconds 5
}

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
    if ($gpuMonitorJob) { Stop-GPUMonitoring -Job $gpuMonitorJob }
    $portForward | Stop-Job | Remove-Job
    exit 1
}

# Warmup
Write-Host "Warming up..." -ForegroundColor Green
Write-Host "Note: Large models (gpt-oss, deepseek-r1) may take 60-90 seconds to load..." -ForegroundColor Gray
$warmupBody = @{ model = $Model; prompt = "Test"; stream = $false } | ConvertTo-Json
try {
    # Increase timeout to 180 seconds for large model loading
    $null = Invoke-RestMethod -Uri "$OllamaUrl/api/generate" -Method Post -Body $warmupBody -ContentType "application/json" -TimeoutSec 180
    Write-Host "[OK] Model loaded" -ForegroundColor Green
}
catch {
    Write-Host "[FAIL] Failed to load model: $_" -ForegroundColor Red
    Write-Host "Hint: Large models may need more time. Try with a smaller model first (e.g., phi3.5, llama3.1:8b)" -ForegroundColor Yellow
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

        # Increase timeout to 180 seconds for large models (gpt-oss can take 90+ seconds)
        $response = Invoke-RestMethod -Uri "$Url/api/generate" -Method Post -Body $body -ContentType "application/json" -TimeoutSec 180

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

    # Update GPU metrics
    if ($gpuMonitorJob) {
        Update-PeakGPUMetrics
    }

    # Show progress
    $elapsed = ((Get-Date) - $startTime).TotalSeconds
    $rate = if ($elapsed -gt 0) { [Math]::Round($global:completed / $elapsed, 2) } else { 0 }
    $tokRate = if ($elapsed -gt 0 -and $global:totalTokens -gt 0) { [Math]::Round($global:totalTokens / $elapsed, 1) } else { 0 }

    Write-Host "  Progress: $global:completed/$TotalRequests completed, $global:failed failed | Rate: $rate req/s, $tokRate tok/s" -ForegroundColor Yellow
    Write-Host ""
}

# Stop GPU monitoring
if ($gpuMonitorJob) {
    Update-PeakGPUMetrics  # Get final metrics
    Stop-GPUMonitoring -Job $gpuMonitorJob
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

# Display GPU metrics if available
if ($global:gpuMetricsSamples -gt 0) {
    Write-Host ""
    Write-Host "=== GPU Metrics ===" -ForegroundColor Cyan
    Write-Host "Peak GPU Memory: $([math]::Round($global:peakGpuMemory, 2)) MB ($([math]::Round($global:peakGpuMemory/1024, 2)) GB)" -ForegroundColor White
    Write-Host "Peak GPU Utilization: $([math]::Round($global:peakGpuUtil, 1))%" -ForegroundColor White
    Write-Host "Peak Power Draw: $([math]::Round($global:peakPower, 1)) W" -ForegroundColor White
    Write-Host "Peak Temperature: $([math]::Round($global:peakTemp, 1)) °C" -ForegroundColor White
    Write-Host "Samples Collected: $($global:gpuMetricsSamples)" -ForegroundColor Gray
}
else {
    Write-Host ""
    Write-Host "Note: GPU metrics collection unavailable. Check that Ollama pods are running." -ForegroundColor Yellow
}

# Cleanup
Write-Host ""
Write-Host "Cleaning up..." -ForegroundColor Yellow
$portForward | Stop-Job | Remove-Job -Force

# Clean up GPU metrics temp file
$metricsFile = "$env:TEMP\gpu-metrics-simple.xml"
if (Test-Path $metricsFile) {
    Remove-Item -Path $metricsFile -Force -ErrorAction SilentlyContinue
}

Write-Host ""
Write-Host "=== Test Complete ===" -ForegroundColor Green
Write-Host "Check current GPU state with: kubectl exec -n ollama ollama-0 -- nvidia-smi" -ForegroundColor Gray
