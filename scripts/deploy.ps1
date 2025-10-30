<#
.SYNOPSIS
    Deploy KubeCon NA 2025 LLM Demo - Azure Files + AKS + Ollama + Open-WebUI

.DESCRIPTION
    Orchestrates full infrastructure deployment including:
    - Azure infrastructure (AKS, Azure Files, Key Vault)
    - AKS cluster with GPU node pool (T4/A10)
    - Ollama LLM server
    - Open-WebUI frontend
    - Pre-load Llama-3.1-8B model

.PARAMETER Prefix
    Unique prefix for resource naming (3-15 alphanumeric chars)

.PARAMETER Location
    Azure region

.PARAMETER HuggingFaceToken
    HF token for pre-loading Llama-3.1-8B model

.EXAMPLE
    .\scripts\deploy.ps1 -Prefix "kubecon" -Location "westus2" -HuggingFaceToken "hf_demo_token_placeholder"
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
    [switch]$AutoApprove
)

# Ensure we're in the correct directory (llm-demo folder)
$ScriptRoot = Split-Path -Parent $PSCommandPath
$ProjectRoot = Split-Path -Parent $ScriptRoot

# CRITICAL: Change to project root so all relative paths work
Set-Location -Path $ProjectRoot -ErrorAction Stop
Write-Verbose "Working directory: $(Get-Location)"

# Load System.Web assembly for URL encoding
Add-Type -AssemblyName System.Web

# Trap all errors and show them
$ErrorActionPreference = "Stop"
$VerbosePreference = "Continue"

$ResourceGroupName = "${Prefix}-rg"
$BicepMainFile = "bicep\main.bicep"
$K8sManifestsDir = "k8s"
$PreloadScript = "scripts\preload-model.ps1"

