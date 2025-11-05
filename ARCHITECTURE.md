# Architecture# Architecture Overview



This document explains the design decisions, component interactions, and operational patterns for running LLM inference workloads on Azure Kubernetes Service.## System Architecture



## System OverviewThis deployment demonstrates a production-ready LLM inference platform on Azure Kubernetes Service with GPU acceleration and PostgreSQL vector database.



``````

┌──────────────────────────────────────────────────────────────┐┌─────────────────────────────────────────────────────────────────┐

│                       Azure Cloud                            ││                         Azure Cloud                             │

│                                                              │├─────────────────────────────────────────────────────────────────┤

│  ┌──────────────────────────────────────────────────────┐  ││                                                                 │

│  │            AKS Cluster (K8s 1.30+)                   │  ││  ┌───────────────────────────────────────────────────────────┐ │

│  │                                                      │  ││  │  Azure Kubernetes Service (AKS)                           │ │

│  │  ┌──────────────┐          ┌──────────────────┐    │  ││  │                                                           │ │

│  │  │ System Pool  │          │   GPU Pool       │    │  ││  │  ┌─────────────────────────┐  ┌──────────────────────┐  │ │

│  │  │ D2s_v3 x2    │          │   NC4as_T4_v3    │    │  ││  │  │   System Node Pool      │  │   GPU Node Pool      │  │ │

│  │  │              │          │   + NVIDIA T4    │    │  ││  │  │  2x Standard_D2s_v3     │  │  2x NC4as_T4_v3      │  │ │

│  │  │ - CoreDNS    │          │   + Spot ~70%↓   │    │  ││  │  │  - CoreDNS              │  │  - NVIDIA T4 GPU     │  │ │

│  │  │ - Monitoring │          │                  │    │  ││  │  │  - Metrics Server       │  │  - Ollama Pods       │  │ │

│  │  │ - Open-WebUI │          │   - Ollama       │    │  ││  │  └─────────────────────────┘  └──────────────────────┘  │ │

│  │  └──────────────┘          └──────────────────┘    │  ││  │                                                           │ │

│  │         │                          │               │  ││  │  ┌───────────────────────────────────────────────────┐  │ │

│  │         └──────────┬───────────────┘               │  ││  │  │              ollama namespace                     │  │ │

│  │                    ▼                               │  ││  │  │                                                   │  │ │

│  │          ┌─────────────────────┐                  │  ││  │  │  ┌────────────────┐       ┌─────────────────┐   │  │ │

│  │          │  Storage (CSI)      │                  │  ││  │  │  │ Ollama         │       │ Open-WebUI      │   │  │ │

│  │          │  RWX shared access  │                  │  ││  │  │  │ StatefulSet    │◄──────┤ Deployment      │   │  │ │

│  │          └─────────────────────┘                  │  ││  │  │  │ (starts 1      │       │ (3 replicas)    │   │  │ │

│  └──────────────────────────────────────────────────────┘  ││  │  │  │  scales to N)  │       │ - LoadBalancer  │   │  │ │

│                                                              ││  │  │  │ - GPU: 1x T4   │       │ - Port: 80      │   │  │ │

│  ┌──────────────────────────────────────────────────────┐  ││  │  │  │ - Port: 11434  │       │                 │   │  │ │

│  │  PostgreSQL Flexible Server + PGVector              │  ││  │  │  └────────┬───────┘       └────────┬────────┘   │  │ │

│  │  (Vector DB for RAG, session store)                 │  ││  │  │           │                        │            │  │ │

│  └──────────────────────────────────────────────────────┘  ││  │  │           │                        │            │  │ │

└──────────────────────────────────────────────────────────────┘│  │  │  ┌────────▼────────┐      ┌───────▼────────┐   │  │ │

