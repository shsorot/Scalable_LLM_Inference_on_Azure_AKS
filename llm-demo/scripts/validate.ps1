<#
.SYNOPSIS
    Validate LLM demo deployment health
.DESCRIPTION
    Checks status of all components:
    - Kubernetes resources
    - Pod health
    - Storage mounts
    - Service endpoints
    - Model availability
.PARAMETER Namespace
    Kubernetes namespace to validate
.EXAMPLE
    .\validate.ps1 -Namespace "ollama"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$Namespace = "ollama"
)

$ErrorActionPreference = 'Continue'
$script:errorCount = 0

function Write-Check {
    param([string]$Message, [string]$Status, [string]$Detail = "")

    $color = switch ($Status) {
        "OK" { "Green" }
        "WARN" { "Yellow" }
        "FAIL" { "Red"; $script:errorCount++ }
        default { "Gray" }
    }

    $symbol = switch ($Status) {
        "OK" { "✓" }
        "WARN" { "⚠" }
        "FAIL" { "✗" }
        default { "→" }
    }

    Write-Host "  $symbol $Message" -ForegroundColor $color
    if ($Detail) {
        Write-Host "    $Detail" -ForegroundColor Gray
    }
}

Write-Host "`n=== Validating LLM Demo Deployment ===" -ForegroundColor Cyan

# Check namespace
Write-Host "`n[1] Namespace Check" -ForegroundColor White
$ns = kubectl get namespace $Namespace --no-headers 2>$null
if ($?) {
    Write-Check "Namespace '$Namespace' exists" "OK"
} else {
    Write-Check "Namespace '$Namespace' not found" "FAIL"
    exit 1
}

# Check PVCs
Write-Host "`n[2] Storage Check" -ForegroundColor White
$pvcs = kubectl get pvc -n $Namespace -o json 2>$null | ConvertFrom-Json

foreach ($pvc in $pvcs.items) {
    $name = $pvc.metadata.name
    $status = $pvc.status.phase
    $capacity = $pvc.status.capacity.storage

    if ($status -eq "Bound") {
        Write-Check "PVC '$name' bound ($capacity)" "OK"
    } else {
        Write-Check "PVC '$name' status: $status" "FAIL"
    }
}

# Check Ollama StatefulSet
Write-Host "`n[3] Ollama Server Check" -ForegroundColor White
$ollamaSts = kubectl get statefulset ollama -n $Namespace -o json 2>$null | ConvertFrom-Json

if ($?) {
    $ready = $ollamaSts.status.readyReplicas
    $desired = $ollamaSts.spec.replicas

    if ($ready -eq $desired) {
        Write-Check "Ollama StatefulSet ready ($ready/$desired)" "OK"
    } else {
        Write-Check "Ollama StatefulSet not ready ($ready/$desired)" "FAIL"
    }
} else {
    Write-Check "Ollama StatefulSet not found" "FAIL"
}

# Check Ollama pod
$ollamaPod = kubectl get pod -n $Namespace -l app=ollama -o json 2>$null | ConvertFrom-Json
if ($ollamaPod.items.Count -gt 0) {
    $pod = $ollamaPod.items[0]
    $podName = $pod.metadata.name
    $phase = $pod.status.phase
    $ready = ($pod.status.containerStatuses[0].ready -eq $true)

    if ($phase -eq "Running" -and $ready) {
        Write-Check "Ollama pod '$podName' running and ready" "OK"

        # Check GPU allocation
        $gpuRequest = $pod.spec.containers[0].resources.requests.'nvidia.com/gpu'
        if ($gpuRequest) {
            Write-Check "GPU allocated: $gpuRequest" "OK"
        } else {
            Write-Check "No GPU allocated" "WARN" "Model inference will be slow"
        }
    } else {
        Write-Check "Ollama pod '$podName' not ready (Phase: $phase)" "FAIL"
    }
} else {
    Write-Check "Ollama pod not found" "FAIL"
}

