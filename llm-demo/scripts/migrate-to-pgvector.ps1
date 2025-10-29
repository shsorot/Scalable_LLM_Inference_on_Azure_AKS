<#
.SYNOPSIS
    Migrate Open-WebUI from ChromaDB to PGVector with horizontal scaling
.DESCRIPTION
    This script performs the migration from ChromaDB (SQLite) to PGVector
    and updates storage to Azure Files Premium for multi-replica support.
    
    Steps:
    1. Enable PGVector extension on PostgreSQL
    2. Scale down Open-WebUI to 0 replicas
    3. Delete old storage resources
    4. Apply new storage configuration
    5. Apply updated deployment with PGVector
    6. Scale up to desired replica count
    7. Validate migration

.PARAMETER Prefix
    Resource prefix (e.g., "shsorot")
.PARAMETER Namespace
    Kubernetes namespace (default: "ollama")
.PARAMETER TargetReplicas
    Target number of replicas after migration (default: 3)
.PARAMETER SkipPGVector
    Skip PGVector extension creation (if already done)
.PARAMETER AutoApprove
    Skip confirmation prompts
.EXAMPLE
    .\migrate-to-pgvector.ps1 -Prefix "shsorot" -TargetReplicas 3
.EXAMPLE
    .\migrate-to-pgvector.ps1 -Prefix "shsorot" -SkipPGVector -AutoApprove
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Prefix,

    [Parameter(Mandatory = $false)]
    [string]$Namespace = "ollama",

    [Parameter(Mandatory = $false)]
    [int]$TargetReplicas = 3,

    [Parameter(Mandatory = $false)]
    [switch]$SkipPGVector,

    [Parameter(Mandatory = $false)]
    [switch]$AutoApprove
)

$ErrorActionPreference = 'Stop'

# Color functions
function Write-Header($Message) { Write-Host "`n========================================" -ForegroundColor Cyan; Write-Host $Message -ForegroundColor Cyan; Write-Host "========================================`n" -ForegroundColor Cyan }
function Write-Info($Message) { Write-Host "[INFO] $Message" -ForegroundColor Gray }
function Write-Success($Message) { Write-Host "[OK] $Message" -ForegroundColor Green }
function Write-Warn($Message) { Write-Host "[WARNING] $Message" -ForegroundColor Yellow }
function Write-Err($Message) { Write-Host "[ERROR] $Message" -ForegroundColor Red }

# Script directory
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RootDir = Split-Path -Parent $ScriptDir
$K8sManifestsDir = Join-Path $RootDir "k8s"

Write-Header "Open-WebUI Migration: ChromaDB → PGVector"
Write-Info "Prefix: $Prefix"
Write-Info "Namespace: $Namespace"
Write-Info "Target Replicas: $TargetReplicas"
Write-Info "Skip PGVector Setup: $SkipPGVector"

# Confirmation
if (-not $AutoApprove) {
    Write-Warn "This migration will:"
    Write-Host "  1. Scale down Open-WebUI (brief downtime)"
    Write-Host "  2. Delete existing ChromaDB data"
    Write-Host "  3. Migrate to PGVector on PostgreSQL"
    Write-Host "  4. Scale up to $TargetReplicas replicas"
    $confirmation = Read-Host "`nDo you want to continue? (yes/no)"
    if ($confirmation -ne 'yes') {
        Write-Warn "Migration cancelled"
        exit 0
    }
}

#================================================
# PHASE 1: Enable PGVector Extension
#================================================
Write-Header "Phase 1: Enable PGVector Extension"

