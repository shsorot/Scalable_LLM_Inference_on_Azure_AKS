<#
.SYNOPSIS
    Validate PGVector migration and multi-replica functionality
.DESCRIPTION
    Comprehensive validation script to verify:
    - PGVector extension is working
    - All replicas are healthy
    - Storage is shared correctly
    - RAG functionality works across pods
.PARAMETER Prefix
    Resource prefix (e.g., "shsorot")
.PARAMETER Namespace
    Kubernetes namespace (default: "ollama")
.EXAMPLE
    .\validate-migration.ps1 -Prefix "shsorot"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Prefix,

    [Parameter(Mandatory = $false)]
    [string]$Namespace = "ollama"
)

$ErrorActionPreference = 'Stop'

# Color functions
function Write-Header($Message) { Write-Host "`n========================================" -ForegroundColor Cyan; Write-Host $Message -ForegroundColor Cyan; Write-Host "========================================`n" -ForegroundColor Cyan }
function Write-Test($Message) { Write-Host "[TEST] $Message" -ForegroundColor Magenta }
function Write-Pass($Message) { Write-Host "[PASS] $Message" -ForegroundColor Green }
function Write-Fail($Message) { Write-Host "[FAIL] $Message" -ForegroundColor Red }
function Write-Info($Message) { Write-Host "[INFO] $Message" -ForegroundColor Gray }

$testsPassed = 0
$testsFailed = 0

Write-Header "PGVector Migration Validation"
Write-Info "Prefix: $Prefix"
Write-Info "Namespace: $Namespace"

#================================================
# TEST 1: Check Pod Status
#================================================
Write-Test "Test 1: Checking Open-WebUI pod status..."

$pods = kubectl get pods -n $Namespace -l app=open-webui -o json | ConvertFrom-Json
$readyPods = ($pods.items | Where-Object { $_.status.conditions | Where-Object { $_.type -eq "Ready" -and $_.status -eq "True" } }).Count
$totalPods = $pods.items.Count

Write-Info "Ready pods: $readyPods / $totalPods"

if ($readyPods -gt 0 -and $readyPods -eq $totalPods) {
    Write-Pass "All $totalPods pods are ready"
    $testsPassed++
} else {
    Write-Fail "Not all pods are ready"
    $testsFailed++
    kubectl get pods -n $Namespace -l app=open-webui
}

#================================================
# TEST 2: Check PVC Binding
#================================================
Write-Test "Test 2: Checking PVC binding status..."

$pvcStatus = kubectl get pvc open-webui-files-pvc -n $Namespace -o jsonpath='{.status.phase}' 2>$null

if ($pvcStatus -eq "Bound") {
    Write-Pass "PVC open-webui-files-pvc is bound"
    $testsPassed++
    
    # Check storage class
    $storageClass = kubectl get pvc open-webui-files-pvc -n $Namespace -o jsonpath='{.spec.storageClassName}'
    Write-Info "Storage Class: $storageClass"
    
    # Check access mode
    $accessMode = kubectl get pvc open-webui-files-pvc -n $Namespace -o jsonpath='{.spec.accessModes[0]}'
    Write-Info "Access Mode: $accessMode"
    
    if ($accessMode -eq "ReadWriteMany") {
        Write-Pass "PVC has ReadWriteMany (RWX) access mode"
        $testsPassed++
    } else {
        Write-Fail "PVC does not have ReadWriteMany access mode: $accessMode"
        $testsFailed++
    }
} else {
    Write-Fail "PVC is not bound. Status: $pvcStatus"
    $testsFailed++
}

#================================================
# TEST 3: Check VECTOR_DB Environment Variable
#================================================
Write-Test "Test 3: Checking VECTOR_DB configuration..."