# Check Ollama service
Write-Host "`n[4] Service Check" -ForegroundColor White
$ollamaSvc = kubectl get svc ollama -n $Namespace -o json 2>$null | ConvertFrom-Json
if ($?) {
    $clusterIp = $ollamaSvc.spec.clusterIP
    $port = $ollamaSvc.spec.ports[0].port
    Write-Check "Ollama ClusterIP service: ${clusterIp}:${port}" "OK"
} else {
    Write-Check "Ollama service not found" "FAIL"
}

# Check WebUI deployment
Write-Host "`n[5] Open-WebUI Check" -ForegroundColor White
$webuiDeploy = kubectl get deployment open-webui -n $Namespace -o json 2>$null | ConvertFrom-Json

if ($?) {
    $ready = $webuiDeploy.status.readyReplicas
    $desired = $webuiDeploy.spec.replicas

    if ($ready -eq $desired) {
        Write-Check "Open-WebUI deployment ready ($ready/$desired)" "OK"
    } else {
        Write-Check "Open-WebUI deployment not ready ($ready/$desired)" "FAIL"
    }
} else {
    Write-Check "Open-WebUI deployment not found" "FAIL"
}

# Check WebUI service
$webuiSvc = kubectl get svc open-webui -n $Namespace -o json 2>$null | ConvertFrom-Json
if ($?) {
    $externalIp = $webuiSvc.status.loadBalancer.ingress[0].ip

    if ($externalIp) {
        Write-Check "Open-WebUI LoadBalancer IP: $externalIp" "OK" "Access at http://$externalIp"
    } else {
        Write-Check "Open-WebUI LoadBalancer IP pending" "WARN" "May take a few minutes"
    }
} else {
    Write-Check "Open-WebUI service not found" "FAIL"
}

# Check models (if Ollama is running)
if ($ollamaPod.items.Count -gt 0 -and $phase -eq "Running") {
    Write-Host "`n[6] Model Check" -ForegroundColor White
    $podName = $ollamaPod.items[0].metadata.name

    $models = kubectl exec -n $Namespace $podName -- ollama list 2>$null

    if ($?) {
        $modelLines = $models -split "`n" | Select-Object -Skip 1 | Where-Object { $_.Trim() -ne "" }

        if ($modelLines.Count -gt 0) {
            Write-Check "Models loaded: $($modelLines.Count)" "OK"
            foreach ($line in $modelLines | Select-Object -First 3) {
                Write-Host "    $line" -ForegroundColor Gray
            }
        } else {
            Write-Check "No models loaded" "WARN" "Run .\scripts\preload-model.ps1 to download"
        }
    } else {
        Write-Check "Cannot list models" "WARN" "Pod may still be initializing"
    }
}

# Check nodes
Write-Host "`n[7] Node Check" -ForegroundColor White
$nodes = kubectl get nodes -o json 2>$null | ConvertFrom-Json

foreach ($node in $nodes.items) {
    $name = $node.metadata.name
    $ready = ($node.status.conditions | Where-Object { $_.type -eq "Ready" }).status
    $isGpu = $node.metadata.labels.gpu -eq "true"

    $nodeType = if ($isGpu) { "GPU" } else { "System" }

    if ($ready -eq "True") {
        Write-Check "Node '$name' ($nodeType) ready" "OK"

        if ($isGpu) {
            $gpuCapacity = $node.status.capacity.'nvidia.com/gpu'
            if ($gpuCapacity) {
                Write-Host "      GPU capacity: $gpuCapacity" -ForegroundColor Gray
            }
        }
    } else {
        Write-Check "Node '$name' not ready" "FAIL"
    }
}

# Summary
Write-Host "`n========================================" -ForegroundColor Cyan
if ($script:errorCount -eq 0) {
    Write-Host "  ✓ All checks passed!" -ForegroundColor Green
    Write-Host "  Demo is ready for use." -ForegroundColor Green
} else {
    Write-Host "  ✗ $script:errorCount check(s) failed" -ForegroundColor Red
    Write-Host "  Review errors above and troubleshoot." -ForegroundColor Yellow
}
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

exit $script:errorCount