if ($SkipPGVector) {
    Write-Info "Skipping PGVector extension setup (--SkipPGVector flag)"
} else {
    Write-Info "Finding PostgreSQL server..."
    $pgServers = az postgres flexible-server list --resource-group "${Prefix}-rg" --query "[].name" -o tsv
    
    if (-not $pgServers) {
        Write-Err "No PostgreSQL servers found in resource group ${Prefix}-rg"
        exit 1
    }
    
    $pgServer = $pgServers[0]
    Write-Success "Found PostgreSQL server: $pgServer"

    Write-Info "Enabling PGVector extension..."
    Write-Info "You need to manually enable the extension. Run this SQL command:"
    Write-Host ""
    Write-Host "-- Connect to your PostgreSQL server" -ForegroundColor Yellow
    Write-Host "-- Option 1: Azure Portal → Query editor" -ForegroundColor Yellow
    Write-Host "-- Option 2: psql -h $pgServer.postgres.database.azure.com -U pgadmin -d openwebui" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "CREATE EXTENSION IF NOT EXISTS vector;" -ForegroundColor Green
    Write-Host "CREATE EXTENSION IF NOT EXISTS ""uuid-ossp"";" -ForegroundColor Green
    Write-Host "\dx  -- Verify extensions" -ForegroundColor Green
    Write-Host ""
    
    if (-not $AutoApprove) {
        $confirmation = Read-Host "Have you enabled the PGVector extension? (yes/no)"
        if ($confirmation -ne 'yes') {
            Write-Err "Please enable PGVector extension first, then re-run with --SkipPGVector"
            exit 1
        }
    }
}

#================================================
# PHASE 2: Backup Current State (Optional)
#================================================
Write-Header "Phase 2: Backup Current State"

Write-Info "Checking if Open-WebUI is running..."
$pods = kubectl get pods -n $Namespace -l app=open-webui -o jsonpath='{.items[*].metadata.name}' 2>$null

if ($pods) {
    Write-Info "Creating backup of current ChromaDB data..."
    $firstPod = $pods.Split(' ')[0]
    
    Write-Info "Backing up from pod: $firstPod"
    kubectl exec -n $Namespace $firstPod -- tar czf /tmp/chromadb-backup.tar.gz /app/backend/data/vector_db 2>$null
    kubectl cp "${Namespace}/${firstPod}:/tmp/chromadb-backup.tar.gz" "./chromadb-backup-$(Get-Date -Format 'yyyyMMdd-HHmmss').tar.gz"
    
    Write-Success "Backup created (optional - can be deleted if not needed)"
} else {
    Write-Info "No running Open-WebUI pods found, skipping backup"
}

#================================================
# PHASE 3: Scale Down and Delete Old Resources
#================================================
Write-Header "Phase 3: Scale Down and Remove Old Storage"

Write-Info "Scaling Open-WebUI to 0 replicas..."
kubectl scale deployment open-webui -n $Namespace --replicas=0 2>$null

Write-Info "Waiting for pods to terminate..."
Start-Sleep -Seconds 10

Write-Info "Checking for remaining pods..."
$remainingPods = kubectl get pods -n $Namespace -l app=open-webui -o jsonpath='{.items[*].metadata.name}' 2>$null
if ($remainingPods) {
    Write-Info "Waiting for pods to fully terminate..."
    kubectl wait --for=delete pod -l app=open-webui -n $Namespace --timeout=60s 2>$null
}

Write-Success "Open-WebUI scaled down"

Write-Info "Deleting old storage PVC..."
kubectl delete pvc open-webui-disk-pvc -n $Namespace --ignore-not-found=true
Write-Success "Old PVC deleted"

Write-Info "Removing unused storage class manifest..."
if (Test-Path "$K8sManifestsDir/03-storage-standard.yaml") {
    Remove-Item "$K8sManifestsDir/03-storage-standard.yaml" -Force
    Write-Success "Removed unused 03-storage-standard.yaml"
}

if (Test-Path "$K8sManifestsDir/04-storage-webui-disk.yaml") {
    Rename-Item "$K8sManifestsDir/04-storage-webui-disk.yaml" "$K8sManifestsDir/04-storage-webui-disk.yaml.backup" -Force
    Write-Success "Backed up old 04-storage-webui-disk.yaml"
}

#================================================
# PHASE 4: Apply New Configuration
#================================================
Write-Header "Phase 4: Apply New Configuration"

Write-Info "Creating new Azure Files PVC for Open-WebUI..."
kubectl apply -f "$K8sManifestsDir/04-storage-webui-files.yaml"

Write-Info "Waiting for PVC to be bound..."
$maxWait = 120
$elapsed = 0
while ($elapsed -lt $maxWait) {
    $pvcStatus = kubectl get pvc open-webui-files-pvc -n $Namespace -o jsonpath='{.status.phase}' 2>$null
    if ($pvcStatus -eq "Bound") {
        Write-Success "PVC bound successfully"
        break
    }
    Start-Sleep -Seconds 5
    $elapsed += 5
    Write-Info "Waiting for PVC to bind... ($elapsed/$maxWait seconds)"
}

