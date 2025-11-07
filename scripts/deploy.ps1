<#
.SYNOPSIS
    Deploy Scalable LLM Inference Platform on Azure AKS with GPU autoscaling

.DESCRIPTION
    Deploys complete infrastructure: AKS with GPU nodes, Ollama, Open-WebUI,
    Prometheus/Grafana monitoring, and GPU-based autoscaling.

.PARAMETER Prefix
    Unique prefix for resource naming (3-8 lowercase alphanumeric chars)

.PARAMETER Location
    Azure region (northeurope, westus2, or eastus)

.PARAMETER HuggingFaceToken
    HuggingFace token for model downloads

.EXAMPLE
    .\scripts\deploy.ps1 -Prefix "demo" -Location "westus2" -HuggingFaceToken "hf_xxx"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true, HelpMessage="Enter a unique prefix (3-8 lowercase alphanumeric chars) for resource naming, e.g., 'demo01' or 'kube'")]
    [ValidatePattern('^[a-z0-9]{3,8}$')]
    [ValidateNotNullOrEmpty()]
    [string]$Prefix,

    [Parameter(Mandatory=$false)]
    [string]$Location = "westus2",

    [Parameter(Mandatory=$true, HelpMessage="Enter your HuggingFace token for model downloads")]
    [ValidateNotNullOrEmpty()]
    [string]$HuggingFaceToken,

    [Parameter(Mandatory=$false, HelpMessage="Automatically reuse existing resource group without prompting")]
    [switch]$AutoApprove,

    [Parameter(Mandatory=$false, HelpMessage="Storage backend for LLM models: 'AzureFiles' (fast, expensive) or 'BlobStorage' (streaming, 87% cheaper)")]
    [ValidateSet('AzureFiles', 'BlobStorage')]
    [string]$StorageBackend = 'AzureFiles'
)

# Ensure we're in the correct directory (llm-demo folder)
$ScriptRoot = Split-Path -Parent $PSCommandPath
$ProjectRoot = Split-Path -Parent $ScriptRoot

# CRITICAL: Change to project root so all relative paths work
Set-Location -Path $ProjectRoot -ErrorAction Stop
Write-Verbose "Working directory: $(Get-Location)"

# Load System.Web assembly for URL encoding
Add-Type -AssemblyName System.Web

# Function to generate secure random password
function New-RandomPassword {
    param(
        [int]$Length = 16
    )
    $chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*"
    $password = -join ((1..$Length) | ForEach-Object { $chars[(Get-Random -Maximum $chars.Length)] })
    return $password
}

# Trap all errors and show them
$ErrorActionPreference = "Stop"
$VerbosePreference = "Continue"

$ResourceGroupName = "${Prefix}-rg"
$BicepMainFile = "bicep\main.bicep"
$K8sManifestsDir = "k8s"
$PreloadScript = "scripts\preload-model.ps1"

# Validate files exist
if (-not (Test-Path $BicepMainFile)) {
    Write-ErrorMsg "Bicep file not found at: $(Resolve-Path $BicepMainFile -ErrorAction SilentlyContinue). Current directory: $(Get-Location)"
    exit 1
}
if (-not (Test-Path $K8sManifestsDir)) {
    Write-ErrorMsg "K8s directory not found at: $(Resolve-Path $K8sManifestsDir -ErrorAction SilentlyContinue). Current directory: $(Get-Location)"
    exit 1
}

function Write-StepHeader {
    param([string]$Message)
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host $Message -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
}

function Write-Success {
    param([string]$Message)
    Write-Host "[OK] $Message" -ForegroundColor Green
}

function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Yellow
}

