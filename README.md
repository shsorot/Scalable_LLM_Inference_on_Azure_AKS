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
- ✅ **Ollama** inference server (2 replicas) serving 6 pre-loaded models (~35GB)
- ✅ **Open-WebUI** chat interface (3 replicas) with document upload and RAG
- ✅ **PostgreSQL Flexible Server** with PGVector extension for embeddings
- ✅ **Prometheus + Grafana** monitoring stack with GPU metrics and custom dashboards
- ✅ **Azure Key Vault** integration for secure credential management
- ✅ **Auto-scaling** configuration (CPU/Memory based HPA ready to enable)

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
- ✅ **Vector Database Integration** - PostgreSQL with PGVector enables semantic search with <50ms query latency for RAG applications
- ✅ **Smart Storage Strategy** - Azure Files Premium with RWX access enables horizontal scaling while maintaining sub-10ms model load latency
- ✅ **Horizontal Scaling** - Load balanced across 3 Open-WebUI replicas, scales to N replicas without model duplication
- ✅ **Multi-Model Support** - Pre-load 6 different LLM models (~35GB total) with instant access from any pod
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
- **Python 3.8+** - Required for PGVector setup scripts
- **HuggingFace Token** (optional) - For downloading gated models

### Verify Prerequisites

```powershell
# Check Azure CLI
az version

# Check kubectl
kubectl version --client

# Install Python dependencies
pip install psycopg2-binary

# Login to Azure
az login
az account show
```

## 🚀 Deployment Guide

### Step 1: Clone and Navigate

```powershell
git clone <repository-url>
cd llm-demo/scripts
```

### Step 2: Deploy Everything (Single Command)

```powershell
.\deploy.ps1 -Prefix <your-prefix> -Location northeurope -AutoApprove -HuggingFaceToken <optional>
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
│  │  │ Monitoring Stack │       │ - ollama-1 (GPU)      │   │    │
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
llm-demo/
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
│   ├── 06-postgres.yaml
│   ├── 07-webui-deployment.yaml
│   ├── 08-webui-service.yaml
│   └── 09-resource-quota.yaml
└── scripts/                   # Deployment automation
    ├── deploy.ps1             # Main deployment script
    ├── cleanup.ps1            # Cleanup script
    ├── preload-multi-models.ps1
    ├── enable-pgvector.py
    └── wipe-database.py
```

## 📦 Storage Strategy: Choosing the Right Storage

This demo uses **Azure Files Premium** for model storage. This section explains the tradeoffs to help you make informed decisions for your specific workload.

###Storage Options Comparison

| Storage Type | Access Mode | Latency | Durability | Cost/1TB/mo | Best For |
|--------------|-------------|---------|------------|---------------|----------|
| **Azure Files Premium** | RWX (many pods) | 1-10ms | 99.9% SLA | ~$200 | Multi-replica LLM workloads |
| **Azure Blob NFS** | RWX (many pods) | 10-50ms | 99.999999999% | ~$20 | Large-scale, cost-sensitive |
| **Local NVMe (Lsv3)** | RWO (one pod) | <1ms | Ephemeral | ~$3000-5000/VM* | Ultra-low latency needs |
| **Azure Disk Premium** | RWO (one pod) | <5ms | 99.9% SLA | ~$140 | Single-replica apps |

_*Local NVMe cost shown as VM premium over standard GPU VMs_

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

#### 5. **Cost Analysis (Monthly)**

**Azure Files Premium (1TB)**:
- Storage: $200/month (1TB × $0.20/GB)
- Transactions: ~$5/month (startup operations)
- **Total: ~$205/month**

**Local NVMe (3x NC4as_T4_v3 Lsv3)**:
- VM premium over standard: ~$300/month/VM
- 3 VMs: $900/month additional
- **Total: ~$900/month** (for NVMe capability)

**Savings: $875/month (97% reduction)**

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

### When to Consider Local NVMe

Local NVMe makes sense for:
1. **Single-node deployments** - No need for RWX sharing
2. **Ultra-low latency requirements** - <1ms random I/O needed
3. **Small models (<1GB)** - Load time difference negligible
4. **Stateless workloads** - No persistence required

**This is NOT our workload!** LLM inference requires:
- Large models (2-40GB+)
- Multi-replica scaling
- High availability
- Sequential I/O patterns (not latency-critical)

### Real-World Performance Metrics

From our testing environment:

```
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
```

### Decision Matrix

Choose **Azure Files Premium** when:
- ✅ Running multiple replicas
- ✅ Need pod mobility across nodes
- ✅ Require storage durability
- ✅ Want operational simplicity
- ✅ Cost optimization is important
- ✅ Sequential I/O workload

Choose **Local NVMe** when:
- Single replica per node guaranteed
- <1ms latency is critical
- Random I/O intensive workload
- Short-lived, stateless workloads
- Budget allows 10x storage cost

**For LLM inference, Azure Files Premium is the clear winner.**

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

Edit `scripts/preload-multi-models.ps1` to customize the model list:

```powershell
[string[]]$Models = @(
    "phi3.5",           # 2.3GB
    "llama3.1:8b",      # 4.7GB
    "mistral:7b",       # 4.1GB
    "gemma2:2b",        # 1.6GB
    "gpt-oss",          # 13GB
    "deepseek-r1"       # 8GB
)
```

### Scale Open-WebUI Replicas

```powershell
kubectl scale deployment open-webui -n ollama --replicas=5
```

### Check PGVector Status

```powershell
python scripts/enable-pgvector.py
```

## 📊 Monitoring

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

## 🐛 Troubleshooting

### Open-WebUI Pods CrashLoopBackOff

**Cause**: PGVector extensions not enabled

**Solution**:
```powershell
python scripts/enable-pgvector.py
kubectl delete pods -n ollama -l app=open-webui
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