```│  │  │  │ Azure Files     │      │  PostgreSQL    │   │  │ │

│  │  │  │ Premium         │      │  Connection    │   │  │ │

## Node Pool Design│  │  │  │ (RWX)           │      │  (via secret)  │   │  │ │

│  │  │  │ - Models: 100GB │      └────────────────┘   │  │ │

### Why Two Node Pools?│  │  │  │ - WebUI:  20GB  │                           │  │ │

│  │  │  └─────────────────┘                           │  │ │

Separating GPU and system workloads provides cost optimization and resource isolation:│  │  └───────────────────────────────────────────────┘  │ │

│  └───────────────────────────────────────────────────────┘ │

**System Pool (D2s_v3)**:│                                                                 │

- Runs Kubernetes control plane components (CoreDNS, metrics-server)│  ┌───────────────────────────────────────────────────────────┐ │

- Hosts CPU-bound workloads (Open-WebUI, monitoring)│  │  Azure PostgreSQL Flexible Server                        │ │

- General-purpose VMs without GPU cost overhead│  │  - Tier: Burstable B1ms (1 vCore, 2GB RAM)              │ │

- 2 nodes for high availability│  │  - Storage: 32GB                                         │ │

│  │  - Extensions: vector (PGVector), uuid-ossp              │ │

**GPU Pool (NC4as_T4_v3)**:│  │  - Database: openwebui                                   │ │

- Dedicated to LLM inference (Ollama)│  │  - Tables: users, chats, messages, document_chunk        │ │

- NVIDIA T4 GPUs (16GB VRAM)│  └───────────────────────────────────────────────────────────┘ │

- Spot instances reduce costs by 70-90%│                                                                 │

- Taints prevent non-GPU workloads from scheduling here│  ┌───────────────────────────────────────────────────────────┐ │

│  │  Azure Key Vault                                          │ │

This separation ensures GPU resources aren't wasted on system pods, and spot instance interruptions only affect inference capacity, not cluster stability.│  │  - postgres-admin-password (auto-generated)               │ │

│  │  - postgres-connection-string                             │ │

### Spot Instance Strategy│  └───────────────────────────────────────────────────────────┘ │

│                                                                 │

GPU nodes use Azure Spot VMs with these considerations:│  ┌───────────────────────────────────────────────────────────┐ │

│  │  Azure Storage Account (for CSI driver)                  │ │

- **Eviction handling**: StatefulSet ensures pods reschedule on eviction│  │  - File shares created dynamically by CSI                │ │

- **Model persistence**: Azure Files stores model data; no re-download needed│  │  - Premium_LRS storage tier                              │ │

- **Availability**: 2-node pool maintains capacity during evictions│  └───────────────────────────────────────────────────────────┘ │

- **Cost savings**: ~70-90% reduction ($0.40/hr vs $1.50/hr for NC4as_T4_v3)└─────────────────────────────────────────────────────────────────┘

```

For production workloads requiring guaranteed capacity, use regular VMs by removing spot configuration in `bicep/aks.bicep`.

## Data Flow

## Workload Design

### Chat Request Flow

### Ollama: StatefulSet Pattern

```

Ollama runs as a StatefulSet, not a Deployment. Here's why:User Browser

    │

**StatefulSet Benefits**:    ▼

- Stable pod identity (`ollama-0`, `ollama-1`) enables predictable DNS namesLoadBalancer (Azure)

- Ordered startup/shutdown ensures clean GPU initialization    │

- Persistent volume binding survives pod restarts    ▼

- GPU-bound workload doesn't benefit from rapid horizontal scalingOpen-WebUI Pod (1 of 3)

    │

**Resource Configuration**:    ├──► PostgreSQL (session, history)

```yaml    │

resources:    └──► Ollama Pod

  requests:         │

    nvidia.com/gpu: 1        # Request exactly 1 GPU         ├──► NVIDIA GPU (inference)

    memory: 8Gi         │

    cpu: 4         └──► Azure Files (model weights)

  limits:```

    nvidia.com/gpu: 1

    memory: 16Gi### RAG (Retrieval Augmented Generation) Flow

```

```

GPU requests are specified as `nvidia.com/gpu: 1`, which triggers the NVIDIA device plugin to schedule the pod on a GPU node. The limit matches the request to prevent overcommitment.Document Upload

    │

### Open-WebUI: Deployment Pattern    ▼

Open-WebUI

Open-WebUI uses a Deployment for stateless horizontal scaling:    │

    ├──► Parse & Chunk Document

**Deployment Benefits**:    │

- Rolling updates without downtime    ├──► Generate Embeddings (384-dim vectors)

- Multiple replicas (default: 3) for load distribution    │

- Any pod can handle any request (stateless design)    └──► PostgreSQL PGVector

- CPU-bound workload (embedding generation, UI) benefits from horizontal scaling         └──► Store in document_chunk table

              (id, vector, collection_name, text, metadata)

**State Management**:

- User sessions: PostgreSQLUser Query

- Uploaded documents: Azure Files PVC    │

- Embeddings: PostgreSQL PGVector    ▼

Open-WebUI

The LoadBalancer service distributes incoming traffic across replicas using round-robin by default.    │

    ├──► Generate Query Embedding

## Storage Architecture    │

    ├──► PGVector Similarity Search

### Why ReadWriteMany (RWX)?    │    └──► SELECT * ORDER BY vector <-> query_vector LIMIT 5

    │

Both Ollama and Open-WebUI use RWX volumes to enable multi-pod access:    ├──► Retrieve Relevant Chunks

    │

**Ollama Models (RWX required)**:    └──► Send to Ollama

- Multiple Ollama replicas (if scaled) share the same model files         └──► LLM generates response with context

- Avoid duplicating 35GB+ per replica```