function Write-ErrorMsg {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

# Display deployment configuration
Write-Host "`n============================================" -ForegroundColor Magenta
Write-Host "  KubeCon NA 2025 - LLM Demo Deployment" -ForegroundColor Magenta
Write-Host "============================================" -ForegroundColor Magenta
Write-Host "Deployment Prefix  : " -NoNewline -ForegroundColor White
Write-Host "$Prefix" -ForegroundColor Green
Write-Host "Resource Group     : " -NoNewline -ForegroundColor White
Write-Host "$ResourceGroupName" -ForegroundColor Green
Write-Host "Location           : " -NoNewline -ForegroundColor White
Write-Host "$Location" -ForegroundColor Green
Write-Host "HuggingFace Token  : " -NoNewline -ForegroundColor White
Write-Host "***" -NoNewline -ForegroundColor Green
Write-Host $HuggingFaceToken.Substring($HuggingFaceToken.Length - 6) -ForegroundColor Green
Write-Host "============================================`n" -ForegroundColor Magenta

Write-StepHeader "Pre-Flight Checks"

try {
    $azVersion = (az version | ConvertFrom-Json).'azure-cli'
    Write-Success "Azure CLI installed: $azVersion"
} catch {
    Write-ErrorMsg "Azure CLI not found. Please install from https://aka.ms/installazurecli"
    exit 1
}

try {
    $kubectlVersion = kubectl version --client -o json | ConvertFrom-Json
    Write-Success "kubectl installed: $($kubectlVersion.clientVersion.gitVersion)"
} catch {
    Write-ErrorMsg "kubectl not found. Please install from https://kubernetes.io/docs/tasks/tools/"
    exit 1
}

if (-not (Test-Path $BicepMainFile)) {
    Write-ErrorMsg "Bicep file not found: $BicepMainFile"
    exit 1
}
Write-Success "Bicep files found"

if (-not (Test-Path $K8sManifestsDir)) {
    Write-ErrorMsg "K8s manifests directory not found: $K8sManifestsDir"
    exit 1
}
Write-Success "K8s manifests directory found"

try {
    $account = az account show | ConvertFrom-Json
    Write-Success "Logged into Azure: $($account.user.name) (Subscription: $($account.name))"
} catch {
    Write-ErrorMsg "Not logged into Azure. Run 'az login'"
    exit 1
}

Write-StepHeader "Deploying Azure Infrastructure"

# Check if resource group exists
$rgExists = az group exists --name $ResourceGroupName
if ($rgExists -eq "true") {
    $existingRg = az group show --name $ResourceGroupName | ConvertFrom-Json
    Write-Host "`n[WARNING] Resource group '$ResourceGroupName' already exists in location: $($existingRg.location)" -ForegroundColor Yellow

    if ($existingRg.location -ne $Location) {
        Write-ErrorMsg "Resource group exists in different location ($($existingRg.location)). Please use a different prefix or run cleanup first."
        Write-Host "To cleanup: .\scripts\cleanup.ps1 -Prefix $Prefix" -ForegroundColor Cyan
        exit 1
    }

    if ($AutoApprove) {
        Write-Success "Reusing existing resource group (auto-approved)"
    } else {
        $reuse = Read-Host "`nDo you want to reuse this resource group? (yes/no)"
        if ($reuse -ne "yes") {
            Write-Host "`nPlease run cleanup first: .\scripts\cleanup.ps1 -Prefix $Prefix" -ForegroundColor Cyan
            exit 1
        }
        Write-Success "Reusing existing resource group"
    }
} else {
    Write-Info "Creating resource group: $ResourceGroupName in $Location"
    az group create --name $ResourceGroupName --location $Location
    if ($LASTEXITCODE -ne 0) {
        Write-ErrorMsg "Failed to create resource group"
        exit 1
    }
    Write-Success "Resource group created"
}

Write-StepHeader "Generating PostgreSQL Admin Password"

# Generate secure random password for PostgreSQL
$PostgresPassword = -join ((48..57) + (65..90) + (97..122) | Get-Random -Count 24 | ForEach-Object {[char]$_})
# Add special characters to meet Azure PostgreSQL requirements
$PostgresPassword = $PostgresPassword + "!@#"
Write-Success "PostgreSQL admin password generated (will be stored in Key Vault)"

Write-StepHeader "Generating Grafana Admin Password"

# Generate secure random password for Grafana
$GrafanaPassword = New-RandomPassword -Length 16
Write-Success "Grafana admin password generated (will be stored in Key Vault)"

Write-Info "Deploying Bicep template (this takes 8-10 minutes)..."
Write-Info "Progress will be shown below. Please wait..."
Write-Host ""

# Run deployment in foreground with output visible
az deployment group create `
    --resource-group $ResourceGroupName `
    --template-file $BicepMainFile `
    --parameters prefix=$Prefix location=$Location huggingFaceToken=$HuggingFaceToken postgresAdminPassword=$PostgresPassword storageBackend=$StorageBackend `
    --output table

if ($LASTEXITCODE -ne 0) {
    Write-ErrorMsg "Bicep deployment failed. Check the output above for details."
    exit 1
}

Write-Success "Infrastructure deployed"

# Get deployment outputs
Write-Info "Retrieving deployment outputs..."
$deploymentOutput = az deployment group show `
    --name main `
    --resource-group $ResourceGroupName `
    --query 'properties.outputs' `
    --output json

try {
    $deployment = $deploymentOutput | ConvertFrom-Json
} catch {
    Write-ErrorMsg "Failed to parse deployment output"
    exit 1
}

$aksClusterName = $deployment.aksClusterName.value
$keyVaultName = $deployment.keyVaultName.value
$premiumStorageAccountName = $deployment.premiumStorageAccountName.value
$standardStorageAccountName = $deployment.standardStorageAccountName.value
$postgresServerFqdn = $deployment.postgresServerFqdn.value
$postgresAdminUsername = $deployment.postgresAdminUsername.value
$postgresDatabaseName = $deployment.postgresDatabaseName.value

Write-Info "AKS Cluster: $aksClusterName"
Write-Info "Key Vault: $keyVaultName"
Write-Info "Premium Storage: $premiumStorageAccountName"
Write-Info "Standard Storage: $standardStorageAccountName"
Write-Info "PostgreSQL Server: $postgresServerFqdn"
Write-Info "PostgreSQL Database: $postgresDatabaseName"

Write-StepHeader "Storing Secrets in Key Vault"

Write-Info "Assigning Key Vault Secrets Officer role to current user..."
$currentUserId = az ad signed-in-user show --query id -o tsv
$keyVaultResourceId = az keyvault show --name $keyVaultName --resource-group $ResourceGroupName --query id -o tsv

az role assignment create `
    --assignee $currentUserId `
    --role "Key Vault Secrets Officer" `
    --scope $keyVaultResourceId `
    --output none 2>&1 | Out-Null

if ($LASTEXITCODE -eq 0) {
    Write-Success "Key Vault Secrets Officer role assigned"
    Write-Info "Waiting 30 seconds for RBAC propagation..."
    Start-Sleep -Seconds 30
} else {
    Write-Warning "Failed to assign Key Vault role (may already exist). Waiting 15 seconds for propagation..."
    Start-Sleep -Seconds 15
}

Write-Info "Storing PostgreSQL password in Key Vault..."
az keyvault secret set `
    --vault-name $keyVaultName `
    --name "postgres-admin-password" `
    --value $PostgresPassword `
    --output none

if ($LASTEXITCODE -eq 0) {
    Write-Success "PostgreSQL password stored in Key Vault"
} else {
    Write-Warning "Failed to store PostgreSQL password in Key Vault"
}

Write-Info "Storing PostgreSQL connection string in Key Vault..."
# URL-encode the password for the connection string
$urlEncodedPassword = [System.Web.HttpUtility]::UrlEncode($PostgresPassword)
$postgresConnectionString = "postgresql://${postgresAdminUsername}:${urlEncodedPassword}@${postgresServerFqdn}:5432/${postgresDatabaseName}?sslmode=require"
az keyvault secret set `
    --vault-name $keyVaultName `
    --name "postgres-connection-string" `
    --value $postgresConnectionString `
    --output none

if ($LASTEXITCODE -eq 0) {
    Write-Success "PostgreSQL connection string stored in Key Vault"
} else {
    Write-Warning "Failed to store connection string in Key Vault"
}

Write-Info "Storing Grafana admin password in Key Vault..."
az keyvault secret set `
    --vault-name $keyVaultName `
    --name "grafana-admin-password" `
    --value $GrafanaPassword `
    --output none

if ($LASTEXITCODE -eq 0) {
    Write-Success "Grafana password stored in Key Vault"
} else {
    Write-Warning "Failed to store Grafana password in Key Vault"
}

Write-StepHeader "Configuring kubectl and RBAC"

Write-Info "Waiting for AKS cluster to be fully provisioned..."
$maxWaitSeconds = 600  # 10 minutes
$elapsedSeconds = 0
$clusterReady = $false

while ($elapsedSeconds -lt $maxWaitSeconds) {
    # Suppress warnings from Azure CLI extensions
    $ErrorActionPreference = 'SilentlyContinue'
    $clusterStatus = (az aks show --resource-group $ResourceGroupName --name $aksClusterName --query "provisioningState" -o tsv 2>&1 | Where-Object { $_ -notmatch '^WARNING:' }) -join ''
    $ErrorActionPreference = 'Stop'

    if ($clusterStatus -eq "Succeeded") {
        $clusterReady = $true
        Write-Success "AKS cluster is ready (provisioningState: Succeeded)"
        break
    }

    Write-Host "  Waiting for AKS cluster to be ready... ($elapsedSeconds/$maxWaitSeconds seconds, Current state: $clusterStatus)" -ForegroundColor Yellow
    Start-Sleep -Seconds 15
    $elapsedSeconds += 15
}

if (-not $clusterReady) {
    Write-ErrorMsg "AKS cluster did not reach ready state within $maxWaitSeconds seconds"
    exit 1
}

Write-Info "Assigning Azure Kubernetes Service RBAC Cluster Admin role to current user..."
# $currentUserId already retrieved earlier for Key Vault
$aksResourceId = az aks show --resource-group $ResourceGroupName --name $aksClusterName --query id -o tsv

az role assignment create `
    --assignee $currentUserId `
    --role "Azure Kubernetes Service RBAC Cluster Admin" `
    --scope $aksResourceId `
    --output none 2>&1 | Out-Null

if ($LASTEXITCODE -eq 0) {
    Write-Success "Azure Kubernetes Service RBAC Cluster Admin role assigned"
} else {
    Write-Warning "Failed to assign RBAC role (may already exist or insufficient permissions)"
}

Write-Info "Assigning Azure Kubernetes Service Cluster User Role for portal access..."
az role assignment create `
    --assignee $currentUserId `
    --role "Azure Kubernetes Service Cluster User Role" `
    --scope $aksResourceId `
    --output none 2>&1 | Out-Null

if ($LASTEXITCODE -eq 0) {
    Write-Success "Azure Kubernetes Service Cluster User Role assigned"
} else {
    Write-Warning "Failed to assign Cluster User role (may already exist)"
}

Write-Info "Assigning Reader role on resource group for portal access..."
$rgId = az group show --name $ResourceGroupName --query id -o tsv
az role assignment create `
    --assignee $currentUserId `
    --role "Reader" `
    --scope $rgId `
    --output none 2>&1 | Out-Null

if ($LASTEXITCODE -eq 0) {
    Write-Success "Reader role assigned on resource group"
} else {
    Write-Warning "Failed to assign Reader role (may already exist)"
}

Write-Info "Waiting 15 seconds for AKS RBAC propagation..."
Start-Sleep -Seconds 15

Write-Info "Getting AKS credentials..."
az aks get-credentials `
    --resource-group $ResourceGroupName `
    --name $aksClusterName `
    --overwrite-existing `
    --admin | Out-Null

if ($LASTEXITCODE -ne 0) {
    Write-ErrorMsg "Failed to get AKS credentials"
    exit 1
}
Write-Success "kubectl configured"

Write-Info "Verifying cluster connection and waiting for nodes to be Ready..."
$maxNodeWaitSeconds = 300  # 5 minutes
$nodeElapsedSeconds = 0
$allNodesReady = $false

while ($nodeElapsedSeconds -lt $maxNodeWaitSeconds) {
    $nodes = kubectl get nodes --no-headers 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  Waiting for API server to respond... ($nodeElapsedSeconds/$maxNodeWaitSeconds seconds)" -ForegroundColor Yellow
        Start-Sleep -Seconds 10
        $nodeElapsedSeconds += 10
        continue
    }

    # Check if all nodes are Ready
    $notReadyNodes = kubectl get nodes --no-headers | Where-Object { $_ -notmatch '\sReady\s' }

    if (-not $notReadyNodes) {
        $allNodesReady = $true
        Write-Success "All nodes are Ready"
        break
    }

    $nodeCount = (kubectl get nodes --no-headers | Measure-Object).Count
    $readyCount = (kubectl get nodes --no-headers | Where-Object { $_ -match '\sReady\s' } | Measure-Object).Count
    Write-Host "  Waiting for all nodes to be Ready... ($readyCount/$nodeCount ready, $nodeElapsedSeconds/$maxNodeWaitSeconds seconds)" -ForegroundColor Yellow
    Start-Sleep -Seconds 15
    $nodeElapsedSeconds += 15
}

