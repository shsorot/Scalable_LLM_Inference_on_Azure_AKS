# Architecture Overview

## System Architecture

This deployment demonstrates a production-ready LLM inference platform on Azure Kubernetes Service with GPU acceleration and PostgreSQL vector database.

```
┌─────────────────────────────────────────────────────────────────┐
│                         Azure Cloud                             │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌───────────────────────────────────────────────────────────┐ │
│  │  Azure Kubernetes Service (AKS)                           │ │
│  │                                                           │ │
│  │  ┌─────────────────────────┐  ┌──────────────────────┐  │ │
│  │  │   System Node Pool      │  │   GPU Node Pool      │  │ │
│  │  │  2x Standard_D2s_v3     │  │  2x NC4as_T4_v3      │  │ │
│  │  │  - CoreDNS              │  │  - NVIDIA T4 GPU     │  │ │
│  │  │  - Metrics Server       │  │  - Ollama Pods       │  │ │
│  │  └─────────────────────────┘  └──────────────────────┘  │ │
│  │                                                           │ │
│  │  ┌───────────────────────────────────────────────────┐  │ │
│  │  │              ollama namespace                     │  │ │
│  │  │                                                   │  │ │
│  │  │  ┌────────────────┐       ┌─────────────────┐   │  │ │
│  │  │  │ Ollama         │       │ Open-WebUI      │   │  │ │
│  │  │  │ StatefulSet    │◄──────┤ Deployment      │   │  │ │
│  │  │  │ (starts 1      │       │ (3 replicas)    │   │  │ │
│  │  │  │  scales to N)  │       │ - LoadBalancer  │   │  │ │
│  │  │  │ - GPU: 1x T4   │       │ - Port: 80      │   │  │ │
│  │  │  │ - Port: 11434  │       │                 │   │  │ │
│  │  │  └────────┬───────┘       └────────┬────────┘   │  │ │
│  │  │           │                        │            │  │ │
│  │  │           │                        │            │  │ │
│  │  │  ┌────────▼────────┐      ┌───────▼────────┐   │  │ │
│  │  │  │ Azure Files     │      │  PostgreSQL    │   │  │ │
│  │  │  │ Premium         │      │  Connection    │   │  │ │
│  │  │  │ (RWX)           │      │  (via secret)  │   │  │ │
│  │  │  │ - Models: 100GB │      └────────────────┘   │  │ │
│  │  │  │ - WebUI:  20GB  │                           │  │ │
│  │  │  └─────────────────┘                           │  │ │
│  │  └───────────────────────────────────────────────┘  │ │
│  └───────────────────────────────────────────────────────┘ │
│                                                                 │
│  ┌───────────────────────────────────────────────────────────┐ │
│  │  Azure PostgreSQL Flexible Server                        │ │
│  │  - Tier: Burstable B1ms (1 vCore, 2GB RAM)              │ │
│  │  - Storage: 32GB                                         │ │
│  │  - Extensions: vector (PGVector), uuid-ossp              │ │
│  │  - Database: openwebui                                   │ │
│  │  - Tables: users, chats, messages, document_chunk        │ │
│  └───────────────────────────────────────────────────────────┘ │
│                                                                 │
│  ┌───────────────────────────────────────────────────────────┐ │
│  │  Azure Key Vault                                          │ │
│  │  - postgres-admin-password (auto-generated)               │ │
│  │  - postgres-connection-string                             │ │
│  └───────────────────────────────────────────────────────────┘ │
│                                                                 │
│  ┌───────────────────────────────────────────────────────────┐ │
│  │  Azure Storage Account (for CSI driver)                  │ │
│  │  - File shares created dynamically by CSI                │ │
│  │  - Premium_LRS storage tier                              │ │
│  └───────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

## Data Flow

### Chat Request Flow

```
User Browser
    │
    ▼
LoadBalancer (Azure)
    │
    ▼
