# Scripts Directory

Management and deployment scripts for the LLM Infrastructure platform.

## Overview

All scripts use a common library (`Common.ps1`) that provides standardized logging, validation, and utility functions for consistency and easier maintenance.

## Quick Reference

| Script | Purpose | Usage |
|--------|---------|-------|
| **deploy.ps1** | Full infrastructure deployment | Main deployment script |
| **cleanup.ps1** | Resource cleanup | Tear down infrastructure |
| **preload-multi-models.ps1** | Download models | Pre-load LLM models |
| **scale-ollama-to-zero.ps1** | Manual scale-to-zero | Scale Ollama pods to 0 |
| **update-dashboard.ps1** | Update Grafana dashboards | Upload dashboard JSON files |
| **verify-deployment-ready.ps1** | Verify deployment | Check deployment status |
| **verify-gpu-metrics.ps1** | Check GPU metrics | Validate GPU monitoring |

## Common Library

**File:** `Common.ps1`

Provides shared functions for all scripts:

### Logging Functions
- `Write-StepHeader` - Section headers
- `Write-Success` - Success messages
- `Write-Info` - Informational messages
- `Write-ErrorMsg` - Error messages
- `Write-Warning` - Warning messages

### Validation Functions
- `Test-Prerequisites` - Check required tools
- `Test-AzureConnection` - Verify Azure CLI auth
- `Test-KubernetesConnection` - Verify kubectl connection

### Password & Security Functions
- `New-RandomPassword` - Generate secure random passwords
- `Get-KeyVaultSecret` - Retrieve secrets from Key Vault with error handling
- `Set-KeyVaultRBACAccess` - Assign Key Vault Secrets Officer role

### Helm Functions
- `Deploy-HelmChart` - Deploy or upgrade Helm charts with standard error handling
- `Get-HelmReleaseStatus` - Get the status of a Helm release

### Azure Functions
- `Get-AKSCredentials` - Get AKS cluster credentials
- `Get-DeploymentOutput` - Get outputs from Azure deployment

### Kubernetes Functions
- `Wait-ForPodReady` - Wait for pod readiness
- `Get-PodName` - Get pod name by label

### Utility Functions
- `Confirm-Action` - User confirmation prompts
- `Format-ByteSize` - Format bytes to human-readable
- `Get-ElapsedTime` - Get elapsed time string

### Usage in Scripts

```powershell
# Load common library
. (Join-Path $PSScriptRoot "Common.ps1")

# Use functions
Write-StepHeader "My Section"
Write-Info "Starting process..."

if (Test-Prerequisites -Tools @('kubectl', 'az')) {
    Write-Success "All tools found"
}
```

## Script Details

### deploy.ps1

**Purpose:** Deploy complete LLM infrastructure

**Parameters:**
- `-Prefix` (required) - Unique prefix for resources (3-8 chars)
- `-Location` - Azure region (default: westus2)
- `-HuggingFaceToken` (required) - HuggingFace API token
- `-AutoApprove` - Skip confirmation prompts

**Example:**
```powershell
.\scripts\deploy.ps1 -Prefix "demo" -Location "westus2" -HuggingFaceToken "hf_xxx"
```

**What it does:**
1. Validates prerequisites
2. Creates resource group
3. Deploys Bicep infrastructure (AKS, Key Vault, Storage)
4. Configures Kubernetes
5. Deploys applications (Ollama, Open-WebUI)
6. Sets up monitoring (Prometheus, Grafana)

---

### cleanup.ps1

**Purpose:** Clean up deployed resources

**Parameters:**
- `-Prefix` (required) - Deployment prefix
- `-KeepResourceGroup` - Delete only K8s resources
- `-DataOnly` - Delete only user data
- `-WipeDatabase` - Drop and recreate database
- `-Force` - Skip confirmations

**Examples:**
```powershell
# Full cleanup
.\scripts\cleanup.ps1 -Prefix "demo"

# Keep infrastructure, delete K8s only
.\scripts\cleanup.ps1 -Prefix "demo" -KeepResourceGroup -Force

# Reset user data only
.\scripts\cleanup.ps1 -Prefix "demo" -DataOnly
```

---

### preload-multi-models.ps1

**Purpose:** Download multiple LLM models into Ollama

**Parameters:**
- `-Namespace` - Kubernetes namespace (default: ollama)
- `-Models` - Array of model names
- `-DryRun` - Test without downloading

**Example:**
```powershell
# Use default models
.\scripts\preload-multi-models.ps1

# Custom models
.\scripts\preload-multi-models.ps1 -Models @("phi3.5", "llama3.1:8b")

# Dry run
.\scripts\preload-multi-models.ps1 -DryRun
```

