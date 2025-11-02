# Monitoring & Observability

## Overview

This LLM platform includes comprehensive monitoring using **Prometheus + Grafana** stack, providing real-time visibility into GPU utilization, model performance, and infrastructure health.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Grafana Dashboards                        │
│  (Visualization Layer - LoadBalancer Service)                │
└─────────────────────┬───────────────────────────────────────┘
                      │ PromQL Queries
┌─────────────────────▼───────────────────────────────────────┐
│                    Prometheus Server                         │
│  (Metrics Collection & Storage - 7 day retention)            │
└─────┬─────────┬──────────┬──────────┬────────────┬──────────┘
      │         │          │          │            │
      │ Scrape  │ Scrape   │ Scrape   │ Scrape     │ Scrape
      │ :9400   │ :9100    │ :8080    │ :8080      │ :10250
      │         │          │          │            │
┌─────▼─────┐ ┌─▼────────┐ ┌▼────────┐ ┌▼─────────┐ ┌▼─────────┐
│   DCGM    │ │   Node   │ │ Ollama  │ │Open-WebUI│ │  Kube    │
│ Exporter  │ │ Exporter │ │  Pods   │ │   Pods   │ │  State   │
│ (GPU)     │ │ (System) │ │(App)    │ │  (App)   │ │ Metrics  │
└───────────┘ └──────────┘ └─────────┘ └──────────┘ └──────────┘
```

## Components

### 1. **Prometheus**
- **Purpose**: Metrics collection, storage, and querying
- **Retention**: 7 days
- **Storage**: 20GB PVC
- **Scrape Interval**: 30 seconds
- **Access**: Internal ClusterIP (port 9090)

### 2. **Grafana**
- **Purpose**: Metrics visualization and dashboards
- **Service Type**: LoadBalancer (external access)
- **Port**: 80
- **Storage**: 10GB PVC for dashboard persistence
- **Default Credentials**:
  - Username: `admin`
  - Password: `admin123!` (change after first login)

### 3. **DCGM Exporter**
- **Purpose**: NVIDIA GPU metrics (already deployed in k8s/11-dcgm-exporter.yaml)
- **Deployment**: DaemonSet on GPU nodes
- **Port**: 9400
- **Metrics**: GPU utilization, memory, temperature, power

### 4. **Node Exporter**
- **Purpose**: Node-level system metrics
- **Deployment**: DaemonSet on all nodes
- **Port**: 9100
- **Metrics**: CPU, memory, disk, network

### 5. **Kube State Metrics**
- **Purpose**: Kubernetes object metrics
- **Deployment**: Deployment (1 replica)
- **Metrics**: Pod status, deployments, HPAs, nodes

## Quick Start

### Deploy Monitoring Stack
```powershell
# Navigate to scripts directory
cd d:\temp\kubecon-na-booth-demo\llm-demo\scripts

# Deploy Prometheus + Grafana (takes 3-5 minutes)
.\deploy-monitoring.ps1

# Import custom dashboards
.\import-dashboards.ps1
```

### Access Grafana
```powershell
# Get Grafana URL
kubectl get svc -n monitoring monitoring-grafana

# Or use port-forward
kubectl port-forward -n monitoring svc/monitoring-grafana 3000:80

