# KubeCon NA 2025 - Booth Demo Guide

**5-10 Minute Presenter Script for Azure Files + AKS LLM Demo**

---

## Pre-Demo Setup (Before KubeCon)

### 1. Deploy Infrastructure
```powershell
cd d:\temp\kubecon-na-booth-demo\llm-demo
.\scripts\deploy.ps1 -Prefix "kubecon" -Location "westus2" -HuggingFaceToken "hf_xxxxx" -AutoApprove
```

### 2. Verify Deployment
```powershell
# Check all pods are running
kubectl get pods -n ollama

# Verify model is loaded
kubectl exec -n ollama ollama-0 -- ollama list

# Get WebUI URL
kubectl get svc open-webui -n ollama -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
```

### 3. Create Demo Account
- Open WebUI URL in browser
- Create account: `demo@kubecon.com` / `KubeCon2025!`
- Test a quick query to warm up the model

### 4. Pre-open Browser Tabs
- **Tab 1:** Azure Portal → Resource Group
- **Tab 2:** Open-WebUI (logged in)
- **Tab 3:** Terminal with kubectl context set

---

## Demo Flow (5-10 Minutes)

### [0:00-1:00] Introduction

**Say:**
> "Hi! I'm from the Azure Files team. Today I'll show you how Azure Files powers AI workloads on Azure Kubernetes Service. We're running Llama-3.1—an 8 billion parameter model—entirely on AKS with GPU acceleration and Azure Files Premium storage."

**Do:**
- Open Azure Portal → Navigate to resource group
- Quick scan of deployed resources (AKS, Key Vault, Storage)

---

### [1:00-3:00] Azure Files Storage Integration

**Say:**
> "The key to running LLMs on Kubernetes is persistent, high-performance storage. Let me show you our setup."

**Do:**

#### 1. Show Storage in Portal
```
Azure Portal → Resource Group → Storage Account → File Shares
```
- Point out Premium Files share (100GB for models)
- **Explain:** "Premium tier gives us high IOPS and low latency for fast model loading"

#### 2. Show Kubernetes Storage
```powershell
kubectl get pvc -n ollama
kubectl describe pvc ollama-models-pvc -n ollama
```

**Highlight:**
- `StorageClass: azurefile-premium-llm`
- `Access Mode: ReadWriteMany` ← **Key feature!**
- `Status: Bound`

**Say:**
> "Notice the `ReadWriteMany` access mode. This means multiple pods can mount the same file share simultaneously. If we scale our LLM service to handle more traffic, all replicas share the same model data—no duplication, no synchronization complexity."

---

### [3:00-5:00] Running the LLM

**Say:**
> "Now let's see the LLM in action. Our Ollama server is running on a GPU node with the model stored on Azure Files."

**Do:**

#### 1. Show Pod Running on GPU Node
```powershell
kubectl get pods -n ollama -o wide
```

**Point out:** Pod is scheduled on GPU node (aks-gpu-xxxxx)

#### 2. Check Loaded Models
```powershell
kubectl exec -n ollama ollama-0 -- ollama list
```

**Say:**
> "We've pre-loaded 4 different models on this deployment:
> - **phi3.5** (2.3GB) - Microsoft's latest compact model
> - **llama3.1:8b** (4.7GB) - Meta's popular instruction-tuned model
> - **mistral:7b** (4.1GB) - Strong general-purpose model
> - **gemma2:2b** (1.6GB) - Google's efficient small model
> 
> That's about 13GB of models, all stored once on Azure Files and instantly available to all pods. No duplication, no synchronization—just efficient shared storage."

**Do (Optional - Show in WebUI):**
- Click model selector dropdown
- Show all 4 models available
- Briefly explain each model's use case

#### 3. Show Storage Mount
```powershell
kubectl describe pod ollama-0 -n ollama | Select-String -Pattern "Volumes:" -Context 0,10
```

**Highlight:** Volume mount from Azure Files PVC to `/root/.ollama`

---

### [5:00-7:00] Live Inference Demo

**Say:**
> "Let's chat with the model through our web interface."

**Do:**

#### 1. Switch to Open-WebUI Browser Tab
- Already logged in with demo account

#### 2. Send a Prompt
```
"Explain how Azure Files CSI driver works in Kubernetes in 2 sentences."
```

#### 3. While Waiting for Response (GPU processing)

**Say:**
> "Behind the scenes, the GPU is processing this request. The model weights are being read from Azure Files Premium storage, which provides consistent low-latency access. The CSI driver handles all the mounting and lifecycle management automatically."

#### 4. Show Response

**Say:**
> "There's our answer! This entire interaction—from web UI to LLM to GPU inference—is running on AKS with Azure Files providing the persistent storage layer. The user experience is seamless, and operationally, we get all the benefits of managed Kubernetes storage."

