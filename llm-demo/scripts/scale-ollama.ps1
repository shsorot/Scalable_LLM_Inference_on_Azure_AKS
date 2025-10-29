<#
.SYNOPSIS
    Demonstrate horizontal scaling of Ollama LLM service
.DESCRIPTION
    Scales Ollama StatefulSet to showcase Azure Files ReadWriteMany capability.
    All replicas share the same model storage on Azure Files Premium.
.PARAMETER Replicas
    Number of replicas to scale to (default: 3)
.PARAMETER Namespace
    Kubernetes namespace (default: ollama)
.PARAMETER ShowDetails
    Show detailed pod information after scaling
.EXAMPLE
    .\scale-ollama.ps1
.EXAMPLE
    .\scale-ollama.ps1 -Replicas 5 -ShowDetails
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 10)]
    [int]$Replicas = 3,

    [Parameter(Mandatory = $false)]
    [string]$Namespace = "ollama",

    [Parameter(Mandatory = $false)]
    [switch]$ShowDetails
)

$ErrorActionPreference = 'Stop'

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Ollama Horizontal Scaling Demo" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Validate kubectl is available
Write-Host "Checking prerequisites..." -ForegroundColor Gray
$kubectlExists = Get-Command kubectl -ErrorAction SilentlyContinue
if (-not $kubectlExists) {
    throw "kubectl not found in PATH. Please install kubectl and ensure it's configured."
}
Write-Host "  kubectl: Found" -ForegroundColor Green
Write-Host ""

# Get current state
Write-Host "Current state:" -ForegroundColor Yellow
$currentPods = kubectl get pods -n $Namespace -l app=ollama --no-headers 2>$null

if ($LASTEXITCODE -ne 0) {
    throw "Failed to get pods. Is kubectl configured correctly? Is the namespace '$Namespace' correct?"
}

$currentCount = ($currentPods | Measure-Object).Count

if ($currentCount -eq 0) {
    throw "No Ollama pods found in namespace '$Namespace'. Has the application been deployed?"
}

Write-Host "  Current replicas: $currentCount" -ForegroundColor White
Write-Host "  Target replicas: $Replicas" -ForegroundColor White

if ($currentCount -eq $Replicas) {
    Write-Host "`nAlready at target replica count. No scaling needed." -ForegroundColor Yellow
    exit 0
}

Write-Host "`nScaling demonstration:" -ForegroundColor Yellow
Write-Host "  This showcases Azure Files ReadWriteMany capability" -ForegroundColor Gray
Write-Host "  All $Replicas pods will share the SAME Azure Files volume" -ForegroundColor Gray
Write-Host "  No storage duplication - all access same model files`n" -ForegroundColor Gray

# Scale the StatefulSet
Write-Host "Scaling StatefulSet..." -ForegroundColor Cyan
kubectl scale statefulset ollama --replicas=$Replicas -n $Namespace

if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to scale StatefulSet"
    exit 1
}

Write-Host "  Scale command sent successfully" -ForegroundColor Green

# Wait for pods to be ready
Write-Host "`nWaiting for pods to be ready (this may take 2-3 minutes)..." -ForegroundColor Yellow
Write-Host "  Pods need to:" -ForegroundColor Gray
Write-Host "    1. Mount Azure Files volume" -ForegroundColor Gray
Write-Host "    2. Start Ollama server" -ForegroundColor Gray
Write-Host "    3. Load model index from shared storage`n" -ForegroundColor Gray

$maxWaitSeconds = 300
$startTime = Get-Date

while (((Get-Date) - $startTime).TotalSeconds -lt $maxWaitSeconds) {
    $pods = kubectl get pods -n $Namespace -l app=ollama --no-headers 2>$null
    $readyPods = ($pods | Where-Object { $_ -match "1/1.*Running" }).Count

    Write-Host "  [$([math]::Floor(((Get-Date) - $startTime).TotalSeconds))s] Ready: $readyPods/$Replicas" -ForegroundColor $(if ($readyPods -eq $Replicas) { "Green" } else { "Yellow" })

    if ($readyPods -eq $Replicas) {
        Write-Host "`n  All pods ready!" -ForegroundColor Green
        break
    }

    Start-Sleep -Seconds 5
}

# Verify final state after timeout
$finalPods = kubectl get pods -n $Namespace -l app=ollama --no-headers 2>$null
$finalReadyCount = ($finalPods | Where-Object { $_ -match "1/1.*Running" }).Count

if ($finalReadyCount -lt $Replicas) {
    Write-Host "`n  WARNING: Only $finalReadyCount/$Replicas pods are ready after $maxWaitSeconds seconds" -ForegroundColor Yellow
    Write-Host "  Some pods may still be starting. Check 'kubectl get pods -n $Namespace' for details." -ForegroundColor Gray
}

# Check final status
Write-Host "`n========================================" -ForegroundColor Green
Write-Host "Scaling Complete!" -ForegroundColor Green
Write-Host "========================================`n" -ForegroundColor Green