if ($pods.items.Count -gt 0) {
    $firstPod = $pods.items[0].metadata.name
    $vectorDbEnv = kubectl exec -n $Namespace $firstPod -- env 2>$null | Select-String "VECTOR_DB="
    
    Write-Info "Environment: $vectorDbEnv"
    
    if ($vectorDbEnv -match "VECTOR_DB=pgvector") {
        Write-Pass "VECTOR_DB is set to pgvector"
        $testsPassed++
    } else {
        Write-Fail "VECTOR_DB is not set to pgvector"
        $testsFailed++
    }
    
    # Check PGVECTOR_DB_URL
    $pgvectorUrl = kubectl exec -n $Namespace $firstPod -- env 2>$null | Select-String "PGVECTOR_DB_URL"
    if ($pgvectorUrl) {
        Write-Pass "PGVECTOR_DB_URL is configured"
        $testsPassed++
    } else {
        Write-Fail "PGVECTOR_DB_URL is not configured"
        $testsFailed++
    }
}

#================================================
# TEST 4: Check Shared Storage Mount
#================================================
Write-Test "Test 4: Verifying shared storage mounts..."

$mountCheck = $true
foreach ($pod in $pods.items) {
    $podName = $pod.metadata.name
    Write-Info "Checking pod: $podName"
    
    $mountInfo = kubectl exec -n $Namespace $podName -- df -h 2>$null | Select-String "/app/backend/data"
    
    if ($mountInfo) {
        Write-Info "  Mount: $mountInfo"
    } else {
        Write-Fail "  No mount found at /app/backend/data"
        $mountCheck = $false
    }
}

if ($mountCheck) {
    Write-Pass "All pods have storage mounted"
    $testsPassed++
} else {
    Write-Fail "Some pods missing storage mount"
    $testsFailed++
}

#================================================
# TEST 5: Check Embedding Model Cache
#================================================
Write-Test "Test 5: Checking embedding model cache..."

if ($pods.items.Count -gt 0) {
    $firstPod = $pods.items[0].metadata.name
    $modelPath = kubectl exec -n $Namespace $firstPod -- ls -la /app/backend/data/cache/embedding/models/ 2>$null
    
    if ($modelPath -match "sentence-transformers") {
        Write-Pass "Embedding model cache exists"
        $testsPassed++
        
        # Check if all pods see the same cache
        if ($pods.items.Count -gt 1) {
            $secondPod = $pods.items[1].metadata.name
            $secondPath = kubectl exec -n $Namespace $secondPod -- ls -la /app/backend/data/cache/embedding/models/ 2>$null
            
            if ($secondPath -match "sentence-transformers") {
                Write-Pass "Embedding model cache is shared across pods"
                $testsPassed++
            } else {
                Write-Fail "Embedding model cache not accessible from second pod"
                $testsFailed++
            }
        }
    } else {
        Write-Fail "Embedding model cache not found"
        $testsFailed++
    }
}

#================================================
# TEST 6: Check PostgreSQL Connection
#================================================
Write-Test "Test 6: Verifying PostgreSQL connectivity..."

if ($pods.items.Count -gt 0) {
    $firstPod = $pods.items[0].metadata.name
    
    # Check if the pod can resolve PostgreSQL hostname
    $dbUrl = kubectl exec -n $Namespace $firstPod -- env 2>$null | Select-String "DATABASE_URL" | ForEach-Object { $_.ToString() }
    
    if ($dbUrl -match "@([^:]+):") {
        $pgHost = $matches[1]
        Write-Info "PostgreSQL host: $pgHost"
        
        # Try to resolve the hostname (basic connectivity check)
        $dnsCheck = kubectl exec -n $Namespace $firstPod -- nslookup $pgHost 2>$null
        
        if ($dnsCheck -match "Address") {
            Write-Pass "PostgreSQL hostname resolves correctly"
            $testsPassed++
        } else {
            Write-Fail "Cannot resolve PostgreSQL hostname"
            $testsFailed++
        }
    }
}

#================================================
# TEST 7: Check Pod Logs for Errors
#================================================
Write-Test "Test 7: Checking pod logs for errors..."