if (-not $allNodesReady) {
    Write-Warning "Not all nodes are Ready, but continuing deployment..."
}

Write-Success "Connected to AKS cluster"
$nodeList = kubectl get nodes --no-headers
Write-Info "Nodes:`n$nodeList"

Write-StepHeader "Verifying CSI Drivers Readiness"

Write-Info "Waiting for Azure Files CSI driver to be ready..."
$maxWaitSeconds = 120
$elapsedSeconds = 0
$filesCSIReady = $false

while ($elapsedSeconds -lt $maxWaitSeconds) {
    $csiFilePods = kubectl get pods -n kube-system -l app=csi-azurefile-controller -o jsonpath='{.items[*].status.phase}' 2>$null
    if ($csiFilePods -match "Running") {
        $filesCSIReady = $true
        Write-Success "Azure Files CSI driver is ready"
        break
    }
    Write-Host "  Waiting for Azure Files CSI driver... ($elapsedSeconds/$maxWaitSeconds seconds)" -ForegroundColor Gray
    Start-Sleep -Seconds 5
    $elapsedSeconds += 5
}

if (-not $filesCSIReady) {
    Write-Warning "Azure Files CSI driver not ready within timeout, but continuing..."
}

if ($StorageBackend -eq 'BlobStorage') {
    Write-Info "Waiting for Azure Blob CSI driver to be ready..."
    $elapsedSeconds = 0
    $blobCSIReady = $false

    while ($elapsedSeconds -lt $maxWaitSeconds) {
        $csiBlobPods = kubectl get pods -n kube-system -l app=csi-blob-controller -o jsonpath='{.items[*].status.phase}' 2>$null
        if ($csiBlobPods -match "Running") {
            $blobCSIReady = $true
            Write-Success "Azure Blob CSI driver is ready"
            break
        }
        Write-Host "  Waiting for Azure Blob CSI driver... ($elapsedSeconds/$maxWaitSeconds seconds)" -ForegroundColor Gray
        Start-Sleep -Seconds 5
        $elapsedSeconds += 5
    }

    if (-not $blobCSIReady) {
        Write-Warning "Azure Blob CSI driver not ready within timeout, but continuing..."
    }
}

Write-Info "Waiting for Azure Key Vault Secrets Store CSI driver to be ready..."
$elapsedSeconds = 0
$kvCSIReady = $false

while ($elapsedSeconds -lt $maxWaitSeconds) {
    $csiSecretsPods = kubectl get pods -n kube-system -l app.kubernetes.io/name=secrets-store-csi-driver -o jsonpath='{.items[*].status.phase}' 2>$null
    if ($csiSecretsPods -match "Running") {
        $kvCSIReady = $true
        Write-Success "Key Vault Secrets Store CSI driver is ready"
        break
    }
    Write-Host "  Waiting for Secrets Store CSI driver... ($elapsedSeconds/$maxWaitSeconds seconds)" -ForegroundColor Gray
    Start-Sleep -Seconds 5
    $elapsedSeconds += 5
}

if (-not $kvCSIReady) {
    Write-Warning "Secrets Store CSI driver not ready within timeout, but continuing..."
}

Write-StepHeader "Installing NVIDIA GPU Support"

Write-Info "Installing NVIDIA device plugin..."
$nvidiaPluginManifest = Join-Path $K8sManifestsDir "01-nvidia-device-plugin.yaml"
kubectl apply -f $nvidiaPluginManifest
Write-Success "NVIDIA device plugin deployed"

