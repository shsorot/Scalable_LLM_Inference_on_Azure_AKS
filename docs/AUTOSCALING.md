# Autoscaling Architecture

## Overview

This LLM platform implements comprehensive autoscaling for both the web interface and inference engine, optimized for GPU workloads and variable model sizes.

## Architecture Components

### 1. **Open-WebUI Autoscaling** (CPU/Memory Based)
- **Type**: Horizontal Pod Autoscaler (HPA v2)
- **Metrics**: CPU (70%), Memory (80%)
- **Range**: 3-10 replicas
- **Scaling Behavior**:
  - Scale up: Immediate (max 2 pods/min or 50%/min)
  - Scale down: Conservative (5 min stabilization, max 1 pod/min)
- **Storage**: Shared 20GB Azure Files Premium (RWX)

### 2. **Ollama Inference Autoscaling** (GPU Memory + CPU Based)
- **Type**: Horizontal Pod Autoscaler (HPA v2)
- **Primary Metric**: GPU memory utilization (70% target)
- **Fallback Metrics**: CPU (75%), System Memory (80%)
- **Range**: 2-5 replicas
- **Scaling Behavior**:
  - Scale up: Fast (60s stabilization, 1 pod/min)
  - Scale down: Very conservative (10 min stabilization, 1 pod per 5 min)
- **Storage**: Shared 1TB Azure Files Premium (RWX) for models

### 3. **Cluster Autoscaling** (Node Level)
- **Type**: AKS Cluster Autoscaler
- **GPU Node Pool**: 1-5 nodes (Standard_NC4as_T4_v3 or similar)
- **Trigger**: Pending pods due to insufficient GPU resources
- **Scale Down**: Delete mode (cost efficient)

### 4. **GPU Monitoring** (DCGM Exporter)
- **Purpose**: Expose GPU metrics to Prometheus
- **Metrics**:
  - GPU memory used/total (`DCGM_FI_DEV_FB_USED`, `DCGM_FI_DEV_FB_TOTAL`)
  - GPU utilization (`DCGM_FI_DEV_GPU_UTIL`)
  - GPU temperature (`DCGM_FI_DEV_GPU_TEMP`)
- **Deployment**: DaemonSet on GPU nodes
- **Port**: 9400 (Prometheus scraping)

## Model-Aware Scaling Strategy

### Model Size Categories

| Model | Size | GPU Memory | Pods/Node (T4 16GB) |
|-------|------|------------|---------------------|
| gemma2:2b | ~1.5GB | ~3GB in use | 4-5 pods |
| phi3.5 | ~2.2GB | ~4GB in use | 3-4 pods |
| mistral:7b | ~4.1GB | ~6GB in use | 2 pods |
| llama3.1:8b | ~4.7GB | ~7GB in use | 2 pods |
| gpt-oss | ~17GB | ~14GB in use | 1 pod |
| deepseek-r1 | ~8GB | ~10GB in use | 1 pod |

### Scaling Triggers

**Scenario 1: High traffic on small models (phi3.5, gemma2)**
- Multiple requests → CPU/Memory increases
- HPA scales Ollama pods: 2 → 3 → 4
- All pods fit on existing GPU nodes
- Cluster autoscaler: No action needed

**Scenario 2: Large model request (gpt-oss)**
- User loads gpt-oss (17GB model)
- GPU memory on existing nodes: 70% → 90%+
- HPA triggers scale-up: 2 → 3 pods
- Pending pod: Cannot fit on existing nodes
- Cluster autoscaler: Provisions new GPU node
- Pod scheduled on new node with gpt-oss

**Scenario 3: Mixed workload**
- Node 1: 2x llama3.1:8b (~14GB total)
- Node 2: 3x phi3.5 (~12GB total)
- Node 3 (new): 1x gpt-oss (~14GB)
- Load balancing: Ollama service distributes requests
- Fast model switching: Multiple models pre-loaded

## Load Balancing

### Open-WebUI Load Balancing
- **Service Type**: LoadBalancer (Azure LB)
- **Algorithm**: Round-robin (default)
- **Session Affinity**: None (stateless, shared storage)
- **Health Checks**: Readiness probe on `/health`
- **Benefit**: Any replica can serve any user

### Ollama Load Balancing
- **Service Type**: ClusterIP (internal)
- **Algorithm**: Round-robin across all pods
- **Model Locality**:
  - First request: Model loaded (~5-10s)
  - Subsequent: Served from memory (<1s)
- **Sticky Sessions**: Not required (models shared on storage)
- **Benefit**: Parallel inference across multiple GPUs

### Model Switching Performance

**Without Autoscaling** (1 pod):
```
User A: phi3.5 request
→ Load phi3.5 (8s) → Inference (0.5s)

User B: llama3.1 request (arrives during above)
→ Wait for phi3.5 unload
→ Load llama3.1 (12s) → Inference (1s)
→ Total wait: 21.5s
```

