# P0 Features - Quick Reference Card

**KubeCon NA Booth Demo - Enhanced Features**

---

## 🚀 Feature #1: Multi-Model Support

### Quick Commands

```powershell
# Deploy with 4 models (automatic in deploy.ps1)
.\scripts\deploy.ps1 -Prefix "demo" -Location "westus2" -HuggingFaceToken "hf_xxx" -AutoApprove

# Add models to existing deployment
.\scripts\preload-multi-models.ps1

# List models
kubectl exec -n ollama ollama-0 -- ollama list

# Check storage usage
kubectl exec -n ollama ollama-0 -- df -h /root/.ollama
```

### Models Included

| Model | Size | Use Case |
|-------|------|----------|
| **phi3.5** | 2.3 GB | Microsoft's compact, efficient model |
| **llama3.1:8b** | 4.7 GB | Meta's instruction-tuned, versatile |
| **mistral:7b** | 4.1 GB | Strong general-purpose performance |
| **gemma2:2b** | 1.6 GB | Google's smallest, fastest model |

**Total:** ~12.7 GB on Azure Files (stored once, shared by all)

### Demo Talking Points

- ✅ "All 4 models stored once on Azure Files"
- ✅ "No duplication = lower storage costs"
- ✅ "Instant availability when scaling"
- ✅ "Switch models in UI without re-downloading"

---

## 📊 Feature #2: Horizontal Scaling

### Quick Commands

```powershell
# Scale to 3 replicas
.\scripts\scale-ollama.ps1

# Scale to 5 replicas with details
.\scripts\scale-ollama.ps1 -Replicas 5 -ShowDetails

# Scale back to 1
.\scripts\scale-ollama.ps1 -Replicas 1

# Check pod status
kubectl get pods -n ollama -o wide

# Verify shared storage
kubectl exec -n ollama ollama-0 -- ollama list
kubectl exec -n ollama ollama-1 -- ollama list
kubectl exec -n ollama ollama-2 -- ollama list
```

### Demo Flow (2-3 minutes)

1. **Start:** Show current 1 pod
   ```powershell
   kubectl get pods -n ollama
   ```

2. **Scale:** Run scaling script
   ```powershell
   .\scripts\scale-ollama.ps1 -Replicas 3 -ShowDetails
   ```

3. **Verify:** Show 3 pods, same models
   ```powershell
   kubectl get pods -n ollama -o wide
   kubectl exec -n ollama ollama-0 -- ollama list
   kubectl exec -n ollama ollama-1 -- ollama list
   kubectl exec -n ollama ollama-2 -- ollama list
   ```

4. **Explain:** Azure Files ReadWriteMany
   - All 3 pods mount same volume
   - No storage duplication
   - No synchronization needed

### Demo Talking Points

- ✅ "Scale from 1 to 3 pods in under 3 minutes"
- ✅ "All pods share ONE Azure Files volume (ReadWriteMany)"
- ✅ "No data replication = instant scalability"
- ✅ "3x inference capacity, same storage cost"

---

## 🎯 Demo Sequence (Integrated)

### [0:00-2:00] Setup
- Show Azure Portal (resources deployed)
- Show Open-WebUI (logged in)

### [2:00-4:00] Multi-Model Demo
```powershell
# Show 4 models
kubectl exec -n ollama ollama-0 -- ollama list

# Demo in WebUI
# - Open model selector
# - Show 4 models available
# - Test inference with 2 different models
```

**Say:** "All 4 models stored once on Azure Files. No duplication. Switch instantly."

### [4:00-6:00] Inference Test
- Send prompts to different models
- Show response times
- Highlight GPU acceleration

### [6:00-8:00] Persistence Demo
```powershell
# Delete pod
kubectl delete pod ollama-0 -n ollama

# Watch it restart
kubectl get pods -n ollama -w

# Verify models still there
kubectl exec -n ollama ollama-0 -- ollama list
```

**Say:** "Pod restarted in seconds. Models still there. No re-download."

### [8:00-10:00] Horizontal Scaling Demo
```powershell
# Scale to 3
.\scripts\scale-ollama.ps1 -Replicas 3 -ShowDetails

# Show pods
kubectl get pods -n ollama -o wide

# Verify shared access
kubectl exec -n ollama ollama-0 -- ollama list
kubectl exec -n ollama ollama-1 -- ollama list
kubectl exec -n ollama ollama-2 -- ollama list
```

**Say:** "Three pods, one storage volume. That's ReadWriteMany. 3x capacity, same cost."

---

## 🔧 Troubleshooting

### Multi-Model Issues

**Problem:** Model download fails
```powershell
# Check pod logs
kubectl logs -n ollama ollama-0 -f

# Check storage space
kubectl exec -n ollama ollama-0 -- df -h /root/.ollama

# Re-run preload (idempotent)
.\scripts\preload-multi-models.ps1
```

**Problem:** Model not in WebUI
```powershell
# Restart WebUI pod
kubectl delete pod -n ollama -l app=open-webui

# Clear browser cache
# Ctrl+Shift+R (hard refresh)
```

### Scaling Issues

**Problem:** Pods stuck in Pending
```powershell
# Check GPU availability
kubectl get nodes -l agentpool=gpu

# Check GPU allocation
kubectl describe nodes -l agentpool=gpu | Select-String -Pattern "nvidia.com/gpu"

# Scale down if insufficient GPUs
.\scripts\scale-ollama.ps1 -Replicas 1
```

**Problem:** Pods not Ready
```powershell
# Check pod events
kubectl describe pod -n ollama ollama-1

# Check logs
kubectl logs -n ollama ollama-1 -f

# Check PVC binding
kubectl get pvc -n ollama
```

---

## 📋 Testing Checklist

### Before KubeCon
- [ ] Run full deployment with multi-model preload
- [ ] Verify all 4 models in WebUI
- [ ] Test scaling to 3 replicas
- [ ] Verify all 3 pods access same models
- [ ] Practice demo flow 2-3 times
- [ ] Time each section (should fit in 10 minutes)
- [ ] Prepare fallback (single model, no scaling) if issues

### At KubeCon Booth
- [ ] Deploy before booth opens
- [ ] Keep Terminal + Portal + WebUI open
- [ ] Have cleanup.ps1 ready for quick resets
- [ ] Memorize key talking points
- [ ] Test scaling once before first visitor

---

## 🎤 Elevator Pitch (30 seconds)

> "This is a production-ready LLM deployment on Azure Kubernetes Service. We're running 4 different AI models—totaling 13GB—all stored once on Azure Files Premium. Watch as I scale from 1 pod to 3 pods in real-time. All three pods instantly access the same models with no storage duplication. That's the power of ReadWriteMany. Scale up for peak demand, scale down to save costs—Azure Files makes it seamless."

---

## 📞 Emergency Contacts

**If Demo Breaks:**
1. Run `.\scripts\cleanup.ps1 -AutoApprove`
2. Run `.\scripts\deploy.ps1 -Prefix "backup" -AutoApprove`
3. Wait 12-15 minutes
4. Resume demo

**Fallback Script:**
- Show single model (llama3.1:8b)
- Skip scaling demo
- Focus on persistence (pod restart)
- Explain ReadWriteMany verbally

---

## 📚 Resources

- **README.md** - Full technical documentation
- **DEMOGUIDE.md** - Detailed presenter script
- **ENHANCEMENTS.md** - P0 feature implementation details
- **scripts/validate.ps1** - Health check utility

---

**Last Updated:** January 25, 2025  
**Demo Version:** v2.0 (Multi-Model + Scaling)