# Validate files exist
if (-not (Test-Path $BicepMainFile)) {
    Write-Error "Bicep file not found at: $(Resolve-Path $BicepMainFile -ErrorAction SilentlyContinue). Current directory: $(Get-Location)"
    exit 1
}
if (-not (Test-Path $K8sManifestsDir)) {
    Write-Error "K8s directory not found at: $(Resolve-Path $K8sManifestsDir -ErrorAction SilentlyContinue). Current directory: $(Get-Location)"
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

function Write-Error {
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
    Write-Error "Azure CLI not found. Please install from https://aka.ms/installazurecli"
    exit 1
}

try {
    $kubectlVersion = kubectl version --client -o json | ConvertFrom-Json
    Write-Success "kubectl installed: $($kubectlVersion.clientVersion.gitVersion)"
} catch {
    Write-Error "kubectl not found. Please install from https://kubernetes.io/docs/tasks/tools/"
    exit 1
}

if (-not (Test-Path $BicepMainFile)) {
    Write-Error "Bicep file not found: $BicepMainFile"
    exit 1
}
Write-Success "Bicep files found"

if (-not (Test-Path $K8sManifestsDir)) {
    Write-Error "K8s manifests directory not found: $K8sManifestsDir"
    exit 1
}
Write-Success "K8s manifests directory found"

try {
    $account = az account show | ConvertFrom-Json
    Write-Success "Logged into Azure: $($account.user.name) (Subscription: $($account.name))"
} catch {
    Write-Error "Not logged into Azure. Run 'az login'"
    exit 1
}

Write-StepHeader "Deploying Azure Infrastructure"

# Check if resource group exists
$rgExists = az group exists --name $ResourceGroupName
if ($rgExists -eq "true") {
    $existingRg = az group show --name $ResourceGroupName | ConvertFrom-Json
    Write-Host "`n[WARNING] Resource group '$ResourceGroupName' already exists in location: $($existingRg.location)" -ForegroundColor Yellow

    if ($existingRg.location -ne $Location) {
        Write-Error "Resource group exists in different location ($($existingRg.location)). Please use a different prefix or run cleanup first."
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
        Write-Error "Failed to create resource group"
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

Write-Info "Deploying Bicep template (this takes 8-10 minutes)..."
Write-Info "Progress will be shown below. Please wait..."
Write-Host ""

# Run deployment in foreground with output visible
az deployment group create `
    --resource-group $ResourceGroupName `
    --template-file $BicepMainFile `
    --parameters prefix=$Prefix location=$Location huggingFaceToken=$HuggingFaceToken postgresAdminPassword=$PostgresPassword `
    --output table

if ($LASTEXITCODE -ne 0) {
    Write-Error "Bicep deployment failed. Check the output above for details."
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
    Write-Error "Failed to parse deployment output"
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
    Write-Error "AKS cluster did not reach ready state within $maxWaitSeconds seconds"
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
    Write-Error "Failed to get AKS credentials"
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
    Write-Error "GPU drivers did not initialize within 5 minutes. Check NVIDIA device plugin logs."
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

Write-StepHeader "Deploying Kubernetes Resources"

Write-Info "Applying resource quota..."
kubectl apply -f "$K8sManifestsDir/09-resource-quota.yaml"
Write-Success "Resource quota applied"

Write-Info "Creating Ollama namespace..."
kubectl apply -f "$K8sManifestsDir/01-namespace.yaml"
Write-Success "Ollama namespace created"

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
kubectl apply -f "$K8sManifestsDir/02-storage-premium.yaml"
Write-Success "Storage class deployed (Azure Files Premium)"

Write-Info "Deploying Persistent Volume Claims..."
Write-Info "  - Ollama models PVC (Azure Files Premium, 1024GB / 1TB)..."
Write-Info "  - Open-WebUI data PVC (Azure Files Premium, 20GB)..."
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
    Write-Error "PVCs did not bind within timeout"
    exit 1
}

Write-Info "Deploying Ollama server (Deployment with autoscaling)..."
# Deploy either StatefulSet or Deployment based on what exists
if (Test-Path "$K8sManifestsDir/05-ollama-deployment.yaml") {
    kubectl apply -f "$K8sManifestsDir/05-ollama-deployment.yaml"
} elseif (Test-Path "$K8sManifestsDir/05-ollama-statefulset.yaml") {
    kubectl apply -f "$K8sManifestsDir/05-ollama-statefulset.yaml"
}
kubectl apply -f "$K8sManifestsDir/06-ollama-service.yaml"
Write-Success "Ollama deployed"

Write-Info "Waiting for Ollama pod to be ready (max 5 minutes)..."
kubectl wait --for=condition=ready pod -l app=ollama -n ollama --timeout=300s
if ($LASTEXITCODE -ne 0) {
    Write-Error "Ollama pod did not become ready"
    exit 1
}
Write-Success "Ollama pod ready"

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

Write-Info "Deploying GPU monitoring (DCGM Exporter)..."
if (Test-Path "$K8sManifestsDir/11-dcgm-exporter.yaml") {
    kubectl apply -f "$K8sManifestsDir/11-dcgm-exporter.yaml"
    Write-Success "DCGM Exporter deployed for GPU metrics"
}

Write-Info "Waiting for Open-WebUI pod to be ready (max 5 minutes)..."
Write-Info "Note: First startup may take 2-3 minutes to download embedding model..."
kubectl wait --for=condition=ready pod -l app=open-webui -n ollama --timeout=300s
if ($LASTEXITCODE -ne 0) {
    Write-Warning "Open-WebUI pods not ready yet (may need PGVector extensions)"
    Write-Info "Will enable PGVector extensions in next step..."
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
        Write-Error "Multi-model pre-load failed"
        exit 1
    }
    Write-Success "Models pre-loaded successfully"
} else {
    Write-Info "Multi-model script not found, falling back to single model..."
    if (Test-Path $PreloadScript) {
        & $PreloadScript -ModelName "llama3.1:8b" -Namespace "ollama"
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Model pre-load failed"
            exit 1
        }
        Write-Success "Model pre-loaded successfully"
    } else {
        Write-Info "No pre-load scripts found, skipping model pre-load"
    }
}

# ================================================================================
# Step 7: Enable PGVector Extensions
# ================================================================================
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
    Write-Info "Creating pgvector extension in $postgresDatabaseName database..."    # Create temporary pod manifest
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

# Step 8: Deploy Monitoring Stack (Prometheus + Grafana)
# ================================================================================
Write-StepHeader "Deploying Monitoring Stack (Prometheus + Grafana)"

Write-Info "Checking if monitoring namespace exists..."
# Check if namespace exists without showing error
$existingNs = kubectl get namespaces -o json 2>$null | ConvertFrom-Json
$monitoringExists = $existingNs.items | Where-Object { $_.metadata.name -eq "monitoring" }

if ($monitoringExists) {
    Write-Success "Namespace 'monitoring' already exists"
} else {
    Write-Info "Creating monitoring namespace..."
    kubectl create namespace monitoring 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Namespace 'monitoring' created"
    } else {
        Write-Error "Failed to create monitoring namespace"
        exit 1
    }
}