**With Autoscaling** (3 pods):
```
User A: phi3.5 request → Pod 1
→ Load phi3.5 (8s) → Inference (0.5s)

User B: llama3.1 request → Pod 2 (parallel)
→ Load llama3.1 (12s) → Inference (1s)
→ Total wait: 13s (vs 21.5s)

User C: phi3.5 request → Pod 1 (already loaded)
→ Inference (0.5s) immediately
```

**Benefits**:
- ✅ Parallel model loading
- ✅ Multiple models kept in memory simultaneously
- ✅ Faster switching for popular models
- ✅ Load distribution across GPUs

## Configuration Details

### Open-WebUI HPA
```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: open-webui-hpa
spec:
  minReplicas: 3
  maxReplicas: 10
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 70
    - type: Resource
      resource:
        name: memory
        target:
          type: Utilization
          averageUtilization: 80
```

### Ollama HPA
```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: ollama-hpa
spec:
  minReplicas: 2
  maxReplicas: 5
  metrics:
    - type: Pods  # Custom metric (requires Prometheus Adapter)
      pods:
        metric:
          name: gpu_memory_utilization
        target:
          type: AverageValue
          averageValue: "70"
    - type: Resource  # Fallback
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 75
```

### Cluster Autoscaler (AKS Bicep)
```bicep
{
  name: 'gpu'
  count: 1              // Initial nodes
  minCount: 1           // Min for cost
  maxCount: 5           // Max for scaling
  enableAutoScaling: true
  scaleDownMode: 'Delete'
}
```

## Metrics Pipeline

```
GPU Hardware
    ↓ (NVML API)
DCGM (Data Collection Microservice)
    ↓ (gRPC)
DCGM Exporter (Port 9400)
    ↓ (HTTP /metrics)
Prometheus (Scraping)
    ↓ (PromQL)
Prometheus Adapter (Custom Metrics API)
    ↓ (Kubernetes API)
HPA Controller
    ↓ (Scale Decision)
Deployment/ReplicaSet
    ↓ (Pod Creation)
Kubernetes Scheduler
    ↓ (Node Selection)
Cluster Autoscaler (if needed)
    ↓ (Node Provisioning)
Azure VMSS (GPU Node)
```

## Testing Autoscaling

### 1. Monitor Current State
```powershell
# View HPA status
kubectl get hpa -n ollama

# View pod metrics
kubectl top pods -n ollama

# View node metrics
kubectl top nodes
```

### 2. Manual Scaling Test
```powershell
# Scale up Open-WebUI
kubectl scale deployment open-webui -n ollama --replicas=6

# Scale up Ollama
kubectl scale deployment ollama -n ollama --replicas=4

# Watch changes
kubectl get pods -n ollama -w
```

### 3. Load Test (Triggers Autoscaling)
```powershell
# Run automated load test
.\scripts\test-scaling.ps1 -LoadTest

# Watch scaling in real-time
.\scripts\test-scaling.ps1 -MonitorOnly
```

### 4. Verify Model Switching
```powershell
# Check loaded models per pod
$pods = kubectl get pods -n ollama -l app=ollama -o name
foreach ($pod in $pods) {
    Write-Host "=== $pod ==="
    kubectl exec -n ollama $pod -- curl -s http://localhost:11434/api/tags
}
```

## Cost Optimization

### Without Autoscaling
- GPU nodes: 2 nodes * $0.50/hour = $1.00/hour
- Monthly: $730/month
- Utilization: 20% average (idle most of time)
- Effective cost: $3,650/month per utilized node

### With Autoscaling
- GPU nodes: 1-5 nodes (dynamic)
- Average: 1.5 nodes * $0.50/hour = $0.75/hour
- Monthly: ~$550/month
- Utilization: 70% average (scales with demand)
- Savings: **~25% reduction** + higher utilization

### Cluster Autoscaler Behavior
- **Scale up**: ~3-5 minutes (new node provisioning)
- **Scale down**: 10 minutes idle + drain (conservative)
- **Cost**: Pay per minute (Azure VMSS)
- **Benefit**: Only pay for what you use

## Advanced: Custom GPU Metrics

To enable GPU memory-based autoscaling (currently using CPU/memory fallback):

### 1. Install Prometheus Stack
```powershell
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install prometheus prometheus-community/kube-prometheus-stack -n monitoring --create-namespace
```

### 2. Configure Prometheus to Scrape DCGM
```yaml
# prometheus-additional.yaml
- job_name: 'dcgm-exporter'
  kubernetes_sd_configs:
    - role: pod
      namespaces:
        names:
          - ollama
  relabel_configs:
    - source_labels: [__meta_kubernetes_pod_label_app_kubernetes_io_name]
      action: keep
      regex: dcgm-exporter
```

### 3. Install Prometheus Adapter
```powershell
helm install prometheus-adapter prometheus-community/prometheus-adapter `
  -n monitoring `
  --set prometheus.url=http://prometheus-kube-prometheus-prometheus.monitoring.svc `
  --set rules.default=false `
  -f prometheus-adapter-rules.yaml
```