Write-Info "Waiting for GPU drivers to initialize on GPU nodes (max 5 minutes)..."
$maxWaitSeconds = 300
$elapsedSeconds = 0
$gpuReady = $false

while ($elapsedSeconds -lt $maxWaitSeconds) {
    try {
        # Check if nvidia.com/gpu resource is available on GPU nodes
        $gpuNodes = kubectl get nodes -l workload=llm -o json | ConvertFrom-Json
        $allGpusReady = $true

        foreach ($node in $gpuNodes.items) {
            $gpuCapacity = $node.status.capacity.'nvidia.com/gpu'
            if (-not $gpuCapacity -or $gpuCapacity -eq "0") {
                $allGpusReady = $false
                Write-Host "  ? Node $($node.metadata.name): GPU not ready yet..." -ForegroundColor Gray
                break
            } else {
                Write-Host "  ? Node $($node.metadata.name): $gpuCapacity GPU(s) available" -ForegroundColor Green
            }
        }

        if ($allGpusReady -and $gpuNodes.items.Count -gt 0) {
            $gpuReady = $true
            break
        }
    } catch {
        Write-Host "  ? Checking GPU status..." -ForegroundColor Gray
    }

    Start-Sleep -Seconds 10
    $elapsedSeconds += 10
}

if (-not $gpuReady) {
    Write-ErrorMsg "GPU drivers did not initialize within 5 minutes. Check NVIDIA device plugin logs."
    Write-Info "Debug command: kubectl logs -n kube-system -l name=nvidia-device-plugin-ds"
    exit 1
}

Write-Success "GPU drivers initialized and available"

# Verify GPU availability
$totalGpus = kubectl get nodes -l workload=llm -o json | ConvertFrom-Json |
    ForEach-Object { $_.items } |
    ForEach-Object { [int]$_.status.capacity.'nvidia.com/gpu' } |
    Measure-Object -Sum |
    Select-Object -ExpandProperty Sum

Write-Info "Total GPUs available in cluster: $totalGpus"

Write-Info "Deploying GPU monitoring (DCGM Exporter)..."
if (Test-Path "$K8sManifestsDir/11-dcgm-exporter.yaml") {
    kubectl apply -f "$K8sManifestsDir/11-dcgm-exporter.yaml"
    Write-Success "DCGM Exporter deployed for GPU metrics"

    Write-Info "Waiting for DCGM Exporter to be ready..."
    $maxWait = 60
    $elapsed = 0
    while ($elapsed -lt $maxWait) {
        $dcgmReady = kubectl get pods -n ollama -l app.kubernetes.io/name=dcgm-exporter -o jsonpath='{.items[*].status.phase}' 2>$null
        if ($dcgmReady -match "Running") {
            Write-Success "DCGM Exporter is ready"
            break
        }
        Start-Sleep -Seconds 5
        $elapsed += 5
    }
} else {
    Write-Warning "DCGM Exporter manifest not found, skipping GPU metrics deployment"
}

Write-StepHeader "Deploying Kubernetes Resources"

Write-Info "Applying resource quota..."
kubectl apply -f "$K8sManifestsDir/09-resource-quota.yaml"
Write-Success "Resource quota applied"

Write-Info "Creating Ollama namespace..."
kubectl apply -f "$K8sManifestsDir/01-namespace.yaml"
Write-Success "Ollama namespace created"

Write-Info "Deploying Azure Key Vault SecretProviderClass..."
$tenantId = az account show --query tenantId -o tsv
$secretProviderManifest = Get-Content "$K8sManifestsDir/03-keyvault-secret-provider.yaml" -Raw
$secretProviderManifest = $secretProviderManifest -replace 'KEYVAULT_NAME', $keyVaultName -replace 'TENANT_ID', $tenantId
$tempSecretProviderFile = Join-Path $env:TEMP "keyvault-secret-provider.yaml"
Set-Content -Path $tempSecretProviderFile -Value $secretProviderManifest
kubectl apply -f $tempSecretProviderFile | Out-Null
Remove-Item $tempSecretProviderFile -ErrorAction SilentlyContinue
Write-Success "SecretProviderClass created for Key Vault access"

# Storage account keys are only needed if using standalone storage accounts
if ($premiumStorageAccountName -and $standardStorageAccountName) {
    Write-Info "Storing storage account keys in Key Vault..."
    $premiumKey = az storage account keys list --resource-group $ResourceGroupName --account-name $premiumStorageAccountName --query '[0].value' -o tsv
    $standardKey = az storage account keys list --resource-group $ResourceGroupName --account-name $standardStorageAccountName --query '[0].value' -o tsv

    az keyvault secret set --vault-name $keyVaultName --name "azurefiles-models-key" --value $premiumKey
    az keyvault secret set --vault-name $keyVaultName --name "azurefiles-cache-key" --value $standardKey
    Write-Success "Storage keys stored in Key Vault"
} else {
    Write-Info "Using AKS built-in Azure Files CSI driver (no standalone storage accounts)"
    $premiumKey = ""
    $standardKey = ""
}

Write-Info "Creating Kubernetes secrets..."

# Generate secure random key for Open-WebUI (PowerShell 5.1 compatible)
$rng = New-Object System.Security.Cryptography.RNGCryptoServiceProvider
$secretKeyBytes = New-Object byte[] 32
$rng.GetBytes($secretKeyBytes)
$rng.Dispose()
$secretKey = [System.Convert]::ToBase64String($secretKeyBytes)