# Open: http://localhost:3000
# Login: admin / admin123!
```

## Pre-Configured Dashboards

### 1. **GPU Monitoring - LLM Platform**
Custom dashboard showing:
- GPU utilization % per GPU
- GPU memory used/free (MB)
- GPU temperature (°C)
- GPU power usage (watts)
- GPU memory utilization %
- Active Ollama pods
- Ollama pod CPU usage

**Location**: Dashboards → GPU Monitoring → GPU Monitoring - LLM Platform

### 2. **LLM Platform Overview**
Comprehensive platform health:
- Pod counts (Ollama, Open-WebUI, Nodes)
- Total GPU memory used
- Average GPU utilization
- Pod replica status (desired vs available)
- CPU usage by component
- Memory usage by component
- GPU utilization per node
- GPU memory distribution

**Location**: Dashboards → LLM Platform → LLM Platform Overview

### 3. **Kubernetes Cluster** (Pre-imported, ID: 15398)
General cluster health:
- Cluster capacity
- Pod status
- Resource utilization
- Network I/O

**Location**: Dashboards → Kubernetes Cluster

### 4. **Node Exporter Full** (Pre-imported, ID: 1860)
Detailed node metrics:
- CPU usage per node
- Memory usage per node
- Disk I/O
- Network traffic

**Location**: Dashboards → Node Exporter Full

### 5. **NVIDIA DCGM Exporter** (Pre-imported, ID: 12239)
Detailed GPU metrics:
- All GPU statistics
- Multi-GPU comparison
- Historical trends

**Location**: Dashboards → NVIDIA DCGM Exporter

## Key Metrics Reference

### GPU Metrics (DCGM)
| Metric | Description | Unit | Normal Range |
|--------|-------------|------|--------------|
| `DCGM_FI_DEV_GPU_UTIL` | GPU utilization | percent | 0-100% |
| `DCGM_FI_DEV_FB_USED` | GPU memory used | bytes | 0-16GB (T4) |
| `DCGM_FI_DEV_FB_FREE` | GPU memory free | bytes | 0-16GB |
| `DCGM_FI_DEV_GPU_TEMP` | GPU temperature | celsius | 30-85°C |
| `DCGM_FI_DEV_POWER_USAGE` | Power consumption | watts | 50-250W |
| `DCGM_FI_DEV_MEM_CLOCK` | Memory clock | MHz | varies |
| `DCGM_FI_DEV_SM_CLOCK` | SM clock | MHz | varies |

### Kubernetes Metrics
| Metric | Description | Unit |
|--------|-------------|------|
| `kube_pod_status_phase` | Pod phase status | enum |
| `kube_deployment_status_replicas` | Desired replicas | count |
| `kube_deployment_status_replicas_available` | Available replicas | count |
| `container_cpu_usage_seconds_total` | CPU usage | seconds |
| `container_memory_working_set_bytes` | Memory usage | bytes |

### PromQL Examples

**Average GPU utilization:**
```promql
avg(DCGM_FI_DEV_GPU_UTIL)
```

**GPU memory utilization percentage:**
```promql
(DCGM_FI_DEV_FB_USED / DCGM_FI_DEV_FB_TOTAL) * 100
```

**Ollama pod count:**
```promql
count(kube_pod_status_phase{namespace="ollama",pod=~"ollama-.*",phase="Running"})
```

**CPU usage rate (5min average):**
```promql
rate(container_cpu_usage_seconds_total{namespace="ollama",pod=~"ollama-.*"}[5m])
```

**HPA current replicas:**
```promql
kube_horizontalpodautoscaler_status_current_replicas{namespace="ollama"}
```

## Demo Workflow

### Scenario: Show Autoscaling with Monitoring

1. **Baseline Metrics**
   ```powershell
   # Open Grafana dashboard
   # Navigate to: LLM Platform Overview
   # Note baseline: 2 Ollama pods, 3 WebUI pods, ~20% GPU utilization
   ```

2. **Generate Load**
   ```powershell
   # Run load test
   cd d:\temp\kubecon-na-booth-demo\llm-demo\scripts
   .\test-scaling.ps1 -LoadTest
   ```

3. **Watch Metrics in Real-Time**
   - GPU utilization spikes: 20% → 70%+
   - CPU usage increases
   - HPA triggers scale-up
   - Pod count increases: 2 → 3 → 4
   - GPU memory per pod decreases (load distribution)

4. **Post-Load Stabilization**
   - Load stops
   - Metrics normalize
   - HPA scales down (after 10 min stabilization)
   - Pods return to baseline

### Scenario: Model Switching Visualization

1. **Check Initial State**
   - Open: GPU Monitoring dashboard
   - Note GPU memory usage (~4GB for small model)

2. **Load Large Model**
   ```powershell
   kubectl exec -n ollama <pod-name> -- curl -X POST http://localhost:11434/api/pull -d '{"name":"gpt-oss"}'
   ```

3. **Watch GPU Memory**
   - GPU memory increases: 4GB → 17GB
   - Temperature increases
   - Power usage increases
   - HPA may trigger scale-up if threshold exceeded

4. **Cluster Autoscaler (if configured)**
   - If GPU memory exhausted, new node provisions
   - Watch node count increase in dashboard
   - Pod schedules on new node

## Alerting (Optional)

Alertmanager is included for alert routing. To configure alerts:

### 1. Create PrometheusRule
```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: llm-platform-alerts
  namespace: monitoring
spec:
  groups:
    - name: gpu
      interval: 30s
      rules:
        - alert: HighGPUTemperature
          expr: DCGM_FI_DEV_GPU_TEMP > 85
          for: 5m
          labels:
            severity: warning
          annotations:
            summary: "High GPU temperature detected"
            description: "GPU {{$labels.gpu}} on {{$labels.kubernetes_node}} is at {{$value}}°C"

        - alert: GPUMemoryHigh
          expr: (DCGM_FI_DEV_FB_USED / DCGM_FI_DEV_FB_TOTAL) > 0.90
          for: 5m
          labels:
            severity: warning
          annotations:
            summary: "GPU memory critically high"
            description: "GPU {{$labels.gpu}} memory usage is {{$value | humanizePercentage}}"
```

### 2. Configure Alertmanager
```yaml
# alertmanager-config.yaml
global:
  resolve_timeout: 5m

route:
  group_by: ['alertname']
  receiver: 'default'

receivers:
  - name: 'default'
    webhook_configs:
      - url: 'http://your-webhook-url'