- New pods access pre-loaded models instantly

## Component Details

**Open-WebUI Files (RWX beneficial)**:

- Any replica can serve uploaded documents### Ollama Server

- User uploads persist regardless of which pod handled the request

- Simplifies failover (no pod-specific state)**Purpose**: LLM inference engine with GPU acceleration



### CSI Driver Management**Configuration**:

- StatefulSet with 1 replica (GPU-bound)

The AKS cluster uses Azure-managed CSI drivers for storage:- Resource requests: 1 GPU, 8Gi memory

- Persistent storage: Azure Files Premium (1TB)

**Azure Files CSI Driver** (`file.csi.azure.com`):- Models loaded: phi3.5, llama3.1:8b, mistral:7b, gemma2:2b, gpt-oss, deepseek-r1

- Automatically provisioned by AKS

- Creates storage accounts in the node resource group**Why StatefulSet?**

- Supports RWX via SMB 3.0 protocol- Guarantees pod identity and stable storage

- Premium tier for low-latency model access- Ensures model cache persists across restarts

- Single replica sufficient (GPU bottleneck)

**Blob Storage CSI Driver** (`blob.csi.azure.com`):

- Optional alternative for cost optimization### Open-WebUI

- Uses BlobFuse2 for POSIX-like filesystem

- RWX via BlobFuse mount on each node**Purpose**: Web interface for chat and document management

- 87% cheaper than Azure Files (~$227/TB vs $1,740/TB)

**Configuration**:

**Key Design Point**: CSI drivers handle storage account lifecycle automatically. The Bicep deployment doesn't explicitly create storage accounts—they're created on-demand when PVCs are provisioned.- Deployment with 3 replicas (horizontally scalable)

- Resource requests: 2 CPU cores, 4Gi memory

### Storage Class Configuration- Persistent storage: Azure Files Premium (20GB)

- Database: PostgreSQL (connection via Kubernetes secret)

**Azure Files (Default)**:

```yaml**Why Multiple Replicas?**

apiVersion: storage.k8s.io/v1- Load distribution across user sessions

kind: StorageClass- High availability (pod failures don't interrupt service)

metadata:- CPU-bound workload (embedding generation, UI rendering)

  name: azurefile-csi-premium

provisioner: file.csi.azure.com### PostgreSQL with PGVector

parameters:

  skuName: Premium_LRS**Purpose**: Vector database for RAG and application state

mountOptions:

  - dir_mode=0755**Schema**:

  - file_mode=0644- `users` - User accounts and preferences

  - uid=1000- `chats` - Chat sessions

  - gid=1000- `messages` - Chat message history

```- `document_chunk` - Vector embeddings for documents

  - `id TEXT PRIMARY KEY`

**Blob Storage (Optional)**:  - `vector VECTOR(384)` - Embedding vector

```yaml  - `collection_name TEXT` - Document grouping

apiVersion: storage.k8s.io/v1  - `text TEXT` - Original chunk text

kind: StorageClass  - `vmetadata JSONB` - Chunk metadata

metadata:

  name: azureblob-fuse2**Extensions**:

provisioner: blob.csi.azure.com- `vector` (PGVector v0.8.0) - Vector similarity operations

parameters:- `uuid-ossp` (v1.1) - UUID generation

  protocol: fuse2

  skuName: Standard_LRS**Queries**:

mountOptions:- Similarity search: `ORDER BY vector <-> query_vector`

  - --streaming                  # Stream reads from blob- Distance metrics: Cosine, L2, Inner Product

  - --file-cache-timeout=3600    # 1-hour local cache

  - --cache-size-mb=51200        # 50GB cache per node### Storage Strategy

```

**Azure Files Premium (RWX)**:

The Blob Storage configuration uses **hybrid caching**: writes go to a local cache first (fast), then asynchronously sync to Blob Storage. Reads stream from Blob after the 1-hour cache timeout, optimizing for both download speed and storage costs.- Ollama models: 1TB persistent volume