kubectl create secret generic ollama-secrets `
    --from-literal=premium-key=$premiumKey `
    --from-literal=standard-key=$standardKey `
    --from-literal=hf-token=$HuggingFaceToken `
    --from-literal=openwebui-secret-key=$secretKey `
    --from-literal=postgres-connection-string=$postgresConnectionString `
    --namespace ollama `
    --dry-run=client -o yaml | kubectl apply -f -

Write-Success "Kubernetes secrets created (including PostgreSQL connection)"

Write-Info "Deploying storage classes..."
if ($StorageBackend -eq 'AzureFiles') {
    Write-Info "  Using Azure Files Premium for model storage (default)"
    kubectl apply -f "$K8sManifestsDir/02-storage-premium.yaml"
    Write-Success "Storage class deployed (Azure Files Premium)"
} else {
    Write-Info "  Using Azure Blob Storage with BlobFuse2 for model storage (streaming mode, 87% cheaper)"
    kubectl apply -f "$K8sManifestsDir/02-storage-blob-fuse.yaml"
    Write-Success "Storage class deployed (Azure Blob Storage + BlobFuse2)"
    Write-Info "  Also deploying Azure Files StorageClass for WebUI storage..."
    kubectl apply -f "$K8sManifestsDir/02-storage-premium.yaml"
    Write-Success "Azure Files StorageClass deployed for WebUI"
}

Write-Info "Deploying Persistent Volume Claims..."
if ($StorageBackend -eq 'AzureFiles') {
    Write-Info "  - Ollama models PVC (Azure Files Premium, 1024GB / 1TB)..."
} else {
    Write-Info "  - Ollama models PVC (Azure Blob Storage, 1024GB / 1TB, streaming)..."
}
Write-Info "  - Open-WebUI data PVC (Azure Files Premium, 20GB - always Azure Files)..."
kubectl apply -f "$K8sManifestsDir/04-storage-webui-files.yaml"
Write-Success "PVCs created"

Write-Info "Waiting for PVCs to be bound (max 2 minutes)..."
$maxWaitSeconds = 120
$elapsedSeconds = 0
while ($elapsedSeconds -lt $maxWaitSeconds) {
    $pvcStatus = kubectl get pvc -n ollama -o json | ConvertFrom-Json
    $allBound = $true
    foreach ($pvc in $pvcStatus.items) {
        if ($pvc.status.phase -ne "Bound") {
            # Check if this PVC uses WaitForFirstConsumer binding mode
            $storageClassName = $pvc.spec.storageClassName
            $sc = kubectl get storageclass $storageClassName -o json 2>$null | ConvertFrom-Json
            if ($sc.volumeBindingMode -eq "WaitForFirstConsumer") {
                Write-Info "  PVC '$($pvc.metadata.name)' uses WaitForFirstConsumer (will bind when pod starts)"
                continue
            }
            $allBound = $false
            break
        }
    }
    if ($allBound) {
        Write-Success "All immediate-binding PVCs bound"
        break
    }
    Start-Sleep -Seconds 5
    $elapsedSeconds += 5
    if (($elapsedSeconds % 15) -eq 0) {
        Write-Info "Still waiting... ($elapsedSeconds/$maxWaitSeconds seconds)"
    }
}

if ($elapsedSeconds -ge $maxWaitSeconds) {
    Write-ErrorMsg "PVCs did not bind within timeout"
    exit 1
}

Write-Info "Deploying Ollama server (StatefulSet with autoscaling)..."
kubectl apply -f "$K8sManifestsDir/05-ollama-statefulset.yaml"
kubectl apply -f "$K8sManifestsDir/06-ollama-service.yaml"
Write-Success "Ollama deployed"

Write-Info "Waiting for Ollama pod to be ready (max 5 minutes)..."
kubectl wait --for=condition=ready pod -l app=ollama -n ollama --timeout=300s
if ($LASTEXITCODE -ne 0) {
    Write-ErrorMsg "Ollama pod did not become ready"
    exit 1
}
Write-Success "Ollama pod ready"

Write-StepHeader "Enabling PGVector Extensions"

Write-Info "Retrieving PostgreSQL server details..."
# Extract server name from FQDN (format: servername.postgres.database.azure.com)
$pgServerName = $postgresServerFqdn -replace '\.postgres\.database\.azure\.com$', ''
$pgHost = $postgresServerFqdn

Write-Info "PostgreSQL Server: $pgServerName"

Write-Info "Enabling pgvector extension parameter on PostgreSQL server..."
try {
    # Enable VECTOR and PGCRYPTO extensions in azure.extensions parameter
    az postgres flexible-server parameter set `
        --resource-group $ResourceGroupName `
        --server-name $pgServerName `
        --name azure.extensions `
        --value "VECTOR,PGCRYPTO" `
        --output none 2>$null

    Write-Success "Azure PostgreSQL extension parameter updated (VECTOR, PGCRYPTO enabled)"
} catch {
    Write-Warning "Failed to update extension parameter: $_"
}

Write-Info "Retrieving PostgreSQL connection details..."
$pgPassword = az keyvault secret show --vault-name $keyVaultName --name postgres-admin-password --query value -o tsv 2>$null

if ([string]::IsNullOrWhiteSpace($pgPassword)) {
    Write-Warning "Could not retrieve PostgreSQL password from Key Vault"
    Write-Info "You may need to create PGVector extension manually"
} else {
    Write-Info "Creating pgvector extension in $postgresDatabaseName database..."
    # Create temporary pod manifest
    $podManifest = @"
apiVersion: v1
kind: Pod
metadata:
  name: pgvector-setup
  namespace: ollama
spec:
  restartPolicy: Never
  nodeSelector:
    workload: system
  tolerations:
    - key: CriticalAddonsOnly
      operator: Equal
      value: "true"
      effect: NoSchedule
  containers:
    - name: psql
      image: postgres:16
      resources:
        requests:
          cpu: "100m"
          memory: "128Mi"
        limits:
          cpu: "500m"
          memory: "256Mi"
      command:
        - sh
        - -c
        - |
          export PGPASSWORD='$pgPassword'
          echo "Connecting to PostgreSQL..."
          psql -h $pgHost -U $postgresAdminUsername -d $postgresDatabaseName -c "CREATE EXTENSION IF NOT EXISTS vector;" || exit 1
          echo "pgvector extension created successfully!"
"@

    $tempPodFile = Join-Path $env:TEMP "pgvector-setup-pod.yaml"
    Set-Content -Path $tempPodFile -Value $podManifest

    try {
        # Delete pod if it exists from previous run
        kubectl delete pod pgvector-setup -n ollama --ignore-not-found=true 2>$null | Out-Null
        Start-Sleep -Seconds 2

        # Create the pod
        Write-Info "Running pgvector setup pod..."
        kubectl apply -f $tempPodFile | Out-Null

        # Wait for pod to complete (max 60 seconds)
        Write-Info "Waiting for extension creation..."
        $maxWait = 60
        $elapsed = 0
        $podCompleted = $false

        while ($elapsed -lt $maxWait -and -not $podCompleted) {
            Start-Sleep -Seconds 3
            $elapsed += 3

            $podStatus = kubectl get pod pgvector-setup -n ollama -o jsonpath='{.status.phase}' 2>$null
            if ($podStatus -eq "Succeeded") {
                $podCompleted = $true
                $logs = kubectl logs pgvector-setup -n ollama 2>$null
                Write-Info "Pod output: $logs"
                Write-Success "pgvector extension created successfully in openwebui database"
            } elseif ($podStatus -eq "Failed") {
                $logs = kubectl logs pgvector-setup -n ollama 2>$null
                Write-Warning "Pod failed. Logs: $logs"
                break
            }
        }

        if (-not $podCompleted) {
            Write-Warning "pgvector setup pod did not complete in time"
            Write-Info "Check pod status with: kubectl logs pgvector-setup -n ollama"
        }

        # Cleanup
        kubectl delete pod pgvector-setup -n ollama --ignore-not-found=true 2>$null | Out-Null
        Remove-Item $tempPodFile -ErrorAction SilentlyContinue

    } catch {
        Write-Warning "Failed to create pgvector extension via Kubernetes job: $_"
        Write-Info "Extension parameter is enabled, but you may need to create it manually"
        Write-Info "Run: CREATE EXTENSION IF NOT EXISTS vector; in the openwebui database"
    }
}

