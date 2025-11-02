# Scalable LLM Inference on Azure AKS

**Production-ready deployment of Ollama + Open-WebUI with GPU acceleration, demonstrating horizontal scaling patterns for Large Language Models**

## 🎯 What This Demo Does

This demo deploys a complete, scalable LLM inference platform on Azure Kubernetes Service that solves real-world challenges in running Large Language Models at scale:

### The Problem
Running LLMs in production requires:
- **Sharing large model files** (2-40GB each) across multiple pods
- **GPU acceleration** while keeping costs under control
- **High availability** with pod mobility across nodes
- **Vector search** for RAG (Retrieval Augmented Generation) applications
- **Horizontal scaling** without duplicating 35GB+ of model weights

### The Solution
This architecture demonstrates:
1. **ReadWriteMany Storage** - Multiple pods access the same model files simultaneously
2. **GPU-Accelerated Inference** - NVIDIA T4 GPUs with Kubernetes scheduling
3. **Stateful Model Management** - StatefulSet for Ollama with persistent volume claims
4. **Stateless Web Layer** - Multiple Open-WebUI replicas behind a load balancer
5. **PostgreSQL + PGVector** - Semantic search for document Q&A with RAG
6. **Complete Automation** - Single-command deployment with monitoring included

### What You Get
- ✅ **Ollama** inference server (StatefulSet) serving 6 pre-loaded models (~35GB)
- ✅ **Open-WebUI** chat interface (3 replicas) with document upload and RAG
- ✅ **PostgreSQL Flexible Server** with PGVector extension for embeddings
- ✅ **Prometheus + Grafana** monitoring stack with GPU metrics and custom dashboards
- ✅ **Prometheus Adapter** for GPU-based autoscaling (custom metrics API)
- ✅ **Azure Key Vault** integration for secure credential management
- ✅ **GPU-Based Autoscaling** - HPA with GPU memory utilization metrics

### Key Technologies
| Component | Purpose | Why This Choice |
|-----------|---------|-----------------|
| **Ollama** | LLM inference engine | GPU acceleration, model management, OpenAI-compatible API |
| **Open-WebUI** | User interface | Modern UX, RAG support, multi-user, document processing |
| **PostgreSQL + PGVector** | Vector database | Sub-50ms semantic search, mature ecosystem, Azure-managed |
| **Azure Files Premium** | Shared storage | RWX access, 99.9% SLA, pod mobility enablement |
| **AKS with GPU nodes** | Container orchestration | NVIDIA T4 GPUs, Spot pricing, enterprise-grade K8s |
| **Prometheus + Grafana** | Observability | GPU metrics, inference monitoring, custom dashboards |

## ✨ Key Features

- ✅ **GPU-Accelerated Inference** - NVIDIA T4 GPUs deliver 10-20x faster inference compared to CPU-only deployments
- ✅ **GPU-Based Autoscaling** - HPA scales Ollama pods based on GPU memory utilization (via Prometheus Adapter + DCGM)
- ✅ **Vector Database Integration** - PostgreSQL with PGVector enables semantic search with <50ms query latency for RAG applications
- ✅ **Smart Storage Strategy** - Azure Files Premium with RWX access enables horizontal scaling while maintaining sub-10ms model load latency
- ✅ **Horizontal Scaling** - Load balanced across 3 Open-WebUI replicas, scales to N replicas without model duplication
- ✅ **Multi-Model Support** - Pre-load 6 different LLM models (~35GB total) with instant access from any pod
- ✅ **Multi-User Ready** - Model access control bypassed, all users can access all models
- ✅ **Production Ready** - 99.9% SLA, automatic backups, integrated monitoring, and enterprise security with Azure Key Vault
- ✅ **Cost Optimized** - Spot GPU instances + burstable PostgreSQL = ~$15-25/day (70-90% savings vs. standard pricing)

## 📋 Prerequisites

### Azure Requirements
- **Azure Subscription** with sufficient quota:
  - 2x `Standard_NC4as_T4_v3` (NVIDIA T4 GPU nodes)
  - 2x `Standard_D2s_v3` (System nodes)
- **Subscription Permissions**: Contributor or Owner role

