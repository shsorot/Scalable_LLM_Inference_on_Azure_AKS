# Deployment Fixes and Enhancements

This document details all fixes and validation checks incorporated into the deployment process to ensure robust and reliable deployments.

## Overview

The deployment script (`scripts/deploy.ps1`) has been enhanced with comprehensive validation checks and error handling to prevent common deployment issues and provide clear troubleshooting guidance.

## Fixes Implemented

### 1. Pre-Deployment Validation (Lines 189-238)

#### PostgreSQL Regional Availability Check
**Problem**: PostgreSQL Flexible Server is not available in all Azure regions (e.g., westus2 may be restricted).

**Solution**:
- Validates PostgreSQL Flexible Server availability in target region before deployment
- Provides list of commonly supported regions if validation fails
- Prevents wasted time deploying infrastructure that will fail

```powershell
$pgLocations = az postgres flexible-server list-skus --location $Location --output json
if ($LASTEXITCODE -eq 0 -and $pgLocations) {
    Write-Success "PostgreSQL Flexible Server is available in '$Location'"
} else {
    Write-Error "PostgreSQL Flexible Server is NOT available in '$Location'"
    # ... provides region suggestions
}
```

#### Key Vault Conflict Detection
**Problem**: Key Vault names must be globally unique. Purge protection prevents reusing names even after deletion.

**Solution**:
- Checks for soft-deleted Key Vaults with same prefix
- Warns about potential naming conflicts
- Lists existing soft-deleted Key Vaults with deletion dates

```powershell
$softDeletedKvs = az keyvault list-deleted --query "[?starts_with(name, '$Prefix')]"
if ($softDeletedKvs -and $softDeletedKvs.Count -gt 0) {
    Write-Warning "Found soft-deleted Key Vault(s) with prefix '$Prefix'"
    # ... lists each vault
}
```

#### GPU VM Quota Validation
**Problem**: GPU VM quotas are often low by default (0 in many regions), causing AKS GPU node pool deployment to fail.

**Solution**:
- Checks Standard NCASv3_T4 Family vCPU quota
- Warns if quota is insufficient (requires 16 vCPUs)
- Provides link to request quota increase
- Allows deployment to continue with warning

```powershell
$gpuQuota = az vm list-usage --location $Location --query "[?localName=='Standard NCASv3_T4 Family vCPUs']"
if ($gpuQuota -and $gpuQuota.Limit -ge 16) {
    Write-Success "GPU VM quota is sufficient"
} else {
    Write-Warning "GPU VM quota may be insufficient"
    # ... provides quota increase link
}
```

### 2. Key Vault Configuration Validation (Lines 295-310)

**Problem**: Key Vault naming must include location for regional uniqueness. Purge protection settings affect cleanup.

**Solution**:
- Validates Key Vault name includes location identifier
- Checks purge protection status
- Warns about multi-region deployment implications

```powershell
if ($keyVaultName -like "*$Location*") {
    Write-Success "Key Vault name includes location identifier"
} else {
    Write-Warning "Key Vault name does not include location"
}

$purgeProtection = $kvDetails.properties.enablePurgeProtection
if ($purgeProtection -eq $true) {
    Write-Warning "Key Vault has purge protection enabled"
}
```

### 3. PostgreSQL Password Synchronization (Lines 295-320)

**Problem**: Deploy script generated random password, but PostgreSQL server might be created with different password, causing authentication failures.

**Solution**:
- Updates PostgreSQL admin password after deployment to match generated password
- Attempts to verify connection using `psql` (if available locally)
- Provides fallback instructions for verification from within AKS cluster
- Gracefully handles when `psql` is not installed locally

```powershell
$updateOutput = az postgres flexible-server update `
    --resource-group $ResourceGroupName `
    --name $postgresServerName `
    --admin-password $PostgresPassword `
    --output json

if ($LASTEXITCODE -eq 0) {
    Write-Success "PostgreSQL password updated successfully"

    # Verify connection
    $env:PGPASSWORD = $PostgresPassword
    $testConnection = & psql -h $postgresServerFqdn -U $postgresAdminUsername -d $postgresDatabaseName -c "SELECT 1;"

    if ($LASTEXITCODE -eq 0) {
        Write-Success "PostgreSQL connection verified"
    } else {
        Write-Warning "Could not verify PostgreSQL connection (psql may not be installed)"
        Write-Info "To test from AKS: kubectl run -n ollama psql-test --rm -it --image=postgres:15 -- psql '...'"
    }
}
```

### 4. Enhanced Open-WebUI Startup Monitoring (Lines 520-595)