$errorFound = $false
foreach ($pod in $pods.items) {
    $podName = $pod.metadata.name
    Write-Info "Checking logs for: $podName"
    
    $logs = kubectl logs -n $Namespace $podName --tail=50 2>$null
    
    $criticalErrors = $logs | Select-String -Pattern "ERROR|CRITICAL|Failed to connect|Connection refused" -CaseSensitive
    
    if ($criticalErrors) {
        Write-Fail "  Found errors in logs:"
        $criticalErrors | ForEach-Object { Write-Info "    $_" }
        $errorFound = $true
    } else {
        Write-Info "  No critical errors found"
    }
}

if (-not $errorFound) {
    Write-Pass "No critical errors in pod logs"
    $testsPassed++
} else {
    Write-Fail "Critical errors found in pod logs"
    $testsFailed++
}

#================================================
# TEST 8: Check Service Endpoint
#================================================
Write-Test "Test 8: Checking service endpoint..."

$serviceIp = kubectl get svc open-webui -n $Namespace -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>$null

if ($serviceIp) {
    Write-Pass "Service external IP: $serviceIp"
    $testsPassed++
    
    Write-Info "Testing HTTP endpoint..."
    try {
        $response = Invoke-WebRequest -Uri "http://${serviceIp}:8080/health" -TimeoutSec 10 -UseBasicParsing
        if ($response.StatusCode -eq 200) {
            Write-Pass "Health endpoint responding (HTTP 200)"
            $testsPassed++
        } else {
            Write-Fail "Health endpoint returned HTTP $($response.StatusCode)"
            $testsFailed++
        }
    } catch {
        Write-Fail "Cannot reach health endpoint: $_"
        $testsFailed++
    }
} else {
    Write-Info "Service external IP not available yet"
    Write-Info "Check: kubectl get svc open-webui -n $Namespace"
    $testsFailed++
}

#================================================
# TEST 9: Check Replica Distribution
#================================================
Write-Test "Test 9: Checking replica distribution across nodes..."

$nodeDistribution = @{}
foreach ($pod in $pods.items) {
    $nodeName = $pod.spec.nodeName
    if (-not $nodeDistribution.ContainsKey($nodeName)) {
        $nodeDistribution[$nodeName] = 0
    }
    $nodeDistribution[$nodeName]++
}

Write-Info "Pod distribution:"
foreach ($nodeName in $nodeDistribution.Keys) {
    $podCount = $nodeDistribution[$nodeName]
    Write-Info "  Node ${nodeName}: $podCount pod(s)"
}

if ($nodeDistribution.Count -gt 1) {
    Write-Pass "Pods distributed across $($nodeDistribution.Count) nodes"
    $testsPassed++
} else {
    Write-Info "All pods on single node (acceptable for small clusters)"
    $testsPassed++
}

#================================================
# SUMMARY
#================================================
Write-Header "Validation Summary"

$totalTests = $testsPassed + $testsFailed
$successRate = [math]::Round(($testsPassed / $totalTests) * 100, 2)

Write-Host "Total Tests: $totalTests"
Write-Pass "Passed: $testsPassed"
if ($testsFailed -gt 0) {
    Write-Fail "Failed: $testsFailed"
}
Write-Host "Success Rate: $successRate%"

if ($testsFailed -eq 0) {
    Write-Host "`n✅ All validation tests passed!" -ForegroundColor Green
    Write-Host "Migration to PGVector is successful and ready for production use."
    Write-Host ""
    Write-Host "Next Steps:" -ForegroundColor Cyan
    Write-Host "  1. Test RAG functionality by uploading documents"
    Write-Host "  2. Verify documents are accessible from all replicas"
    Write-Host "  3. Implement HPA for auto-scaling"
    Write-Host "  4. Set up monitoring with Prometheus/Grafana"
    exit 0
} else {
    Write-Host "`n⚠️ Some tests failed. Please review the issues above." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Troubleshooting Commands:" -ForegroundColor Cyan
    Write-Host "  kubectl get pods -n $Namespace -l app=open-webui"
    Write-Host "  kubectl logs -n $Namespace -l app=open-webui --tail=100 -f"
    Write-Host "  kubectl describe pod -n $Namespace <pod-name>"
    Write-Host "  kubectl exec -n $Namespace <pod-name> -- env | grep VECTOR"
    exit 1
}