---

### [7:00-9:00] Storage Benefits & Resilience

**Say:**
> "Let me demonstrate why Azure Files matters for production AI workloads."

**Do:**

#### 1. Show Pod Resilience
```powershell
# Delete the Ollama pod
kubectl delete pod ollama-0 -n ollama

# Watch it recreate (StatefulSet controller)
kubectl get pods -n ollama -w
```

**Say:**
> "I just deleted the pod. Watch it restart... and it's back! The model is still on Azure Files, so there's no re-download. In production, this means:
> - Faster recovery (seconds, not minutes)
> - Lower bandwidth costs (no repeated 4.7GB downloads)
> - Better reliability (persistent state across failures)"

#### 2. Wait for Pod Ready
```powershell
kubectl wait --for=condition=ready pod/ollama-0 -n ollama --timeout=60s
```

#### 3. Verify Model Still Available
```powershell
kubectl exec -n ollama ollama-0 -- ollama list
```

**Say:**
> "See? The model is immediately available. No initialization delay."

---

### [9:00-10:00] Horizontal Scaling Demo (BONUS)

**Say:**
> "Now let me show you the real power of Azure Files ReadWriteMany. We're going to scale this from 1 pod to 3 pods—all sharing the same model storage."

**Do:**

#### 1. Run the Scaling Script
```powershell
.\scripts\scale-ollama.ps1 -Replicas 3 -ShowDetails
```

**Say while running:**
> "Watch this. The script is scaling our StatefulSet to 3 replicas. All 3 pods will mount the SAME Azure Files share. No storage duplication, no synchronization—just instant access to all models."

#### 2. Show Pod Distribution
```powershell
kubectl get pods -n ollama -o wide
```

**Say:**
> "See? We now have 3 Ollama pods, potentially distributed across different nodes. Each pod has its own GPU, but they all share the same model storage. This means:
> - 3x inference capacity
> - Same storage costs (no duplication)
> - No model synchronization overhead
> - Zero setup time for new pods"

#### 3. Verify Shared Storage
```powershell
kubectl exec -n ollama ollama-0 -- ollama list
kubectl exec -n ollama ollama-1 -- ollama list
kubectl exec -n ollama ollama-2 -- ollama list
```

**Say:**
> "All three pods see the same 4 models instantly. That's the power of ReadWriteMany—true shared storage for AI workloads."

#### 4. Test Load Balancing (If Time)
```powershell
# Get service IP
$svcIP = kubectl get svc ollama -n ollama -o jsonpath='{.spec.clusterIP}'

# Send a few requests
for ($i=1; $i -le 3; $i++) {
    Write-Host "Request $i to $svcIP..."
    kubectl run curl-test-$i --rm -i --restart=Never --image=curlimages/curl -- curl -s http://ollama.ollama.svc.cluster.local:11434/api/tags
}
```

**Say:**
> "The Kubernetes service is load balancing across all 3 pods. Each can handle inference requests independently, but they're all working from the same model library."

#### 5. Scale Back (Optional)
```powershell
.\scripts\scale-ollama.ps1 -Replicas 1
```

**Say:**
> "And we can scale back down just as easily. This elasticity is crucial for AI workloads with variable demand—scale up for peak hours, scale down to save costs."

---

### [10:00] Architecture & Wrap-Up
```
Azure Portal → Storage Account → Monitoring → Metrics
- Transaction count
- Ingress
- Success E2E Latency
```

**Explain:** "During model loading, we see high throughput. During inference, latency stays consistently low."

---

### [10:00] Wrap-Up & Questions

**Say:**
> "To summarize what you've seen:
> - ✅ **Production LLM on AKS:** Llama-3.1-8B running on GPU-accelerated nodes
> - ✅ **Azure Files Premium:** High-performance, persistent storage for 4.7GB model
> - ✅ **Native Kubernetes:** Standard CSI driver, no custom controllers
> - ✅ **Scalable:** ReadWriteMany enables horizontal scaling
> - ✅ **Resilient:** Models persist across pod restarts, no re-downloads
>
> This is production-ready today. The entire deployment is automated—12-15 minutes from zero to running LLM. All the code is open source in our GitHub repo."

**Show:**
- GitHub repo link (if available)
- Contact info / team booth location

**Ask:**
> "Any questions about Azure Files, AKS, or running AI/ML workloads on Kubernetes?"

---

## Quick Commands Reference

### Check Deployment Status
```powershell
kubectl get all -n ollama
kubectl get pvc -n ollama
kubectl get nodes -l agentpool=gpu -o wide
```