Write-Info "Deploying Open-WebUI (with Azure Files Premium + PostgreSQL backend)..."
kubectl apply -f "$K8sManifestsDir/07-webui-deployment.yaml"
kubectl apply -f "$K8sManifestsDir/08-webui-service.yaml"
Write-Success "Open-WebUI deployed"

# Deploy autoscaling components
Write-Info "Deploying Horizontal Pod Autoscalers..."
if (Test-Path "$K8sManifestsDir/10-webui-hpa.yaml") {
    kubectl apply -f "$K8sManifestsDir/10-webui-hpa.yaml"
    Write-Success "Open-WebUI HPA deployed"
}
if (Test-Path "$K8sManifestsDir/12-ollama-hpa.yaml") {
    kubectl apply -f "$K8sManifestsDir/12-ollama-hpa.yaml"
    Write-Success "Ollama HPA deployed"
}

Write-Info "Waiting for Open-WebUI pod to be ready (max 5 minutes)..."
Write-Info "Note: First startup may take 2-3 minutes to download embedding model..."
kubectl wait --for=condition=ready pod -l app=open-webui -n ollama --timeout=300s
if ($LASTEXITCODE -ne 0) {
    Write-Warning "Open-WebUI pods not ready yet, but continuing..."
    Write-Info "Pods may still be initializing, check with: kubectl get pods -n ollama"
} else {
    Write-Success "Open-WebUI pods ready"
}

Write-StepHeader "Pre-Loading Multiple Models"

$MultiModelScript = Join-Path $ScriptRoot "preload-multi-models.ps1"
if (Test-Path $MultiModelScript) {
    Write-Info "Running multi-model pre-load script..."
    Write-Info "This will download 6 models (~33.7 GB total):"
    Write-Info "  - phi3.5 (2.3 GB)"
    Write-Info "  - llama3.1:8b (4.7 GB)"
    Write-Info "  - mistral:7b (4.1 GB)"
    Write-Info "  - gemma2:2b (1.6 GB)"
    Write-Info "  - gpt-oss (13 GB)"
    Write-Info "  - deepseek-r1 (8 GB)"
    & $MultiModelScript -Namespace "ollama"
    if ($LASTEXITCODE -ne 0) {
        Write-ErrorMsg "Multi-model pre-load failed"
        exit 1
    }
    Write-Success "Models pre-loaded successfully"
} else {
    Write-Info "Multi-model script not found, falling back to single model..."
    if (Test-Path $PreloadScript) {
        & $PreloadScript -ModelName "llama3.1:8b" -Namespace "ollama"
        if ($LASTEXITCODE -ne 0) {
            Write-ErrorMsg "Model pre-load failed"
            exit 1
        }
        Write-Success "Model pre-loaded successfully"
    } else {
        Write-Info "No pre-load scripts found, skipping model pre-load"
    }
}

# Step 8: Deploy Monitoring Stack (Prometheus + Grafana)
# ================================================================================
Write-StepHeader "Deploying Monitoring Stack (Prometheus + Grafana)"

# Step 8.1: Create Grafana database in PostgreSQL
# ================================================================================
Write-Info "Creating Grafana database in PostgreSQL..."