- Open-WebUI data: 20GB persistent volume

## GPU Scheduling- Allows ReadWriteMany (multiple pods access same storage)

- Essential for horizontal scaling

### NVIDIA Device Plugin

**Why Azure Files over Disk?**

The NVIDIA device plugin runs as a DaemonSet on GPU nodes:- Ollama models need to be accessible from any pod instance

- Azure Disk (RWO) would limit scaling to single replica

```yaml- Premium tier provides low-latency access (sub-10ms)

apiVersion: apps/v1

kind: DaemonSet### GPU Node Pool

metadata:

  name: nvidia-device-plugin-daemonset**Configuration**:

  namespace: kube-system- Node count: 2 (for availability)

spec:- VM SKU: Standard_NC4as_T4_v3

  selector:  - 4 vCPUs

    matchLabels:  - 28GB RAM

      name: nvidia-device-plugin-ds  - 1x NVIDIA Tesla T4 (16GB VRAM)

  template:- Spot instances: 70-90% cost savings

    spec:- Max pods: 30 per node

      nodeSelector:

        accelerator: nvidia**GPU Allocation**:

      containers:- NVIDIA device plugin DaemonSet

      - image: nvcr.io/nvidia/k8s-device-plugin:v0.14.0- GPU requested via: `nvidia.com/gpu: 1`

        name: nvidia-device-plugin-ctr- Only Ollama pods request GPU

```- Automatic scheduling to GPU nodes



**How it works**:### System Node Pool

1. Plugin discovers GPUs on each node (via NVML library)

2. Advertises GPU count to Kubernetes API (`nvidia.com/gpu: 1`)**Configuration**:

3. Scheduler assigns pods requesting `nvidia.com/gpu: 1` to nodes with available GPUs- Node count: 2 (for control plane HA)

4. Plugin allocates specific GPU device to the pod- VM SKU: Standard_D2s_v3

  - 2 vCPUs

### Taints and Tolerations  - 8GB RAM

- Non-GPU workloads (CoreDNS, metrics, Open-WebUI)

GPU nodes are tainted to prevent non-GPU workloads from wasting expensive resources:

## Network Architecture

**Node Taint** (applied via Bicep):

```yaml### Ingress Traffic

taints:

  - key: sku```

    value: gpuInternet

    effect: NoSchedule    │

```    ▼

Azure LoadBalancer (Public IP)

**Pod Toleration** (Ollama StatefulSet):    │

```yaml    ▼

tolerations:open-webui Service (LoadBalancer)

  - key: sku    │

    operator: Equal    ▼

    value: gpuOpen-WebUI Pods (Round-robin)

    effect: NoSchedule```

```

### Internal Traffic

Only pods with matching tolerations can schedule on GPU nodes.

```

## Database DesignOpen-WebUI Pods

    │

### PostgreSQL + PGVector    ├──► ollama Service (ClusterIP: 11434)

    │    └──► Ollama Pod

The deployment uses Azure PostgreSQL Flexible Server for two purposes:    │

    └──► PostgreSQL (External FQDN)

1. **Application State**: User accounts, chat history, settings         └──► Azure PostgreSQL Flexible Server

2. **Vector Search**: Document embeddings for RAG```



**Key Extensions**:### Service Mesh

- `vector` (v0.8.0): Vector similarity search with pgvector

- `uuid-ossp` (v1.1): UUID generation for primary keys- No service mesh required (simple architecture)

- Native Kubernetes services provide load balancing

### Vector Search Schema- DNS-based service discovery



```sql## Security

CREATE TABLE document_chunk (

    id TEXT PRIMARY KEY,### Secrets Management

    vector VECTOR(384),              -- Embedding dimension

    collection_name TEXT,            -- Group related chunks**Key Vault Integration**:

    text TEXT,                       -- Original chunk content- PostgreSQL admin password generated during deployment

    metadata JSONB                   -- Arbitrary metadata- Stored in Azure Key Vault

);- Retrieved by deployment script

- Injected into Kubernetes secret

CREATE INDEX idx_vector ON document_chunk

USING ivfflat (vector vector_cosine_ops) **Kubernetes Secrets**:

WITH (lists = 100);- `ollama-secrets` - PostgreSQL connection string

```- Environment variables in Open-WebUI pods

- Mounted as env vars, not volumes

**Index Strategy**:

- IVFFlat index for approximate nearest neighbor (ANN) search### Network Security

- Cosine distance operator for semantic similarity