# Show pod status
Write-Host "Pod Status:" -ForegroundColor Yellow
kubectl get pods -n $Namespace -l app=ollama -o wide

# Show PVC usage
Write-Host "`nAzure Files PVC (shared by all pods):" -ForegroundColor Yellow
kubectl get pvc -n $Namespace ollama-models-pvc

if ($ShowDetails) {
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "Detailed Pod Information" -ForegroundColor Cyan
    Write-Host "========================================`n" -ForegroundColor Cyan

    $pods = kubectl get pods -n $Namespace -l app=ollama -o jsonpath='{.items[*].metadata.name}' 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  Warning: Could not retrieve pod names for detailed view" -ForegroundColor Yellow
    } else {
        $podNames = $pods -split ' '

        foreach ($pod in $podNames) {
            if ([string]::IsNullOrWhiteSpace($pod)) { continue }

            Write-Host "Pod: $pod" -ForegroundColor White

            # Show which node
            $node = kubectl get pod $pod -n $Namespace -o jsonpath='{.spec.nodeName}' 2>$null
            if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($node)) {
                Write-Host "  Node: $node" -ForegroundColor Gray
            }

            # Show volume mounts
            Write-Host "  Storage Mount:" -ForegroundColor Gray
            $storageInfo = kubectl exec -n $Namespace $pod -- df -h /root/.ollama 2>$null | Select-Object -Last 1
            if ($LASTEXITCODE -eq 0) {
                Write-Host "    $storageInfo" -ForegroundColor Gray
            } else {
                Write-Host "    Unable to retrieve storage info" -ForegroundColor Yellow
            }

            # Show models available
            Write-Host "  Models Available:" -ForegroundColor Gray
            $modelList = kubectl exec -n $Namespace $pod -- ollama list 2>$null | Select-Object -Skip 1
            if ($LASTEXITCODE -eq 0) {
                $modelList | ForEach-Object {
                    Write-Host "    $_" -ForegroundColor Gray
                }
            } else {
                Write-Host "    Unable to retrieve model list" -ForegroundColor Yellow
            }
            Write-Host ""
        }
    }
}

# Show service endpoints
Write-Host "`nService Endpoints:" -ForegroundColor Yellow
$clusterIp = kubectl get svc ollama -n $Namespace -o jsonpath='{.spec.clusterIP}' 2>$null
Write-Host "  Cluster IP: $clusterIp:11434" -ForegroundColor White
Write-Host "  Load balancing across $Replicas pods" -ForegroundColor Gray

# Demo talking points
Write-Host "`n========================================" -ForegroundColor Green
Write-Host "Demo Talking Points" -ForegroundColor Green
Write-Host "========================================`n" -ForegroundColor Green

Write-Host "Key Benefits Demonstrated:" -ForegroundColor Yellow
Write-Host "  ReadWriteMany:" -ForegroundColor White
Write-Host "    - All $Replicas pods mount the SAME Azure Files share" -ForegroundColor Gray
Write-Host "    - No storage replication or synchronization needed" -ForegroundColor Gray
Write-Host "  Storage Efficiency:" -ForegroundColor White
Write-Host "    - Models stored once, accessed by all pods" -ForegroundColor Gray
Write-Host "    - No duplication = lower costs" -ForegroundColor Gray
Write-Host "  Horizontal Scaling:" -ForegroundColor White
Write-Host "    - Scale from 1 to $Replicas pods in minutes" -ForegroundColor Gray
Write-Host "    - All pods instantly have access to all models" -ForegroundColor Gray
Write-Host "    - Load balanced for higher throughput" -ForegroundColor Gray

Write-Host "`nNext Steps:" -ForegroundColor Cyan
Write-Host "  1. Test load balancing: Send requests to http://$clusterIp`:11434" -ForegroundColor White
Write-Host "  2. Show pod distribution: kubectl get pods -n $Namespace -o wide" -ForegroundColor White
Write-Host "  3. Scale down: .\scale-ollama.ps1 -Replicas 1`n" -ForegroundColor White

# Optional: Show scaling metrics
Write-Host "Resource Usage Summary:" -ForegroundColor Yellow
$gpuOutput = kubectl get nodes -l agentpool=gpu -o jsonpath='{range .items[*]}{.status.capacity.nvidia\.com/gpu}{"\n"}{end}' 2>$null

if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($gpuOutput)) {
    $totalGPUs = ($gpuOutput | Measure-Object -Sum).Sum
    Write-Host "  GPUs in cluster: $totalGPUs" -ForegroundColor Gray
    Write-Host "  GPUs requested: $Replicas (1 per pod)" -ForegroundColor Gray
    if ($Replicas -gt $totalGPUs) {
        Write-Host "  WARNING: Not enough GPUs! Some pods will be pending." -ForegroundColor Red
    }
} else {
    Write-Host "  GPU information unavailable (cluster may not have GPU nodes)" -ForegroundColor Yellow
}

Write-Host "`n"