### 4. Define Custom Metrics Rules
```yaml
# prometheus-adapter-rules.yaml
rules:
  custom:
    - seriesQuery: 'DCGM_FI_DEV_FB_USED'
      resources:
        overrides:
          namespace: { resource: "namespace" }
          pod: { resource: "pod" }
      name:
        matches: "^(.*)$"
        as: "gpu_memory_used_bytes"
      metricsQuery: 'DCGM_FI_DEV_FB_USED{<<.LabelMatchers>>}'

    - seriesQuery: 'DCGM_FI_DEV_FB_USED'
      resources:
        overrides:
          namespace: { resource: "namespace" }
          pod: { resource: "pod" }
      name:
        matches: "^(.*)$"
        as: "gpu_memory_utilization"
      metricsQuery: '(DCGM_FI_DEV_FB_USED{<<.LabelMatchers>>} / DCGM_FI_DEV_FB_TOTAL{<<.LabelMatchers>>}) * 100'
```

### 5. Verify Custom Metrics
```powershell
kubectl get --raw "/apis/custom.metrics.k8s.io/v1beta1" | jq .
kubectl get --raw "/apis/custom.metrics.k8s.io/v1beta1/namespaces/ollama/pods/*/gpu_memory_utilization" | jq .
```

Once configured, the Ollama HPA will use GPU memory metrics for intelligent scaling decisions.

## Demo Script

### Scenario: Auto-scaling during model switching

```powershell
# 1. Baseline (2 Ollama pods, 3 WebUI pods)
kubectl get pods -n ollama
kubectl get hpa -n ollama

# 2. Load small models across pods
# Pod 1: phi3.5, Pod 2: gemma2:2b
.\scripts\preload-multi-models.ps1

# 3. Generate mixed traffic
.\scripts\test-scaling.ps1 -LoadTest

# 4. Observe scaling
# - Open-WebUI: 3 → 5 replicas (CPU increases)
# - Ollama: 2 → 3 replicas (GPU memory + CPU)
kubectl get hpa -n ollama -w

# 5. Large model request
# Load gpt-oss (17GB) - triggers node scaling
kubectl exec -n ollama ollama-0 -- curl -X POST http://localhost:11434/api/pull -d '{"name":"gpt-oss"}'

# 6. Watch cluster autoscaler
kubectl get pods -n ollama -o wide
kubectl get nodes -l gpu=true

# 7. Result
# - 3 GPU nodes provisioned
# - 4 Ollama pods (multi-model support)
# - 6 WebUI pods (high concurrency)
# - Fast model switching (models in memory)
```

## Troubleshooting

### HPA shows "unknown" metrics
```powershell
# Check metrics-server
kubectl get deployment metrics-server -n kube-system

# Install if missing
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
```

### GPU metrics not available
```powershell
# Check DCGM exporter pods
kubectl get pods -n ollama -l app.kubernetes.io/name=dcgm-exporter

# Check logs
kubectl logs -n ollama -l app.kubernetes.io/name=dcgm-exporter

# Verify Prometheus scraping
kubectl port-forward -n ollama svc/dcgm-exporter 9400:9400
curl http://localhost:9400/metrics | grep DCGM
```

### Cluster autoscaler not scaling
```powershell
# Check autoscaler logs
kubectl logs -n kube-system -l app=cluster-autoscaler

# Verify node pool configuration
az aks nodepool show --resource-group <rg> --cluster-name <cluster> --name gpu

# Check for pending pods
kubectl get pods -n ollama -o wide | grep Pending
```

### Pods not distributing across nodes
```powershell
# Check pod anti-affinity
kubectl describe deployment ollama -n ollama | grep -A 10 Affinity

# Manually drain node to force rescheduling
kubectl drain <node-name> --ignore-daemonsets --delete-emptydir-data
kubectl uncordon <node-name>
```

## Future Enhancements

1. **KEDA (Kubernetes Event-Driven Autoscaling)**
   - Scale based on queue depth (message-driven inference)
   - Scale to zero during idle periods
   - Event sources: Azure Queue, HTTP requests, custom metrics

2. **Model Preloading Strategy**
   - Predict popular models based on time-of-day
   - Pre-warm pods with likely models
   - Cache warming during scale-up

3. **Intelligent Load Balancing**
   - Route requests to pods with model already loaded
   - Weighted routing based on GPU memory available
   - Affinity for repeat users/sessions

4. **Multi-Region Scaling**
   - Geographic load balancing
   - Cross-region failover
   - Data residency compliance

5. **Cost Analytics Dashboard**
   - Real-time scaling cost tracking
   - Model inference cost per request
   - Optimization recommendations

## Summary

This autoscaling architecture provides:
- ✅ **Automatic horizontal scaling** for both UI and inference
- ✅ **GPU-aware scheduling** with memory-based decisions
- ✅ **Dynamic node provisioning** via cluster autoscaler
- ✅ **Fast model switching** through parallel pod deployment
- ✅ **Cost optimization** through demand-based scaling
- ✅ **High availability** with multi-replica deployments
- ✅ **Shared storage** for seamless model access

**Demo value**: Shows enterprise-grade LLM platform with automatic scaling based on demand, GPU utilization, and model size requirements.