& "$PSScriptRoot\setup-grafana-database.ps1" `
    -KeyVaultName $keyVaultName `
    -PostgresServerFqdn $postgresServerFqdn `
    -PostgresAdminUsername $postgresAdminUsername

# Step 8.2: Deploy Monitoring Stack
# ================================================================================

$grafanaPassword = az keyvault secret show --vault-name $keyVaultName --name grafana-admin-password --query value -o tsv 2>$null
$postgresPassword = az keyvault secret show --vault-name $keyVaultName --name postgres-admin-password --query value -o tsv 2>$null

$deploymentResult = & "$PSScriptRoot\deploy-monitoring-stack.ps1" `
    -GrafanaPassword $grafanaPassword `
    -PostgresPassword $postgresPassword `
    -PostgresServerFqdn $postgresServerFqdn `
    -PostgresAdminUsername $postgresAdminUsername

if (-not $deploymentResult) {
    Write-ErrorMsg "Monitoring stack deployment failed"
    exit 1
}

# Wait for Grafana to be ready
Write-Info "Waiting for Grafana pod to be ready..."
$maxWait = 120
$elapsed = 0
$grafanaReady = $false

while ($elapsed -lt $maxWait -and -not $grafanaReady) {
    $grafanaPod = kubectl get pods -n monitoring -l "app.kubernetes.io/name=grafana" -o jsonpath='{.items[0].status.phase}' 2>$null
    if ($grafanaPod -eq "Running") {
        Start-Sleep -Seconds 5  # Give it a few more seconds to fully start
        $grafanaReady = $true
        Write-Success "Grafana is ready"
    } else {
        Start-Sleep -Seconds 5
        $elapsed += 5
    }
}

# Install Prometheus Adapter for Custom Metrics API
Write-StepHeader "Installing Prometheus Adapter"
Write-Info "Prometheus Adapter enables HPA to use custom GPU metrics..."

$prometheusAdapterValues = @"
# Prometheus Adapter Configuration
# Enables custom metrics API for HPA to query GPU metrics from Prometheus

prometheus:
  url: http://monitoring-kube-prometheus-prometheus.monitoring.svc
  port: 9090

rules:
  default: true
  custom:
  # DCGM GPU metrics - using exported_namespace and exported_pod labels
  # These labels point to the actual workload pod using the GPU, not the dcgm-exporter pod
  - seriesQuery: 'DCGM_FI_DEV_GPU_UTIL{exported_namespace!="",exported_pod!=""}'
    resources:
      overrides:
        exported_namespace: {resource: "namespace"}
        exported_pod: {resource: "pod"}
    name:
      matches: "^(.*)$"
      as: "gpu_utilization"
    metricsQuery: 'avg(<<.Series>>{<<.LabelMatchers>>}) by (<<.GroupBy>>)'

  - seriesQuery: 'DCGM_FI_DEV_FB_USED{exported_namespace!="",exported_pod!=""}'
    resources:
      overrides:
        exported_namespace: {resource: "namespace"}
        exported_pod: {resource: "pod"}
    name:
      matches: "^(.*)$"
      as: "gpu_memory_used_bytes"
    metricsQuery: 'avg(<<.Series>>{<<.LabelMatchers>>}) by (<<.GroupBy>>)'

  - seriesQuery: 'DCGM_FI_DEV_FB_FREE{exported_namespace!="",exported_pod!=""}'
    resources:
      overrides:
        exported_namespace: {resource: "namespace"}
        exported_pod: {resource: "pod"}
    name:
      matches: "^(.*)$"
      as: "gpu_memory_free_bytes"
    metricsQuery: 'avg(<<.Series>>{<<.LabelMatchers>>}) by (<<.GroupBy>>)'

  # Calculate GPU memory utilization percentage
  - seriesQuery: 'DCGM_FI_DEV_FB_USED{exported_namespace!="",exported_pod!=""}'
    resources:
      overrides:
        exported_namespace: {resource: "namespace"}
        exported_pod: {resource: "pod"}
    name:
      matches: "^(.*)$"
      as: "gpu_memory_utilization"
    metricsQuery: 'avg((DCGM_FI_DEV_FB_USED{<<.LabelMatchers>>} / (DCGM_FI_DEV_FB_USED{<<.LabelMatchers>>} + DCGM_FI_DEV_FB_FREE{<<.LabelMatchers>>})) * 100) by (<<.GroupBy>>)'

resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 200m
    memory: 256Mi

# Tolerations to run on system nodes
tolerations:
  - key: CriticalAddonsOnly
    operator: Exists
"@

$adapterValuesFile = Join-Path $env:TEMP "prometheus-adapter-values.yaml"
Set-Content -Path $adapterValuesFile -Value $prometheusAdapterValues

Write-Info "Installing prometheus-adapter..."
$ErrorActionPreference = 'Continue'
$adapterOutput = helm install prometheus-adapter prometheus-community/prometheus-adapter `
    --namespace monitoring `
    -f $adapterValuesFile `
    --wait `
    --timeout 3m 2>&1
$adapterExitCode = $LASTEXITCODE
$ErrorActionPreference = 'Stop'

# Check for Azure Policy warnings
$policyWarnings = $adapterOutput | Select-String -Pattern "azurepolicy.*has not been allowed"
if ($policyWarnings) {
    Write-Info "Note: Azure Policy warnings detected for prometheus-adapter (audit mode only)"
}

# Verify deployment
$adapterStatus = helm list -n monitoring -o json 2>$null | ConvertFrom-Json
$adapterSuccess = $adapterStatus | Where-Object { $_.name -eq "prometheus-adapter" -and $_.status -eq "deployed" }

if ($adapterSuccess) {
    Write-Success "Prometheus Adapter installed successfully"
    Write-Info "Custom metrics API is now available for GPU-based HPA"
} else {
    Write-Warning "Prometheus Adapter deployment had issues, but continuing..."
    Write-Info "GPU metrics may not be available for HPA. Check with: kubectl get apiservices | Select-String custom"
}

# Wait for Prometheus Adapter to be ready
Write-Info "Waiting for Prometheus Adapter to be ready..."
Start-Sleep -Seconds 10

# Wait for Prometheus Operator CRDs to be established
Write-Info "Verifying ServiceMonitor CRD is ready..."
$maxWait = 60
$elapsed = 0
$crdReady = $false

while ($elapsed -lt $maxWait) {
    $crdStatus = kubectl get crd servicemonitors.monitoring.coreos.com -o jsonpath='{.status.conditions[?(@.type=="Established")].status}' 2>$null
    if ($crdStatus -eq "True") {
        $crdReady = $true
        Write-Success "ServiceMonitor CRD is ready"
        break
    }
    Write-Host "  Waiting for ServiceMonitor CRD... ($elapsed/$maxWait seconds)" -ForegroundColor Gray
    Start-Sleep -Seconds 5
    $elapsed += 5
}

if (-not $crdReady) {
    Write-Warning "ServiceMonitor CRD not ready, but continuing..."
}

# Create ServiceMonitors for GPU and application metrics
Write-Info "Creating ServiceMonitors for metrics collection..."

# DCGM Exporter ServiceMonitor
# Note: Service is already created by k8s/11-dcgm-exporter.yaml
# We only need to create the ServiceMonitor to tell Prometheus to scrape it
Write-Info "Creating DCGM ServiceMonitor for Prometheus scraping..."
if (Test-Path "$K8sManifestsDir/13-dcgm-servicemonitor.yaml") {
    # Apply from k8s manifests to keep configuration in sync
    kubectl apply -f "$K8sManifestsDir/13-dcgm-servicemonitor.yaml" | Out-Null
    Write-Success "DCGM ServiceMonitor created from k8s/13-dcgm-servicemonitor.yaml"
} else {
    # Fallback: Create inline if file doesn't exist
    $dcgmServiceMonitor = @"
---
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: dcgm-exporter
  namespace: monitoring
  labels:
    app: dcgm-exporter
    release: monitoring
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: dcgm-exporter
  namespaceSelector:
    matchNames:
      - ollama
  endpoints:
    - port: metrics
      interval: 30s
      path: /metrics
"@
    $dcgmTempFile = Join-Path $env:TEMP "dcgm-servicemonitor.yaml"
    Set-Content -Path $dcgmTempFile -Value $dcgmServiceMonitor
    kubectl apply -f $dcgmTempFile | Out-Null
    Remove-Item $dcgmTempFile -ErrorAction SilentlyContinue
    Write-Success "DCGM ServiceMonitor created (inline fallback)"
}

# Get Grafana LoadBalancer IP
Write-Info "Retrieving Grafana LoadBalancer IP..."
$maxWait = 60
$elapsed = 0
$grafanaIp = ""

while ($elapsed -lt $maxWait) {
    $grafanaSvc = kubectl get svc -n monitoring monitoring-grafana -o json 2>$null | ConvertFrom-Json
    if ($grafanaSvc -and $grafanaSvc.status.loadBalancer.ingress) {
        $grafanaIp = $grafanaSvc.status.loadBalancer.ingress[0].ip
        if ($grafanaIp) {
            Write-Success "Grafana LoadBalancer IP: $grafanaIp"
            break
        }
    }
    Start-Sleep -Seconds 5
    $elapsed += 5
}

# Import custom dashboards
if ($grafanaIp -and $grafanaReady) {
    Write-Info "Importing custom dashboards to Grafana..."
    Start-Sleep -Seconds 10  # Give Grafana a bit more time

    $dashboardDir = Join-Path $PSScriptRoot "..\dashboards"
    $dashboardFiles = Get-ChildItem -Path $dashboardDir -Filter "*.json" -ErrorAction SilentlyContinue

    if ($dashboardFiles) {
        $grafanaUrl = "http://$grafanaIp"
        $auth = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("admin:$GrafanaPassword"))
        $headers = @{
            "Authorization" = "Basic $auth"
            "Content-Type" = "application/json"
        }

        foreach ($file in $dashboardFiles) {
            try {
                Write-Info "Importing: $($file.Name)"
                $dashboardJson = Get-Content -Path $file.FullName -Raw | ConvertFrom-Json
                $payload = @{ dashboard = $dashboardJson; overwrite = $true } | ConvertTo-Json -Depth 100

                $result = Invoke-RestMethod -Method Post -Uri "$grafanaUrl/api/dashboards/db" -Headers $headers -Body $payload -ErrorAction Stop
                Write-Success "  Dashboard imported: $($result.slug)"
            } catch {
                Write-Warning "  Failed to import $($file.Name): $_"
            }
        }
        Write-Success "Dashboard import complete"
    } else {
        Write-Info "No custom dashboards found in $dashboardDir"
    }
}

# Cleanup temp files
if ($monitoringValuesFile -and (Test-Path $monitoringValuesFile)) {
    Remove-Item $monitoringValuesFile -ErrorAction SilentlyContinue
}

Write-StepHeader "Deployment Complete!"

Write-Info "Fetching service endpoints..."
Write-Info "Waiting for Open-WebUI LoadBalancer IP (may take a few minutes)..."
$maxWaitSeconds = 180
$elapsedSeconds = 0
$externalIp = ""
$ollamaClusterIp = ""

while ($elapsedSeconds -lt $maxWaitSeconds) {
    $svcInfo = kubectl get svc open-webui -n ollama -o json | ConvertFrom-Json
    $externalIp = $svcInfo.status.loadBalancer.ingress[0].ip

    if (-not [string]::IsNullOrWhiteSpace($externalIp) -and $externalIp -ne "pending") {
        break
    }

    Start-Sleep -Seconds 10
    $elapsedSeconds += 10
    Write-Info "Still waiting for IP... ($elapsedSeconds/$maxWaitSeconds seconds)"
}

# Get Ollama service connection info
try {
    $ollamaSvcInfo = kubectl get svc ollama -n ollama -o json | ConvertFrom-Json
    $ollamaClusterIp = $ollamaSvcInfo.spec.clusterIP
} catch {
    $ollamaClusterIp = "N/A"
}

Write-Host "`n========================================" -ForegroundColor Green
Write-Host "DEPLOYMENT SUMMARY" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host "Resource Group    : $ResourceGroupName" -ForegroundColor White
Write-Host "AKS Cluster       : $aksClusterName" -ForegroundColor White
Write-Host "Key Vault         : $keyVaultName" -ForegroundColor White
Write-Host "PostgreSQL Server : $postgresServerFqdn" -ForegroundColor White
Write-Host "PostgreSQL DB     : $postgresDatabaseName" -ForegroundColor White
Write-Host "Premium Storage   : $premiumStorageAccountName" -ForegroundColor White
Write-Host "Standard Storage  : $standardStorageAccountName" -ForegroundColor White
Write-Host "`n--- Service Endpoints ---" -ForegroundColor Cyan