- `lists = 100` parameter balances recall and speed**PostgreSQL Firewall**:

- Allow Azure services: 0.0.0.0/0 (Azure internal traffic)

### RAG Query Flow- SSL/TLS required: `sslmode=require`

- No public internet access (Azure backbone only)

1. User uploads document (PDF, DOCX, TXT)

2. Open-WebUI chunks text (512 tokens per chunk)**AKS Network**:

3. Embedding model generates 384-dim vectors- Kubenet networking (simple, cost-effective)

4. Vectors stored in PostgreSQL: `INSERT INTO document_chunk ...`- Network policies: None (demo environment)

5. User asks question about document- Production: Add Azure CNI + Network Policies

6. Query embedding generated

7. Similarity search: `ORDER BY vector <-> query_vector LIMIT 5`### RBAC

8. Top 5 chunks passed to Ollama as context

9. LLM generates answer using retrieved context**Key Vault Access**:

- User assigned: `Key Vault Secrets Officer` role

**Performance**: Sub-50ms for similarity searches across 10,000 document chunks.- Deployment script reads secrets

- Pods do not access Key Vault directly

## Scaling Strategies

**AKS Access**:

### Horizontal Pod Autoscaler (HPA)- User assigned: `Azure Kubernetes Service RBAC Cluster Admin`

- kubectl configured with admin credentials

**Open-WebUI HPA** (CPU-based):- Production: Use Azure AD integration + RBAC

```yaml

apiVersion: autoscaling/v2## Scaling Considerations

kind: HorizontalPodAutoscaler

metadata:### Horizontal Scaling

  name: webui-hpa

spec:**Open-WebUI**:

  scaleTargetRef:```powershell

    apiVersion: apps/v1kubectl scale deployment open-webui -n ollama --replicas=5

    kind: Deployment```

    name: open-webui- Each replica can handle ~100 concurrent users

  minReplicas: 3- Load balanced by Kubernetes service

  maxReplicas: 10- Shared PostgreSQL state

  metrics:

  - type: Resource**Ollama**:

    resource:- Single replica (GPU constraint)

      name: cpu- To scale: Deploy multiple Ollama StatefulSets (ollama-0, ollama-1, ...)

      target:- Load balance at Open-WebUI level (configure multiple backends)

        type: Utilization

        averageUtilization: 70### Vertical Scaling

```

**GPU Nodes**:

Scales based on CPU usage (embedding generation, request handling).- Larger VMs: NC6s_v3 (1x V100), NC12s_v3 (2x V100)

- More VRAM for larger models (70B, 405B)

**Ollama HPA** (GPU-based):

```yaml**Open-WebUI**:

apiVersion: autoscaling/v2- Increase CPU/memory requests for embedding workloads

kind: HorizontalPodAutoscaler- Faster embedding generation

metadata:

  name: ollama-hpa## Cost Optimization

spec:

  scaleTargetRef:### Azure Resource Costs (Daily, 8h usage)

    apiVersion: apps/v1

    kind: StatefulSet| Resource | SKU | Cost/Day |

    name: ollama|----------|-----|----------|

  minReplicas: 1| AKS GPU Nodes | 2x NC4as_T4_v3 Spot | $8-12 |

  maxReplicas: 4| AKS System Nodes | 2x Standard_D2s_v3 | $2-3 |

  metrics:| PostgreSQL | Burstable B1ms | $1-2 |

  - type: Pods| Storage | Premium Files (120GB) | $1-2 |

    pods:| Key Vault | Standard | $0.10 |

      metric:| LoadBalancer | Basic | $0.50 |

        name: DCGM_FI_DEV_GPU_UTIL| **Total** | | **~$15-25** |

      target:

        type: AverageValue### Cost Reduction Strategies

        averageValue: "75"

```1. **Spot VMs**: 70-90% savings on GPU nodes

2. **Auto-scaling**: Scale down during inactivity

Scales based on GPU utilization via DCGM exporter metrics.3. **Burstable PostgreSQL**: B1ms sufficient for demo

4. **Storage optimization**: Only use Premium where needed

### Cluster Autoscaler5. **Delete when not in use**: `cleanup.ps1` removes all resources



AKS Cluster Autoscaler automatically adjusts node count based on pending pods:## Deployment Process



**Enabled via Bicep**:### Infrastructure as Code (Bicep)