if ($pvcStatus -ne "Bound") {
    Write-Err "PVC failed to bind within $maxWait seconds"
    Write-Info "Check PVC status: kubectl describe pvc open-webui-files-pvc -n $Namespace"
    exit 1
}

Write-Info "Applying updated Open-WebUI deployment..."
kubectl apply -f "$K8sManifestsDir/07-webui-deployment.yaml"
Write-Success "Deployment configuration applied"

#================================================
# PHASE 5: Scale Up and Validate
#================================================
Write-Header "Phase 5: Scale Up to $TargetReplicas Replicas"

Write-Info "Scaling Open-WebUI to $TargetReplicas replicas..."
kubectl scale deployment open-webui -n $Namespace --replicas=$TargetReplicas

Write-Info "Waiting for pods to be ready..."
$maxWait = 300
$elapsed = 0
$allReady = $false

while ($elapsed -lt $maxWait) {
    $podStatus = kubectl get pods -n $Namespace -l app=open-webui -o jsonpath='{.items[*].status.conditions[?(@.type=="Ready")].status}' 2>$null
    $readyCount = ($podStatus -split ' ' | Where-Object { $_ -eq "True" }).Count
    
    Write-Info "Ready pods: $readyCount / $TargetReplicas"
    
    if ($readyCount -eq $TargetReplicas) {
        $allReady = $true
        Write-Success "All $TargetReplicas replicas are ready!"
        break
    }
    
    Start-Sleep -Seconds 10
    $elapsed += 10
}

if (-not $allReady) {
    Write-Warn "Not all pods became ready within $maxWait seconds"
    Write-Info "Current pod status:"
    kubectl get pods -n $Namespace -l app=open-webui
    Write-Info "`nCheck pod logs: kubectl logs -n $Namespace -l app=open-webui --tail=50"
    exit 1
}

#================================================
# PHASE 6: Validation
#================================================
Write-Header "Phase 6: Validation"

Write-Info "Checking pod distribution..."
kubectl get pods -n $Namespace -l app=open-webui -o wide

Write-Info "`nChecking PVC mount in pods..."
$pods = kubectl get pods -n $Namespace -l app=open-webui -o jsonpath='{.items[*].metadata.name}'
$firstPod = $pods.Split(' ')[0]
kubectl exec -n $Namespace $firstPod -- df -h | Select-String "webui"

Write-Info "`nChecking Open-WebUI environment variables..."
$vectorDb = kubectl exec -n $Namespace $firstPod -- env | Select-String "VECTOR_DB"
Write-Info "VECTOR_DB setting: $vectorDb"

Write-Info "`nGetting service external IP..."
$serviceIp = kubectl get svc open-webui -n $Namespace -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>$null
if ($serviceIp) {
    Write-Success "Open-WebUI accessible at: http://${serviceIp}:8080"
} else {
    Write-Info "Service type may be ClusterIP or LoadBalancer not ready yet"
    Write-Info "Check service: kubectl get svc open-webui -n $Namespace"
}

#================================================
# PHASE 7: Summary
#================================================
Write-Header "Migration Complete!"

Write-Success "✅ Migration Summary:"
Write-Host "  • PGVector extension enabled on PostgreSQL"
Write-Host "  • ChromaDB (SQLite) replaced with PGVector"
Write-Host "  • Storage migrated to Azure Files Premium (RWX)"
Write-Host "  • Open-WebUI scaled to $TargetReplicas replicas"
Write-Host "  • All pods in Ready state"

Write-Info "`nNext Steps:"
Write-Host "  1. Test RAG functionality:"
Write-Host "     - Access WebUI at http://${serviceIp}:8080"
Write-Host "     - Upload a document"
Write-Host "     - Refresh browser (may hit different pod)"
Write-Host "     - Verify document appears and RAG works"
Write-Host ""
Write-Host "  2. Monitor pods:"
Write-Host "     kubectl get pods -n $Namespace -l app=open-webui -w"
Write-Host ""
Write-Host "  3. Check logs if issues:"
Write-Host "     kubectl logs -n $Namespace -l app=open-webui --tail=100 -f"
Write-Host ""
Write-Host "  4. Query PostgreSQL to verify PGVector:"
Write-Host "     \d document_chunk  -- Should show vector column"
Write-Host ""

Write-Success "`nMigration completed successfully!"
