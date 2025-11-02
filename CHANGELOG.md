# Recent Updates & Changes

## November 1, 2025

### 1. GPU-Based Autoscaling Implementation ✅

**What Changed:**
- Added Prometheus Adapter installation to `deploy.ps1` (lines 928-1038)
- Configured custom metrics API for GPU metrics (DCGM integration)
- Updated DCGM ServiceMonitor deployment (lines 1039-1074)

**Impact:**
- HPA can now autoscale based on GPU memory utilization
- Custom metrics API exposes: `gpu_utilization`, `gpu_memory_utilization`, `gpu_memory_used_bytes`, `gpu_memory_free_bytes`
- Ollama pods automatically scale when GPU memory usage exceeds 70%

**Configuration Details:**
- Uses `exported_namespace` and `exported_pod` labels from DCGM metrics
- Prometheus scrapes GPU metrics every 30 seconds
- HPA evaluates metrics every 15 seconds (default)

**Files Modified:**
- `scripts/deploy.ps1` - Added Prometheus Adapter installation
- `k8s/13-dcgm-servicemonitor.yaml` - Removed duplicate Service, kept only ServiceMonitor

**Verification:**
```powershell
# Check custom metrics API
kubectl get apiservices v1beta1.custom.metrics.k8s.io

# View available GPU metrics
kubectl get --raw /apis/custom.metrics.k8s.io/v1beta1 | ConvertFrom-Json |
  Select-Object -ExpandProperty resources | Where-Object { $_.name -like "*gpu*" }

# Check HPA status
kubectl get hpa -n ollama ollama-hpa
```

### 2. Model Access Control Configuration ✅

**What Changed:**
- Added `BYPASS_MODEL_ACCESS_CONTROL: "True"` to Open-WebUI deployment
- Works in conjunction with existing `ENABLE_MODEL_FILTER: "False"`

**Impact:**
- All users can access all models without restrictions
- No per-user model permissions required
- Simplified multi-user deployment

**Files Modified:**
- `k8s/07-webui-deployment.yaml` - Added environment variable (line 117)

**Verification:**
```powershell
# Check environment in running pods
kubectl exec -n ollama deployment/open-webui -- env | grep MODEL
```

### 3. Azure Policy Warning Handling ✅

**What Changed:**
- Enhanced Helm deployment error handling in `deploy.ps1`
- Detects Azure Policy warnings without treating them as failures
- Provides clear guidance on policy exemptions

**Impact:**
- Deployment succeeds even with Azure Policy audit warnings
- Users informed about policy issues without blocking deployment
- Optional policy exemption script available

**Files Modified:**
- `scripts/deploy.ps1` - Enhanced error handling for Helm operations

## Documentation Updates

### New Documents Created:
1. **PROMETHEUS-ADAPTER-IMPLEMENTATION.md** - Technical implementation details for GPU metrics
2. **DEPLOYMENT-INTEGRATION-SUMMARY.md** - Complete deployment flow and verification

### Updated Documents:
1. **README.md** - Added GPU autoscaling and model access control features
2. **AUTOSCALING.md** - Should be updated with GPU metrics details (if not already)

## Key Features Summary

| Feature | Status | Description |
|---------|--------|-------------|
| GPU Autoscaling | ✅ Active | HPA scales based on GPU memory utilization |
| Custom Metrics API | ✅ Active | Prometheus Adapter exposes GPU metrics |
| DCGM GPU Monitoring | ✅ Active | Real-time GPU metrics collection |
| Model Access Control | ✅ Bypassed | All users access all models |
| Azure Policy Handling | ✅ Active | Graceful handling of policy warnings |
| Multi-User Support | ✅ Active | 4 Open-WebUI replicas |
| Vector Search (RAG) | ✅ Active | PostgreSQL + PGVector |

## Deployment Status

### Current Configuration:
- **Ollama**: 2 replicas (StatefulSet)
- **Open-WebUI**: 4 replicas (Deployment)
- **Prometheus Adapter**: 1 replica (Deployment)
- **DCGM Exporter**: 2 pods (DaemonSet on GPU nodes)

### HPA Configuration:
- **Ollama HPA**:
  - Min: 2, Max: 5 replicas
  - Metrics: CPU (75%), Memory (80%), GPU Memory (70%)
  - Current: 2 replicas (GPU idle: 0%)

- **Open-WebUI HPA**:
  - Min: 3, Max: 10 replicas
  - Metrics: CPU (70%), Memory (80%)
  - Current: 4 replicas

## Known Issues & Solutions

### Issue: HPA shows `<unknown>` for GPU metrics
**Solution**: Wait 30-60 seconds after deployment for metrics to populate. Verify:
```powershell
kubectl get apiservices | Select-String custom
kubectl logs -n monitoring deployment/prometheus-adapter
```

### Issue: Azure Policy warnings during deployment
**Solution**: These are informational (audit mode). Use exemption script if needed:
```powershell
.\scripts\create-policy-exemption.ps1
```

### Issue: Models not visible to users
**Solution**: Both settings now configured:
- `ENABLE_MODEL_FILTER: "False"`
- `BYPASS_MODEL_ACCESS_CONTROL: "True"`

## Next Steps & Recommendations

1. **Test GPU Autoscaling**:
   ```powershell
   .\benchmarks\run-benchmarks.ps1
   kubectl get hpa -n ollama -w
   ```

2. **Monitor GPU Metrics**:
   - Access Grafana dashboard
   - Check GPU utilization trends
   - Adjust HPA thresholds if needed

3. **Review Costs**:
   - Monitor actual GPU usage
   - Consider reducing replicas during off-hours
   - Evaluate Spot instance savings

4. **Security Hardening** (Production):
   - Enable model access control for multi-tenant
   - Configure network policies
   - Enable Azure Policy compliance mode

## Quick Reference

### Useful Commands:
```powershell
# Check all component status
kubectl get pods -n ollama
kubectl get pods -n monitoring
kubectl get hpa -n ollama

# View GPU metrics
kubectl get --raw "/apis/custom.metrics.k8s.io/v1beta1/namespaces/ollama/pods/*/gpu_memory_utilization"

# Scale manually (override HPA)
kubectl scale statefulset ollama -n ollama --replicas=3

# View logs
kubectl logs -n ollama statefulset/ollama -f
kubectl logs -n ollama deployment/open-webui -f
```

### Service Endpoints:
- Open-WebUI: `http://<external-ip>` (from `kubectl get svc -n ollama open-webui`)
- Grafana: `http://<external-ip>` (from `kubectl get svc -n monitoring monitoring-grafana`)
- Default credentials: admin/prom-operator

---

**Last Updated**: November 1, 2025
**Version**: 1.2.0 - GPU Autoscaling + Model Access Updates