**Problem**:
- Open-WebUI first startup requires downloading embedding model from HuggingFace (5-15 minutes)
- Original 5-minute timeout was insufficient
- No visibility into download progress
- Unhelpful error messages when timeout occurred

**Solution**:
- Extended timeout to 15 minutes (900 seconds)
- Progress monitoring with 30-second status updates
- Detects embedding model download in logs
- Only prints status when changed (reduces console spam)
- Verifies HTTP endpoint responds after pod shows ready
- Comprehensive troubleshooting guide if deployment fails

```powershell
$timeout = 900  # 15 minutes
$checkInterval = 30  # Check every 30 seconds

while (((Get-Date) - $startTime).TotalSeconds -lt $timeout) {
    $podStatus = kubectl get pods -n ollama -l app=open-webui -o jsonpath='{.items[0].status.phase}'
    $podReady = kubectl get pods -n ollama -l app=open-webui -o jsonpath='{.items[0].status.conditions[?(@.type=="Ready")].status}'

    if ($podReady -eq "True" -and $containerReady -eq "true") {
        Write-Success "Open-WebUI pod is ready!"

        # Verify HTTP endpoint
        $httpCheck = kubectl exec -n ollama $podName -- wget -q -O- http://localhost:8080/health
        break
    }

    $elapsed = [math]::Floor(((Get-Date) - $startTime).TotalSeconds)
    $remaining = [math]::Floor($timeout - $elapsed)
    Write-Host "[$elapsed`s/$timeout`s] Phase: $podStatus | Ready: $podReady | Restarts: $restartCount"

    # Check logs for embedding model indicator
    if ($podStatus -eq "Running") {
        $recentLogs = kubectl logs -n ollama -l app=open-webui --tail=5 | Select-String -Pattern "Embedding model"
        if ($recentLogs) {
            Write-Host "└─ Detected: Initializing embedding model (5-15 minutes on first run)"
        }
    }

    Start-Sleep -Seconds $checkInterval
}

# Comprehensive troubleshooting if failed
if ($finalReady -ne "True") {
    Write-Error "Open-WebUI pod did not become ready within $timeout seconds"
    Write-Host "Troubleshooting steps:"
    Write-Host "1. Check pod logs: kubectl logs -n ollama -l app=open-webui --tail=100"
    Write-Host "2. Check pod status: kubectl describe pod -n ollama -l app=open-webui"
    Write-Host "3. Wait longer: kubectl wait --for=condition=ready pod -l app=open-webui -n ollama --timeout=600s"
    Write-Host "4. Port-forward: kubectl port-forward -n ollama svc/open-webui 8080:8080"
    exit 1
}
```

## Infrastructure Configuration Fixes

### Key Vault Naming (bicep/main.bicep Line 54)

**Change**: Updated Key Vault name generation to include location

**Before**:
```bicep
var keyVaultName = '${prefix}kv${uniqueString(resourceGroup().id)}'
```

**After**:
```bicep
var keyVaultName = take('${prefix}${location}${uniqueString(resourceGroup().id, location)}', 24)
```

**Benefits**:
- Each region gets unique Key Vault name
- Prevents conflicts in multi-region deployments
- Truncated to 24 characters (Key Vault name limit)

### Key Vault Purge Protection (bicep/main.bicep Line 106)

**Change**: Set purge protection to null (flexible)

**Before**:
```bicep
enablePurgeProtection: true
```

**After**:
```bicep
enablePurgeProtection: null
```

**Benefits**:
- Allows flexibility in cleanup
- Can be enabled per-environment if needed
- Prevents irreversible purge protection issues

### PostgreSQL Cost Optimization (bicep/postgres.bicep)

**Configuration**:
- SKU: Standard_B1ms (Burstable, 1 vCore, 2 GiB RAM)
- Storage: 32 GB, no auto-grow
- Backup: 7-day retention, no geo-redundancy
- High Availability: Disabled
- **Estimated Cost**: ~$13/month

**Why B1ms**:
- Sufficient for demo/dev workloads
- Burstable tier provides cost savings
- Can be scaled up if needed

## Validation Checklist

When deploying, the script now validates:

- ✅ Azure CLI is installed and authenticated
- ✅ PostgreSQL Flexible Server is available in target region
- ✅ No Key Vault naming conflicts exist
- ✅ GPU VM quota is sufficient (warning if not)
- ✅ Resource group exists or can be created
- ✅ Bicep deployment completes successfully
- ✅ Key Vault name includes location identifier
- ✅ Key Vault purge protection status is appropriate
- ✅ PostgreSQL password is synchronized
- ✅ PostgreSQL connection can be verified (if psql available)
- ✅ AKS cluster credentials are retrieved
- ✅ Kubectl context is set correctly
- ✅ NVIDIA GPU plugin is deployed
- ✅ Ollama pods become ready
- ✅ Open-WebUI pods become ready (with extended timeout)
- ✅ Open-WebUI HTTP endpoint responds
- ✅ LoadBalancer external IP is assigned