Open-WebUI Pod (1 of 3)
    │
    ├──► PostgreSQL (session, history)
    │
    └──► Ollama Pod
         │
         ├──► NVIDIA GPU (inference)
         │
         └──► Azure Files (model weights)
```

### RAG (Retrieval Augmented Generation) Flow

```
Document Upload
    │
    ▼
Open-WebUI
    │
    ├──► Parse & Chunk Document
    │
    ├──► Generate Embeddings (384-dim vectors)
    │
    └──► PostgreSQL PGVector
         └──► Store in document_chunk table
              (id, vector, collection_name, text, metadata)

User Query
    │
    ▼
Open-WebUI
    │
    ├──► Generate Query Embedding
    │
    ├──► PGVector Similarity Search
    │    └──► SELECT * ORDER BY vector <-> query_vector LIMIT 5
    │
    ├──► Retrieve Relevant Chunks
    │
    └──► Send to Ollama
         └──► LLM generates response with context
```

## Component Details

### Ollama Server

**Purpose**: LLM inference engine with GPU acceleration

**Configuration**:
- StatefulSet with 1 replica (GPU-bound)
- Resource requests: 1 GPU, 8Gi memory
- Persistent storage: Azure Files Premium (1TB)
- Models loaded: phi3.5, llama3.1:8b, mistral:7b, gemma2:2b, gpt-oss, deepseek-r1

**Why StatefulSet?**
- Guarantees pod identity and stable storage
- Ensures model cache persists across restarts
- Single replica sufficient (GPU bottleneck)

### Open-WebUI

**Purpose**: Web interface for chat and document management

**Configuration**:
- Deployment with 3 replicas (horizontally scalable)
- Resource requests: 2 CPU cores, 4Gi memory
- Persistent storage: Azure Files Premium (20GB)
- Database: PostgreSQL (connection via Kubernetes secret)

**Why Multiple Replicas?**
- Load distribution across user sessions
- High availability (pod failures don't interrupt service)
- CPU-bound workload (embedding generation, UI rendering)

### PostgreSQL with PGVector

**Purpose**: Vector database for RAG and application state

**Schema**:
- `users` - User accounts and preferences
- `chats` - Chat sessions
- `messages` - Chat message history
- `document_chunk` - Vector embeddings for documents
  - `id TEXT PRIMARY KEY`
  - `vector VECTOR(384)` - Embedding vector
  - `collection_name TEXT` - Document grouping
  - `text TEXT` - Original chunk text
  - `vmetadata JSONB` - Chunk metadata

**Extensions**:
- `vector` (PGVector v0.8.0) - Vector similarity operations
- `uuid-ossp` (v1.1) - UUID generation

**Queries**:
- Similarity search: `ORDER BY vector <-> query_vector`
- Distance metrics: Cosine, L2, Inner Product

### Storage Strategy

**Azure Files Premium (RWX)**:
- Ollama models: 1TB persistent volume
- Open-WebUI data: 20GB persistent volume
- Allows ReadWriteMany (multiple pods access same storage)
- Essential for horizontal scaling

**Why Azure Files over Disk?**
- Ollama models need to be accessible from any pod instance
- Azure Disk (RWO) would limit scaling to single replica
- Premium tier provides low-latency access (sub-10ms)

### GPU Node Pool

**Configuration**:
- Node count: 2 (for availability)
- VM SKU: Standard_NC4as_T4_v3
  - 4 vCPUs
  - 28GB RAM
  - 1x NVIDIA Tesla T4 (16GB VRAM)
- Spot instances: 70-90% cost savings
- Max pods: 30 per node

**GPU Allocation**:
- NVIDIA device plugin DaemonSet
- GPU requested via: `nvidia.com/gpu: 1`
- Only Ollama pods request GPU
- Automatic scheduling to GPU nodes

### System Node Pool

**Configuration**:
- Node count: 2 (for control plane HA)
- VM SKU: Standard_D2s_v3
  - 2 vCPUs
  - 8GB RAM
- Non-GPU workloads (CoreDNS, metrics, Open-WebUI)

## Network Architecture

### Ingress Traffic

```
Internet
    │
    ▼
