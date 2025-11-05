# Scalable LLM Inference on Azure AKS# Scalable LLM Inference on Azure AKS



A production-ready deployment pattern for running Large Language Models on Azure Kubernetes Service with GPU acceleration, demonstrating horizontal scaling, shared storage, and vector search capabilities.**Production-ready deployment of Ollama + Open-WebUI with GPU acceleration, demonstrating horizontal scaling patterns for Large Language Models**



## Overview## 🎯 What This Demo Does



This project demonstrates how to deploy and scale LLM inference workloads on Azure Kubernetes Service. It addresses common challenges in running large language models at scale:This demo deploys a complete, scalable LLM inference platform on Azure Kubernetes Service that solves real-world challenges in running Large Language Models at scale:



- **Shared Model Storage**: Multiple pods access the same model files without duplication### The Problem

- **GPU Acceleration**: NVIDIA T4 GPUs for efficient inferenceRunning LLMs in production requires:

- **Horizontal Scaling**: Scale inference capacity without replicating 35GB+ of model data- **Sharing large model files** (2-40GB each) across multiple pods

- **Vector Search**: PostgreSQL with PGVector extension for RAG applications- **GPU acceleration** while keeping costs under control

- **Cost Optimization**: Spot instances and flexible storage options reduce operational costs- **High availability** with pod mobility across nodes

- **Vector search** for RAG (Retrieval Augmented Generation) applications

### Components- **Horizontal scaling** without duplicating 35GB+ of model weights



| Component | Purpose | Technology |### The Solution

|-----------|---------|------------|This architecture demonstrates:

| **Ollama** | LLM inference engine | StatefulSet with GPU scheduling |1. **ReadWriteMany Storage** - Multiple pods access the same model files simultaneously

| **Open-WebUI** | Chat interface | Deployment with HPA |2. **GPU-Accelerated Inference** - NVIDIA T4 GPUs with Kubernetes scheduling

| **PostgreSQL + PGVector** | Vector database for RAG | Azure Flexible Server |3. **Stateful Model Management** - StatefulSet for Ollama with persistent volume claims

| **Storage** | Model persistence | Azure Files or Blob Storage (CSI drivers) |4. **Stateless Web Layer** - Multiple Open-WebUI replicas behind a load balancer

| **Monitoring** | Observability | Prometheus + Grafana with GPU metrics |5. **PostgreSQL + PGVector** - Semantic search for document Q&A with RAG

6. **Complete Automation** - Single-command deployment with monitoring included

## Key Features

### What You Get

- **GPU-Accelerated Inference**: NVIDIA T4 GPUs deliver 10-20x faster inference than CPU-only deployments- ✅ **Ollama** inference server (StatefulSet) serving 6 pre-loaded models (~35GB)

- **Automatic Scaling**: Horizontal Pod Autoscaler based on GPU memory utilization- ✅ **Open-WebUI** chat interface (3 replicas) with document upload and RAG

- **Flexible Storage**: Choose between Azure Files Premium (performance) or Blob Storage (cost)- ✅ **PostgreSQL Flexible Server** with PGVector extension for embeddings

- **Vector Search**: Sub-50ms semantic search latency for document Q&A- ✅ **Prometheus + Grafana** monitoring stack with GPU metrics and custom dashboards

- **Multi-Model Support**: Pre-load multiple models with instant access from any pod- ✅ **Prometheus Adapter** for GPU-based autoscaling (custom metrics API)

- **Production Ready**: 99.9% SLA, automated backups, comprehensive monitoring- ✅ **Azure Key Vault** integration for secure credential management

- ✅ **GPU-Based Autoscaling** - HPA with GPU memory utilization metrics

## Prerequisites

### Key Technologies

### Azure Resources| Component | Purpose | Why This Choice |

|-----------|---------|-----------------|

- Azure subscription with Contributor access| **Ollama** | LLM inference engine | GPU acceleration, model management, OpenAI-compatible API |

- Sufficient quota for:| **Open-WebUI** | User interface | Modern UX, RAG support, multi-user, document processing |

  - 2x `Standard_NC4as_T4_v3` GPU nodes (NVIDIA T4)| **PostgreSQL + PGVector** | Vector database | Sub-50ms semantic search, mature ecosystem, Azure-managed |

  - 2x `Standard_D2s_v3` system nodes| **Azure Files Premium** | Shared storage | RWX access, 99.9% SLA, pod mobility enablement |

| **AKS with GPU nodes** | Container orchestration | NVIDIA T4 GPUs, Spot pricing, enterprise-grade K8s |

### Local Tools| **Prometheus + Grafana** | Observability | GPU metrics, inference monitoring, custom dashboards |



- [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli) 2.50+## ✨ Key Features