## Troubleshooting Guide

### If PostgreSQL Deployment Fails
1. Check region availability: `az postgres flexible-server list-skus --location <region>`
2. Try different region (northeurope, eastus, westus3)
3. Check subscription restrictions in Azure Portal

### If Key Vault Deployment Fails
1. Check for soft-deleted vaults: `az keyvault list-deleted`
2. Purge if needed: `az keyvault purge --name <vault-name>`
3. Use different prefix or location
4. Run cleanup script: `.\scripts\cleanup.ps1 -Prefix <prefix>`

### If Open-WebUI Pod Doesn't Start
1. Check logs: `kubectl logs -n ollama -l app=open-webui --tail=100`
2. Look for "Embedding model" in logs (indicates download in progress)
3. Wait up to 15 minutes for first startup
4. Use port-forward to access while waiting: `kubectl port-forward -n ollama svc/open-webui 8080:8080`
5. Check PostgreSQL connection: `kubectl run -n ollama psql-test --rm -it --image=postgres:15 -- psql 'postgresql://...'`

### If GPU Nodes Don't Start
1. Check quota: `az vm list-usage --location <location> --query "[?contains(localName, 'NCASv3')]"`
2. Request quota increase: https://portal.azure.com/#view/Microsoft_Azure_Support/HelpAndSupportBlade
3. Use different region with available GPU quota
4. Consider different GPU SKU if NCASv3_T4 not available

## Testing the Fixes

To test the deployment with all fixes:

```powershell
# Full deployment with validation
.\scripts\deploy.ps1 -Prefix mytest -Location northeurope -HuggingFaceToken hf_xxx

# With auto-approve (for CI/CD)
.\scripts\deploy.ps1 -Prefix mytest -Location northeurope -HuggingFaceToken hf_xxx -AutoApprove

# Custom PostgreSQL password
.\scripts\deploy.ps1 -Prefix mytest -Location northeurope -HuggingFaceToken hf_xxx -PostgresPassword "MySecureP@ssw0rd!"
```

## Monitoring Deployment Progress

The script now provides detailed progress information:

```
[INFO] Pre-Deployment Validation
[SUCCESS] PostgreSQL Flexible Server is available in 'northeurope'
[SUCCESS] No Key Vault naming conflicts detected
[SUCCESS] GPU VM quota is sufficient (Limit: 48 vCPUs, Current: 0)
[SUCCESS] Pre-deployment validation complete

[INFO] Deploying Bicep template (this takes 8-10 minutes)...
[SUCCESS] Infrastructure deployed

[SUCCESS] Key Vault name includes location identifier (ensures regional uniqueness)
[SUCCESS] Key Vault purge protection is disabled - allows full cleanup

[SUCCESS] PostgreSQL password updated successfully
[SUCCESS] PostgreSQL connection verified successfully

[INFO] Waiting for Open-WebUI pod to be ready...
[WARNING] IMPORTANT: First startup requires downloading embedding model from HuggingFace (5-15 minutes)

[45s/900s] Phase: Running | Ready: False | Container Ready: false | Restarts: 0
  └─ Detected: Initializing embedding model (this takes 5-15 minutes on first run)

[75s/900s] Phase: Running | Ready: False | Container Ready: false | Restarts: 0

[SUCCESS] Open-WebUI pod is ready!
[SUCCESS] Open-WebUI HTTP endpoint is responding
```

## Related Documentation

- [POSTGRES-CONFIG.md](./POSTGRES-CONFIG.md) - PostgreSQL configuration details
- [README.md](./README.md) - Main project documentation
- [scripts/cleanup.ps1](./scripts/cleanup.ps1) - Enhanced cleanup with Key Vault purging

## Change Log

| Date | Change | Impact |
|------|--------|--------|
| 2024-01-XX | Added pre-deployment validation | Prevents regional deployment failures |
| 2024-01-XX | Enhanced Key Vault naming | Enables multi-region deployments |
| 2024-01-XX | PostgreSQL password sync | Fixes authentication failures |
| 2024-01-XX | Extended Open-WebUI timeout | Handles first-startup model download |
| 2024-01-XX | Added progress monitoring | Improves deployment visibility |
| 2024-01-XX | Comprehensive error messages | Easier troubleshooting |