Azure LoadBalancer (Public IP)
    │
    ▼
open-webui Service (LoadBalancer)
    │
    ▼
Open-WebUI Pods (Round-robin)
```

### Internal Traffic

```
Open-WebUI Pods
    │
    ├──► ollama Service (ClusterIP: 11434)
    │    └──► Ollama Pod
    │
    └──► PostgreSQL (External FQDN)
         └──► Azure PostgreSQL Flexible Server
```

### Service Mesh

- No service mesh required (simple architecture)
- Native Kubernetes services provide load balancing
- DNS-based service discovery

## Security

### Secrets Management

**Key Vault Integration**:
- PostgreSQL admin password generated during deployment
- Stored in Azure Key Vault
- Retrieved by deployment script
- Injected into Kubernetes secret

**Kubernetes Secrets**:
- `ollama-secrets` - PostgreSQL connection string
- Environment variables in Open-WebUI pods
- Mounted as env vars, not volumes

### Network Security

**PostgreSQL Firewall**:
- Allow Azure services: 0.0.0.0/0 (Azure internal traffic)
- SSL/TLS required: `sslmode=require`
- No public internet access (Azure backbone only)

**AKS Network**:
- Kubenet networking (simple, cost-effective)
- Network policies: None (demo environment)
- Production: Add Azure CNI + Network Policies

### RBAC

**Key Vault Access**:
- User assigned: `Key Vault Secrets Officer` role
- Deployment script reads secrets
- Pods do not access Key Vault directly

**AKS Access**:
- User assigned: `Azure Kubernetes Service RBAC Cluster Admin`
- kubectl configured with admin credentials
- Production: Use Azure AD integration + RBAC

## Scaling Considerations

### Horizontal Scaling

**Open-WebUI**:
```powershell
kubectl scale deployment open-webui -n ollama --replicas=5
```
- Each replica can handle ~100 concurrent users
- Load balanced by Kubernetes service
- Shared PostgreSQL state

**Ollama**:
- Single replica (GPU constraint)
- To scale: Deploy multiple Ollama StatefulSets (ollama-0, ollama-1, ...)
- Load balance at Open-WebUI level (configure multiple backends)

### Vertical Scaling

**GPU Nodes**:
- Larger VMs: NC6s_v3 (1x V100), NC12s_v3 (2x V100)
- More VRAM for larger models (70B, 405B)

**Open-WebUI**:
- Increase CPU/memory requests for embedding workloads
- Faster embedding generation

## Cost Optimization

### Azure Resource Costs (Daily, 8h usage)

| Resource | SKU | Cost/Day |
|----------|-----|----------|
| AKS GPU Nodes | 2x NC4as_T4_v3 Spot | $8-12 |
| AKS System Nodes | 2x Standard_D2s_v3 | $2-3 |
| PostgreSQL | Burstable B1ms | $1-2 |
| Storage | Premium Files (120GB) | $1-2 |
| Key Vault | Standard | $0.10 |
| LoadBalancer | Basic | $0.50 |
| **Total** | | **~$15-25** |

### Cost Reduction Strategies

1. **Spot VMs**: 70-90% savings on GPU nodes
2. **Auto-scaling**: Scale down during inactivity
3. **Burstable PostgreSQL**: B1ms sufficient for demo
4. **Storage optimization**: Only use Premium where needed
5. **Delete when not in use**: `cleanup.ps1` removes all resources

## Deployment Process

### Infrastructure as Code (Bicep)

1. **main.bicep** - Orchestrates all modules
2. **aks.bicep** - AKS cluster with GPU and system node pools
3. **postgres.bicep** - PostgreSQL Flexible Server with PGVector

### Deployment Pipeline

```
deploy.ps1
    │
    ├──► [1] Pre-flight checks (Azure CLI, kubectl)
    │
    ├──► [2] Deploy Bicep templates
    │    └──► Azure infrastructure (10 min)
    │
    ├──► [3] Store secrets in Key Vault
    │
    ├──► [4] Configure kubectl
    │
    ├──► [5] Install NVIDIA GPU plugin
    │
    ├──► [6] Deploy Kubernetes resources
    │    ├──► Namespace
    │    ├──► Secrets
    │    ├──► Storage classes
    │    ├──► Ollama StatefulSet
    │    └──► Open-WebUI Deployment
    │
    ├──► [7] Enable PGVector extensions
    │    └──► Python script (psycopg2)
    │
    └──► [8] Pre-load models
         └──► 6 models (~35GB total)
