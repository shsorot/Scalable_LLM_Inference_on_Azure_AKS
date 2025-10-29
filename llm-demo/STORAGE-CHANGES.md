# Azure Files Premium Storage Changes

## Summary
Modified the Web UI deployment to use Azure Files Premium storage for better performance and multi-replica support.

## Changes Made

### 1. Ollama Models Storage (1 TiB)
**File**: `k8s/02-storage-premium.yaml`
- **Storage Class**: `azurefile-premium-llm` (Azure Files Premium)
- **PVC**: `ollama-models-pvc`
- **Size**: 1 TiB (increased from 100Gi)
- **Access Mode**: ReadWriteMany (supports multiple Ollama replicas)
- **Purpose**: Store LLM models for Ollama
- **Mount Point**: `/root/.ollama` in Ollama pods

### 2. WebUI User Data Storage (100 GiB)
**File**: `k8s/04-storage-webui-disk.yaml`
- **Storage Class**: `azurefile-premium-webui` (Azure Files Premium - NEW)
- **PVC**: `open-webui-data-pvc` (renamed from `open-webui-disk-pvc`)
- **Size**: 100 GiB (increased from 10Gi)
- **Access Mode**: ReadWriteMany (supports multiple WebUI replicas)
- **Purpose**: Store user artifacts, chats, archives, uploads, and application data
- **Mount Point**: `/app/backend/data` in WebUI pods

### 3. WebUI Deployment Multi-Replica Support
**File**: `k8s/07-webui-deployment.yaml`
- **Replicas**: Increased from 1 to 2
- **Storage Backend**: Changed from Azure Disk to Azure Files Premium
- **PVC Reference**: Updated to use `open-webui-data-pvc`
- **Benefits**:
  - Multiple WebUI instances can serve requests (load balancing)
  - Shared storage across all replicas
  - High availability with no single point of failure

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    AKS Cluster                               │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐ │
│  │ Ollama StatefulSet                                     │ │
│  │  - Models: /root/.ollama                               │ │
│  │  - Storage: ollama-models-pvc (1 TiB Premium)          │ │
│  └────────────────────────────────────────────────────────┘ │
│                          │                                   │
│                          │ ReadWriteMany                     │
│                          ▼                                   │
│  ┌──────────────────────────────────────┐                   │
│  │ Azure Files Premium - 1 TiB          │                   │
│  │ (azurefile-premium-llm)              │                   │
│  └──────────────────────────────────────┘                   │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐ │
│  │ Open WebUI Deployment (2 replicas)                     │ │
│  │  ├─ Pod 1: /app/backend/data                           │ │
│  │  └─ Pod 2: /app/backend/data                           │ │
│  │  - Storage: open-webui-data-pvc (100 GiB Premium)      │ │
│  │  - Database: PostgreSQL Flexible Server (external)     │ │
│  └────────────────────────────────────────────────────────┘ │
│                          │                                   │
│                          │ ReadWriteMany                     │
│                          ▼                                   │
│  ┌──────────────────────────────────────┐                   │
│  │ Azure Files Premium - 100 GiB        │                   │
│  │ (azurefile-premium-webui)            │                   │
│  │  - User uploads                      │                   │
│  │  - Chat archives                     │                   │
│  │  - Artifacts                         │                   │
│  │  - Application data                  │                   │
│  └──────────────────────────────────────┘                   │
│                                                              │
└─────────────────────────────────────────────────────────────┘
         │
         ▼