### Local Tools
- **Azure CLI** - [Install Guide](https://learn.microsoft.com/cli/azure/install-azure-cli)
- **kubectl** - [Install Guide](https://kubernetes.io/docs/tasks/tools/)
- **PowerShell** - 5.1+ (Windows) or PowerShell Core 7+ (cross-platform)
- **HuggingFace Token** (optional) - For downloading gated models

### Verify Prerequisites

```powershell
# Check Azure CLI
az version

# Check kubectl
kubectl version --client

# Login to Azure
az login
az account show
```

## 🚀 Deployment Guide

### Step 1: Clone and Navigate

```powershell
git clone https://github.com/shsorot/Scalable_LLM_Inference_on_Azure_AKS.git
cd Scalable_LLM_Inference_on_Azure_AKS
```

### Step 2: Deploy Everything (Single Command)

```powershell
.\scripts\deploy.ps1 -Prefix <your-prefix> -Location northeurope -AutoApprove -HuggingFaceToken <optional>
```

**Parameters:**
- `-Prefix` - Unique identifier for resources (e.g., `mycompany`)
- `-Location` - Azure region (e.g., `northeurope`, `eastus`)
- `-AutoApprove` - Skip manual confirmation prompts
- `-HuggingFaceToken` - Optional, for gated models like Llama

**What Gets Deployed:**

| Step | Component | Duration | Details |
|------|-----------|----------|---------|
| 1 | Resource Group | 10s | Creates Azure resource group |
| 2 | Key Vault | 30s | Stores PostgreSQL credentials |
| 3 | Infrastructure | 8-10min | AKS cluster, PostgreSQL, Storage (via Bicep) |
| 4 | Kubernetes Config | 30s | Connects kubectl to AKS |
| 5 | Applications | 2-3min | Deploys Ollama, Open-WebUI, storage |
| 6 | Model Preload | 3-5min | Downloads 6 models (~35GB) |
| 7 | PostgreSQL Setup | 30s | Enables PGVector extension |
| 8 | Monitoring Stack | 2-3min | Prometheus, Grafana, dashboards |

**Total Time:** 15-20 minutes

### Step 3: Access Applications

After deployment completes, the script shows:

```
========================================
DEPLOYMENT SUMMARY
========================================
Resource Group    : mycompany-rg
AKS Cluster       : mycompany-aks-...
PostgreSQL Server : mycompany-pg-...

--- Service Endpoints ---
Open-WebUI URL    : http://20.54.123.45
  └─ First user becomes admin
  └─ Create account to get started

Grafana Dashboard : http://20.54.123.67
  └─ Username: admin
  └─ Password: admin123!

--- Pre-loaded Models (35GB) ---
✓ phi3.5 (2.3GB)
✓ llama3.1:8b (4.7GB)
✓ mistral:7b (4.1GB)
✓ gemma2:2b (1.6GB)
✓ gpt-oss (13GB)
✓ deepseek-r1 (8GB)
```

### Step 4: Start Using the Chat Interface

1. **Open Web UI** - Navigate to the Open-WebUI URL
2. **Create Account** - First user becomes admin automatically
3. **Select Model** - Choose from 6 pre-loaded models
4. **Start Chatting** - GPU-accelerated inference ready to go

### Step 5: Test RAG (Document Q&A)

1. Click **`+`** icon → **Upload Document** (PDF, TXT, or DOCX)
2. Wait for document processing (~30s for 10-page PDF)
3. In chat, ask questions about the document
4. System uses PGVector semantic search to retrieve relevant context

### Step 6: Monitor Performance

1. **Access Grafana** - Navigate to Grafana URL (admin / admin123!)
2. **Browse Dashboards**:
   - **GPU Monitoring** - GPU utilization, memory, temperature
   - **LLM Platform Overview** - Pod status, inference rates, latency

## 🧹 Cleanup

### Option 1: Delete Everything

```powershell
.\cleanup.ps1 -Prefix <your-prefix> -Force
```

Removes:
- Resource group
- All Azure resources (AKS, PostgreSQL, Storage, Key Vault)
- Local kubectl config

### Option 2: Wipe Database Only

```powershell
.\cleanup.ps1 -Prefix <your-prefix> -WipeDatabase -KeepResourceGroup
```

Clears:
- All chat history
- Uploaded documents
- User accounts
- Vector embeddings

Keeps infrastructure running.

### Option 3: Keep Everything

```powershell
# Just stop the cluster to save costs
az aks stop --resource-group <prefix>-rg --name <prefix>-aks-...

# Restart later
az aks start --resource-group <prefix>-rg --name <prefix>-aks-...
```

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         Azure Cloud                              │
│                                                                   │
│  ┌─────────────────┐        ┌──────────────────┐                │
│  │   Azure Files   │◄───────┤  PostgreSQL      │                │
│  │   Premium 1TB   │        │  Flexible Server │                │
│  │   (RWX Storage) │        │  + PGVector      │                │
│  └────────┬────────┘        └────────┬─────────┘                │
│           │                          │                           │
│  ┌────────▼─────────────────────────▼──────────────────────┐    │
│  │              AKS Cluster (K8s 1.30+)                     │    │
│  │                                                           │    │
│  │  System Pool (2x D2s_v3)    GPU Pool (2x NC4as_T4_v3)   │    │
│  │  ┌──────────────────┐       ┌───────────────────────┐   │    │
│  │  │ Prometheus       │       │ Ollama StatefulSet    │   │    │
│  │  │ Grafana          │       │ - ollama-0 (GPU)      │   │    │
│  │  │ Monitoring Stack │       │   (scales to N)       │   │    │
│  │  └──────────────────┘       └───────────────────────┘   │    │
│  │                              ┌───────────────────────┐   │    │
│  │                              │ Open-WebUI Deployment │   │    │
│  │                              │ - webui-pod-1 (CPU)   │   │    │
│  │                              │ - webui-pod-2 (CPU)   │   │    │
│  │                              │ - webui-pod-3 (CPU)   │   │    │
│  │                              └───────────────────────┘   │    │
│  └───────────────────────────────────────────────────────────┘   │
│                                                                   │
└─────────────────────────────────────────────────────────────────┘
```

**Key Architectural Decisions:**
- **StatefulSet for Ollama** - Stable network identity, ordered deployment, persistent volume claims
- **Deployment for Open-WebUI** - Stateless replicas, rolling updates, horizontal scaling
- **External PostgreSQL** - Managed service with automatic backups, HA, and PGVector extension
- **GPU Taints** - Ensure only GPU-requiring workloads run on expensive GPU nodes
- **System/GPU node separation** - Cost optimization (monitoring on cheap nodes, inference on GPU nodes)

See [ARCHITECTURE.md](ARCHITECTURE.md) for detailed diagrams and design rationale.

## 💰 Cost Analysis

### Estimated Monthly Costs (North Europe region)

| Component | SKU/Configuration | Monthly Cost |
|-----------|-------------------|--------------|
| **AKS Control Plane** | Free tier | $0 |
| **System Nodes** | 2x Standard_D2s_v3 | ~$140 |
| **GPU Nodes (Spot)** | 2x Standard_NC4as_T4_v3 Spot | ~$90-120 |
| **PostgreSQL** | Flexible Server B1ms (Burstable) | ~$15 |
| **Azure Files Premium** | 1TB storage | ~$200 |
| **Key Vault** | Secrets storage | ~$1 |
| **Monitoring** | Prometheus storage (20GB) | ~$3 |
| **Bandwidth** | Outbound data transfer | ~$5-10 |
| **Total** | | **~$454-489/month** |

**Cost Optimization Tips:**
- Use **Spot instances** for 70-90% GPU savings (already configured)
- Enable **AKS cluster autoscaler** to scale down during inactivity
- Use **Burstable PostgreSQL** tier (B1ms) for demo workloads
- **Stop cluster** when not in use: `az aks stop` (keeps resources, no compute charges)

**Daily cost for 8 hours of active use:** ~$15-25 USD

## 📁 Project Structure

```
Scalable_LLM_Inference_on_Azure_AKS/
├── bicep/                      # Azure infrastructure templates
│   ├── main.bicep             # Main orchestration
│   ├── aks.bicep              # AKS cluster with GPU nodes
│   ├── postgres.bicep         # PostgreSQL Flexible Server
│   └── parameters.example.json
├── k8s/                       # Kubernetes manifests
│   ├── 01-namespace.yaml
│   ├── 01-nvidia-device-plugin.yaml
│   ├── 02-storage-premium.yaml
│   ├── 05-ollama-statefulset.yaml
│   ├── 06-ollama-service.yaml
│   ├── 07-webui-deployment.yaml
│   ├── 08-webui-service.yaml
│   ├── 09-resource-quota.yaml
│   ├── 10-webui-hpa.yaml
│   ├── 11-dcgm-exporter.yaml
│   ├── 12-ollama-hpa.yaml
│   └── 13-dcgm-servicemonitor.yaml
├── scripts/                   # Deployment automation (see scripts/README.md)
│   ├── Common.ps1             # Shared functions library
│   ├── deploy.ps1             # Main deployment script
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