# Check if Helm repo is added
Write-Info "Adding Prometheus Helm repository..."
$helmRepoAdd = helm repo add prometheus-community https://prometheus-community.github.io/helm-charts 2>&1
if ($LASTEXITCODE -ne 0 -and $helmRepoAdd -notlike "*already exists*") {
    Write-Warning "Helm repo add had issues, but continuing..."
}
$helmRepoUpdate = helm repo update 2>&1 | Out-Null
Write-Success "Helm repository updated"

# Create monitoring values file with tolerations
$monitoringValuesFile = Join-Path $env:TEMP "monitoring-values.yaml"
$monitoringValues = @"
# Prometheus + Grafana Stack Values with Tolerations
defaultTolerations: &commonTolerations
  - key: CriticalAddonsOnly
    operator: Equal
    value: "true"
    effect: NoSchedule

prometheusOperator:
  tolerations: *commonTolerations
  admissionWebhooks:
    patch:
      tolerations: *commonTolerations

prometheus:
  prometheusSpec:
    serviceMonitorSelectorNilUsesHelmValues: false
    retention: 7d
    storageSpec:
      volumeClaimTemplate:
        spec:
          accessModes: ["ReadWriteOnce"]
          resources:
            requests:
              storage: 20Gi
    tolerations: *commonTolerations

grafana:
  adminPassword: admin123!
  service:
    type: LoadBalancer
  tolerations: *commonTolerations

alertmanager:
  alertmanagerSpec:
    tolerations: *commonTolerations

kube-state-metrics:
  tolerations: *commonTolerations

prometheus-node-exporter:
  tolerations:
    - operator: Exists
"@

Set-Content -Path $monitoringValuesFile -Value $monitoringValues

Write-Info "Installing kube-prometheus-stack (this may take 2-3 minutes)..."
$helmInstall = helm install monitoring prometheus-community/kube-prometheus-stack `
    --namespace monitoring `
    -f $monitoringValuesFile `
    --wait `
    --timeout 5m 2>&1

if ($LASTEXITCODE -eq 0) {
    Write-Success "Monitoring stack deployed successfully"
} else {
    Write-Warning "Monitoring stack deployment encountered issues"
    Write-Info "You can check status with: kubectl get pods -n monitoring"
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

# Create ServiceMonitors for GPU and application metrics
Write-Info "Creating ServiceMonitors for metrics collection..."

# DCGM Exporter ServiceMonitor
$dcgmServiceMonitor = @"
---
apiVersion: v1
kind: Service
metadata:
  name: dcgm-exporter
  namespace: ollama
  labels:
    app.kubernetes.io/name: dcgm-exporter
    app.kubernetes.io/component: gpu-metrics
spec:
  type: ClusterIP
  ports:
    - name: metrics
      port: 9400
      targetPort: 9400
      protocol: TCP
  selector:
    app: dcgm-exporter
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

$dcgmFile = Join-Path $env:TEMP "dcgm-servicemonitor.yaml"
Set-Content -Path $dcgmFile -Value $dcgmServiceMonitor
kubectl apply -f $dcgmFile | Out-Null
Write-Success "DCGM ServiceMonitor created"

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
        $auth = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("admin:admin123!"))
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
Remove-Item $monitoringValuesFile -ErrorAction SilentlyContinue
Remove-Item $dcgmFile -ErrorAction SilentlyContinue

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
        Write-Host "  Username: admin | Password: admin123!" -ForegroundColor Gray
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
        Write-Host "  Grafana        : http://$grafanaIp (admin/admin123!)" -ForegroundColor White
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