- [kubectl](https://kubernetes.io/docs/tasks/tools/) 1.28+

- PowerShell 5.1+ or PowerShell Core 7+- ✅ **GPU-Accelerated Inference** - NVIDIA T4 GPUs deliver 10-20x faster inference compared to CPU-only deployments

- HuggingFace token (optional, for gated models)- ✅ **GPU-Based Autoscaling** - HPA scales Ollama pods based on GPU memory utilization (via Prometheus Adapter + DCGM)

- ✅ **Vector Database Integration** - PostgreSQL with PGVector enables semantic search with <50ms query latency for RAG applications

## Quick Start- ✅ **Smart Storage Strategy** - Azure Files Premium with RWX access enables horizontal scaling while maintaining sub-10ms model load latency

- ✅ **Horizontal Scaling** - Load balanced across 3 Open-WebUI replicas, scales to N replicas without model duplication

### 1. Clone Repository- ✅ **Multi-Model Support** - Pre-load 6 different LLM models (~35GB total) with instant access from any pod

- ✅ **Multi-User Ready** - Model access control bypassed, all users can access all models

```powershell- ✅ **Production Ready** - 99.9% SLA, automatic backups, integrated monitoring, and enterprise security with Azure Key Vault

git clone https://github.com/shsorot/Scalable_LLM_Inference_on_Azure_AKS.git- ✅ **Cost Optimized** - Spot GPU instances + burstable PostgreSQL = ~$15-25/day (70-90% savings vs. standard pricing)

cd Scalable_LLM_Inference_on_Azure_AKS

```## 📋 Prerequisites



### 2. Deploy Infrastructure and Applications### Azure Requirements

- **Azure Subscription** with sufficient quota:

```powershell  - 2x `Standard_NC4as_T4_v3` (NVIDIA T4 GPU nodes)

.\scripts\deploy.ps1 `  - 2x `Standard_D2s_v3` (System nodes)

    -Prefix "myproject" `- **Subscription Permissions**: Contributor or Owner role

    -Location "northeurope" `

    -HuggingFaceToken "hf_xxx" `### Local Tools

    -AutoApprove- **Azure CLI** - [Install Guide](https://learn.microsoft.com/cli/azure/install-azure-cli)

```- **kubectl** - [Install Guide](https://kubernetes.io/docs/tasks/tools/)

- **PowerShell** - 5.1+ (Windows) or PowerShell Core 7+ (cross-platform)

**Deployment Time**: ~15-20 minutes- **HuggingFace Token** (optional) - For downloading gated models



The script deploys:### Verify Prerequisites

- AKS cluster with GPU and system node pools

- PostgreSQL Flexible Server with PGVector extension```powershell

- Ollama inference server (6 pre-loaded models ~35GB)# Check Azure CLI

- Open-WebUI interface (3 replicas)az version

- Prometheus + Grafana monitoring stack

# Check kubectl

### 3. Access Applicationskubectl version --client



After deployment, you'll receive:# Login to Azure

az login

```az account show

Open-WebUI URL    : http://<public-ip>```

Grafana Dashboard : http://<public-ip>

```## 🚀 Deployment Guide



**First user to sign up becomes admin.**### Step 1: Clone and Navigate



## Storage Options```powershell

git clone https://github.com/shsorot/Scalable_LLM_Inference_on_Azure_AKS.git

Choose the storage backend that fits your requirements:cd Scalable_LLM_Inference_on_Azure_AKS

```

### Azure Files Premium (Default)

### Step 2: Deploy Everything (Single Command)

Best for production workloads requiring fast I/O and frequent model updates.

```powershell

```powershell.\scripts\deploy.ps1 -Prefix <your-prefix> -Location northeurope -AutoApprove -HuggingFaceToken <optional>

.\scripts\deploy.ps1 -Prefix "prod" -StorageBackend "AzureFiles"```

```

**Parameters:**

**Characteristics:**- `-Prefix` - Unique identifier for resources (e.g., `mycompany`)

- RWX (ReadWriteMany) access mode- `-Location` - Azure region (e.g., `northeurope`, `eastus`)

- Sub-10ms latency for model loading- `-AutoApprove` - Skip manual confirmation prompts

- Automatic caching and replication- `-HuggingFaceToken` - Optional, for gated models like Llama

- ~$1.74/GB/month ($1,740/TB)- `-StorageBackend` - **NEW!** Storage backend for LLM models: `AzureFiles` (default) or `BlobStorage`



### Blob Storage### 💾 Storage Backend Options



Ideal for cost-sensitive environments or dev/test scenarios.Choose between two storage backends for LLM model storage:



```powershell| Backend | Cold Start | Monthly Cost* | Best For |

.\scripts\deploy.ps1 -Prefix "dev" -StorageBackend "BlobStorage"|---------|------------|---------------|----------|

```| **AzureFiles** (default) | ~5-8s | ~$1,740 | Fast inference, production |

| **BlobStorage** | ~15-30s | ~$227 | Cost-sensitive, dev/test |

**Characteristics:**

- RWX access mode via BlobFuse2***Cost comparison**: 1TB Azure Files Premium ($1.74/GB/month) vs 1TB Blob Storage Hot tier ($0.0227/GB/month) = **87% savings**

- Streaming with 1-hour local cache

- 87% cost savings vs Azure Files**Key Differences:**

- ~$0.0227/GB/month ($227/TB)- **Azure Files Premium** (default):

  - ✅ Fastest cold start (5-8 seconds)

**Note**: Uses hybrid caching (50GB local cache, 1-hour timeout) to accelerate model downloads while maintaining streaming benefits.  - ✅ Local caching on disk

  - ✅ Best for production workloads

See [Storage Backend Selection](docs/STORAGE-BACKEND-SELECTION.md) for detailed comparison.  - ❌ Higher cost (~$1,740/month for 1TB)



## Architecture- **Blob Storage** (streaming):

  - ✅ 87% cheaper (~$227/month for 1TB)

```  - ✅ Pure streaming from cloud (no local cache)

┌─────────────────────────────────────────────────────────────┐  - ✅ Ideal for dev/test environments

│                      Azure Cloud                            │  - ❌ Slower cold start (15-30 seconds)

│                                                              │  - ⚠️ +12-30s latency on first model load per pod

│  ┌─────────────┐            ┌──────────────┐               │

│  │  Storage    │────────────│  PostgreSQL  │               │**Storage Architecture:**

│  │  (CSI)      │            │  + PGVector  │               │- **Model Storage** (1TB): User-selectable via `-StorageBackend` parameter

│  └──────┬──────┘            └──────┬───────┘               │- **WebUI Data** (20GB): Always uses Azure Files Premium (mixed read/write workload)

│         │                          │                        │

│    ┌────┴──────────────────────────┴──────────────┐        │**Deployment Examples:**

│    │         AKS Cluster (K8s 1.30+)              │        │

│    │                                               │        │```powershell

│    │  [System Pool]        [GPU Pool]             │        │# Default: Azure Files Premium (fast, production-ready)

│    │  - Monitoring         - Ollama (StatefulSet) │        │.\scripts\deploy.ps1 -Prefix "demo" -Location "westus2" -HuggingFaceToken "hf_xxx"

│    │  - Prometheus         - GPU scheduling       │        │

│    │  - Grafana            - Auto-scaling         │        │# Cost-optimized: Blob Storage with streaming (87% cheaper)

│    │                                               │        │.\scripts\deploy.ps1 -Prefix "demo" -Location "westus2" -HuggingFaceToken "hf_xxx" -StorageBackend "BlobStorage"

│    │                       [Web Layer]             │        │```

│    │                       - Open-WebUI (3x)      │        │

│    │                       - LoadBalancer         │        │For detailed cost analysis and migration guide, see:

│    └───────────────────────────────────────────────┘        │- 📄 [Storage Feasibility Analysis](docs/STORAGE-BLOBFUSE-FEASIBILITY.md)

└─────────────────────────────────────────────────────────────┘- 📄 [Implementation Guide](docs/STORAGE-BLOBFUSE-IMPLEMENTATION.md)

```- 📄 [Quick Reference](docs/STORAGE-BLOB-VS-FILES-QUICKREF.md)



### Design Decisions**What Gets Deployed:**



**StatefulSet for Ollama**: Provides stable network identity and ordered deployment for GPU workloads. Each pod gets persistent storage via PVC.| Step | Component | Duration | Details |

|------|-----------|----------|---------|

**Deployment for Open-WebUI**: Stateless replicas behind a LoadBalancer enable horizontal scaling and zero-downtime updates.| 1 | Resource Group | 10s | Creates Azure resource group |

| 2 | Key Vault | 30s | Stores PostgreSQL credentials |

**Node Pool Separation**: System pool (D2s_v3) runs Kubernetes system components and monitoring, while GPU pool (NC4as_T4_v3) is dedicated to LLM inference. This optimizes costs and ensures GPU resources aren't wasted on non-ML workloads.| 3 | Infrastructure | 8-10min | AKS cluster, PostgreSQL, Storage (via Bicep) |

| 4 | Kubernetes Config | 30s | Connects kubectl to AKS |

**CSI Driver Storage**: Azure Files and Blob Storage CSI drivers automatically manage storage accounts in the AKS-managed resource group, simplifying lifecycle management and RBAC.| 5 | Applications | 2-3min | Deploys Ollama, Open-WebUI, storage |

| 6 | Model Preload | 3-5min | Downloads 6 models (~35GB) |

**External PostgreSQL**: Managed service provides automatic backups, HA, and PGVector extension without operational overhead.| 7 | PostgreSQL Setup | 30s | Enables PGVector extension |

| 8 | Monitoring Stack | 2-3min | Prometheus, Grafana, dashboards |

See [ARCHITECTURE.md](ARCHITECTURE.md) for detailed design documentation.

**Total Time:** 15-20 minutes

## Operations

### Step 3: Access Applications

### Scaling Replicas

After deployment completes, the script shows:

```powershell

# Scale Open-WebUI horizontally```

kubectl scale deployment open-webui -n ollama --replicas=5========================================

DEPLOYMENT SUMMARY

# Scale Ollama (GPU workload)========================================

kubectl scale statefulset ollama -n ollama --replicas=2Resource Group    : mycompany-rg

```AKS Cluster       : mycompany-aks-...

PostgreSQL Server : mycompany-pg-...

### Monitoring

--- Service Endpoints ---

Access Grafana dashboard (credentials provided after deployment):Open-WebUI URL    : http://20.54.123.45

  └─ First user becomes admin

- **GPU Monitoring**: Utilization, memory, temperature per node  └─ Create account to get started

- **LLM Platform Overview**: Pod status, request rates, latency metrics

Grafana Dashboard : http://20.54.123.67

```powershell  └─ Username: admin

# Check pod status  └─ Password: <randomly-generated>

kubectl get pods -n ollama  └─ (also stored in Key Vault: grafana-admin-password)



# View logs--- Pre-loaded Models (35GB) ---

kubectl logs -n ollama -l app=ollama --tail=50✓ phi3.5 (2.3GB)

✓ llama3.1:8b (4.7GB)

# Check GPU allocation✓ mistral:7b (4.1GB)

kubectl describe nodes -l agentpool=gpu✓ gemma2:2b (1.6GB)

```✓ gpt-oss (13GB)

✓ deepseek-r1 (8GB)

### Model Management```



Models are stored in `/root/.ollama` within Ollama pods:### Step 4: Start Using the Chat Interface



```powershell1. **Open Web UI** - Navigate to the Open-WebUI URL

# List loaded models2. **Create Account** - First user becomes admin automatically

kubectl exec -n ollama ollama-0 -- ollama list3. **Select Model** - Choose from 6 pre-loaded models

4. **Start Chatting** - GPU-accelerated inference ready to go

# Pull additional model

kubectl exec -n ollama ollama-0 -- ollama pull llama2:13b### Step 5: Test RAG (Document Q&A)



# Remove unused model1. Click **`+`** icon → **Upload Document** (PDF, TXT, or DOCX)

kubectl exec -n ollama ollama-0 -- ollama rm <model-name>2. Wait for document processing (~30s for 10-page PDF)

```3. In chat, ask questions about the document

4. System uses PGVector semantic search to retrieve relevant context

### Cleanup

### Step 6: Monitor Performance

```powershell

# Delete all resources1. **Access Grafana** - Navigate to Grafana URL (use credentials from deployment output)

.\scripts\cleanup.ps1 -Prefix "myproject" -Force2. **Browse Dashboards**:

   - **GPU Monitoring** - GPU utilization, memory, temperature

# Keep infrastructure, clean Kubernetes resources only   - **LLM Platform Overview** - Pod status, inference rates, latency

.\scripts\cleanup.ps1 -Prefix "myproject" -KeepResourceGroup

## 🧹 Cleanup

# Wipe database (reset user data)

.\scripts\cleanup.ps1 -Prefix "myproject" -WipeDatabase -KeepResourceGroup### Option 1: Delete Everything

```

```powershell

**Cost Saving Tip**: Stop the cluster when not in use:.\cleanup.ps1 -Prefix <your-prefix> -Force

```

```powershell

az aks stop --resource-group myproject-rg --name myproject-aks-<hash>Removes:

az aks start --resource-group myproject-rg --name myproject-aks-<hash>- Resource group

```- All Azure resources (AKS, PostgreSQL, Storage, Key Vault)

- Local kubectl config

## Cost Estimation

### Option 2: Wipe Database Only

Monthly costs for North Europe region:

```powershell

| Component | SKU | Monthly Cost |.\cleanup.ps1 -Prefix <your-prefix> -WipeDatabase -KeepResourceGroup

|-----------|-----|--------------|```

| AKS Control Plane | Free tier | $0 |

| System Nodes | 2x Standard_D2s_v3 | ~$140 |Clears:

| GPU Nodes (Spot) | 2x NC4as_T4_v3 | ~$90-120 |- All chat history

| PostgreSQL | B1ms Burstable | ~$15 |- Uploaded documents

| Storage (Azure Files) | 1TB Premium | ~$1,740 |- User accounts

| Storage (Blob) | 1TB Hot | ~$230 |- Vector embeddings

| Key Vault | Standard | ~$1 |

| **Total (Azure Files)** | | **~$1,986-2,016/month** |Keeps infrastructure running.

| **Total (Blob Storage)** | | **~$476-506/month** |

### Option 3: Keep Everything

**Daily cost for 8-hour workday**: ~$16-25 (with Spot instances)

```powershell

## RAG (Retrieval Augmented Generation)# Just stop the cluster to save costs

az aks stop --resource-group <prefix>-rg --name <prefix>-aks-...

The platform supports document Q&A via PGVector semantic search:

# Restart later

1. Sign in to Open-WebUIaz aks start --resource-group <prefix>-rg --name <prefix>-aks-...

2. Upload documents (PDF, TXT, DOCX) via the `+` menu```

3. Ask questions about the uploaded content

4. The system performs vector similarity search to retrieve relevant context## 🏗️ Architecture



**Performance**: Sub-50ms semantic search across embedded documents.```

┌─────────────────────────────────────────────────────────────────┐

## Troubleshooting│                         Azure Cloud                              │

│                                                                   │

### Pods Not Starting│  ┌─────────────────┐        ┌──────────────────┐                │

│  │   Azure Files   │◄───────┤  PostgreSQL      │                │

Check events and describe the pod:│  │   Premium 1TB   │        │  Flexible Server │                │

│  │   (RWX Storage) │        │  + PGVector      │                │

```powershell│  └────────┬────────┘        └────────┬─────────┘                │

kubectl get events -n ollama --sort-by='.lastTimestamp'│           │                          │                           │

kubectl describe pod <pod-name> -n ollama│  ┌────────▼─────────────────────────▼──────────────────────┐    │

```│  │              AKS Cluster (K8s 1.30+)                     │    │

│  │                                                           │    │

### GPU Not Allocated│  │  System Pool (2x D2s_v3)    GPU Pool (2x NC4as_T4_v3)   │    │

│  │  ┌──────────────────┐       ┌───────────────────────┐   │    │

Verify GPU node pool and NVIDIA device plugin:│  │  │ Prometheus       │       │ Ollama StatefulSet    │   │    │

│  │  │ Grafana          │       │ - ollama-0 (GPU)      │   │    │

```powershell│  │  │ Monitoring Stack │       │   (scales to N)       │   │    │

kubectl get nodes -l agentpool=gpu│  │  └──────────────────┘       └───────────────────────┘   │    │

kubectl get pods -n kube-system -l name=nvidia-device-plugin-ds│  │                              ┌───────────────────────┐   │    │

```│  │                              │ Open-WebUI Deployment │   │    │

│  │                              │ - webui-pod-1 (CPU)   │   │    │

### Storage Mount Failures│  │                              │ - webui-pod-2 (CPU)   │   │    │

│  │                              │ - webui-pod-3 (CPU)   │   │    │

Check CSI driver logs:│  │                              └───────────────────────┘   │    │

│  └───────────────────────────────────────────────────────────┘   │

```powershell│                                                                   │

# For Azure Files└─────────────────────────────────────────────────────────────────┘

kubectl logs -n kube-system -l app=csi-azurefile-controller --tail=50```



# For Blob Storage**Key Architectural Decisions:**

kubectl logs -n kube-system -l app=csi-blob-controller --tail=50- **StatefulSet for Ollama** - Stable network identity, ordered deployment, persistent volume claims

```- **Deployment for Open-WebUI** - Stateless replicas, rolling updates, horizontal scaling

- **External PostgreSQL** - Managed service with automatic backups, HA, and PGVector extension

See [TROUBLESHOOTING.md](docs/TROUBLESHOOTING-GPU-WEBUI.md) for more solutions.- **GPU Taints** - Ensure only GPU-requiring workloads run on expensive GPU nodes

- **System/GPU node separation** - Cost optimization (monitoring on cheap nodes, inference on GPU nodes)

## Documentation

See [ARCHITECTURE.md](ARCHITECTURE.md) for detailed diagrams and design rationale.

- [Architecture Details](ARCHITECTURE.md) - System design and patterns

- [Deployment Guide](DEPLOYMENT.md) - Step-by-step deployment## 💰 Cost Analysis

- [Autoscaling](docs/AUTOSCALING.md) - HPA configuration and tuning

- [Monitoring](docs/MONITORING.md) - Prometheus and Grafana setup### Estimated Monthly Costs (North Europe region)

- [Storage Selection](docs/STORAGE-BACKEND-SELECTION.md) - Choosing the right storage

- [Storage Optimization](docs/STORAGE-OPTIMIZATION-SUMMARY.md) - CSI driver management| Component | SKU/Configuration | Monthly Cost |

|-----------|-------------------|--------------|

## Project Structure| **AKS Control Plane** | Free tier | $0 |

| **System Nodes** | 2x Standard_D2s_v3 | ~$140 |

```| **GPU Nodes (Spot)** | 2x Standard_NC4as_T4_v3 Spot | ~$90-120 |

├── bicep/              # Azure infrastructure (IaC)| **PostgreSQL** | Flexible Server B1ms (Burstable) | ~$15 |

├── k8s/                # Kubernetes manifests| **Azure Files Premium** | 1TB storage | ~$200 |

├── scripts/            # PowerShell deployment automation| **Key Vault** | Secrets storage | ~$1 |

├── dashboards/         # Grafana dashboard definitions| **Monitoring** | Prometheus storage (20GB) | ~$3 |

├── docs/               # Additional documentation| **Bandwidth** | Outbound data transfer | ~$5-10 |

└── ARCHITECTURE.md     # System architecture| **Total** | | **~$454-489/month** |

```

**Cost Optimization Tips:**

## Contributing- Use **Spot instances** for 70-90% GPU savings (already configured)

- Enable **AKS cluster autoscaler** to scale down during inactivity

Contributions are welcome. Please ensure:- Use **Burstable PostgreSQL** tier (B1ms) for demo workloads

- **Stop cluster** when not in use: `az aks stop` (keeps resources, no compute charges)

- Code follows existing patterns

- PowerShell scripts include error handling**Daily cost for 8 hours of active use:** ~$15-25 USD

- Kubernetes manifests follow best practices

- Documentation is updated accordingly## 📁 Project Structure



## License```

Scalable_LLM_Inference_on_Azure_AKS/

MIT License - see LICENSE file for details.├── bicep/                      # Azure infrastructure templates

│   ├── main.bicep             # Main orchestration

## Acknowledgments│   ├── aks.bicep              # AKS cluster with GPU nodes

│   ├── postgres.bicep         # PostgreSQL Flexible Server

Built with:│   └── parameters.example.json

- [Ollama](https://ollama.ai) - LLM inference runtime├── k8s/                       # Kubernetes manifests

- [Open-WebUI](https://openwebui.com) - Chat interface│   ├── 01-namespace.yaml

- [PGVector](https://github.com/pgvector/pgvector) - Vector similarity search│   ├── 01-nvidia-device-plugin.yaml

- Azure Kubernetes Service│   ├── 02-storage-premium.yaml

- NVIDIA GPU Operator│   ├── 05-ollama-statefulset.yaml

│   ├── 06-ollama-service.yaml

## Support│   ├── 07-webui-deployment.yaml

│   ├── 08-webui-service.yaml

For issues or questions:│   ├── 09-resource-quota.yaml

- Check [documentation](docs/)│   ├── 10-webui-hpa.yaml

- Review [DEPLOYMENT.md](DEPLOYMENT.md)│   ├── 11-dcgm-exporter.yaml

- Open an issue on GitHub│   ├── 12-ollama-hpa.yaml

│   └── 13-dcgm-servicemonitor.yaml

---├── scripts/                   # Deployment automation (see scripts/README.md)

│   ├── Common.ps1             # Shared functions library

**Note**: This project demonstrates production-ready patterns for LLM deployment on Kubernetes. Adjust configurations based on your specific workload requirements, security policies, and compliance needs.│   ├── deploy.ps1             # Main deployment script

│   ├── cleanup.ps1            # Cleanup script
│   ├── preload-multi-models.ps1
│   ├── set-models-public.ps1
│   ├── test-scaling.ps1
│   ├── verify-deployment-ready.ps1
│   ├── verify-gpu-metrics.ps1
│   └── README.md              # Detailed script documentation
├── benchmarks/                # Performance testing (see benchmarks/README.md)
│   ├── benchmark.ps1          # Unified benchmark suite
│   └── README.md              # Benchmark documentation
├── dashboards/                # Grafana dashboards
│   ├── gpu-monitoring.json
│   └── llm-platform-overview.json
├── docs/                      # Additional documentation
│   ├── AUTOSCALING.md
│   ├── BENCHMARK.md
│   └── MONITORING.md
├── ARCHITECTURE.md            # System architecture overview
├── DEPLOYMENT.md              # Detailed deployment guide
└── CHANGELOG.md               # Version history
```

## 📦 Storage Strategy: Choosing the Right Storage

This demo uses **Azure Files Premium** for model storage. This section explains the tradeoffs to help you make informed decisions for your specific workload.

### Storage Options Comparison

| Storage Type | Access Mode | Latency | Durability | Cost (100GB) | Monthly Cost | Best For |
|--------------|-------------|---------|------------|--------------|--------------|----------|
| **Azure Files Premium** | RWX (many pods) | 1-10ms | 99.9% SLA | $0.20/GB | ~$20/month | Multi-replica shared model storage |
| **Azure Blob NFS** | RWX (many pods) | 10-50ms | 99.999999999% | $0.02/GB | ~$2/month | Large-scale, cost-sensitive, read-heavy |
| **Azure Disk Premium** | RWO (one pod) | <5ms | 99.9% SLA | $0.14/GB | ~$14/month | Single-replica, persistent workloads |
| **ACSTor Ephemeral** | RWO* (one pod) | <5ms | Ephemeral | ~$0.50/GB | ~$50/month | Pod-local, high-IOPS, emerging |
| **Local NVMe (GPU VMs)** | RWO (one pod) | <1ms | Ephemeral | Included in VM | See VM cost** | Single-node, ultra-low latency, random I/O |

_*ACSTor RWX support is experimental and limited_
_**NVMe comes with specific GPU VM SKUs: NV36ads_A10_v5 (~$1,565/mo) or NC24ads_A100_v4 (~$2,100/mo) per VM_

### Why Azure Files Premium for This Workload

**1. ReadWriteMany Enables Horizontal Scaling**

**Azure Files (RWX)**:
```
                 ┌────────────┐
                 │ Azure Files│
                 │  Premium   │
                 │  (100GB)   │
                 └─────┬──────┘
                       │
          ┌────────────┼────────────┐
          │            │            │
     ┌────▼───┐   ┌────▼───┐   ┌────▼───┐
     │Ollama-0│   │Ollama-1│   │Ollama-2│
     │ Node A │   │ Node B │   │ Node C │
     └────────┘   └────────┘   └────────┘

✅ All pods access same models
✅ Scale from 1 to N replicas instantly
✅ No model duplication
```

**Local NVMe (RWO)**:
```
     ┌────────────┐   ┌────────────┐   ┌────────────┐
     │  Node A    │   │  Node B    │   │  Node C    │
     │  NVMe      │   │  NVMe      │   │  NVMe      │
     │  (2TB)     │   │  (2TB)     │   │  (2TB)     │
     └─────┬──────┘   └─────┬──────┘   └─────┬──────┘
           │                │                │
      ┌────▼───┐       ┌────▼───┐       ┌────▼───┐
      │Ollama-0│       │Ollama-1│       │Ollama-2│
      │35GB dup│       │35GB dup│       │35GB dup│
      └────────┘       └────────┘       └────────┘

❌ 3x storage duplication (105GB total)
❌ 3x download time on scale-up
❌ Model sync complexity
```

#### 3. **Pod Mobility and High Availability**

**Scenario: Node Failure**

With Azure Files:
```
1. Node A fails
2. Kubernetes reschedules Ollama pod to Node B
3. Pod starts, attaches Azure Files share
4. Model already present, starts in 10 seconds
5. Total downtime: ~30 seconds
```

With Local NVMe:
```
1. Node A fails
2. Kubernetes reschedules Ollama pod to Node B
3. NVMe on Node B is empty (or has stale data)
4. Must re-download 35GB of models
5. Total downtime: 10-15 minutes
```

#### 4. **Storage Capacity Planning**

**Multi-Model Deployment (this demo)**:
- 6 models × average 6GB = ~35GB
- With Azure Files: 35GB stored once
- With Local NVMe: 35GB × number of GPU nodes

**Scaling Example**:
- 5 GPU nodes for production
- Azure Files: Still 35GB (RWX sharing)
- Local NVMe: 175GB total (35GB × 5 nodes)
- **5x storage waste with NVMe**

#### 5. **Cost Analysis - Realistic Comparison for 2 GPU Nodes**

**Option A: Current Architecture (Azure Files Premium + T4 Spot)**
- GPU Nodes: 2x NC4as_T4_v3 Spot @ $0.158/hr = ~$228/month
- Storage: 100GB Azure Files Premium = ~$20/month
- **Total: ~$248/month**

**Option B: NVMe GPU VMs with A10 GPUs**
- GPU Nodes: 2x NV36ads_A10_v5 Standard @ $2.16/hr = ~$3,110/month
  - Includes: 1x A10 GPU (24GB) + 1.8TB NVMe per VM
- Storage: Included in VM price
- **Total: ~$3,110/month**
- **Cost increase: +$2,862/month (+1,154%)**

**Option C: NVMe GPU VMs with A100 GPUs**
- GPU Nodes: 2x NC24ads_A100_v4 Standard @ $2.90/hr = ~$4,176/month
  - Includes: 1x A100 GPU (40GB) + 3.8TB NVMe per VM
- Storage: Included in VM price
- **Total: ~$4,176/month**
- **Cost increase: +$3,928/month (+1,584%)**

**Option D: ACSTor Ephemeral Disk + T4 Spot**
- GPU Nodes: 2x NC4as_T4_v3 Spot @ $0.158/hr = ~$228/month
- Storage: ACSTor Ephemeral Disk Pool 100GB = ~$50-100/month
- **Total: ~$278-328/month**
- **Cost increase: +$30-80/month (+12-32%)**

**Key Consideration:** NVMe options include more powerful GPUs (A10/A100) but cost 10-16× more. For T4-class inference workloads, Azure Files Premium provides the most cost-effective shared storage.

#### 6. **Operational Simplicity**

**Azure Files**:
- ✅ Automatic replication and durability
- ✅ Snapshot support for model versioning
- ✅ No manual model synchronization
- ✅ Centralized management
- ✅ Persistent across cluster recreation

**Local NVMe**:
- ❌ Manual model distribution to each node
- ❌ No built-in replication
- ❌ Lost on VM deallocation (Spot VMs!)
- ❌ Requires custom sync scripts
- ❌ State lost on cluster recreation

### When to Use Each Storage Option

#### Choose Azure Files Premium When:
✅ **Multi-replica LLM deployments** (this demo's use case)
- Multiple pods need simultaneous access to same model files
- Horizontal scaling without storage duplication
- Pod mobility across nodes for high availability
- Spot VMs where storage must persist during deallocation

✅ **Cost optimization is critical**
- T4-class GPU workloads where storage cost matters
- Sequential read patterns (model loading) where latency difference is negligible
- Dev/test environments with frequent cluster recreation

✅ **Operational simplicity preferred**
- Managed service with automatic replication
- No manual synchronization between nodes
- Snapshot support for model versioning

#### Choose NVMe GPU VMs When:
✅ **Single-replica per node with node affinity**
- Workload guarantees one pod per GPU node
- No need for pod mobility or cross-node sharing
- Can tolerate node failures requiring full model redownload

✅ **Ultra-low latency random I/O required**
- Database workloads with sub-millisecond requirements
- Random access patterns, not sequential model loading
- Small file operations (<100MB) performance critical

✅ **Higher GPU compute needed anyway**
- Already deploying A10/A100 VMs for GPU performance
- NVMe storage is a bonus, not the primary driver
- Budget allows 10-16× cost increase

✅ **Stateless or ephemeral workloads**
- Short-lived training jobs where NVMe is scratch space
- No persistence required beyond job execution
- Can re-download/rebuild state quickly

#### Choose ACSTor Ephemeral Disk When:
⚠️ **Testing emerging technologies**
- Willing to work with experimental RWX support
- Single-pod-per-node deployment pattern
- 30% cost premium acceptable for managed ephemeral storage

**Note:** ACSTor is evolving; monitor for improved RWX capabilities in future releases.

#### Choose Azure Blob NFS When:
✅ **Large-scale, cost-sensitive read-heavy workloads**
- Massive model repositories (100s of GBs to TBs)
- Predominantly read access patterns
- Can tolerate 10-50ms latency
- Budget constraints require lowest storage cost (~90% cheaper than Azure Files Premium)

### Real-World Performance Metrics

From our testing environment:

```text
Model: llama3.1:8b (4.7GB)

Azure Files Premium:
├── First load (cold): 18.3 seconds
├── Subsequent loads: 16.8 seconds (cache warming)
└── Inference: 127ms/token average

Hypothetical Local NVMe:
├── First load: ~6 seconds (estimated)
├── Subsequent loads: ~6 seconds
└── Inference: 127ms/token average (identical)

Conclusion: 12-second startup difference for hours of operation
Performance bottleneck: GPU compute, not storage I/O
```

### Ideal Use Cases for This Architecture

This architecture (Azure Files Premium + T4 Spot + Multi-Replica) is optimized for:

#### ✅ Development & Testing Environments
- Rapid iteration with frequent cluster recreation
- Cost-sensitive budgets requiring Spot instances
- Multiple developers sharing same infrastructure
- Need for quick scale-up/scale-down

#### ✅ Multi-Tenant SaaS Platforms
- Serving multiple customers from shared model pool
- Horizontal scaling based on customer demand
- High availability requirements (pod mobility)
- Cost optimization through resource sharing

#### ✅ Enterprise Internal AI Assistants
- Departmental chatbots with varying load patterns
- Multiple models for different use cases (HR, IT, Finance)
- Auto-scaling based on business hours
- Managed service preference (minimal ops overhead)

#### ✅ RAG-Based Document Q&A Systems
- Large document corpus requiring vector search
- Multiple UI replicas handling concurrent users
- Persistent storage for uploaded documents
- Integration with existing PostgreSQL workflows

#### ✅ Model Experimentation & A/B Testing
- Frequently swapping between different model versions
- Testing multiple models simultaneously
- Need to preserve model artifacts between tests
- Snapshot support for model versioning

#### ✅ Educational & Demo Environments
- Workshop/training scenarios with ephemeral clusters
- Budget constraints (Spot + Premium Files = $250-400/month)
- Need to demonstrate Kubernetes patterns
- Quick teardown and rebuild capability

#### ❌ NOT Ideal For:

**High-Frequency Trading or Real-Time Systems**
- Where every millisecond of startup latency matters
- Consider NVMe GPU VMs despite higher cost

**Single-Model, Single-Replica Production Systems**
- No benefit from RWX storage sharing
- Azure Disk Premium may be more cost-effective

**GPU-Intensive Training Workloads**
- Requires A100/H100-class GPUs with NVMe anyway
- Storage I/O is secondary to GPU interconnect speed

**Extremely Large Models (>100GB)**
- Consider Azure Blob NFS for cost (~90% cheaper)
- Or model sharding across multiple GPUs

### Storage Decision Summary

For **this specific workload** (multi-replica LLM inference with shared models):

**Azure Files Premium** is the optimal choice because:
- ✅ Native RWX support enables horizontal scaling without duplication
- ✅ 10-16× more cost-effective than NVMe GPU VMs for T4-class workloads
- ✅ Pod mobility and high availability built-in
- ✅ Spot VM compatible (storage persists during deallocation)
- ✅ Managed service reduces operational overhead
- ✅ Sequential read pattern makes storage latency non-critical

**However, storage strategy must match your workload:**
- Single-replica + ultra-low latency → NVMe GPU VMs
- Cost-sensitive + massive scale → Azure Blob NFS
- Multi-replica + shared models → **Azure Files Premium** (this demo)
- Single-replica + persistent → Azure Disk Premium

**There is no universal "best" storage—only the right fit for your requirements.**

## �📖 Deployment Guide

See [DEPLOYMENT.md](DEPLOYMENT.md) for detailed deployment instructions, troubleshooting, and advanced configurations.

## 🧪 Testing RAG Functionality

1. **Create Account**: First user becomes admin
2. **Upload Document**: Click '+' → Upload a PDF or text file
3. **Enable RAG**: In chat settings, enable document context
4. **Ask Questions**: Query about the uploaded document content

The system uses PGVector to perform semantic search across document embeddings.

## 💰 Cost Optimization

- **Burstable PostgreSQL**: B1ms tier for demo workloads
- **Spot GPU Nodes**: 70-90% cost savings on GPU compute
- **Auto-scaling**: Scales down during inactivity
- **Storage Optimization**: Premium tier only where needed

Estimated daily cost: ~$15-25 USD (with 8 hours active usage)

## 🧹 Cleanup

### Keep Infrastructure, Clean Kubernetes

```powershell
.\scripts\cleanup.ps1 -Prefix <your-prefix> -KeepResourceGroup
```

### Wipe Database Content

```powershell
.\scripts\cleanup.ps1 -Prefix <your-prefix> -WipeDatabase -KeepResourceGroup
```

### Delete Everything

```powershell
.\scripts\cleanup.ps1 -Prefix <your-prefix>
```

## 🔧 Advanced Configuration

### Pre-load Specific Models

Use the `-Models` parameter to customize which models to download:

```powershell
.\scripts\preload-multi-models.ps1 -Models @(
    "phi3.5",           # 2.3GB
    "llama3.1:8b",      # 4.7GB
    "mistral:7b",       # 4.1GB
    "gemma2:2b",        # 1.6GB
    "gpt-oss",          # 13GB
    "deepseek-r1"       # 8GB
)
```

Or test without downloading:

```powershell
.\scripts\preload-multi-models.ps1 -DryRun
```

See `scripts/README.md` for more details.

### Scale Open-WebUI Replicas

```powershell
kubectl scale deployment open-webui -n ollama --replicas=5
```

### Verify Deployment Status

```powershell
.\scripts\verify-deployment-ready.ps1 -Prefix <your-prefix>
```

## 📊 Monitoring & Benchmarking

### Monitoring Commands

```powershell
# Check pod status
kubectl get pods -n ollama

# Check resource usage
kubectl top pods -n ollama

# View logs
kubectl logs -n ollama deployment/open-webui --tail=50

# Check GPU allocation
kubectl describe nodes -l agentpool=gpu
```

### Performance Benchmarking

Run comprehensive benchmarks across all models:

```powershell
# Run all benchmarks (single-user, multi-user, all models)
.\benchmarks\benchmark.ps1 -Mode AllModels

# Test specific model
.\benchmarks\benchmark.ps1 -Mode SingleModel -Model "phi3.5"

# Multi-user test (3 concurrent users)
.\benchmarks\benchmark.ps1 -Mode MultiUser -Users 3

# Generate HTML report
.\benchmarks\benchmark.ps1 -Mode Report
```

See `benchmarks/README.md` for detailed benchmark documentation and result analysis.

## 🐛 Troubleshooting

### Azure Policy Warnings During Deployment

**Symptom**: Warnings about container images during Helm installation:
```
Warning: [azurepolicy-*] Container image quay.io/prometheus/node-exporter:v1.10.2
for container node-exporter has not been allowed.
```

**Cause**: Azure Policy in audit/warn mode restricts container registries to `*.azurecr.io` and `mcr.microsoft.com`

**Impact**:
- ✅ If enforcement mode is `warn`: Deployment succeeds, warnings are informational only
- ❌ If enforcement mode is `deny`: Pods fail to start

**Solution**: See [Azure Policy Compliance Guide](docs/AZURE-POLICY-COMPLIANCE.md) for detailed options:
1. **Informational handling** (already implemented in deployment scripts)
2. **Create policy exemptions** using `scripts/create-policy-exemption.ps1`
3. **Mirror images to ACR** for full compliance
4. **Request policy modification** from your governance team

### Open-WebUI Pods CrashLoopBackOff

**Cause**: PostgreSQL connection issues or PGVector extension not enabled

**Solution**:
```powershell
# Check PostgreSQL connection
kubectl logs -n ollama deployment/open-webui --tail=50

# Restart pods
kubectl delete pods -n ollama -l app=open-webui

# Verify deployment status
.\scripts\verify-deployment-ready.ps1 -Prefix <your-prefix>
```

### Model Download Timeouts

**Cause**: Large models take time to download

**Solution**: Models continue downloading in background. Check Ollama logs:
```powershell
kubectl logs -n ollama ollama-0 --tail=100
```

### LoadBalancer IP Pending

**Cause**: Azure provisioning LoadBalancer

**Solution**: Wait 2-3 minutes, then check again:
```powershell
kubectl get svc open-webui -n ollama
```

## 🤝 Contributing

This demo is maintained for KubeCon NA 2025. For issues or improvements, please contact the maintainers.

## 📄 License

This project is provided as-is for demonstration purposes.

## 🔗 Resources

- [Ollama Documentation](https://ollama.ai/docs)
- [Open-WebUI Documentation](https://docs.openwebui.com/)
- [Azure AKS Documentation](https://learn.microsoft.com/azure/aks/)
- [PGVector Documentation](https://github.com/pgvector/pgvector)

## 📧 Support

For questions about this demo:
- See [DEPLOYMENT.md](DEPLOYMENT.md) for detailed guides
- See [ARCHITECTURE.md](ARCHITECTURE.md) for technical details
