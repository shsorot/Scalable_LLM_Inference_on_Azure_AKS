# Deployment Guide

Complete step-by-step guide for deploying the Azure AKS LLM Demo.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Quick Start](#quick-start)
3. [Detailed Deployment Steps](#detailed-deployment-steps)
4. [Post-Deployment Configuration](#post-deployment-configuration)
5. [Troubleshooting](#troubleshooting)
6. [Cleanup](#cleanup)
7. [Advanced Configurations](#advanced-configurations)

## Prerequisites

### Azure Requirements

**Subscription Quotas:**
- Standard_NC4as_T4_v3: 8 vCPUs (2 VMs)
- Standard_D2s_v3: 4 vCPUs (2 VMs)
- Check quotas: [Azure Portal](https://portal.azure.com) → Subscriptions → Usage + quotas

**Required Permissions:**
- Contributor role on subscription or resource group
- Ability to create:
  - Resource Groups
  - AKS Clusters
  - PostgreSQL Flexible Servers
  - Storage Accounts
  - Key Vaults
  - Public IPs

### Local Tools

**Required:**
- Azure CLI 2.50.0 or later
- kubectl 1.27 or later
- PowerShell 5.1+ (Windows) or PowerShell Core 7+ (cross-platform)
- Python 3.8 or later
- Git

**Installation:**

```powershell
# Install Azure CLI (Windows)
winget install Microsoft.AzureCLI

# Install kubectl
az aks install-cli

# Install Python dependencies
pip install psycopg2-binary

# Verify installations
az --version
kubectl version --client
python --version
```

### Azure Login

```powershell
# Login to Azure
az login

# Set subscription (if you have multiple)
az account list --output table
az account set --subscription "<subscription-id>"

# Verify login
az account show
```

## Quick Start

### 1-Command Deployment

```powershell
git clone <repository-url>
cd llm-demo/scripts
.\deploy.ps1 -Prefix <your-prefix> -Location northeurope -AutoApprove
```

**Parameters:**
- `Prefix`: Unique prefix for resource names (lowercase, 3-10 characters)
- `Location`: Azure region (northeurope, westus2, eastus, etc.)
- `AutoApprove`: Skip manual approval prompts

**Deployment Time:** 10-15 minutes

## Detailed Deployment Steps

### Step 1: Prepare Environment

```powershell
# Clone repository
git clone <repository-url>
cd llm-demo

# Install Python dependencies
pip install psycopg2-binary

# Verify Azure CLI login
az account show
```

### Step 2: Configure Parameters

**Option A: Use defaults (recommended for demo)**

```powershell
cd scripts
.\deploy.ps1 -Prefix myprefix -Location northeurope
```

**Option B: Customize parameters**

Edit `bicep/parameters.example.json`:

```json
{
  "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "prefix": {
      "value": "myprefix"
    },
    "location": {
      "value": "northeurope"
    },
    "gpuNodeCount": {
      "value": 2
    },
    "systemNodeCount": {
      "value": 2
    }
  }
}
```

Then deploy:

```powershell
.\deploy.ps1 -ParametersFile ../bicep/parameters.json
```

### Step 3: Run Deployment

```powershell
cd scripts
.\deploy.ps1 -Prefix myprefix -Location northeurope -AutoApprove
```

**What Happens:**

1. **Pre-flight checks** (30 seconds)
   - Verify Azure CLI installed
   - Verify kubectl installed
   - Check Bicep template syntax
   - Verify Azure login

2. **Deploy Azure infrastructure** (8-10 minutes)
   - Create/verify resource group
   - Deploy AKS cluster (GPU + system nodes)
   - Deploy PostgreSQL Flexible Server
   - Create Key Vault
   - Create Storage Account

3. **Configure Kubernetes** (1-2 minutes)
   - Get AKS credentials
   - Install NVIDIA device plugin
   - Wait for GPU nodes to be ready

4. **Deploy Kubernetes resources** (2-3 minutes)
   - Create ollama namespace
   - Create Kubernetes secrets
   - Deploy Ollama StatefulSet
   - Deploy Open-WebUI Deployment
   - Create LoadBalancer service

5. **Enable PGVector extensions** (30 seconds)
   - Connect to PostgreSQL
   - Create vector extension
   - Create uuid-ossp extension
   - Restart Open-WebUI pods

6. **Pre-load models** (5-15 minutes, varies by model count)
   - phi3.5 (2.3GB)
   - llama3.1:8b (4.7GB)
   - mistral:7b (4.1GB)
   - gemma2:2b (1.6GB)
   - gpt-oss (13GB)
   - deepseek-r1 (8GB)

### Step 4: Verify Deployment

```powershell
# Check pod status (all should be Running)
kubectl get pods -n ollama

# Expected output:
# NAME                          READY   STATUS    RESTARTS   AGE
# ollama-0                      1/1     Running   0          5m
# open-webui-6c9c8d558f-abc123  1/1     Running   0          4m
# open-webui-6c9c8d558f-def456  1/1     Running   0          4m
# open-webui-6c9c8d558f-ghi789  1/1     Running   0          4m

# Get external IP
kubectl get svc open-webui -n ollama

# Check GPU allocation
kubectl describe nodes -l agentpool=gpu | grep -A5 "Allocated resources"
```

### Step 5: Access Web UI

```powershell
# Get external IP
$externalIp = kubectl get svc open-webui -n ollama -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
Write-Host "Open-WebUI URL: http://$externalIp"

# Open in browser
Start-Process "http://$externalIp"
```

## Post-Deployment Configuration

### Create Admin Account

1. Open browser to `http://<EXTERNAL-IP>`
2. Click "Sign up"
3. Enter email and password
4. **First user becomes admin automatically**

### Test Chat Functionality

1. Select a model from dropdown (e.g., "phi3.5")
2. Type a message: "What is Kubernetes?"
3. Verify response

### Test RAG (Document Upload)

1. Click "+" button
2. Upload a PDF or text file
3. Wait for processing (embeddings generated)
4. In chat settings, enable "Use documents"
5. Ask question about document content
6. Verify answer uses uploaded context

## Troubleshooting

### Issue: Open-WebUI Pods CrashLoopBackOff

**Symptoms:**
```
NAME                          READY   STATUS             RESTARTS   AGE
open-webui-6c9c8d558f-abc123  0/1     CrashLoopBackOff   5          5m
```

**Cause:** PGVector extensions not enabled

**Solution:**
```powershell
# Enable extensions manually
cd scripts
python enable-pgvector.py

# Restart pods
kubectl delete pods -n ollama -l app=open-webui

# Verify they come up
kubectl wait --for=condition=ready pod -l app=open-webui -n ollama --timeout=120s
```

### Issue: Models Download Slowly

**Symptoms:**
- `preload-multi-models.ps1` takes very long
- Models show low download speed

**Cause:** Bandwidth limitations or Ollama registry issues

**Solution:**
- Models download in background, check progress:
```powershell
kubectl logs -n ollama ollama-0 --tail=50 --follow
```
- Skip model preloading, download from UI instead
- Pre-load only small models: edit `preload-multi-models.ps1`, remove large models

### Issue: LoadBalancer IP Shows `<pending>`

**Symptoms:**
```
NAME         TYPE           CLUSTER-IP      EXTERNAL-IP   PORT(S)
open-webui   LoadBalancer   10.100.175.97   <pending>     80:32580/TCP
```

**Cause:** Azure provisioning LoadBalancer (takes 2-3 minutes)

**Solution:**
```powershell
# Wait and check again
Start-Sleep -Seconds 60
kubectl get svc open-webui -n ollama
```

If still pending after 5 minutes:
```powershell
# Check Azure LoadBalancer status
$rgName = "<your-prefix>-rg"
az network lb list --resource-group $rgName --output table
```

### Issue: GPU Not Detected

**Symptoms:**
- Ollama pod running but slow inference
- No GPU shown in node description

**Cause:** NVIDIA device plugin not installed

**Solution:**
```powershell
# Install NVIDIA device plugin
kubectl apply -f k8s/01-nvidia-device-plugin.yaml

# Wait for DaemonSet
kubectl wait --for=condition=ready pod -l name=nvidia-device-plugin-ds -n kube-system --timeout=180s

# Verify GPU
kubectl describe nodes -l agentpool=gpu | grep nvidia.com/gpu
```

### Issue: PostgreSQL Connection Failed

**Symptoms:**
- Open-WebUI logs show "connection refused" or "authentication failed"

**Cause:** Incorrect connection string or password

**Solution:**
```powershell
# Get current password from Key Vault
$kvName = az keyvault list --resource-group "<your-prefix>-rg" --query "[0].name" -o tsv
$pgPassword = az keyvault secret show --vault-name $kvName --name postgres-admin-password --query value -o tsv
Write-Host "Password: $pgPassword"

# Update Kubernetes secret
kubectl create secret generic ollama-secrets `
    --from-literal=POSTGRES_CONNECTION="postgresql://pgadmin:$pgPassword@<pg-server>.postgres.database.azure.com:5432/openwebui?sslmode=require" `
    --dry-run=client -o yaml | kubectl apply -n ollama -f -

# Restart Open-WebUI
kubectl rollout restart deployment open-webui -n ollama
```

### Issue: Insufficient Quota

**Symptoms:**
```
ERROR: Operation failed with status: 'Bad Request'. Details: Requested VM size Standard_NC4as_T4_v3 
is not available in location 'westus2'. Please try another location or choose a different VM size.
```

**Solution:**
1. Check quota: Azure Portal → Subscriptions → Usage + quotas
2. Request quota increase (can take 1-2 business days)
3. Or use different region with available quota:
   - northeurope
   - westus2
   - eastus

### Issue: Deployment Timeout

**Symptoms:**
- Script hangs at "Waiting for AKS cluster..."
- Deployment stuck for >15 minutes

**Solution:**
```powershell
# Check deployment status in portal
# Or check via CLI:
az deployment group show `
    --resource-group "<your-prefix>-rg" `
    --name "main" `
    --query "properties.provisioningState"

# If failed, check error:
az deployment group show `
    --resource-group "<your-prefix>-rg" `
    --name "main" `
    --query "properties.error"

# Clean up and retry:
.\cleanup.ps1 -Prefix <your-prefix>
.\deploy.ps1 -Prefix <your-prefix> -Location northeurope -AutoApprove
```

## Cleanup

### Option 1: Keep Infrastructure, Clean Kubernetes

Useful for pausing deployment without losing infrastructure investment.

```powershell
cd scripts
.\cleanup.ps1 -Prefix <your-prefix> -KeepResourceGroup
```

**What's deleted:**
- Kubernetes namespace and all resources
- PVCs (Persistent Volume Claims)
- PVs (Persistent Volumes)

**What's kept:**
- AKS cluster
- PostgreSQL database (including data)
- Key Vault
- Storage Account

**To redeploy:**
```powershell
.\deploy.ps1 -Prefix <your-prefix> -Location northeurope -AutoApprove
```

### Option 2: Wipe Database, Keep Infrastructure

Useful for demo resets.

```powershell
cd scripts
.\cleanup.ps1 -Prefix <your-prefix> -WipeDatabase -KeepResourceGroup
```

**What's deleted:**
- Kubernetes namespace and all resources
- PostgreSQL database content (users, chats, documents)

**What's kept:**
- AKS cluster
- PostgreSQL server (but empty database)
- Key Vault
- Storage Account

### Option 3: Delete Everything

Complete teardown.

```powershell
cd scripts
.\cleanup.ps1 -Prefix <your-prefix>
```

**What's deleted:**
- Entire resource group
- AKS cluster
- PostgreSQL server and database
- Key Vault
- Storage Account
- All data

## Advanced Configurations

### Custom Model List

Edit `scripts/preload-multi-models.ps1`:

```powershell
[string[]]$Models = @(
    "phi3.5",           # Keep small model for quick testing
    "llama3.1:8b"       # Add your preferred models
)
```

### Scale Open-WebUI

```powershell
# Scale to 5 replicas
kubectl scale deployment open-webui -n ollama --replicas=5

# Verify
kubectl get pods -n ollama -l app=open-webui
```

### Add GPU Nodes

```powershell
# Scale GPU node pool
az aks nodepool scale `
    --resource-group "<your-prefix>-rg" `
    --cluster-name "<your-prefix>-aks" `
    --name gpu `
    --node-count 3
```

### Enable Autoscaling

```powershell
# Enable cluster autoscaler on GPU pool
az aks nodepool update `
    --resource-group "<your-prefix>-rg" `
    --cluster-name "<your-prefix>-aks" `
    --name gpu `
    --enable-cluster-autoscaler `
    --min-count 1 `
    --max-count 3
```

### Custom Domain with TLS

1. Deploy NGINX Ingress Controller
2. Configure DNS A record
3. Install cert-manager
4. Create Ingress resource with TLS

(Beyond scope of this demo)

### Monitoring with Prometheus

1. Install Prometheus + Grafana
2. Configure ServiceMonitors
3. Import Ollama/GPU dashboards

(Beyond scope of this demo)

## Best Practices

### Security

- **Rotate PostgreSQL password** after initial deployment
- **Enable Network Policies** for pod-to-pod traffic control
- **Use Azure AD integration** for AKS RBAC
- **Enable Key Vault soft delete** and purge protection
- **Configure Azure Policy** for compliance

### Cost Optimization

- **Use Spot VMs** for GPU nodes (already configured)
- **Stop cluster during off-hours**:
  ```powershell
  az aks stop --resource-group <rg> --name <cluster>
  az aks start --resource-group <rg> --name <cluster>
  ```
- **Delete when not in use**:
  ```powershell
  .\cleanup.ps1 -Prefix <your-prefix>
  ```

### Performance

- **Use Premium Storage** for model files (already configured)
- **Co-locate resources** in same region
- **Monitor GPU utilization**:
  ```powershell
  kubectl top pods -n ollama
  ```

### Operations

- **Backup PostgreSQL** regularly (automatic with 7-day retention)
- **Monitor pod health**:
  ```powershell
  kubectl get pods -n ollama --watch
  ```
- **Check logs** for errors:
  ```powershell
  kubectl logs -n ollama deployment/open-webui --tail=100
  ```

## Support

For issues or questions:
1. Check [Troubleshooting](#troubleshooting) section
2. Review [ARCHITECTURE.md](ARCHITECTURE.md) for technical details
3. Check logs: `kubectl logs -n ollama <pod-name>`
4. Contact demo maintainers

## Next Steps

After successful deployment:
1. Test chat functionality with different models
2. Upload documents and test RAG
3. Monitor GPU utilization
4. Experiment with model parameters
5. Scale Open-WebUI replicas
6. Review cost in Azure Portal
