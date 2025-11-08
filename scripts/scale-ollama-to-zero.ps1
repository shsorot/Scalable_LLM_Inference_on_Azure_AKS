<#
.SYNOPSIS
    Scale Ollama StatefulSet to zero replicas (manual scale-to-zero)

.DESCRIPTION
    Since HPA cannot scale to 0 with Pods metrics, this script manually scales
    the Ollama StatefulSet to 0 replicas when there's no load.

    This allows the GPU node pool to scale down to zero, saving costs.

    When new requests arrive, manually scale back up or the HPA will handle it
    once you scale to 1.

.EXAMPLE
    .\scripts\scale-ollama-to-zero.ps1

.EXAMPLE
    # Scale back up to 1 replica
    kubectl scale statefulset -n ollama ollama --replicas=1
#>

[CmdletBinding()]
param()

Write-Host "`n" -NoNewline
Write-Host "="*80 -ForegroundColor Cyan
Write-Host "SCALE OLLAMA TO ZERO" -ForegroundColor Cyan
Write-Host "="*80 -ForegroundColor Cyan
Write-Host ""

# Check current replica count
Write-Host "Checking current Ollama replica count..." -ForegroundColor Yellow
$currentReplicas = kubectl get statefulset -n ollama ollama -o jsonpath='{.spec.replicas}'
Write-Host "  Current replicas: $currentReplicas" -ForegroundColor White
Write-Host ""

if ($currentReplicas -eq "0") {
    Write-Host "✓ Ollama is already scaled to zero" -ForegroundColor Green
    Write-Host ""
    Write-Host "To scale back up when needed:" -ForegroundColor Cyan
    Write-Host "  kubectl scale statefulset -n ollama ollama --replicas=1" -ForegroundColor White
    Write-Host ""
    exit 0
}

# Check recent activity
Write-Host "Checking for recent activity..." -ForegroundColor Yellow
$recentRequests = kubectl logs -n ollama ollama-0 --since=5m --tail=100 2>$null | Select-String "POST" | Measure-Object | Select-Object -ExpandProperty Count

if ($recentRequests -gt 0) {
    Write-Host "  ⚠️  WARNING: Detected $recentRequests requests in the last 5 minutes" -ForegroundColor Red
    Write-Host ""
    $confirmation = Read-Host "Are you sure you want to scale down? (yes/no)"
    if ($confirmation -ne "yes") {
        Write-Host "Aborted." -ForegroundColor Yellow
        exit 1
    }
} else {
    Write-Host "  No recent activity detected (last 5 minutes)" -ForegroundColor Green
}
Write-Host ""

# Scale down to zero
Write-Host "Scaling Ollama StatefulSet to 0 replicas..." -ForegroundColor Yellow
kubectl scale statefulset -n ollama ollama --replicas=0

if ($LASTEXITCODE -eq 0) {
    Write-Host "✓ Successfully scaled to zero" -ForegroundColor Green
    Write-Host ""

    Write-Host "Waiting for pod termination..." -ForegroundColor Yellow
    Start-Sleep -Seconds 10

    # Check GPU node status
    Write-Host ""
    Write-Host "GPU node pool status:" -ForegroundColor Cyan
    kubectl get nodes -l workload=llm

    Write-Host ""
    Write-Host "The GPU node pool will scale down to zero in ~2-5 minutes" -ForegroundColor Green
    Write-Host "(configured via cluster autoscaler scale-down-unneeded-time: 2m)" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Monitor with:" -ForegroundColor Cyan
    Write-Host "  kubectl get nodes -w -l workload=llm" -ForegroundColor White
    Write-Host ""
    Write-Host "To scale back up when needed:" -ForegroundColor Cyan
    Write-Host "  kubectl scale statefulset -n ollama ollama --replicas=1" -ForegroundColor White
    Write-Host ""
} else {
    Write-Host "✗ Failed to scale down" -ForegroundColor Red
    exit 1
}

Write-Host "="*80 -ForegroundColor Cyan
Write-Host ""