┌──────────────────────────────────────┐
│ PostgreSQL Flexible Server           │
│ (Database: user data, sessions)      │
└──────────────────────────────────────┘
```

## Storage Benefits

### Azure Files Premium Advantages
1. **High Performance**: Premium SSD-backed storage with low latency
2. **ReadWriteMany**: Multiple pods can mount the same volume simultaneously
3. **Scale-Out**: Supports horizontal scaling of WebUI replicas
4. **Large File Shares**: Supports 1 TiB+ file shares
5. **Shared Access**: All replicas see the same files instantly

### Multi-Replica Benefits
1. **High Availability**: If one replica fails, others continue serving
2. **Load Balancing**: Kubernetes service distributes traffic across replicas
3. **Zero Downtime Updates**: Rolling updates with no service interruption
4. **Better Performance**: Multiple replicas handle concurrent users better

## Data Storage Locations

### Ollama (1 TiB Azure Files Premium)
- **Location**: `/root/.ollama`
- **Contents**:
  - Downloaded LLM models (e.g., Llama-3.1-8B, Mistral, etc.)
  - Model metadata and configuration
  - Model cache

### WebUI (100 GiB Azure Files Premium)
- **Location**: `/app/backend/data`
- **Contents**:
  - User uploaded files
  - Chat exports and archives
  - Generated artifacts (PDFs, images)
  - Vector database files (Chroma)
  - Application cache
  - User documents

### PostgreSQL Flexible Server (Database)
- **Location**: External Azure managed service
- **Contents**:
  - User accounts and authentication
  - Chat history and conversations
  - Session data
  - Application configuration
  - User preferences

## Cost Considerations

### Azure Files Premium Pricing (North Europe)
- **1 TiB**: ~$210/month (Ollama models)
- **100 GiB**: ~$21/month (WebUI data)
- **Total Storage**: ~$231/month

### Comparison with Previous Setup
- **Previous**: Azure Disk Premium 10 GiB (~$2.50/month) + Azure Files Premium 100 GiB (~$21/month) = ~$23.50/month
- **New**: Azure Files Premium 1 TiB (~$210/month) + Azure Files Premium 100 GiB (~$21/month) = ~$231/month
- **Increase**: ~$207.50/month for 10x model storage capacity

## Deployment Steps

### For Fresh Deployments
Run the standard deployment script:
```powershell
.\scripts\deploy.ps1 -Prefix "your-prefix" -Location "northeurope" -HuggingFaceToken "your-token" -AutoApprove
```

The script will automatically create:
- Azure Files Premium 1 TiB for Ollama models
- Azure Files Premium 100 GiB for WebUI data
- 2 WebUI replicas with shared storage

### For Existing Deployments
To update an existing deployment:

```powershell
# 1. Delete old PVC and deployment
kubectl delete pvc open-webui-disk-pvc -n ollama
kubectl delete deployment open-webui -n ollama

# 2. Apply new storage configuration
kubectl apply -f k8s/04-storage-webui-disk.yaml

# 3. Update Ollama models PVC (optional - only if you want 1 TiB)
kubectl delete pvc ollama-models-pvc -n ollama
kubectl apply -f k8s/02-storage-premium.yaml

# 4. Deploy new WebUI with multi-replica support
kubectl apply -f k8s/07-webui-deployment.yaml

# 5. Verify deployment
kubectl get pods -n ollama -l app=open-webui
kubectl get pvc -n ollama
```

## Verification

### Check Storage
```powershell
# Verify PVCs are bound
kubectl get pvc -n ollama

# Expected output:
# NAME                   STATUS   VOLUME       CAPACITY   ACCESS MODES   STORAGECLASS
# ollama-models-pvc      Bound    pvc-xxx...   1Ti        RWX            azurefile-premium-llm
# open-webui-data-pvc    Bound    pvc-yyy...   100Gi      RWX            azurefile-premium-webui
```

### Check Pods
```powershell
# Verify WebUI replicas are running
kubectl get pods -n ollama -l app=open-webui

# Expected output:
# NAME                          READY   STATUS    RESTARTS   AGE
# open-webui-xxxxxxxxxx-xxxxx   1/1     Running   0          2m
# open-webui-xxxxxxxxxx-yyyyy   1/1     Running   0          2m
```

### Check Storage Mounts
```powershell
# Verify storage is mounted in pods
kubectl exec -n ollama -it deployment/open-webui -- df -h /app/backend/data

# Check files are shared across replicas
kubectl exec -n ollama -it <pod-1-name> -- ls -la /app/backend/data
kubectl exec -n ollama -it <pod-2-name> -- ls -la /app/backend/data
# Both should show the same files
```

## Troubleshooting

### PVC Not Binding
If PVC stays in Pending state:
```powershell
kubectl describe pvc <pvc-name> -n ollama
```
Check for:
- Storage class exists
- Sufficient quota in subscription
- Correct parameters in storage class

### Pod Mount Issues
If pod fails to mount volume:
```powershell
kubectl describe pod <pod-name> -n ollama
```
Check for:
- PVC is in Bound state
- Mount options are correct
- File share was created successfully

### Performance Issues
Monitor storage performance:
```powershell
# Check IOPS and throughput in Azure Portal
# Azure Files Premium provides:
# - 1 TiB: 4,000 IOPS, 100 MiB/s baseline
# - 100 GiB: 400 IOPS, 10 MiB/s baseline
```

## Notes

1. **Database vs File Storage**:
   - PostgreSQL stores structured data (users, chats, sessions)
   - Azure Files stores unstructured data (files, uploads, archives)
   - This separation provides optimal performance for each type

2. **Multi-Replica Compatibility**:
   - WebUI with PostgreSQL backend fully supports multiple replicas
   - Azure Files Premium with ReadWriteMany ensures file consistency
   - Kubernetes service provides automatic load balancing

3. **Migration from Disk to Files**:
   - Data must be manually copied if migrating existing deployment
   - Fresh deployments automatically use the new configuration
   - Consider backup before migration

4. **Scalability**:
   - Can scale WebUI replicas up to 10+ with current storage configuration
   - Ollama remains as StatefulSet (typically 1 replica due to GPU constraints)
   - Both storage volumes support expansion if needed