```bicep

autoScalerProfile: {1. **main.bicep** - Orchestrates all modules

  'scale-down-delay-after-add': '10m'2. **aks.bicep** - AKS cluster with GPU and system node pools

  'scale-down-unneeded-time': '10m'3. **postgres.bicep** - PostgreSQL Flexible Server with PGVector

  'max-graceful-termination-sec': '600'

}### Deployment Pipeline

```

```

**How it works**:deploy.ps1

1. Pod requests GPU resource    │

2. No available GPU nodes → pod remains `Pending`    ├──► [1] Pre-flight checks (Azure CLI, kubectl)

3. Cluster Autoscaler detects pending pod    │

4. New GPU node provisioned (up to `maxCount: 10`)    ├──► [2] Deploy Bicep templates

5. Pod schedules on new node    │    └──► Azure infrastructure (10 min)

    │

Scale-down occurs when nodes are underutilized for 10+ minutes.    ├──► [3] Store secrets in Key Vault

    │

## Monitoring Architecture    ├──► [4] Configure kubectl

    │

### Prometheus + Grafana    ├──► [5] Install NVIDIA GPU plugin

    │

**Prometheus Stack** (deployed via Helm):    ├──► [6] Deploy Kubernetes resources

- Prometheus Operator    │    ├──► Namespace

- Node Exporter (system metrics)    │    ├──► Secrets

- DCGM Exporter (GPU metrics)    │    ├──► Storage classes

- Grafana (visualization)    │    ├──► Ollama StatefulSet

    │    └──► Open-WebUI Deployment

**DCGM Exporter DaemonSet**:    │

```yaml    ├──► [7] Enable PGVector extensions

apiVersion: apps/v1    │    └──► Python script (psycopg2)

kind: DaemonSet    │

metadata:    └──► [8] Pre-load models

  name: dcgm-exporter         └──► 6 models (~35GB total)

  namespace: monitoring```

spec:

  selector:## Monitoring and Observability

    matchLabels:

      app: dcgm-exporter### Built-in Metrics

  template:

    spec:```powershell

      nodeSelector:# Pod resource usage

        accelerator: nvidiakubectl top pods -n ollama

      containers:

      - name: dcgm-exporter# Node resource usage

        image: nvcr.io/nvidia/k8s/dcgm-exporter:3.1.3-3.1.4-ubuntu20.04kubectl top nodes

        securityContext:

          runAsNonRoot: false# GPU utilization

          runAsUser: 0kubectl describe nodes -l agentpool=gpu

``````



Runs only on GPU nodes, exposes metrics on port 9400.### Logs



**Key Metrics**:```powershell

- `DCGM_FI_DEV_GPU_UTIL`: GPU utilization percentage# Ollama logs (model loading, inference)

- `DCGM_FI_DEV_FB_USED`: GPU memory used (bytes)kubectl logs -n ollama ollama-0 --tail=100

- `DCGM_FI_DEV_GPU_TEMP`: GPU temperature (Celsius)

- `DCGM_FI_DEV_POWER_USAGE`: Power consumption (watts)# Open-WebUI logs (requests, errors)

kubectl logs -n ollama deployment/open-webui --tail=100

### ServiceMonitor for DCGM

# Previous pod logs (after crash)

```yamlkubectl logs -n ollama <pod-name> --previous

apiVersion: monitoring.coreos.com/v1```

kind: ServiceMonitor

metadata:### Production Monitoring (Not Included)

  name: dcgm-exporter

  namespace: monitoring- Azure Monitor for Containers

spec:- Prometheus + Grafana

  selector:- Application Insights

    matchLabels:- Log Analytics workspace

      app: dcgm-exporter

  endpoints:## High Availability

  - port: metrics

    interval: 30s### Current HA Status

```

| Component | Replicas | Availability |

Prometheus discovers and scrapes DCGM metrics automatically.|-----------|----------|--------------|

| Open-WebUI | 3 | High (load balanced) |

## Security Considerations| Ollama | 1 | Single point of failure |

| PostgreSQL | 1 | Single point of failure |

### RBAC Configuration| GPU Nodes | 2 | Node failure tolerant |

| System Nodes | 2 | Node failure tolerant |

The deployment uses minimal RBAC:

### Production HA Enhancements

- Default service account for Open-WebUI (no cluster access)

- No custom ClusterRoles or RoleBindings1. **Ollama**: Deploy 2+ replicas across availability zones

- PostgreSQL credentials stored in Kubernetes Secret2. **PostgreSQL**: Enable zone-redundant HA mode

3. **Storage**: Zone-redundant storage (ZRS)

**Secret Management**:4. **Multi-region**: Traffic Manager for global distribution