```

## Troubleshooting

### Grafana Not Accessible

**Check LoadBalancer status:**
```powershell
kubectl get svc -n monitoring monitoring-grafana
```

**Use port-forward:**
```powershell
kubectl port-forward -n monitoring svc/monitoring-grafana 3000:80
# Access: http://localhost:3000
```

### No GPU Metrics

**Check DCGM exporter pods:**
```powershell
kubectl get pods -n ollama -l app.kubernetes.io/name=dcgm-exporter
kubectl logs -n ollama -l app.kubernetes.io/name=dcgm-exporter
```

**Verify ServiceMonitor:**
```powershell
kubectl get servicemonitor -n monitoring dcgm-exporter -o yaml
```

**Check Prometheus targets:**
```powershell
kubectl port-forward -n monitoring svc/monitoring-kube-prometheus-prometheus 9090:9090
# Open: http://localhost:9090/targets
# Find: dcgm-exporter (should be UP)
```

### Dashboards Not Loading

**Check Prometheus data source:**
1. Open Grafana
2. Configuration → Data Sources
3. Verify "Prometheus" is set as default
4. Test connection

**Reimport dashboards:**
```powershell
cd d:\temp\kubecon-na-booth-demo\llm-demo\scripts
.\import-dashboards.ps1
```

### High Memory Usage (Prometheus)

**Reduce retention period:**
```powershell
# Edit prometheus-values.yaml
# Change: retention: 7d → retention: 3d

# Upgrade Helm release
helm upgrade monitoring prometheus-community/kube-prometheus-stack `
  --namespace monitoring `
  --values prometheus-values.yaml
```

### Missing Metrics

**Check scrape targets:**
```powershell
# Port-forward Prometheus
kubectl port-forward -n monitoring svc/monitoring-kube-prometheus-prometheus 9090:9090

# Open: http://localhost:9090/targets
# Verify all targets are UP
```

**Check ServiceMonitor labels:**
```powershell
# Prometheus must discover ServiceMonitors
kubectl get servicemonitors -n monitoring
```

## Advanced: Custom Metrics

### Add Ollama-Specific Metrics

To add custom metrics (e.g., model load time, inference latency):

1. **Option A: Instrument Ollama** (requires code changes)
   - Add Prometheus client library to Ollama
   - Expose `/metrics` endpoint
   - Update ServiceMonitor

2. **Option B: Sidecar Exporter** (no Ollama changes)
   - Deploy Python sidecar container
   - Parse Ollama logs
   - Expose custom metrics

Example sidecar exporter (simplified):
```python
from prometheus_client import start_http_server, Counter, Histogram
import time

# Define metrics
model_loads = Counter('ollama_model_loads_total', 'Total model loads', ['model'])
inference_duration = Histogram('ollama_inference_duration_seconds', 'Inference duration', ['model'])

# Parse logs and update metrics
# ... (implementation)

if __name__ == '__main__':
    start_http_server(8000)  # Expose metrics on :8000/metrics
    # ... (log parsing logic)
```

### Integration with Azure Monitor

For hybrid monitoring (Prometheus + Azure Monitor):

```powershell
# Enable Container Insights (already enabled in AKS deployment)
# View in Azure Portal → AKS → Insights

# Query with Azure Monitor
# Kusto Query Language (KQL):
# ContainerGpuInventory
# | where TimeGenerated > ago(1h)
# | summarize avg(GpuUtilization) by bin(TimeGenerated, 5m)
```

## Cost Considerations

**Prometheus + Grafana Stack:**
- Storage: ~20GB (Prometheus) + 10GB (Grafana) = 30GB
- Azure Disk Premium: ~$5/month
- LoadBalancer: ~$0.005/hour = ~$3.65/month
- **Total**: ~$9/month

**Alternative (Azure Monitor):**
- Log Analytics: $2.76/GB ingested
- Estimated: 10GB/month = ~$28/month
- More expensive but managed service

**Recommendation**: Use Prometheus + Grafana for demos (lower cost, more flexible)

## Cleanup

To remove monitoring stack:
```powershell
# Remove Helm release
helm uninstall monitoring -n monitoring

# Delete namespace
kubectl delete namespace monitoring

# Delete PVCs (if needed)
kubectl delete pvc -n monitoring --all
```

## Resources

- **Prometheus**: https://prometheus.io/docs/
- **Grafana**: https://grafana.com/docs/
- **DCGM Exporter**: https://github.com/NVIDIA/dcgm-exporter
- **Grafana Dashboards**: https://grafana.com/grafana/dashboards/
- **PromQL**: https://prometheus.io/docs/prometheus/latest/querying/basics/

## Summary

This monitoring solution provides:
- ✅ Real-time GPU metrics (utilization, memory, temperature)
- ✅ Application metrics (pod status, CPU, memory)
- ✅ Infrastructure metrics (nodes, deployments, HPAs)
- ✅ Pre-configured dashboards (5 dashboards ready to use)
- ✅ Alerting capabilities (Alertmanager included)
- ✅ 7-day metric retention (adjustable)
- ✅ External access (LoadBalancer for Grafana)
- ✅ Cost-effective (~$9/month)

**Perfect for KubeCon demos** showing enterprise-grade LLM platform observability!