**Default Models:**
- phi3.5 (2.3GB)
- llama3.1:8b (4.7GB)
- mistral:7b (4.1GB)
- gemma2:2b (1.6GB)
- gpt-oss (13GB)
- deepseek-r1 (8GB)

---

### verify-deployment-ready.ps1

**Purpose:** Verify deployment is fully operational

**Parameters:**
- `-Prefix` - Deployment prefix
- `-Namespace` - Kubernetes namespace (default: ollama)

**Example:**
```powershell
.\scripts\verify-deployment-ready.ps1 -Prefix "demo"
```

**Checks:**
- All pods running
- Services accessible
- GPU metrics available
- Models loaded

---

### verify-gpu-metrics.ps1

**Purpose:** Validate GPU monitoring and metrics

**Parameters:**
- `-Namespace` - Kubernetes namespace (default: ollama)

**Example:**
```powershell
.\scripts\verify-gpu-metrics.ps1
```

**Validates:**
- DCGM Exporter running
- Prometheus collecting metrics
- GPU utilization visible
- GPU memory metrics available

---

## Best Practices

### Error Handling

All scripts use consistent error handling:

```powershell
$ErrorActionPreference = 'Stop'

try {
    # Your code
    Write-Success "Operation completed"
}
catch {
    Write-ErrorMsg "Operation failed: $($_.Exception.Message)"
    exit 1
}
```

### Logging

Use common logging functions for consistency:

```powershell
Write-StepHeader "Starting Process"
Write-Info "Processing item 1..."
Write-Success "Item 1 complete"
Write-Warning "Item 2 needs attention"
Write-ErrorMsg "Item 3 failed"
```

### Validation

Always validate prerequisites:

```powershell
if (-not (Test-Prerequisites -Tools @('kubectl', 'az'))) {
    exit 1
}

if (-not (Test-KubernetesConnection)) {
    exit 1
}
```

---

## Development Guidelines

### Adding New Scripts

1. **Use Common Library:**
   ```powershell
   . (Join-Path $PSScriptRoot "Common.ps1")
   ```

2. **Include Comment-Based Help:**
   ```powershell
   <#
   .SYNOPSIS
       Brief description

   .DESCRIPTION
       Detailed description

   .PARAMETER ParamName
       Parameter description

   .EXAMPLE
       .\script.ps1 -Param value
   #>
   ```

3. **Validate Parameters:**
   ```powershell
   [Parameter(Mandatory=$true)]
   [ValidatePattern('^[a-z0-9]{3,8}$')]
   [string]$Prefix
   ```

4. **Use Consistent Structure:**
   - Load common library
   - Define parameters
   - Validate prerequisites
   - Main logic in regions
   - Cleanup and summary

### Modifying Existing Scripts

1. Test changes with `-DryRun` or `-WhatIf` where available
2. Update comment-based help
3. Maintain parameter validation
4. Keep error handling consistent
5. Update this README if behavior changes

---

## Troubleshooting

### Common Issues

**Script not found:**
```powershell
# Ensure you're in project root
cd d:\github\shsorot\Scalable_LLM_Inference_on_Azure_AKS
.\scripts\script-name.ps1
```

**Prerequisites missing:**
```powershell
# Check tools
kubectl version
az version

# Install if needed
winget install kubernetes-cli
winget install Microsoft.AzureCLI
```

**Authentication errors:**
```powershell
# Azure
az login
az account set --subscription "your-subscription"

# Kubernetes
az aks get-credentials --resource-group demo-rg --name demo-aks
```

**PowerShell execution policy:**
```powershell
# Check policy
Get-ExecutionPolicy

# Set policy (run as Administrator)
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
```

---

## File Size Comparison

After consolidation and Common.ps1 creation:

| File | Lines | Size | Improvement |
|------|-------|------|-------------|
| Common.ps1 | 332 | 11.1 KB | New shared library |
| preload-multi-models.ps1 | 239 | 9.2 KB | -17% lines |
| *Future optimizations* | - | - | More to come |

**Benefits:**
- ✅ Reduced code duplication
- ✅ Easier maintenance
- ✅ Consistent error handling
- ✅ Standardized logging
- ✅ Better readability

---

## Next Steps

Scripts planned for simplification:
1. ~~preload-multi-models.ps1~~ ✅ Complete
2. cleanup.ps1
3. test-scaling.ps1
4. verify-gpu-metrics.ps1
5. set-models-public.ps1

Target: Reduce overall codebase by 20-30%