```

## Monitoring and Observability

### Built-in Metrics

```powershell
# Pod resource usage
kubectl top pods -n ollama

# Node resource usage
kubectl top nodes

# GPU utilization
kubectl describe nodes -l agentpool=gpu
```

### Logs

```powershell
# Ollama logs (model loading, inference)
kubectl logs -n ollama ollama-0 --tail=100

# Open-WebUI logs (requests, errors)
kubectl logs -n ollama deployment/open-webui --tail=100

# Previous pod logs (after crash)
kubectl logs -n ollama <pod-name> --previous
```

### Production Monitoring (Not Included)

- Azure Monitor for Containers
- Prometheus + Grafana
- Application Insights
- Log Analytics workspace

## High Availability

### Current HA Status

| Component | Replicas | Availability |
|-----------|----------|--------------|
| Open-WebUI | 3 | High (load balanced) |
| Ollama | 1 | Single point of failure |
| PostgreSQL | 1 | Single point of failure |
| GPU Nodes | 2 | Node failure tolerant |
| System Nodes | 2 | Node failure tolerant |

### Production HA Enhancements

1. **Ollama**: Deploy 2+ replicas across availability zones
2. **PostgreSQL**: Enable zone-redundant HA mode
3. **Storage**: Zone-redundant storage (ZRS)
4. **Multi-region**: Traffic Manager for global distribution

## Disaster Recovery

### Backup Strategy

**PostgreSQL**:
- Automatic backups: 7-day retention
- Point-in-time restore capability
- Backup stored in geo-redundant storage (optional)

**Storage**:
- Azure Files snapshots (manual)
- Model weights can be re-downloaded
- Application data in PostgreSQL

### Recovery Procedures

**Database Restore**:
```powershell
az postgres flexible-server restore `
    --resource-group shsorot-rg `
    --name shsorot-pg-restored `
    --source-server shsorot-pg-u6nkmvc5rezpy `
    --restore-time "2025-10-29T10:00:00Z"
```

**Full Redeployment**:
```powershell
.\scripts\cleanup.ps1 -Prefix shsorot -WipeDatabase -KeepResourceGroup
.\scripts\deploy.ps1 -Prefix shsorot -Location northeurope -AutoApprove
```

## Future Enhancements

### Potential Improvements

1. **Horizontal Pod Autoscaler (HPA)**
   - Auto-scale Open-WebUI based on CPU/memory
   - Auto-scale Ollama based on request queue

2. **Ingress Controller**
   - NGINX Ingress for TLS termination
   - Custom domain with cert-manager

3. **Service Mesh**
   - Istio or Linkerd for advanced traffic management
   - Mutual TLS between services

4. **Observability Stack**
   - Prometheus + Grafana for metrics
   - Loki for log aggregation
   - Jaeger for distributed tracing

5. **CI/CD Pipeline**
   - GitHub Actions for automated testing
   - ArgoCD for GitOps deployments

6. **Multi-Model Routing**
   - Load balance across multiple Ollama instances
   - Route specific models to dedicated pods
