# Test Horizontal Scaling and Model Switching
# Demonstrates autoscaling behavior and model availability
# Usage: .\test-scaling.ps1 [-LoadTest] [-MonitorOnly]

param(
    [switch]$LoadTest,      # Generate load to trigger scaling
    [switch]$MonitorOnly    # Just monitor current state
)

# Color output functions
function Write-Header { param($Message) Write-Host "`n=== $Message ===" -ForegroundColor Cyan }
function Write-Info { param($Message) Write-Host "[INFO] $Message" -ForegroundColor Blue }
function Write-Success { param($Message) Write-Host "[SUCCESS] $Message" -ForegroundColor Green }
function Write-Warning { param($Message) Write-Host "[WARNING] $Message" -ForegroundColor Yellow }
function Write-Error { param($Message) Write-Host "[ERROR] $Message" -ForegroundColor Red }

# Get Open-WebUI service IP
Write-Header "Getting Open-WebUI Service IP"
$webuiService = kubectl get svc open-webui-service -n ollama -o json | ConvertFrom-Json
$webuiIp = $webuiService.status.loadBalancer.ingress[0].ip
Write-Info "Open-WebUI: http://$webuiIp"

# Get Ollama service endpoint (internal)
$ollamaService = "http://ollama-service.ollama.svc.cluster.local:11434"
Write-Info "Ollama Service: $ollamaService"

# Function to get pod metrics
function Get-PodMetrics {
    Write-Header "Current Pod Status"

    # Open-WebUI pods
    Write-Info "`nOpen-WebUI Pods:"
    kubectl get pods -n ollama -l app.kubernetes.io/name=open-webui -o wide

    # Ollama pods
    Write-Info "`nOllama Pods:"
    kubectl get pods -n ollama -l app=ollama -o wide

    # HPA status
    Write-Info "`nHorizontal Pod Autoscalers:"
    kubectl get hpa -n ollama
}

# Function to get loaded models
function Get-LoadedModels {
    Write-Header "Loaded Models per Ollama Pod"

    $ollamaPods = kubectl get pods -n ollama -l app=ollama -o json | ConvertFrom-Json

    foreach ($pod in $ollamaPods.items) {
        $podName = $pod.metadata.name
        $nodeName = $pod.spec.nodeName
        Write-Info "`nPod: $podName (Node: $nodeName)"

        try {
            $models = kubectl exec -n ollama $podName -- curl -s http://localhost:11434/api/tags | ConvertFrom-Json
            if ($models.models) {
                foreach ($model in $models.models) {
                    Write-Host "  - $($model.name) (Size: $([math]::Round($model.size / 1GB, 2))GB)" -ForegroundColor Green
                }
            } else {
                Write-Warning "  No models loaded in memory"
            }
        } catch {
            Write-Error "  Failed to query models: $_"
        }
    }
}

# Function to test model inference
function Test-ModelInference {
    param([string]$Model, [string]$Prompt)

    Write-Header "Testing Model: $Model"

    # Find an Ollama pod
    $ollamaPods = kubectl get pods -n ollama -l app=ollama -o json | ConvertFrom-Json
    $pod = $ollamaPods.items[0].metadata.name

    Write-Info "Using pod: $pod"
    Write-Info "Prompt: $Prompt"

    $requestBody = @{
        model = $Model
        prompt = $Prompt
        stream = $false
    } | ConvertTo-Json

    $startTime = Get-Date

    try {
        $response = kubectl exec -n ollama $pod -- curl -s -X POST http://localhost:11434/api/generate `
            -H "Content-Type: application/json" `
            -d $requestBody | ConvertFrom-Json

        $duration = (Get-Date) - $startTime

        Write-Success "Response received in $($duration.TotalSeconds) seconds"
        Write-Host "`nResponse: $($response.response)" -ForegroundColor White

        return $true
    } catch {
        Write-Error "Inference failed: $_"
        return $false
    }
}