### Verify Model
```powershell
kubectl exec -n ollama ollama-0 -- ollama list
kubectl exec -n ollama ollama-0 -- df -h | Select-String ollama
```

### Check GPU
```powershell
kubectl exec -n ollama ollama-0 -- nvidia-smi
kubectl get nodes -l agentpool=gpu -o custom-columns=NAME:.metadata.name,GPU:.status.capacity."nvidia\.com/gpu"
```

### Get Service URL
```powershell
kubectl get svc open-webui -n ollama -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
```

---

## Troubleshooting During Demo

### Pod Not Ready
```powershell
kubectl describe pod ollama-0 -n ollama
kubectl logs ollama-0 -n ollama --tail=50
```

**Common issues:**
- GPU not available → Check NVIDIA plugin: `kubectl get pods -n kube-system -l name=nvidia-device-plugin-ds`
- PVC not bound → Check storage: `kubectl describe pvc ollama-models-pvc -n ollama`

### Model Missing
```powershell
.\scripts\preload-model.ps1 -ModelName "llama3.1:8b" -Namespace "ollama"
```

### WebUI Slow/Unresponsive
```powershell
# Check GPU utilization
kubectl exec -n ollama ollama-0 -- nvidia-smi

# Restart WebUI pod
kubectl delete pod -l app=open-webui -n ollama
```

### Storage Mount Fails
```powershell
kubectl get pvc -n ollama
kubectl describe pvc ollama-models-pvc -n ollama
# Check Azure Portal → Storage Account → File Shares → Verify share exists
```

---

## Backup Plan (If Live Demo Fails)

1. **Show architecture diagram** (draw on whiteboard)
2. **Walk through code:**
   - Storage class manifest: `k8s\02-storage-premium.yaml`
   - Ollama StatefulSet: `k8s\05-ollama-statefulset.yaml`
3. **Discuss use cases:**
   - Fine-tuning workflows
   - Model versioning
   - Multi-model serving
4. **Show Azure Portal only:**
   - Resource group layout
   - Storage metrics
   - AKS cluster configuration

---

## Key Talking Points (Memorize These)

1. **Performance:** "Azure Files Premium delivers IOPS and latency comparable to local SSDs"
2. **Resilience:** "Model persists across pod restarts—no re-downloads, faster recovery"
3. **Scalability:** "ReadWriteMany allows horizontal scaling without storage complexity"
4. **Simplicity:** "Native Kubernetes experience via CSI driver—no custom controllers"
5. **Cost-Effective:** "Only pay for storage you use, no over-provisioning needed"
6. **Production-Ready:** "Running in production today for AI/ML workloads"

---

## Expected Questions & Answers

| **Question** | **Answer** |
|-------------|-----------|
| **"How fast is model loading?"** | "Llama-3.1-8B (4.7GB) loads in 8-12 seconds from cold start. Premium Files provides consistent low latency." |
| **"Can I use Standard Files?"** | "Yes, but Premium is recommended for latency-sensitive inference. Standard is great for training data." |
| **"What about NFS?"** | "Azure Files supports both SMB and NFS protocols. This demo uses SMB, but NFS works identically." |
| **"Does this work with Hugging Face?"** | "Absolutely! Just mount Azure Files and point `TRANSFORMERS_CACHE` or `HF_HOME` to the PVC path." |
| **"What's the cost?"** | "Azure Files Premium: ~$0.20/GB/month + transaction costs. For 100GB: ~$20/month storage + minimal transaction fees." |
| **"Can I use Azure NetApp Files instead?"** | "Yes! Azure NetApp Files offers even higher performance for ultra-low latency requirements. Choose based on your performance needs." |
| **"What if I need more IOPS?"** | "Scale up storage size (IOPS scale with capacity) or consider Azure NetApp Files for dedicated high-IOPS volumes." |
| **"Does this work with other AI frameworks?"** | "Yes—TensorFlow, PyTorch, JAX, etc. Any framework that reads model files benefits from persistent storage." |
| **"Can I run this on Azure Stack?"** | "Yes! Azure Files CSI driver works across Azure public cloud and Azure Stack HCI." |
| **"What about multi-region?"** | "Use Azure Storage replication (GRS/GZRS) for disaster recovery. For active-active, deploy separate clusters per region." |

---

## Success Metrics

After the demo, attendees should understand:
- ✅ Azure Files provides enterprise-grade persistent storage for AI workloads
- ✅ ReadWriteMany enables horizontal scaling of LLM services
- ✅ CSI driver integration is seamless (native Kubernetes experience)
- ✅ Deployment is automated and production-ready

**Call to Action:**
- Visit GitHub repo for full code
- Try it in your own subscription (12-15 minute deployment)
- Contact Azure Files team for architecture reviews

---

**Good luck at KubeCon! 🚀**