```yaml

apiVersion: v1## Disaster Recovery

kind: Secret

metadata:### Backup Strategy

  name: postgres-secret

  namespace: ollama**PostgreSQL**:

type: Opaque- Automatic backups: 7-day retention

stringData:- Point-in-time restore capability

  connection-string: "postgresql://user:password@host/db"- Backup stored in geo-redundant storage (optional)

```

**Storage**:

Open-WebUI mounts this secret as an environment variable.- Azure Files snapshots (manual)

- Model weights can be re-downloaded

### Network Policies (Optional)- Application data in PostgreSQL



For enhanced security, consider adding NetworkPolicies:### Recovery Procedures



```yaml**Database Restore**:

apiVersion: networking.k8s.io/v1```powershell

kind: NetworkPolicyaz postgres flexible-server restore `

metadata:    --resource-group shsorot-rg `

  name: ollama-netpol    --name shsorot-pg-restored `

spec:    --source-server shsorot-pg-u6nkmvc5rezpy `

  podSelector:    --restore-time "2025-10-29T10:00:00Z"

    matchLabels:```

      app: ollama

  ingress:**Full Redeployment**:

  - from:```powershell

    - podSelector:.\scripts\cleanup.ps1 -Prefix shsorot -WipeDatabase -KeepResourceGroup

        matchLabels:.\scripts\deploy.ps1 -Prefix shsorot -Location northeurope -AutoApprove

          app: open-webui```

    ports:

    - protocol: TCP## Future Enhancements

      port: 11434

```### Potential Improvements



Restricts Ollama to only accept traffic from Open-WebUI pods.1. **Horizontal Pod Autoscaler (HPA)**

   - Auto-scale Open-WebUI based on CPU/memory

### Pod Security Standards   - Auto-scale Ollama based on request queue



All pods run with non-root users where possible:2. **Ingress Controller**

   - NGINX Ingress for TLS termination

- Ollama: `runAsUser: 1000` (ollama user)   - Custom domain with cert-manager

- Open-WebUI: `runAsUser: 1000`

- DCGM Exporter: `runAsUser: 0` (requires root for GPU access)3. **Service Mesh**

   - Istio or Linkerd for advanced traffic management

## Cost Optimization Patterns   - Mutual TLS between services



### Spot Instances4. **Observability Stack**

   - Prometheus + Grafana for metrics

GPU nodes use Spot VMs to reduce costs:   - Loki for log aggregation

   - Jaeger for distributed tracing

**Bicep Configuration**:

```bicep5. **CI/CD Pipeline**

agentPoolProfiles: [   - GitHub Actions for automated testing

  {   - ArgoCD for GitOps deployments

    name: 'gpu'

    scaleSetPriority: 'Spot'6. **Multi-Model Routing**

    scaleSetEvictionPolicy: 'Delete'   - Load balance across multiple Ollama instances

    spotMaxPrice: -1  // Pay up to on-demand price   - Route specific models to dedicated pods

  }
]
```

**Handling Evictions**:
- StatefulSet automatically reschedules pods
- Azure Files persists models (no re-download)
- 30-second termination grace period

### Storage Tiering

Choose storage based on workload:

- **Azure Files Premium**: Production workloads, frequent access
- **Blob Storage**: Dev/test, infrequent access, cost-sensitive

**Decision Matrix**:

| Scenario | Storage | Reasoning |
|----------|---------|-----------|
| Production, <100GB | Azure Files | Low latency, simple management |
| Production, >500GB | Blob Storage | Cost savings outweigh latency |
| Dev/Test | Blob Storage | 87% cost reduction |
| Multi-region | Blob Storage | GRS replication available |

### Cluster Start/Stop

For non-24/7 workloads, stop the cluster when idle:

```powershell
# Stop (retains all state)
az aks stop --resource-group myproject-rg --name myproject-aks-<hash>

# Start (resumes from stopped state)
az aks start --resource-group myproject-rg --name myproject-aks-<hash>
```

**Savings**: 100% of VM costs during stopped periods (still pay for storage and control plane).

## Deployment Patterns

### Blue-Green Deployments

For zero-downtime updates of Open-WebUI:

1. Deploy new version with different label: `version: v2`
2. Test via temporary service pointing to `version: v2`
3. Switch LoadBalancer service selector to `version: v2`
4. Scale down old version

### Canary Releases

Use traffic splitting for gradual rollouts:

```yaml
# 90% traffic to stable
apiVersion: v1
kind: Service
metadata:
  name: open-webui-stable
spec:
  selector:
    app: open-webui
    version: v1
---
# 10% traffic to canary
apiVersion: v1
kind: Service
metadata:
  name: open-webui-canary
spec:
  selector:
    app: open-webui
    version: v2
```

Use an Ingress controller (NGINX, Traefik) for percentage-based routing.

## Observability Best Practices

### Log Aggregation

For production, enable Azure Monitor Container Insights:

```bicep
omsAgent: {
  enabled: true
  logAnalyticsWorkspaceResourceID: logAnalytics.id
}
```

**Capabilities**:
- Centralized pod logs
- Container performance metrics
- Alerting on pod crashes
- KQL queries for log analysis

### Custom Metrics

Expose application-level metrics in Prometheus format:

**Ollama Metrics Example**:
```
ollama_request_duration_seconds{model="llama3.1:8b",quantile="0.5"} 2.3
ollama_request_duration_seconds{model="llama3.1:8b",quantile="0.99"} 8.1
ollama_tokens_generated_total{model="llama3.1:8b"} 15234
```

Add a ServiceMonitor to scrape these metrics.

## Troubleshooting Patterns

### Pod Stuck in Pending

**Symptom**: Ollama pod shows `Pending` state

**Common Causes**:
1. No GPU nodes available → Check cluster autoscaler: `kubectl get nodes`
2. GPU already allocated → Check GPU requests: `kubectl describe nodes`
3. Taint not tolerated → Verify tolerations in pod spec

**Resolution**:
```powershell
# Check node GPU availability
kubectl describe nodes -l agentpool=gpu | grep -A5 "Allocatable"

# Check pending pod events
kubectl describe pod <pod-name> -n ollama
```

### Storage Mount Failures

**Symptom**: Pod fails with `FailedMount` event

**Common Causes**:
1. CSI driver not ready → Check driver pods: `kubectl get pods -n kube-system -l app=csi-azurefile-controller`
2. Storage account not created → Verify AKS managed identity has Contributor role
3. Mount options invalid → Check `mountOptions` in StorageClass

**Resolution**:
```powershell
# Check CSI driver logs
kubectl logs -n kube-system -l app=csi-azurefile-controller --tail=50

# Verify storage account
az storage account list --resource-group MC_*
```

### GPU Not Detected

**Symptom**: Ollama can't find GPU

**Common Causes**:
1. NVIDIA device plugin not running → Check DaemonSet: `kubectl get ds -n kube-system nvidia-device-plugin-ds`
2. GPU drivers not loaded → SSH to node and run `nvidia-smi`
3. GPU limit not set → Verify `resources.limits.nvidia.com/gpu: 1`

**Resolution**:
```powershell
# Check device plugin
kubectl logs -n kube-system -l name=nvidia-device-plugin-ds

# Verify GPU allocation
kubectl get nodes -o json | jq '.items[].status.allocatable."nvidia.com/gpu"'
```

## Future Enhancements

### Multi-Model Routing

Use an Ingress controller to route requests to different Ollama instances based on model:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: model-router
spec:
  rules:
  - host: llama.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: ollama-llama
            port:
              number: 11434
  - host: mistral.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: ollama-mistral
            port:
              number: 11434
```

### Model Caching Layer

Add a Redis cache for frequently requested completions:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ollama-cache-proxy
spec:
  replicas: 1
  template:
    spec:
      containers:
      - name: proxy
        image: custom-cache-proxy:latest
        env:
        - name: REDIS_URL
          value: redis://redis-service:6379
        - name: OLLAMA_URL
          value: http://ollama:11434
```

Reduces inference costs by caching identical prompts.

### Multi-Region Deployment

For global deployments:

1. Deploy AKS clusters in multiple regions
2. Use Azure Blob Storage with GRS replication for shared model storage
3. Route traffic via Azure Front Door or Traffic Manager
4. Replicate PostgreSQL database across regions using read replicas

## Conclusion

This architecture balances performance, cost, and operational simplicity for LLM inference workloads on Kubernetes. Key design principles:

- **Separation of concerns**: GPU and system workloads on separate node pools
- **Shared storage**: RWX volumes enable horizontal scaling without data duplication
- **Cost optimization**: Spot instances and flexible storage tiers reduce expenses
- **Observability**: Comprehensive metrics for GPU, pods, and application performance
- **Simplicity**: Minimal dependencies and straightforward scaling patterns

For specific use cases, adjust configurations based on workload characteristics, budget constraints, and operational requirements.