# Function to generate load
function Start-LoadTest {
    param([int]$Requests = 20, [int]$Concurrent = 5)

    Write-Header "Starting Load Test"
    Write-Info "Requests: $Requests, Concurrent: $Concurrent"
    Write-Info "This will trigger autoscaling if thresholds are exceeded"

    # Test multiple models concurrently
    $models = @("phi3.5", "gemma2:2b", "llama3.1:8b")
    $prompts = @(
        "What is Kubernetes?",
        "Explain Azure Files in one sentence.",
        "What are the benefits of GPU acceleration?",
        "How does horizontal pod autoscaling work?",
        "What is a container?"
    )

    $jobs = @()

    for ($i = 0; $i -lt $Requests; $i++) {
        $model = $models[$i % $models.Count]
        $prompt = $prompts[$i % $prompts.Count]

        Write-Info "Request $($i + 1): $model - '$prompt'"

        # Use kubectl exec to send requests
        $scriptBlock = {
            param($Namespace, $Model, $Prompt)

            $pods = kubectl get pods -n $Namespace -l app=ollama -o json | ConvertFrom-Json
            $pod = $pods.items[0].metadata.name

            $body = @{
                model = $Model
                prompt = $Prompt
                stream = $false
            } | ConvertTo-Json -Compress

            kubectl exec -n $Namespace $pod -- curl -s -X POST http://localhost:11434/api/generate `
                -H "Content-Type: application/json" `
                -d "$body" 2>&1
        }

        # Start job
        $job = Start-Job -ScriptBlock $scriptBlock -ArgumentList "ollama", $model, $prompt
        $jobs += $job

        # Limit concurrent jobs
        while (($jobs | Where-Object { $_.State -eq 'Running' }).Count -ge $Concurrent) {
            Start-Sleep -Milliseconds 500
        }
    }

    Write-Info "Waiting for all requests to complete..."
    $jobs | Wait-Job | Out-Null

    $successful = ($jobs | Where-Object { $_.State -eq 'Completed' }).Count
    $failed = ($jobs | Where-Object { $_.State -eq 'Failed' }).Count

    Write-Success "Load test complete: $successful successful, $failed failed"

    # Cleanup jobs
    $jobs | Remove-Job
}

# Function to monitor scaling
function Watch-Scaling {
    param([int]$Duration = 300)  # 5 minutes default

    Write-Header "Monitoring Scaling Events"
    Write-Info "Duration: $Duration seconds (Ctrl+C to stop early)"

    $endTime = (Get-Date).AddSeconds($Duration)

    while ((Get-Date) -lt $endTime) {
        Clear-Host
        Write-Host "=== Autoscaling Monitor ===" -ForegroundColor Cyan
        Write-Host "Time: $(Get-Date -Format 'HH:mm:ss')" -ForegroundColor Gray
        Write-Host "Remaining: $([math]::Round(($endTime - (Get-Date)).TotalSeconds)) seconds`n" -ForegroundColor Gray

        # HPA status
        Write-Host "Horizontal Pod Autoscalers:" -ForegroundColor Yellow
        kubectl get hpa -n ollama

        Write-Host "`nPod Status:" -ForegroundColor Yellow
        kubectl get pods -n ollama -l 'app in (ollama,open-webui)' -o wide

        Write-Host "`nNode Status:" -ForegroundColor Yellow
        kubectl get nodes -l gpu=true -o wide

        Start-Sleep -Seconds 10
    }
}

# Main execution
Write-Header "Kubernetes Horizontal Scaling Test"

if ($MonitorOnly) {
    # Just show current state
    Get-PodMetrics
    Get-LoadedModels
} elseif ($LoadTest) {
    # Run load test
    Get-PodMetrics
    Write-Info "`nBaseline established. Starting load test in 5 seconds..."
    Start-Sleep -Seconds 5

    Start-LoadTest -Requests 30 -Concurrent 10

    Write-Info "`nLoad test complete. Monitoring for scale-up..."
    Watch-Scaling -Duration 180

    Get-PodMetrics
} else {
    # Interactive demo
    Get-PodMetrics
    Write-Host "`n"

    Write-Info "Testing model switching..."
    Test-ModelInference -Model "phi3.5" -Prompt "What is Kubernetes in one sentence?"

    Start-Sleep -Seconds 2

    Test-ModelInference -Model "gemma2:2b" -Prompt "Explain Azure in one sentence?"

    Write-Host "`n"
    Get-LoadedModels

    Write-Host "`n=== Demo Complete ===" -ForegroundColor Green
    Write-Host "To run load test: .\test-scaling.ps1 -LoadTest" -ForegroundColor Cyan
    Write-Host "To monitor only: .\test-scaling.ps1 -MonitorOnly" -ForegroundColor Cyan
}