if (-not [string]::IsNullOrWhiteSpace($externalIp) -and $externalIp -ne "pending") {
    Write-Host "Open-WebUI URL    : " -NoNewline -ForegroundColor White
    Write-Host "http://$externalIp" -ForegroundColor Green
    Write-Host "Ollama API        : " -NoNewline -ForegroundColor White
    Write-Host "http://$ollamaClusterIp:11434 (internal)" -ForegroundColor Cyan

    if ($grafanaIp) {
        Write-Host "Grafana Dashboard : " -NoNewline -ForegroundColor White
        Write-Host "http://$grafanaIp" -ForegroundColor Green
        Write-Host "  Username: admin | Password: $GrafanaPassword" -ForegroundColor Gray
        Write-Host "  (Password also stored in Key Vault: $keyVaultName -> grafana-admin-password)" -ForegroundColor DarkGray
    }

    Write-Host "`nAccess Details:" -ForegroundColor Yellow
    Write-Host "  1. Navigate to: " -NoNewline -ForegroundColor White
    Write-Host "http://$externalIp" -ForegroundColor Green
    Write-Host "  2. Create an account (first user = admin)" -ForegroundColor White
    Write-Host "  3. Select from 6 pre-loaded models:" -ForegroundColor White
    Write-Host "       - phi3.5 (2.3 GB)" -ForegroundColor Gray
    Write-Host "       - llama3.1:8b (4.7 GB)" -ForegroundColor Gray
    Write-Host "       - mistral:7b (4.1 GB)" -ForegroundColor Gray
    Write-Host "       - gemma2:2b (1.6 GB)" -ForegroundColor Gray
    Write-Host "       - gpt-oss (13 GB)" -ForegroundColor Gray
    Write-Host "       - deepseek-r1 (8 GB)" -ForegroundColor Gray

    Write-Host "`nConnection Strings:" -ForegroundColor Yellow
    Write-Host "  Public Web UI  : http://$externalIp" -ForegroundColor White
    Write-Host "  Ollama API     : http://$ollamaClusterIp:11434 (cluster-internal)" -ForegroundColor White
    Write-Host "  From Pod       : http://ollama.ollama.svc.cluster.local:11434" -ForegroundColor White
    if ($grafanaIp) {
        Write-Host "  Grafana        : http://$grafanaIp (admin/$GrafanaPassword)" -ForegroundColor White
    }

    Write-Host "`nStorage Configuration:" -ForegroundColor Yellow
    Write-Host "  Ollama Models : Azure Files Premium (1TB, RWX)" -ForegroundColor White
    Write-Host "  Open-WebUI DB : Azure PostgreSQL Flexible Server (B1ms)" -ForegroundColor White
    Write-Host "  Database      : PostgreSQL (highly available, managed)" -ForegroundColor White
    Write-Host "  Password      : Stored in Key Vault (secret: postgres-admin-password)" -ForegroundColor White

    if ($grafanaIp) {
        Write-Host "`nMonitoring Stack:" -ForegroundColor Yellow
        Write-Host "  Prometheus    : Deployed (7-day retention, 20GB storage)" -ForegroundColor White
        Write-Host "  Grafana       : http://$grafanaIp" -ForegroundColor White
        Write-Host "  GPU Metrics   : DCGM Exporter + ServiceMonitors configured" -ForegroundColor White
        Write-Host "  Dashboards    : Pre-loaded (GPU Monitoring, Platform Overview)" -ForegroundColor White
    }
} else {
    Write-Host "Open-WebUI URL    : [PENDING] Run 'kubectl get svc -n ollama' to get IP" -ForegroundColor Yellow
    Write-Host "Ollama API        : http://$ollamaClusterIp:11434 (internal)" -ForegroundColor Cyan
}

Write-Host "`nUseful Commands:" -ForegroundColor Yellow
Write-Host "  kubectl get pods -n ollama" -ForegroundColor White
Write-Host "  kubectl get svc -n ollama" -ForegroundColor White
Write-Host "  kubectl logs -f -l app=ollama -n ollama" -ForegroundColor White
Write-Host "  kubectl logs -f -l app=open-webui -n ollama" -ForegroundColor White
Write-Host "`nTo clean up:" -ForegroundColor Yellow
Write-Host "  .\scripts\cleanup.ps1 -Prefix $Prefix" -ForegroundColor White
Write-Host "========================================`n" -ForegroundColor Green

Write-Host "? Deployment completed successfully!" -ForegroundColor Green
exit 0
