# KubeCon NA 2025 - Azure AKS LLM Demo# KubeCon NA 2025 - Azure AKS LLM Demo# KubeCon NA 2025 - Azure AKS LLM Demo# Azure LLM Demo - KubeCon NA 2025# KubeCon NA 2025 - Azure AKS LLM Demo# KubeCon NA 2025 - LLM Demo on Azure AKS with GPU# KubeCon NA 2025 - Azure Files + AKS LLM Demo



**Production-ready deployment of Ollama + Open-WebUI on Azure Kubernetes Service with GPU acceleration**



## 🎯 Overview**Production-ready deployment of Ollama + Open-WebUI on Azure Kubernetes Service with GPU acceleration**



This demo showcases running Large Language Models (LLMs) on Azure Kubernetes Service with:



- **Ollama** - LLM inference server running on GPU## 🎯 Overview**Production-ready deployment of Ollama + Open-WebUI on Azure Kubernetes Service with GPU acceleration**

- **Open-WebUI** - Modern web interface for chat interactions

- **Azure Files Premium** - High-performance persistent storage for model weights

- **Azure Disk Premium** - Fast storage for SQLite database

- **Azure Key Vault** - Secure credential managementThis demo showcases running Large Language Models (LLMs) on Azure Kubernetes Service with:

- **AKS with GPU nodes** - NVIDIA Tesla T4 GPU-accelerated inference



**Key Benefits:**

- ✅ **Fast Model Loading:** Azure Files Premium delivers low-latency access to models- **Ollama** - LLM inference server running on GPU## 🎯 OverviewA production-ready deployment of Large Language Models on Azure Kubernetes Service, showcasing GPU acceleration, persistent storage, and enterprise features.

- ✅ **Persistent Storage:** Models survive pod restarts (no re-downloads)

- ✅ **Multi-Pod Scalability:** ReadWriteMany enables horizontal scaling- **Open-WebUI** - Modern web interface for chat interactions

- ✅ **Production-Ready:** Secure, monitored, and cost-effective

- **Azure Files Premium** - High-performance persistent storage for model weights

---

- **Azure Disk Premium** - Fast storage for SQLite database

## 📋 Prerequisites

- **Azure Key Vault** - Secure credential managementThis demo showcases running Large Language Models (LLMs) on Azure Kubernetes Service with:

### Required Tools

- **AKS with GPU nodes** - NVIDIA Tesla T4 GPU-accelerated inference

- **Azure CLI** (2.50.0+) - [Install](https://aka.ms/azure-cli)

- **kubectl** (1.28.0+) - [Install](https://kubernetes.io/docs/tasks/tools/)

- **PowerShell** 7.0+ or Windows PowerShell 5.1

**Key Benefits:**

### Azure Requirements

- ✅ **Fast Model Loading:** Azure Files Premium delivers low-latency access to models- **Ollama** - LLM inference server running on GPU## What This Demo Does**Production-ready deployment of Ollama + Open-WebUI on Azure Kubernetes Service with GPU acceleration**

- Active Azure subscription with Contributor or Owner role

- Sufficient quota in target region:- ✅ **Persistent Storage:** Models survive pod restarts (no re-downloads)

  - **Standard_NC8as_T4_v3** (GPU): 16 vCPUs (2 nodes × 8 vCPUs)

  - **Standard_D2s_v3** (System): 4 vCPUs (2 nodes × 2 vCPUs)- ✅ **Multi-Pod Scalability:** ReadWriteMany enables horizontal scaling- **Open-WebUI** - Modern web interface for chat interactions



### Check GPU Quota- ✅ **Production-Ready:** Secure, monitored, and cost-effective



```powershell- **Azure Files Premium** - High-performance persistent storage for model weights

# Check available GPU quota

az vm list-skus --location westus2 --size Standard_NC --all --output table | Select-String "NC8as_T4_v3"---



# Request quota increase if needed- **Azure Disk Premium** - Fast storage for SQLite database

# Portal → Subscriptions → Usage + quotas → Search "NCasT4v3"

```## 📋 Prerequisites



### HuggingFace Token (Optional)- **Azure Key Vault** - Secure credential managementThis solution deploys a complete AI inference platform on Azure:



Some models require authentication:### Required Tools

- Sign up at https://huggingface.co

- Create token at https://huggingface.co/settings/tokens- **AKS with GPU nodes** - NVIDIA Tesla T4 GPU-accelerated inference



---- **Azure CLI** (2.50.0+) - [Install](https://aka.ms/azure-cli)



## 🚀 Quick Start (15-20 minutes)- **kubectl** (1.28.0+) - [Install](https://kubernetes.io/docs/tasks/tools/)



### 1. Clone Repository- **PowerShell** 7.0+ or Windows PowerShell 5.1



```powershell**Key Benefits:**

cd d:\temp

git clone <repo-url>### Azure Requirements

cd kubecon-na-booth-demo\llm-demo

```- ✅ **Fast Model Loading:** Azure Files Premium delivers low-latency access to models- **Ollama** runs multiple open-source LLMs (Llama 3.1, Mistral, DeepSeek-R1, etc.) on GPU-accelerated AKS nodes---A complete, production-ready deployment of Ollama + Open-WebUI on Azure Kubernetes Service (AKS) with GPU acceleration.**Showcase: Running Large Language Models on Azure Kubernetes Service with Azure Files Premium Storage**



### 2. Deploy Infrastructure- Active Azure subscription with Contributor or Owner role



```powershell- Sufficient quota in target region:- ✅ **Persistent Storage:** Models survive pod restarts (no re-downloads)

# Deploy everything (AKS + GPU nodes + Storage + LLM + WebUI)

.\scripts\deploy.ps1 -Prefix "kubecon" -Location "westus2" -AutoApprove  - **Standard_NC8as_T4_v3** (GPU): 16 vCPUs (2 nodes × 8 vCPUs)



# Or with HuggingFace token for additional models  - **Standard_D2s_v3** (System): 4 vCPUs (2 nodes × 2 vCPUs)- ✅ **Multi-Pod Scalability:** ReadWriteMany enables horizontal scaling- **Open-WebUI** provides a modern chat interface with user authentication and approval workflows

.\scripts\deploy.ps1 -Prefix "kubecon" -Location "westus2" -HuggingFaceToken "hf_xxxxx" -AutoApprove

```



**What gets deployed:**### Check GPU Quota- ✅ **Production-Ready:** Secure, monitored, and cost-effective

- ✅ Resource Group: `kubecon-rg`

- ✅ AKS Cluster: `kubecon-aks` (K8s 1.31)

  - 2 system nodes (D2s_v3)

  - 2 GPU nodes (NC8as_T4_v3 with NVIDIA T4)```powershell- **Azure Files Premium** stores model weights with high-performance, shared access across pods

- ✅ Azure Key Vault: `kubecon-kv-xxxxxxx`

- ✅ Storage: Azure Files Premium + Azure Disk Premium# Check available GPU quota

- ✅ NVIDIA GPU drivers

- ✅ Ollama LLM server (ready to download models)az vm list-skus --location westus2 --size Standard_NC --all --output table | Select-String "NC8as_T4_v3"---

- ✅ Open-WebUI frontend



### 3. Access the WebUI

# Request quota increase if needed- **Azure Disk Premium** handles the SQLite database with fast local storage

After deployment completes (15-20 minutes), you'll see:

# Portal → Subscriptions → Usage + quotas → Search "NCasT4v3"

```

========================================```## 📋 Prerequisites

DEPLOYMENT SUMMARY

========================================

Open-WebUI URL    : http://20.x.x.x

### HuggingFace Token (Optional)- **Azure Key Vault** secures credentials and API tokens## 🎯 Overview

NEXT STEPS

========================================

1️⃣  Download Models (REQUIRED)

   .\scripts\preload-multi-models.ps1Some models require authentication:### Required Tools



2️⃣  Create Admin Account- Sign up at https://huggingface.co

   Open browser: http://20.x.x.x

========================================- Create token at https://huggingface.co/settings/tokens

```



**First-Time Setup:**

1. Open the URL in your browser---- **Azure CLI** (2.50.0+) - [Install](https://aka.ms/azure-cli)

2. Create admin account (first user becomes admin)

3. **Download models before chatting** (see next section)



---## 🚀 Quick Start (15-20 minutes)- **kubectl** (1.28.0+) - [Install](https://kubernetes.io/docs/tasks/tools/)Users can chat with different AI models through a web interface, with all infrastructure running on Kubernetes with proper security, monitoring, and scaling capabilities.



## 📦 Download Models



**IMPORTANT:** Models are NOT downloaded during deployment to keep it fast and reliable. After deployment completes, you need to download models before you can chat.### 1. Clone Repository- **PowerShell** 7.0+ or Windows PowerShell 5.1



### Quick Start - Download All Models



The easiest way is to download all 6 recommended models at once (~33.7 GB total):```powershell



```powershellcd d:\temp

.\scripts\preload-multi-models.ps1

```git clone <repo-url>### Azure Requirements



This will download:cd kubecon-na-booth-demo\llm-demo

- `phi3.5` (2.3 GB) - Fast, general purpose

- `llama3.1:8b` (4.7 GB) - Meta's latest, very capable```## PrerequisitesThis demo showcases running Large Language Models (LLMs) on Azure Kubernetes Service with:## 🎯 Overview---

- `mistral:7b` (4.1 GB) - Excellent reasoning

- `gemma2:2b` (1.6 GB) - Lightweight, fast

- `gpt-oss` (13 GB) - Advanced chat model

- `deepseek-r1` (8 GB) - Strong reasoning and math### 2. Deploy Infrastructure- Active Azure subscription with Contributor or Owner role



**Download time:** Approximately 15-20 minutes depending on network speed.



The script now includes diagnostics to help troubleshoot download failures:```powershell- Sufficient quota in target region:

- Internet connectivity check

- Disk space verification# Deploy everything (AKS + GPU nodes + Storage + LLM + WebUI)

- Ollama API health check

- Detailed error logging.\scripts\deploy.ps1 -Prefix "kubecon" -Location "westus2" -AutoApprove  - **Standard_NC8as_T4_v3** (GPU): 16 vCPUs (2 nodes × 8 vCPUs)



### Option 2 - Add Models Manually via UI



If you prefer to download specific models:# Or with HuggingFace token for additional models  - **Standard_D2s_v3** (System): 4 vCPUs (2 nodes × 2 vCPUs)You'll need:



1. Login to Open-WebUI as admin.\scripts\deploy.ps1 -Prefix "kubecon" -Location "westus2" -HuggingFaceToken "hf_xxxxx" -AutoApprove

2. Go to Settings → Models → Pull a model from Ollama.com

3. Enter model name from https://ollama.com/library (e.g., `llama3.1:8b`)```

4. Wait for download to complete before using



**Note:** Manual downloads through the UI may be slower than using the script.

**What gets deployed:**### Check GPU Quota

### Verify Models

- ✅ Resource Group: `kubecon-rg`

```powershell

# Check which models are downloaded- ✅ AKS Cluster: `kubecon-aks` (K8s 1.31)

kubectl exec -n ollama ollama-0 -- ollama list

  - 2 system nodes (D2s_v3)

# Check storage usage

kubectl exec -n ollama ollama-0 -- df -h /root/.ollama  - 2 GPU nodes (NC8as_T4_v3 with NVIDIA T4)```powershell- **Azure CLI** (version 2.50.0 or later) - [Installation guide](https://aka.ms/azure-cli)- **Ollama** - LLM inference server running Llama-3.1-8B (4.7GB model)

```

- ✅ Azure Key Vault: `kubecon-kv-xxxxxxx`

---

- ✅ Storage: Azure Files Premium + Azure Disk Premium# Check available GPU quota

## 🎭 Using the Demo

- ✅ NVIDIA GPU drivers

### For Administrators

- ✅ Ollama LLM server (ready to download models)az vm list-skus --location westus2 --size Standard_NC --all --output table | Select-String "NC8as_T4_v3"- **kubectl** (version 1.28.0 or later) - [Installation guide](https://kubernetes.io/docs/tasks/tools/)

Once logged in as admin, you can:

- ✅ Open-WebUI frontend

- **Approve new users**: Click your profile → Admin Panel → Users

- **Add more models**: Use the script or Settings → Models in the UI

- **Monitor activity**: See who's using the system and what models are popular

- **Manage settings**: Configure authentication, branding, and features### 3. Access the WebUI



### For Regular Users# Request quota increase if needed- **PowerShell** 7.0+ or Windows PowerShell 5.1- **Open-WebUI** - Modern chat interface for model interaction



After your account is approved:After deployment completes (15-20 minutes), you'll see:



1. Login with your email and password# Portal → Subscriptions → Usage + quotas → Search "NCasT4v3"

2. Select a model from the dropdown at the top

3. Type your question in the chat box```

4. The AI model will respond within seconds

5. Your conversations are saved in your personal history========================================```- **Azure subscription** with Contributor or Owner role



---DEPLOYMENT SUMMARY



## 🏗️ Architecture========================================



### InfrastructureOpen-WebUI URL    : http://20.x.x.x



```### HuggingFace Token (Optional)- **GPU quota** in your target region (16 vCPUs for Standard_NC8as_T4_v3)- **AKS with GPU nodes** - NVIDIA Tesla T4 GPU-accelerated inferenceThis solution deploys:## **Overview**

┌─────────────────────────────────────────────────────────┐

│ Azure Resource Group ({prefix}-rg)                      │Next Step - Download Models:

├─────────────────────────────────────────────────────────┤

│  ┌─────────────────────────────────────────────────┐   │  Run this command to download 6 models (~33.7 GB):

│  │ AKS Cluster ({prefix}-aks) - Kubernetes 1.31   │   │

│  ├─────────────────────────────────────────────────┤   │    .\scripts\preload-multi-models.ps1

│  │  System Node Pool (2x Standard_D2s_v3)         │   │

│  │  └─ System pods (CoreDNS, kube-proxy, etc.)    │   │========================================Some models require authentication:

│  │                                                  │   │

│  │  GPU Node Pool (2x Standard_NC8as_T4_v3)       │   │```

│  │  └─ Taint: sku=gpu:NoSchedule                  │   │

│  │  └─ NVIDIA T4 GPU (16GB VRAM each)             │   │- Sign up at https://huggingface.co

│  └─────────────────────────────────────────────────┘   │

│                                                          │**First-Time Setup:**

│  ┌─────────────────────────────────────────────────┐   │

│  │ Azure Key Vault ({prefix}-kv-xxxxxxx)          │   │1. Open the URL in your browser- Create token at https://huggingface.co/settings/tokensCheck your GPU quota:- **Azure Files Premium** - High-performance persistent storage for model weights

│  │ └─ Secure credential storage                    │   │

│  └─────────────────────────────────────────────────┘   │2. Create admin account (first user becomes admin)

│                                                          │

│  ┌─────────────────────────────────────────────────┐   │3. **Download models before chatting** (see next section)

│  │ Storage (Azure Files Premium + Azure Disk)      │   │

│  │ └─ CSI drivers (built into AKS)                 │   │

│  └─────────────────────────────────────────────────┘   │

└─────────────────────────────────────────────────────────┘------```powershell

```



### Storage Strategy

## 📦 Download Models

**Why Azure Files for Models:**

- Models are large (2-13GB each) and expensive to download

- ReadWriteMany allows multiple Ollama pods to share the same models

- Premium tier provides low-latency access for GPU inference**IMPORTANT:** Models are NOT downloaded during deployment to keep it fast and reliable. After deployment completes, you need to download models before you can chat.## 🚀 Quick Start (15-20 minutes)az vm list-skus --location westus2 --size Standard_NC --all --output table | Select-String "NC8as_T4_v3"- **Azure Disk Premium** - Fast storage for SQLite database- **AKS Cluster** with GPU-enabled nodes (NVIDIA Tesla T4)

- Models persist across pod restarts (no re-downloading)



**Why Azure Disk for Database:**

- SQLite requires local disk with exclusive access### Quick Start - Download All Models

- Premium SSD ensures fast queries and writes

- ReadWriteOnce is perfect for single-pod databases



---The easiest way is to download all 6 recommended models at once (~33.7 GB total):### 1. Clone Repository```



## 🛠️ Management Commands



### Check Status```powershell



```powershell.\scripts\preload-multi-models.ps1

# All resources

kubectl get all -n ollama``````powershell- **Azure Key Vault** - Secure credential management



# Pod status

kubectl get pods -n ollama -o wide

This will download:cd d:\temp

# Services and external IP

kubectl get svc -n ollama- `phi3.5` (2.3 GB) - Fast, general purpose



# Storage- `llama3.1:8b` (4.7 GB) - Meta's latest, very capablegit clone <repo-url>If you need more quota, go to Azure Portal → Subscriptions → Usage + quotas → Search for "NCasT4v3"

kubectl get pvc -n ollama

```- `mistral:7b` (4.1 GB) - Excellent reasoning



### View Logs- `gemma2:2b` (1.6 GB) - Lightweight, fastcd kubecon-na-booth-demo\llm-demo



```powershell- `gpt-oss` (13 GB) - Advanced chat model

# Ollama logs

kubectl logs -f -l app=ollama -n ollama- `deepseek-r1` (8 GB) - Strong reasoning and math```- **Ollama** - LLM inference server running on GPUThis demo demonstrates how Azure Files seamlessly integrates with AI/ML workloads on Azure Kubernetes Service (AKS). We deploy a production-ready LLM inference service using:



# Open-WebUI logs

kubectl logs -f -l app=open-webui -n ollama

```**Download time:** Approximately 15-20 minutes depending on network speed.



### Model Management



```powershell### Option 2 - Add Models Manually via UI### 2. Deploy Infrastructure### Optional: HuggingFace Token

# List installed models

kubectl exec -n ollama ollama-0 -- ollama list



# Test a modelIf you prefer to download specific models:

kubectl exec -n ollama ollama-0 -- ollama run llama3.1:8b "Hello!"



# Pull a specific model

kubectl exec -n ollama ollama-0 -- ollama pull <model-name>1. Login to Open-WebUI as admin```powershell**Key Benefits:**



# Remove a model2. Go to Settings → Models → Pull a model from Ollama.com

kubectl exec -n ollama ollama-0 -- ollama rm <model-name>

```3. Enter model name from https://ollama.com/library (e.g., `llama3.1:8b`)# Deploy everything (AKS + GPU nodes + Storage + LLM + WebUI)



### Scaling4. Wait for download to complete before using



```powershell.\scripts\deploy.ps1 -Prefix "kubecon" -Location "westus2" -AutoApproveSome models require authentication. Create a free token at:

# Scale Ollama pods (share same models via Azure Files)

.\scripts\scale-ollama.ps1 -Replicas 3**Note:** Manual downloads through the UI may be slower than using the script.

```



---

### Verify Models

## 🐛 Troubleshooting

# Or with HuggingFace token for additional models- Sign up: https://huggingface.co- ✅ **Fast Model Loading:** Azure Files Premium delivers low-latency access to models- **Open-WebUI** - Modern web interface for chat interactions

### "I don't see the Sign Up button"

```powershell

This is a known issue with Open-WebUI where the signup form doesn't appear even when enabled.

# Check which models are downloaded.\scripts\deploy.ps1 -Prefix "kubecon" -Location "westus2" -HuggingFaceToken "hf_xxxxx" -AutoApprove

**Solution - Create admin via API:**

kubectl exec -n ollama ollama-0 -- ollama list

```powershell

.\scripts\create-admin.ps1 -Email "admin@company.com" -Password "SecurePass123!"```- Generate token: https://huggingface.co/settings/tokens

```

# Check storage usage

This script creates the admin account directly via the Open-WebUI API, bypassing the UI signup form.

kubectl exec -n ollama ollama-0 -- df -h /root/.ollama

### "Models are downloading slowly or failing"

```

The `preload-multi-models.ps1` script now includes diagnostics:

**What gets deployed:**- ✅ **Persistent Storage:** Models survive pod restarts (no re-downloads)

1. **Internet connectivity check** - Verifies pod can reach ollama registry

2. **Disk space check** - Shows available storage---

3. **API health check** - Confirms Ollama service is responding

4. **Detailed error logs** - Captures stdout/stderr for debugging- ✅ Resource Group: `kubecon-rg`



Common issues:## 🎭 Using the Demo

- Network policies blocking outbound traffic to `registry.ollama.ai`

- Insufficient disk space on Azure Files Premium share- ✅ AKS Cluster: `kubecon-aks` (K8s 1.31)## Quick Start

- Ollama service not fully initialized (wait 30 seconds after pod ready)

### For Administrators

Check logs:

  - 2 system nodes (D2s_v3)

```powershell

kubectl logs -n ollama -l app=ollama --followOnce logged in as admin, you can:

```

  - 2 GPU nodes (NC8as_T4_v3 with NVIDIA T4)- ✅ **Multi-Pod Scalability:** ReadWriteMany enables horizontal scaling- **Azure Files** - Premium storage for model persistence- **Ollama** - LLM server running Llama-3.1-8B model

### "Pod is stuck in Pending state"

- **Approve new users**: Click your profile → Admin Panel → Users

Common causes:

- GPU nodes not ready yet (check `kubectl get nodes`)- **Add more models**: Use the script or Settings → Models in the UI- ✅ Azure Key Vault: `kubecon-kv-xxxxxxx`

- Insufficient GPU quota (check Azure portal)

- Storage not provisioned (check `kubectl get pvc -n ollama`)- **Monitor activity**: See who's using the system and what models are popular



Get detailed info:- **Manage settings**: Configure authentication, branding, and features- ✅ Storage: Azure Files Premium + Azure Disk PremiumDeploy everything with one command:



```powershell

kubectl describe pod <pod-name> -n ollama

```### For Booth Demos and Events- ✅ NVIDIA GPU drivers



### "Open-WebUI shows 502 Bad Gateway"



Ollama backend might not be ready yet. Check:If you're running this at a conference booth:- ✅ Ollama LLM server (ready to download models)- ✅ **Production-Ready:** Secure, monitored, and enterprise-grade



```powershell

kubectl get pods -n ollama

kubectl logs -n ollama -l app=ollama1. Create your admin account first (before visitors arrive)- ✅ Open-WebUI frontend

```

2. Download models using the script above

Wait for Ollama pod to show "Running" and "1/1 Ready"

3. Share the WebUI URL via QR code or printed card```powershell

### "Chat responses are slow"

4. Visitors can sign up and wait for approval

First request after model load takes 30-60 seconds (model initialization). Subsequent requests are fast (2-5 seconds).

5. You approve legitimate signups from the Admin Panel### 3. Access the WebUI

If consistently slow:

- Check GPU allocation: `kubectl describe node -l gpu=true`6. Approved users can immediately start chatting with AI models

- Check model size vs GPU memory (T4 has 16GB VRAM)

- Verify no CPU throttling: Check AKS node metrics in Azure portal# Clone the repository- **Azure Disk** - High-performance storage for SQLite database- **Open-WebUI** - Modern web interface for model interaction



---To set up booth materials:



## 💰 Cost EstimateAfter deployment completes (15-20 minutes), you'll see:



Approximate daily costs (West US 2 region):```powershell



| Resource | SKU/Type | Quantity | Daily Cost |.\scripts\setup-booth-demo.ps1git clone <repo-url>

|----------|----------|----------|------------|

| AKS Cluster | Management | 1 | Free |```

| GPU Nodes | Standard_NC8as_T4_v3 | 2 | ~$16.00 |

| System Nodes | Standard_D2s_v3 | 2 | ~$4.00 |```

| Azure Files Premium | 100GB | 1 | ~$0.50 |

| Azure Disk Premium | 10GB (P4) | 1 | ~$0.15 |This creates QR codes and printable materials for your booth.

| Load Balancer | Standard | 1 | ~$0.75 |

| Public IP | Standard | 1 | ~$0.01 |========================================cd llm-demo---

| Key Vault | Standard | 1 | <$0.01 |

| **Total** | | | **~$21/day** |### For Regular Users



**Cost Optimization:**DEPLOYMENT SUMMARY



```powershellAfter your account is approved:

# Scale down to zero (keeps cluster)

.\scripts\scale-ollama.ps1 -Replicas 0========================================



# Full cleanup (deletes everything)1. Login with your email and password

.\scripts\cleanup.ps1 -Prefix "kubecon"

```2. Select a model from the dropdown at the topOpen-WebUI URL    : http://20.x.x.x



---3. Type your question in the chat box



## 🧹 Cleanup4. The AI model will respond within seconds# Deploy to Azure (takes 15-20 minutes)- **Azure Key Vault** - Secure secret management- **Azure Files Premium** - High-performance persistent storage for model weights



### Delete Everything5. Your conversations are saved in your personal history



```powershellNext Step - Download Models:

.\scripts\cleanup.ps1 -Prefix "kubecon"

```---



**What gets deleted:**  Run this command to download 6 models (~33.7 GB):.\scripts\deploy.ps1 -Prefix "kubecon" -Location "westus2" -AutoApprove

- ✅ Kubernetes namespace `ollama` (cascades to all pods/services)

- ✅ Resource group `{prefix}-rg` (cascades to AKS, Key Vault, Storage)## 🏗️ Architecture

- ⏱️ Takes 5-10 minutes

    .\scripts\preload-multi-models.ps1

Costs stop as soon as resources are deleted.

### Infrastructure

### Keep Infrastructure, Delete Data Only

========================================## 📋 Prerequisites

```powershell

.\scripts\cleanup.ps1 -Prefix "kubecon" -DataOnly```

```

┌─────────────────────────────────────────────────────────┐```

---

│ Azure Resource Group ({prefix}-rg)                      │

## 🔐 Security Considerations

├─────────────────────────────────────────────────────────┤# Or with HuggingFace token for additional models

This demo includes production security features:

│  ┌─────────────────────────────────────────────────┐   │

- **Authentication required**: No anonymous access

- **Admin approval workflow**: New users must be approved│  │ AKS Cluster ({prefix}-aks) - Kubernetes 1.31   │   │**First-Time Setup:**

- **Secret management**: Credentials in Azure Key Vault, not in code

- **Network isolation**: Ollama backend not publicly exposed│  ├─────────────────────────────────────────────────┤   │

- **TLS ready**: LoadBalancer supports HTTPS with cert-manager (optional)

│  │  System Node Pool (2x Standard_D2s_v3)         │   │1. Open the URL in your browser.\scripts\deploy.ps1 -Prefix "kubecon" -Location "westus2" -HuggingFaceToken "hf_xxxxx" -AutoApprove- **AKS with GPU nodes** - T4/A10 GPU-accelerated inference

For production deployments, also consider:

- Enable Azure AD integration for user authentication│  │  └─ System pods (CoreDNS, kube-proxy, etc.)    │   │

- Add network policies to restrict pod-to-pod traffic

- Use Azure Private Link for backend services│  │                                                  │   │2. Create admin account (first user becomes admin)

- Enable AKS audit logging

- Implement rate limiting and quotas│  │  GPU Node Pool (2x Standard_NC8as_T4_v3)       │   │



---│  │  └─ Taint: sku=gpu:NoSchedule                  │   │3. **Download models before chatting** (see next section)```



## 📚 Additional Resources│  │  └─ NVIDIA T4 GPU (16GB VRAM each)             │   │



- **Ollama Model Library**: https://ollama.com/library│  └─────────────────────────────────────────────────┘   │

- **Open-WebUI Documentation**: https://github.com/open-webui/open-webui

- **Azure Files Documentation**: https://learn.microsoft.com/azure/storage/files/│                                                          │

- **AKS GPU Documentation**: https://learn.microsoft.com/azure/aks/gpu-cluster

│  ┌─────────────────────────────────────────────────┐   │---### Required Tools

---

│  │ Azure Key Vault ({prefix}-kv-xxxxxxx)          │   │

## 📝 Scripts Reference

│  │ └─ Secure credential storage                    │   │

| Script | Purpose |

|--------|---------|│  └─────────────────────────────────────────────────┘   │

| `deploy.ps1` | Main deployment orchestrator |

| `preload-multi-models.ps1` | Download 6 models post-deployment (~33.7 GB) with diagnostics |│                                                          │## 📦 Download ModelsThe script will:

| `create-admin.ps1` | Create admin account via API |

| `scale-ollama.ps1` | Scale Ollama replicas up/down |│  ┌─────────────────────────────────────────────────┐   │

| `cleanup.ps1` | Teardown resources |

│  │ Storage (Azure Files Premium + Azure Disk)      │   │

---

│  │ └─ CSI drivers (built into AKS)                 │   │

## 🎯 Quick Reference

│  └─────────────────────────────────────────────────┘   │**IMPORTANT:** Models are NOT downloaded during deployment to keep it fast and reliable. After deployment completes, you need to download models before you can chat.1. Create an AKS cluster with GPU nodes- **Azure CLI** (2.50.0+) - [Install](https://aka.ms/azure-cli)## 📋 Prerequisites- **Azure Key Vault** - Secure credential management

```powershell

# Deploy everything└─────────────────────────────────────────────────────────┘

.\scripts\deploy.ps1 -Prefix "demo" -Location "westus2" -AutoApprove

```

# Download models (REQUIRED after deployment)

.\scripts\preload-multi-models.ps1



# Check status### Storage Strategy### Quick Start - Download All Models2. Set up Azure Key Vault for secrets

kubectl get all -n ollama



# View logs

kubectl logs -f -l app=ollama -n ollama**Why Azure Files for Models:**



# Scale up- Models are large (2-13GB each) and expensive to download

.\scripts\scale-ollama.ps1 -Replicas 3

- ReadWriteMany allows multiple Ollama pods to share the same modelsThe easiest way is to download all 6 recommended models at once (~33.7 GB total):3. Configure storage (Azure Files + Azure Disk)- **kubectl** (1.28.0+) - [Install](https://kubernetes.io/docs/tasks/tools/)

# Cleanup

.\scripts\cleanup.ps1 -Prefix "demo"- Premium tier provides low-latency access for GPU inference

```

- Models persist across pod restarts (no re-downloading)

---



**Enjoy the demo! 🚀**

**Why Azure Disk for Database:**```powershell4. Deploy Ollama and download the first model

- SQLite requires local disk with exclusive access

- Premium SSD ensures fast queries and writes.\scripts\preload-multi-models.ps1

- ReadWriteOnce is perfect for single-pod databases

```5. Deploy Open-WebUI with authentication- **PowerShell** 5.1+ (Windows) or PowerShell 7+ (cross-platform)

---



## 🛠️ Management Commands

This will download:6. Provide you with a public URL

### Check Status

- `phi3.5` (2.3 GB) - Fast, general purpose

```powershell

# All resources- `llama3.1:8b` (4.7 GB) - Meta's latest, very capable

kubectl get all -n ollama

- `mistral:7b` (4.1 GB) - Excellent reasoning

# Pod status

kubectl get pods -n ollama -o wide- `gemma2:2b` (1.6 GB) - Lightweight, fastAfter deployment completes (15-20 minutes), you'll see:



# Services and external IP- `gpt-oss` (13 GB) - Advanced chat model

kubectl get svc -n ollama

- `deepseek-r1` (8 GB) - Strong reasoning and math```### Azure Requirements### Required Tools**Key Benefits:**

# Storage

kubectl get pvc -n ollama

```

**Download time:** Approximately 15-20 minutes depending on network speed.========================================

### View Logs



```powershell

# Ollama logs### Option 2 - Add Models Manually via UIDeployment Complete!- Active Azure subscription with Contributor or Owner role

kubectl logs -f -l app=ollama -n ollama



# Open-WebUI logs

kubectl logs -f -l app=open-webui -n ollamaIf you prefer to download specific models:========================================

```



### Model Management

1. Login to Open-WebUI as admin- Sufficient quota in target region:- **Azure CLI** (2.50.0 or later) - [Install](https://docs.microsoft.com/cli/azure/install-azure-cli)- ✅ **Fast Model Loading:** Azure Files Premium delivers low-latency access to 4.7GB model

```powershell

# List installed models2. Go to Settings → Models → Pull a model from Ollama.com

kubectl exec -n ollama ollama-0 -- ollama list

3. Enter model name from https://ollama.com/library (e.g., `llama3.1:8b`)WebUI URL: http://20.30.40.50

# Test a model

kubectl exec -n ollama ollama-0 -- ollama run llama3.1:8b "Hello!"4. Wait for download to complete before using



# Pull a specific model  - **Standard_NC8as_T4_v3** (GPU): 16 vCPUs (2 nodes × 8 vCPUs)

kubectl exec -n ollama ollama-0 -- ollama pull <model-name>

**Note:** Manual downloads through the UI may be slower than using the script.

# Remove a model

kubectl exec -n ollama ollama-0 -- ollama rm <model-name>Next Steps:

```

### Verify Models

### Scaling

1. Open the URL in your browser  - **Standard_D2s_v3** (System): 4 vCPUs (2 nodes × 2 vCPUs)- **kubectl** (1.28.0 or later) - [Install](https://kubernetes.io/docs/tasks/tools/)- ✅ **Persistent Storage:** Models survive pod restarts (no re-downloads)

```powershell

# Scale Ollama pods (share same models via Azure Files)```powershell

.\scripts\scale-ollama.ps1 -Replicas 3

```# Check which models are downloaded2. Click "Sign up" to create your admin account



---kubectl exec -n ollama ollama-0 -- ollama list



## 🐛 Troubleshooting3. Select a model and start chatting!



### "I don't see the Sign Up button"# Check storage usage



This is a known issue with Open-WebUI where the signup form doesn't appear even when enabled.kubectl exec -n ollama ollama-0 -- df -h /root/.ollama```



**Solution - Create admin via API:**```



```powershell### Check GPU Quota- **PowerShell** 7.0+ or Windows PowerShell 5.1- ✅ **Multi-Pod Scalability:** ReadWriteMany enables horizontal scaling

.\scripts\create-admin.ps1 -Email "admin@company.com" -Password "SecurePass123!"

```---



This script creates the admin account directly via the Open-WebUI API, bypassing the UI signup form.## Creating Your Admin Account



### "Models are downloading slowly"## 🎭 Using the Demo



Model downloads take 15-20 minutes for all 6 models (~33.7 GB). Check progress:```powershell



```powershell### For Administrators

kubectl logs -n ollama -l app=ollama --follow

```**Important:** The first person to sign up becomes the administrator automatically.



### "Pod is stuck in Pending state"Once logged in as admin, you can:



Common causes:# Check available GPU quota- ✅ **Native Kubernetes:** Standard CSI driver integration

- GPU nodes not ready yet (check `kubectl get nodes`)

- Insufficient GPU quota (check Azure portal)- **Approve new users**: Click your profile → Admin Panel → Users

- Storage not provisioned (check `kubectl get pvc -n ollama`)

- **Add more models**: Use the script or Settings → Models in the UI1. Open the WebUI URL from the deployment output

Get detailed info:

- **Monitor activity**: See who's using the system and what models are popular

```powershell

kubectl describe pod <pod-name> -n ollama- **Manage settings**: Configure authentication, branding, and features2. Look for "Sign up" at the bottom of the pageaz vm list-skus --location westus2 --size Standard_NC --all --output table | Select-String "NC8as_T4_v3"

```



### "Open-WebUI shows 502 Bad Gateway"

### For Booth Demos and Events3. Enter your email, password, and name

Ollama backend might not be ready yet. Check:



```powershell

kubectl get pods -n ollamaIf you're running this at a conference booth:4. You're now the admin with full system access### Azure Requirements- ✅ **Production-Ready:** Secure, monitored, and cost-effective

kubectl logs -n ollama -l app=ollama

```



Wait for Ollama pod to show "Running" and "1/1 Ready"1. Create your admin account first (before visitors arrive)



### "Chat responses are slow"2. Download models using the script above



First request after model load takes 30-60 seconds (model initialization). Subsequent requests are fast (2-5 seconds).3. Share the WebUI URL via QR code or printed cardIf you don't see a signup option, run this command to create the admin account:# Request quota increase if needed



If consistently slow:4. Visitors can sign up and wait for approval

- Check GPU allocation: `kubectl describe node -l gpu=true`

- Check model size vs GPU memory (T4 has 16GB VRAM)5. You approve legitimate signups from the Admin Panel```powershell

- Verify no CPU throttling: Check AKS node metrics in Azure portal

6. Approved users can immediately start chatting with AI models

---

.\scripts\create-admin.ps1 -Email "your-email@company.com" -Password "YourSecurePassword123!"# Portal → Subscriptions → Usage + quotas → Search "NCasT4v3"- Active Azure subscription

## 💰 Cost Estimate

To set up booth materials:

Approximate daily costs (West US 2 region):

```

| Resource | SKU/Type | Quantity | Daily Cost |

|----------|----------|----------|------------|```powershell

| AKS Cluster | Management | 1 | Free |

| GPU Nodes | Standard_NC8as_T4_v3 | 2 | ~$16.00 |.\scripts\setup-booth-demo.ps1```

| System Nodes | Standard_D2s_v3 | 2 | ~$4.00 |

| Azure Files Premium | 100GB | 1 | ~$0.50 |```

| Azure Disk Premium | 10GB (P4) | 1 | ~$0.15 |

| Load Balancer | Standard | 1 | ~$0.75 |## Using the Demo

| Public IP | Standard | 1 | ~$0.01 |

| Key Vault | Standard | 1 | <$0.01 |This creates QR codes and printable materials for your booth.

| **Total** | | | **~$21/day** |

- Sufficient quota in target region:---

**Cost Optimization:**

### For Regular Users

```powershell

# Scale down to zero (keeps cluster)### For Administrators

.\scripts\scale-ollama.ps1 -Replicas 0

After your account is approved:

# Full cleanup (deletes everything)

.\scripts\cleanup.ps1 -Prefix "kubecon"### HuggingFace Token (Optional)

```

1. Login with your email and password

---

2. Select a model from the dropdown at the topOnce logged in as admin, you can:

## 🧹 Cleanup

3. Type your question in the chat box

### Delete Everything

4. The AI model will respond within seconds- Sign up at https://huggingface.co  - **Standard_NC8as_T4_v3** (NCasT4v3 family): 16 vCPUs (2 nodes x 8 vCPUs)

```powershell

.\scripts\cleanup.ps1 -Prefix "kubecon"5. Your conversations are saved in your personal history

```

- **Approve new users**: Click your profile → Admin Panel → Users

**What gets deleted:**

- ✅ Kubernetes namespace `ollama` (cascades to all pods/services)---

- ✅ Resource group `{prefix}-rg` (cascades to AKS, Key Vault, Storage)

- ⏱️ Takes 5-10 minutes- **Add more models**: The system starts with one model, but you can add more from Ollama's library- Create token at https://huggingface.co/settings/tokens



Costs stop as soon as resources are deleted.## 🏗️ Architecture



### Keep Infrastructure, Delete Data Only- **Monitor activity**: See who's using the system and what models are popular



```powershell### Infrastructure

.\scripts\cleanup.ps1 -Prefix "kubecon" -DataOnly

```- **Manage settings**: Configure authentication, branding, and features- Used for downloading models from HuggingFace (optional for this demo)  - Standard_D2s_v3: 4 vCPUs (2 system nodes)## **Quick Start**



---```



## 🔐 Security Considerations┌─────────────────────────────────────────────────────────┐



This demo includes production security features:│ Azure Resource Group ({prefix}-rg)                      │



- **Authentication required**: No anonymous access├─────────────────────────────────────────────────────────┤### For Booth Demos and Events

- **Admin approval workflow**: New users must be approved

- **Secret management**: Credentials in Azure Key Vault, not in code│  ┌─────────────────────────────────────────────────┐   │

- **Network isolation**: Ollama backend not publicly exposed

- **TLS ready**: LoadBalancer supports HTTPS with cert-manager (optional)│  │ AKS Cluster ({prefix}-aks) - Kubernetes 1.31   │   │



For production deployments, also consider:│  ├─────────────────────────────────────────────────┤   │

- Enable Azure AD integration for user authentication

- Add network policies to restrict pod-to-pod traffic│  │  System Node Pool (2x Standard_D2s_v3)         │   │If you're running this at a conference booth:---- Contributor or Owner role on subscription

- Use Azure Private Link for backend services

- Enable AKS audit logging│  │  └─ System pods (CoreDNS, kube-proxy, etc.)    │   │

- Implement rate limiting and quotas

│  │                                                  │   │

---

│  │  GPU Node Pool (2x Standard_NC8as_T4_v3)       │   │

## 📚 Additional Resources

│  │  └─ Taint: sku=gpu:NoSchedule                  │   │1. Create your admin account first (before visitors arrive)

- **Ollama Model Library**: https://ollama.com/library

- **Open-WebUI Documentation**: https://github.com/open-webui/open-webui│  │  └─ NVIDIA T4 GPU (16GB VRAM each)             │   │

- **Azure Files Documentation**: https://learn.microsoft.com/azure/storage/files/

- **AKS GPU Documentation**: https://learn.microsoft.com/azure/aks/gpu-cluster│  └─────────────────────────────────────────────────┘   │2. Share the WebUI URL via QR code or printed card



---│                                                          │



## 📝 Scripts Reference│  ┌─────────────────────────────────────────────────┐   │3. Visitors can sign up and wait for approval## 🚀 Quick Start (12-15 minutes)### **Prerequisites**



| Script | Purpose |│  │ Azure Key Vault ({prefix}-kv-xxxxxxx)          │   │

|--------|---------|

| `deploy.ps1` | Main deployment orchestrator |│  │ └─ Secure credential storage                    │   │4. You approve legitimate signups from the Admin Panel

| `preload-multi-models.ps1` | Download 6 models post-deployment (~33.7 GB) |

| `create-admin.ps1` | Create admin account via API |│  └─────────────────────────────────────────────────┘   │

| `setup-booth-demo.ps1` | Generate QR codes and booth materials |

| `scale-ollama.ps1` | Scale Ollama replicas up/down |│                                                          │5. Approved users can immediately start chatting with AI models

| `cleanup.ps1` | Teardown resources |

│  ┌─────────────────────────────────────────────────┐   │

---

│  │ Storage (Azure Files Premium + Azure Disk)      │   │

## 🎯 Quick Reference

│  │ └─ CSI drivers (built into AKS)                 │   │

```powershell

# Deploy everything│  └─────────────────────────────────────────────────┘   │To set up booth materials:### 1. Login to Azure### Check GPU Quota

.\scripts\deploy.ps1 -Prefix "demo" -Location "westus2" -AutoApprove

└─────────────────────────────────────────────────────────┘

# Download models (REQUIRED after deployment)

.\scripts\preload-multi-models.ps1``````powershell



# Check status

kubectl get all -n ollama

### Storage Strategy.\scripts\setup-booth-demo.ps1```powershell

# View logs

kubectl logs -f -l app=ollama -n ollama



# Scale up**Why Azure Files for Models:**```

.\scripts\scale-ollama.ps1 -Replicas 3

- Models are large (2-13GB each) and expensive to download

# Cleanup

.\scripts\cleanup.ps1 -Prefix "demo"- ReadWriteMany allows multiple Ollama pods to share the same modelsaz login```bash- Azure CLI (`az`) - [Install](https://aka.ms/azure-cli)

```

- Premium tier provides low-latency access for GPU inference

---

- Models persist across pod restarts (no re-downloading)This creates QR codes and printable materials for your booth.

**Enjoy the demo! 🚀**



**Why Azure Disk for Database:**az account set --subscription "<your-subscription-id>"

- SQLite requires local disk with exclusive access

- Premium SSD ensures fast queries and writes### For Regular Users

- ReadWriteOnce is perfect for single-pod databases

```# Check available GPU quota- kubectl - [Install](https://kubernetes.io/docs/tasks/tools/)

---

After your account is approved:

## 🛠️ Management Commands



### Check Status

1. Login with your email and password

```powershell

# All resources2. Select a model from the dropdown at the top### 2. Deploy Infrastructureaz vm list-skus --location westus2 --size Standard_NC --all --output table | findstr NC8as_T4_v3- Azure subscription with:

kubectl get all -n ollama

3. Type your question in the chat box

# Pod status

kubectl get pods -n ollama -o wide4. The AI model will respond within seconds```powershell



# Services and external IP5. Your conversations are saved in your personal history

kubectl get svc -n ollama

cd d:\temp\kubecon-na-booth-demo\llm-demo  - GPU quota (2x Standard_NC6s_v3 or A10 GPU)

# Storage

kubectl get pvc -n ollama## Adding More Models

```



### View Logs

The deployment starts with one model (phi3.5) to save time. To add more:

```powershell

# Ollama logs# Deploy everything (AKS + GPU nodes + Storage + LLM + WebUI)# Request quota increase if needed (via Azure Portal)  - Contributor access

kubectl logs -f -l app=ollama -n ollama

**Option 1 - Manually via UI:**

# Open-WebUI logs

kubectl logs -f -l app=open-webui -n ollama1. Login to Open-WebUI as admin.\scripts\deploy.ps1 -Prefix "demo01" -Location "westus2" -HuggingFaceToken "hf_xxxxx"

```

2. Go to Settings → Models

### Model Management

3. Add model names from https://ollama.com/library```# Portal → Subscriptions → Usage + quotas → Search "NCasT4v3"- PowerShell 5.1+ (Windows) or Bash (Linux)

```powershell

# List installed models

kubectl exec -n ollama ollama-0 -- ollama list

**Option 2 - Bulk download via script:**

# Test a model

kubectl exec -n ollama ollama-0 -- ollama run llama3.1:8b "Hello!"```powershell



# Pull a specific model# Download 6 popular models (~30GB total)**What gets deployed:**```

kubectl exec -n ollama ollama-0 -- ollama pull <model-name>

.\scripts\preload-multi-models.ps1

# Remove a model

kubectl exec -n ollama ollama-0 -- ollama rm <model-name>```- ✅ Resource Group: `demo01-rg`

```



### Scaling

Available models:- ✅ AKS Cluster: `demo01-aks` (K8s 1.31)### **Deploy in 10 Minutes**

```powershell

# Scale Ollama pods (share same models via Azure Files)- `phi3.5` (2.2GB) - Fast, general purpose

.\scripts\scale-ollama.ps1 -Replicas 3

```- `llama3.1:8b` (4.9GB) - Meta's latest, very capable  - 2 system nodes (D2s_v3)



---- `mistral:7b` (4.4GB) - Excellent reasoning



## 🐛 Troubleshooting- `gemma2:2b` (1.6GB) - Lightweight, fast  - 2 GPU nodes (NC8as_T4_v3 with NVIDIA T4)### HuggingFace Token (Optional)



### "I don't see the Sign Up button"- `deepseek-r1` (5.2GB) - Strong reasoning and math



This is a known issue with Open-WebUI where the signup form doesn't appear even when enabled.- `gpt-oss` (13GB) - Advanced chat model- ✅ Azure Key Vault: `demo01kvxxxxxxx`



**Quick fix:**



```powershell## Architecture- ✅ Storage: Azure Files Premium + Azure Disk Premium- Sign up at https://huggingface.co/```powershell

.\scripts\fix-signup.ps1

```



This recreates the database and forces environment variables to apply.The deployment creates these Azure resources:- ✅ NVIDIA GPU drivers



**Or create admin via API:**



```powershell**Resource Group**: `{prefix}-rg`- ✅ Ollama LLM server (with llama3.1:8b pre-loaded)- Create token at https://huggingface.co/settings/tokens# Clone repo

.\scripts\create-admin.ps1 -Email "admin@company.com" -Password "SecurePass123!"

```- **AKS Cluster**: `{prefix}-aks`



### "Models are downloading slowly"  - 2 GPU nodes: Standard_NC8as_T4_v3 (NVIDIA Tesla T4)- ✅ Open-WebUI frontend



Model downloads take 15-20 minutes for all 6 models (~33.7 GB). Check progress:  - 2 system nodes: Standard_D2s_v3



```powershell  - Kubernetes 1.31 or later- Used for downloading models from HuggingFace (optional)cd d:\temp\kubecon-na-booth-demo\llm-demo

kubectl logs -n ollama -l app=ollama --follow

```- **Key Vault**: `{prefix}-kv-{random}`



### "Pod is stuck in Pending state"  - Stores OpenAI API keys, HuggingFace tokens### 3. Access the Demo



Common causes:  - Managed identity access

- GPU nodes not ready yet (check `kubectl get nodes`)

- Insufficient GPU quota (check Azure portal)- **Storage Account** (auto-created by AKS):After deployment completes (12-15 minutes), you'll see:

- Storage not provisioned (check `kubectl get pvc -n ollama`)

  - Azure Files Premium (100GB) - Model storage

Get detailed info:

  - Azure Disk Premium (10GB) - SQLite database```

```powershell

kubectl describe pod <pod-name> -n ollama

```

**Kubernetes Resources**:========================================## 🚀 Quick Start (15 minutes)# Login to Azure

### "Open-WebUI shows 502 Bad Gateway"

- `ollama` namespace:

Ollama backend might not be ready yet. Check:

  - Ollama StatefulSet (GPU-enabled, 1 replica)Service Endpoints

```powershell

kubectl get pods -n ollama  - Open-WebUI Deployment (web interface, 1 replica)

kubectl logs -n ollama -l app=ollama

```  - Azure Files PVC (ReadWriteMany for models)========================================az login



Wait for Ollama pod to show "Running" and "1/1 Ready"  - Azure Disk PVC (ReadWriteOnce for database)



### "Chat responses are slow"  - LoadBalancer service (public IP)Open-WebUI URL    : http://20.55.123.45



First request after model load takes 30-60 seconds (model initialization). Subsequent requests are fast (2-5 seconds).



If consistently slow:## Storage StrategyOllama Service IP : 10.100.70.76:11434### 1. Clone Repositoryaz account set --subscription "<your-subscription-id>"

- Check GPU allocation: `kubectl describe node -l gpu=true`

- Check model size vs GPU memory (T4 has 16GB VRAM)

- Verify no CPU throttling: Check AKS node metrics in Azure portal

**Why Azure Files for Models:**```

---

- Models are large (2-13GB each) and expensive to download

## 💰 Cost Estimate

- ReadWriteMany allows multiple Ollama pods to share the same models```powershell

Approximate daily costs (West US 2 region):

- Premium tier provides low-latency access for GPU inference

| Resource | SKU/Type | Quantity | Daily Cost |

|----------|----------|----------|------------|- Models persist across pod restarts (no re-downloading)**First-Time Setup:**

| AKS Cluster | Management | 1 | Free |

| GPU Nodes | Standard_NC8as_T4_v3 | 2 | ~$16.00 |

| System Nodes | Standard_D2s_v3 | 2 | ~$4.00 |

| Azure Files Premium | 100GB | 1 | ~$0.50 |**Why Azure Disk for Database:**1. Open the URL in your browsercd d:\temp# Deploy everything (AKS + Storage + LLM)

| Azure Disk Premium | 10GB (P4) | 1 | ~$0.15 |

| Load Balancer | Standard | 1 | ~$0.75 |- SQLite requires local disk with exclusive access

| Public IP | Standard | 1 | ~$0.01 |

| Key Vault | Standard | 1 | <$0.01 |- Premium SSD ensures fast queries and writes2. Create admin account (first user becomes admin)

| **Total** | | | **~$21/day** |

- ReadWriteOnce is perfect for single-pod databases

**Cost Optimization:**

3. Model `llama3.1:8b` is pre-loaded and ready to usegit clone https://github.com/your-org/kubecon-na-booth-demo.git.\scripts\deploy.ps1 -Prefix "kubecon" -Location "westus2"

```powershell

# Scale down to zero (keeps cluster)## Monitoring and Operations

.\scripts\scale-ollama.ps1 -Replicas 0



# Full cleanup (deletes everything)

.\scripts\cleanup.ps1 -Prefix "kubecon"Check deployment health:

```

```powershell---cd kubecon-na-booth-demo\llm-demo

---

# Quick status check

## 🧹 Cleanup

kubectl get pods -n ollama

### Delete Everything



```powershell

.\scripts\cleanup.ps1 -Prefix "kubecon"# Detailed monitoring with watch mode## 📦 What's Deployed```# Output will show WebUI URL:

```

.\scripts\monitor-booth-users.ps1 -Watch

**What gets deleted:**

- ✅ Kubernetes namespace `ollama` (cascades to all pods/services)

- ✅ Resource group `{prefix}-rg` (cascades to AKS, Key Vault, Storage)

- ⏱️ Takes 5-10 minutes# Check model downloads



Costs stop as soon as resources are deleted.kubectl exec -n ollama ollama-0 -- ollama list### Kubernetes Workloads# Open-WebUI: http://<public-ip>



### Keep Infrastructure, Delete Data Only



```powershell# View storage usage```powershell

.\scripts\cleanup.ps1 -Prefix "kubecon" -DataOnly

```kubectl exec -n ollama ollama-0 -- df -h /root/.ollama



---```kubectl get all -n ollama### 2. Login to Azure```



## 🔐 Security Considerations



This demo includes production security features:Scale Ollama pods:```



- **Authentication required**: No anonymous access```powershell

- **Admin approval workflow**: New users must be approved

- **Secret management**: Credentials in Azure Key Vault, not in code.\scripts\scale-ollama.ps1 -Replicas 3```powershell

- **Network isolation**: Ollama backend not publicly exposed

- **TLS ready**: LoadBalancer supports HTTPS with cert-manager (optional)```



For production deployments, also consider:| Resource | Type | Purpose |

- Enable Azure AD integration for user authentication

- Add network policies to restrict pod-to-pod trafficNote: Multiple pods share the same models via Azure Files, saving storage and download time.

- Use Azure Private Link for backend services

- Enable AKS audit logging|----------|------|---------|az login**That's it!** Open the URL in your browser, create an account, and start chatting with Llama-3.1-8B.

- Implement rate limiting and quotas

## Troubleshooting

---

| `ollama-0` | StatefulSet | LLM inference server (GPU pod) |

## 📚 Additional Resources

### "I don't see the Sign Up button"

- **Ollama Model Library**: https://ollama.com/library

- **Open-WebUI Documentation**: https://github.com/open-webui/open-webui| `ollama` | ClusterIP Service | Internal Ollama API (port 11434) |az account set --subscription "<your-subscription-id>"

- **Azure Files Documentation**: https://learn.microsoft.com/azure/storage/files/

- **AKS GPU Documentation**: https://learn.microsoft.com/azure/aks/gpu-clusterThis is a known issue with Open-WebUI where the signup form doesn't appear even when enabled.



---| `open-webui` | Deployment | Web interface |



## 📝 Scripts Reference**Quick fix:**



| Script | Purpose |```powershell| `open-webui` | LoadBalancer Service | External access (port 80) |```---

|--------|---------|

| `deploy.ps1` | Main deployment orchestrator |.\scripts\fix-signup.ps1

| `preload-multi-models.ps1` | Download 6 models (~33.7 GB) |

| `create-admin.ps1` | Create admin account via API |```

| `fix-signup.ps1` | Fix signup form visibility |

| `setup-booth-demo.ps1` | Generate QR codes for booth |

| `monitor-booth-users.ps1` | Monitor user activity |

| `scale-ollama.ps1` | Scale Ollama replicas |This recreates the database and forces environment variables to apply.### Storage

| `cleanup.ps1` | Teardown resources |



---

**Or create admin via API:**```powershell

## 🎯 Quick Reference

```powershell

```powershell

# Deploy everything.\scripts\create-admin.ps1 -Email "admin@company.com" -Password "SecurePass123!"kubectl get pvc -n ollama### 3. Deploy Everything## **Repository Structure**

.\scripts\deploy.ps1 -Prefix "demo" -Location "westus2" -AutoApprove

```

# Download models (REQUIRED after deployment)

.\scripts\preload-multi-models.ps1```



# Check status### "Models are downloading slowly"

kubectl get all -n ollama

```powershell

# View logs

kubectl logs -f -l app=ollama -n ollamaGPU nodes take 3-5 minutes to provision. Model downloads happen after nodes are ready.



# Scale up| PVC | Size | Storage Class | Purpose | Access Mode |

.\scripts\scale-ollama.ps1 -Replicas 3

Check download progress:

# Cleanup

.\scripts\cleanup.ps1 -Prefix "demo"```powershell|-----|------|--------------|---------|-------------|.\scripts\deploy.ps1 ````

```

kubectl logs -n ollama -l app=ollama --follow

---

```| `ollama-models-pvc` | 100GB | azurefile-premium-llm | Model storage | ReadWriteMany |

**Enjoy the demo! 🚀**



### "Pod is stuck in Pending state"| `open-webui-disk-pvc` | 10GB | azuredisk-premium-retain | SQLite DB | ReadWriteOnce |    -Prefix "demo01" `llm-demo/



Common causes:

- GPU nodes not ready yet (check `kubectl get nodes`)

- Insufficient GPU quota (check Azure portal)### GPU Resources    -Location "westus2" `├── bicep/                          # Azure infrastructure (IaC)

- Storage not provisioned (check `kubectl get pvc -n ollama`)

```powershell

Get detailed info:

```powershellkubectl get nodes -l agentpool=gpu -o custom-columns=NAME:.metadata.name,GPU:.status.capacity."nvidia\.com/gpu"    -HuggingFaceToken "hf_your_token_here"│   ├── main.bicep                  # Orchestrator (AKS + Key Vault)

kubectl describe pod <pod-name> -n ollama

``````



### "Open-WebUI shows 502 Bad Gateway"```│   └── aks.bicep                   # AKS cluster with GPU node pool



Ollama backend might not be ready yet. Check:---

```powershell

kubectl get pods -n ollama├── k8s/                            # Kubernetes manifests

kubectl logs -n ollama -l app=ollama

```## 🧪 Validation



Wait for Ollama pod to show "Running" and "1/1 Ready".**That's it!** The script will:│   ├── 01-namespace.yaml           # ollama namespace



### "Chat responses are slow"### Check Cluster Health



First request after model load takes 30-60 seconds (model initialization). Subsequent requests are fast (2-5 seconds).```powershell- ✅ Create resource group and managed identity│   ├── 02-storage-premium.yaml     # Azure Files Premium for models



If consistently slow:# Verify all pods are running

- Check GPU allocation: `kubectl describe node -l gpu=true`

- Check model size vs GPU memory (T4 has 16GB VRAM)kubectl get pods -n ollama- ✅ Deploy AKS cluster with GPU nodes (8-10 min)│   ├── 03-storage-standard.yaml    # Azure Files Standard for UI data

- Verify no CPU throttling: Check AKS node metrics in Azure portal



### "I accidentally deleted resources"

# Check GPU availability- ✅ Install NVIDIA GPU drivers│   ├── 04-secret.yaml              # Hugging Face token

To rebuild everything:

```powershellkubectl get nodes -l agentpool=gpu -o custom-columns=NAME:.metadata.name,GPU:.status.capacity."nvidia\.com/gpu"

# Full cleanup

.\scripts\cleanup.ps1 -Prefix "kubecon"- ✅ Deploy storage infrastructure│   ├── 05-ollama-statefulset.yaml  # LLM server (GPU pod)



# Redeploy# Verify model is loaded

.\scripts\deploy.ps1 -Prefix "kubecon" -Location "westus2" -AutoApprove

```kubectl exec -n ollama ollama-0 -- ollama list- ✅ Deploy Ollama + Open-WebUI│   ├── 06-ollama-service.yaml      # Internal service



To keep infrastructure but reset user data:```

```powershell

.\scripts\cleanup.ps1 -Prefix "kubecon" -DataOnly- ✅ Verify GPU availability│   ├── 07-webui-deployment.yaml    # Web UI

```

### Test Ollama API

## Costs

```powershell│   └── 08-webui-service.yaml       # Public LoadBalancer

Approximate daily costs (West US 2 region):

$ollamaIp = kubectl get svc ollama -n ollama -o jsonpath='{.spec.clusterIP}'

| Resource | SKU/Type | Quantity | Daily Cost |

|----------|----------|----------|------------|kubectl run test-ollama --rm -it --restart=Never --image=curlimages/curl -- curl -X POST http://$ollamaIp:11434/api/generate -d '{"model":"llama3.1:8b","prompt":"Why is Azure Files great for AI workloads?","stream":false}'### 4. Access Your LLM├── scripts/                        # Automation scripts

| AKS Cluster | Management | 1 | Free |

| GPU Nodes | Standard_NC8as_T4_v3 | 2 | ~$16.00 |```

| System Nodes | Standard_D2s_v3 | 2 | ~$4.00 |

| Azure Files Premium | 100GB | 1 | ~$0.50 |At the end of deployment, you'll see:│   ├── deploy.ps1                  # Main deployment orchestrator

| Azure Disk Premium | 10GB (P4) | 1 | ~$0.15 |

| Load Balancer | Standard | 1 | ~$0.75 |---

| Public IP | Standard | 1 | ~$0.01 |

| Key Vault | Standard | 1 | <$0.01 |```│   ├── preload-model.ps1           # Download LLM models

| **Total** | | | **~$21/day** |

## 🎭 Demo Usage

Shutdown GPUs when not in use to save costs:

```powershell========================================│   ├── validate.ps1                # Health checks

# Scale down to zero (keeps cluster)

.\scripts\scale-ollama.ps1 -Replicas 0See **[DEMOGUIDE.md](DEMOGUIDE.md)** for:



# Full cleanup (deletes everything)- 5-minute booth presentation scriptDEPLOYMENT SUMMARY│   └── cleanup.ps1                 # Teardown resources

.\scripts\cleanup.ps1 -Prefix "kubecon"

```- What to show in Azure Portal



## Security Considerations- How to demonstrate storage integration========================================├── docs/                           # Documentation



This demo includes production security features:- Key talking points for Azure Files features



- **Authentication required**: No anonymous accessOpen-WebUI URL    : http://20.x.x.x│   ├── demo-script.md              # 5-minute presenter guide

- **Admin approval workflow**: New users must be approved

- **Secret management**: Credentials in Azure Key Vault, not in code---

- **Network isolation**: Ollama backend not publicly exposed

- **TLS ready**: LoadBalancer supports HTTPS with cert-manager (optional)```│   ├── architecture.md             # Deep dive + diagrams



For production deployments, also consider:## 🧹 Cleanup

- Enable Azure AD integration for user authentication

- Add network policies to restrict pod-to-pod traffic│   └── troubleshooting.md          # Common issues

- Use Azure Private Link for backend services

- Enable AKS audit logging### Delete Everything

- Implement rate limiting and quotas

```powershell1. Open the URL in your browser├── temp/                           # Validation outputs (gitignored)

## Cleanup

.\scripts\cleanup.ps1 -Prefix "demo01"

When you're done with the demo:

```2. Click "Sign up" to create your account (first user = admin)└── README.md                       # This file

```powershell

# Delete everything (cluster, storage, vault)

.\scripts\cleanup.ps1 -Prefix "kubecon"

**What gets deleted:**3. Click "+ New Chat"```

# Or just reset user data (keeps infrastructure)

.\scripts\cleanup.ps1 -Prefix "kubecon" -DataOnly- ✅ Kubernetes namespace `ollama` (cascades to all pods/services)

```

- ✅ Resource group `demo01-rg` (cascades to AKS, Key Vault, Storage)4. Select a model from the dropdown

The cleanup script:

- Deletes the AKS cluster and all workloads- ⏱️ Takes 5-10 minutes

- Removes Azure Files and Azure Disk volumes

- Deletes the Key Vault (with 90-day soft delete)---

- Removes the entire resource group

### Partial Cleanup (K8s only, keep infrastructure)

Costs stop as soon as resources are deleted.

```powershell### 5. Pull a Model (if needed)

## Additional Resources

kubectl delete namespace ollama

- **Ollama Model Library**: https://ollama.com/library

- **Open-WebUI Documentation**: https://github.com/open-webui/open-webui``````powershell## **Architecture**

- **Azure Files Documentation**: https://learn.microsoft.com/azure/storage/files/

- **AKS GPU Documentation**: https://learn.microsoft.com/azure/aks/gpu-cluster



## Support---# Pull Llama 3.1 8B (recommended, 4.9GB)



For issues or questions:

1. Check the troubleshooting section above

2. Review logs: `kubectl logs -n ollama <pod-name>`## 🔧 Troubleshootingkubectl exec -n ollama ollama-0 -- ollama pull llama3.1:8b### **High-Level Diagram**

3. Verify configuration: `kubectl get all -n ollama`

4. Open an issue on the GitHub repository



## License### Pods Not Starting



This demo is provided as-is for educational and demonstration purposes.```powershell


# Check pod status# Other popular models```

kubectl describe pod <pod-name> -n ollama

kubectl exec -n ollama ollama-0 -- ollama pull mistral:7b      # 4.1GB┌─────────────────────────────────────────┐

# Check logs

kubectl logs <pod-name> -n ollamakubectl exec -n ollama ollama-0 -- ollama pull codellama:7b    # 3.8GB│         Users (Browser)                 │

```

kubectl exec -n ollama ollama-0 -- ollama pull phi3:mini       # 2.3GB└────────────────┬────────────────────────┘

**Common issues:**

- GPU nodes not ready → Check NVIDIA device plugin: `kubectl get pods -n kube-system -l name=nvidia-device-plugin-ds````                 │ HTTP

- PVC not binding → Check storage class: `kubectl describe pvc <pvc-name> -n ollama`

- Model download slow → Check internet connectivity from pods                 ▼



### GPU Not Available### 6. Start Chatting!┌─────────────────────────────────────────┐

```powershell

# Check GPU node taints- Select your model from the dropdown│   Azure Load Balancer (Public IP)      │

kubectl get nodes -l agentpool=gpu -o custom-columns=NAME:.metadata.name,TAINTS:.spec.taints

- Start asking questions└────────────────┬────────────────────────┘

# Check NVIDIA plugin

kubectl get daemonset -n kube-system nvidia-device-plugin-daemonset- GPU-accelerated inference!                 │

kubectl logs -n kube-system -l name=nvidia-device-plugin-ds

```┌────────────────▼────────────────────────┐



### Re-deploy After Fixes## 🤖 Available Models│         Azure Kubernetes Service        │

```powershell

# Deploy with auto-approve (no prompts)│  ┌────────────────────────────────┐     │

.\scripts\deploy.ps1 -Prefix "demo01" -Location "westus2" -HuggingFaceToken "hf_xxxxx" -AutoApprove

```Models compatible with Tesla T4 (16GB VRAM):│  │ Open-WebUI (Web Interface)     │     │



---│  └────────────┬───────────────────┘     │



## 📚 Architecture### General Purpose (4-5GB)│               │ HTTP:11434              │



### Infrastructure- **llama3.1:8b** - Meta's latest, excellent all-rounder│               ▼                         │

```

┌─────────────────────────────────────────────────────────┐- **mistral:7b** - Fast and capable│  ┌────────────────────────────────┐     │

│ Azure Resource Group (demo01-rg)                        │

├─────────────────────────────────────────────────────────┤- **gemma2:9b** - Google's reasoning specialist│  │ Ollama (LLM Server)            │     │

│                                                          │

│  ┌─────────────────────────────────────────────────┐   ││  │ - GPU: NVIDIA T4 (16GB)        │     │

│  │ AKS Cluster (demo01-aks) - Kubernetes 1.31      │   │

│  ├─────────────────────────────────────────────────┤   │### Code Generation (3-5GB)│  │ - Model: Llama-3.1-8B (4.7GB)  │     │

│  │                                                  │   │

│  │  System Node Pool (2x Standard_D2s_v3)         │   │- **codellama:7b** - Meta's code specialist│  └────────────┬───────────────────┘     │

│  │  └─ System pods (CoreDNS, kube-proxy, etc.)    │   │

│  │                                                  │   │- **qwen2.5-coder:7b** - Multi-language code expert│               │ Volume Mount            │

│  │  GPU Node Pool (2x Standard_NC8as_T4_v3)       │   │

│  │  └─ Taint: sku=gpu:NoSchedule                  │   │- **deepseek-coder:6.7b** - Strong code generation│               ▼                         │

│  │  └─ NVIDIA T4 GPU (16GB VRAM each)             │   │

│  │                                                  │   ││  ┌────────────────────────────────┐     │

│  └─────────────────────────────────────────────────┘   │

│                                                          │### Fast & Efficient (1-2GB)│  │ PVC (Azure Files Premium)      │     │

│  ┌─────────────────────────────────────────────────┐   │

│  │ Azure Key Vault (demo01kvxxxxxxx)               │   │- **phi3:mini** - Microsoft's efficient model│  │ - 100GB, ReadWriteMany         │     │

│  │ └─ Secure credential storage                    │   │

│  └─────────────────────────────────────────────────┘   │- **llama3.2:3b** - Balance of speed and capability│  └────────────┬───────────────────┘     │

│                                                          │

│  ┌─────────────────────────────────────────────────┐   │- **llama3.2:1b** - Ultra-fast responses└───────────────┼─────────────────────────┘

│  │ Storage (Azure Files Premium + Azure Disk)      │   │

│  │ └─ CSI drivers (built into AKS)                 │   │                │ SMB 3.0

│  └─────────────────────────────────────────────────┘   │

│                                                          │Browse all models: https://ollama.com/library                ▼

└─────────────────────────────────────────────────────────┘

```┌─────────────────────────────────────────┐



### Application Flow## 🛠️ Management Commands│    Azure Storage (File Share)           │

```

┌──────────┐      HTTP       ┌────────────┐      API      ┌─────────┐│    - Premium_LRS (high IOPS)            │

│  User    │ ──────────────> │ Open-WebUI │ ───────────> │ Ollama  │

│ Browser  │   Port 80       │   (Web)    │  Port 11434  │  (GPU)  │### Check Status│    - Model weights + metadata           │

└──────────┘                 └────────────┘               └─────────┘

                                    │                           │```powershell└─────────────────────────────────────────┘

                                    │                           │

                                    ▼                           ▼# All resources```

                             ┌─────────────┐          ┌──────────────┐

                             │ Azure Disk  │          │ Azure Files  │kubectl get all -n ollama

                             │  (SQLite)   │          │   (Models)   │

                             │   10GB      │          │    100GB     │**See [docs/architecture.md](docs/architecture.md) for detailed component breakdown.**

                             └─────────────┘          └──────────────┘

```# Pod status



---kubectl get pods -n ollama -o wide---



## 🔐 Security Features



- ✅ **RBAC-enabled AKS** - Kubernetes role-based access control# Services and external IP## **Key Features**

- ✅ **Azure Key Vault** - Secure secret storage

- ✅ **Managed Identity** - No stored credentialskubectl get svc -n ollama

- ✅ **Network Policies** - Pod-to-pod traffic control

- ✅ **Resource Quotas** - Prevent resource exhaustion### **1. Azure Files CSI Driver Integration**

- ✅ **GPU Node Taints** - Dedicated GPU workloads only

# Storage

---

kubectl get pvc -n ollama```yaml

## 💰 Cost Estimate (westus2)

```# Standard Kubernetes PVC - Azure Files provisioned automatically

| Resource | SKU | Quantity | Monthly Cost |

|----------|-----|----------|--------------|apiVersion: v1

| AKS System Nodes | Standard_D2s_v3 | 2 | ~$140 |

| AKS GPU Nodes | Standard_NC8as_T4_v3 | 2 | ~$1,300 |### View Logskind: PersistentVolumeClaim

| Azure Files Premium | 100GB | 1 | ~$20 |

| Azure Disk Premium | 10GB | 1 | ~$2 |```powershellmetadata:

| Key Vault | Standard | 1 | ~$1 |

| **Total** | | | **~$1,463/month** |# Ollama logs  name: ollama-models-pvc



**💡 Cost Optimization:**kubectl logs -f -l app=ollama -n ollamaspec:

- Stop GPU nodes when not in use

- Use spot instances for non-production  accessModes:

- Scale down to 1 GPU node for demos

# Open-WebUI logs    - ReadWriteMany  # Multi-pod access

---

kubectl logs -f -l app=open-webui -n ollama  storageClassName: azurefile-premium-llm

## 🤝 Contributing

```  resources:

Issues and PRs welcome! This is a demo/reference architecture for KubeCon NA 2025.

    requests:

---

### Model Management      storage: 100Gi

## 📝 License

```powershell```

MIT License - see LICENSE file for details

# List installed models

---

kubectl exec -n ollama ollama-0 -- ollama list**No custom provisioners, no manual File Share creation—just native Kubernetes.**

## 📧 Support



For issues or questions:

- Open an issue in this repo# Pull a new model### **2. GPU-Accelerated Inference**

- Visit our booth at KubeCon NA 2025

- Contact: Azure Files teamkubectl exec -n ollama ollama-0 -- ollama pull <model-name>


```yaml

# Remove a model# StatefulSet with GPU allocation

kubectl exec -n ollama ollama-0 -- ollama rm <model-name>resources:

  requests:

# Test a model    nvidia.com/gpu: "1"  # NVIDIA T4 (16GB VRAM)

kubectl exec -n ollama ollama-0 -- ollama run llama3.1:8b "Hello!"    cpu: "4"

```    memory: "16Gi"

```

## 🧹 Cleanup

**Inference Performance (Llama-3.1-8B):**

### Delete Everything- First token latency: 0.5-1.0s

```powershell- Throughput: 15-25 tokens/second

.\scripts\cleanup.ps1 -Prefix "demo01"

```### **3. Secure Credential Management**



### Keep Infrastructure, Delete K8s Resources Only```yaml

```powershell# Hugging Face token stored in Azure Key Vault

.\scripts\cleanup.ps1 -Prefix "demo01" -KeepResourceGroupenv:

```  - name: HF_TOKEN

    valueFrom:

### Force Cleanup (No Prompts)      secretKeyRef:

```powershell        name: huggingface-token

.\scripts\cleanup.ps1 -Prefix "demo01" -Force        key: token

``````



**Cost**: ~$3-5/hour when running. Always cleanup when not in use!**No secrets in Git, no plain text—full RBAC via managed identities.**



## 🐛 Troubleshooting---



### GPU Quota Error## **Usage**

Request quota increase: Azure Portal → Subscriptions → Usage + quotas → Search "NCasT4v3"

### **Deploy Demo**

### Open-WebUI Not Loading

```powershell```powershell

kubectl get pods -n ollama# Full deployment (first time)

kubectl logs -n ollama -l app=open-webui.\scripts\deploy.ps1 -Prefix "kubecon" -Location "westus2"

kubectl delete pod -n ollama -l app=open-webui  # Restart

```# Skip model download (faster for testing)

.\scripts\deploy.ps1 -Prefix "kubecon" -SkipModelDownload

### Model Not Appearing in UI

1. Refresh browser (F5)# Use existing AKS cluster

2. Verify: `kubectl exec -n ollama ollama-0 -- ollama list`.\scripts\deploy.ps1 -Prefix "kubecon" -SkipInfrastructure

3. Check: Settings → Admin Panel → Connections```



### Can't Access External IP### **Validate Deployment**

```powershell

# Wait 2-3 minutes, then check```powershell

kubectl get svc -n ollama open-webui# Run health checks

```.\scripts\validate.ps1



## 💰 Cost Estimation# Expected output:

# ✓ Namespace 'ollama' exists

Approximate hourly costs (West US 2):# ✓ PVC 'ollama-models-pvc' bound (100Gi)

- GPU Nodes (2x NC8as_T4_v3): ~$2.50/hr# ✓ Ollama StatefulSet ready (1/1)

- System Nodes (2x D2s_v3): ~$0.20/hr# ✓ Ollama pod running and ready

- Storage: ~$0.02/hr# ✓ GPU allocated: 1

- **Total**: ~$2.70-$3.00/hour (~$65-$72/day)# ✓ Models loaded: 1

```

## 📝 Architecture

### **Access WebUI**

```

Resource Group: {prefix}-rg```powershell

├── AKS Cluster: {prefix}-aks# Get public IP

│   ├── System Pool (2 nodes) - Open-WebUIkubectl get svc open-webui -n ollama -o jsonpath='{.status.loadBalancer.ingress[0].ip}'

│   └── GPU Pool (2 nodes) - Ollama + Tesla T4

├── Storage Accounts (Premium & Standard)# Open in browser: http://<ip-address>

├── Key Vault (secrets)# Create account on first visit (local accounts enabled)

└── Managed Identity```

```

### **Preload Additional Models**

## 🔐 Security Notes

```powershell

This is a **demo configuration**. For production:# Download Phi-3.5 (smaller, faster)

- Enable HTTPS/TLS.\scripts\preload-model.ps1 -ModelName "phi3.5"

- Use Private AKS cluster

- Implement network policies# Download Llama-3.1-70B (requires A100 GPU)

- Enable Azure Policy.\scripts\preload-model.ps1 -ModelName "llama3.1:70b"

- Add monitoring and logging```

- Implement secret rotation

### **Cleanup**

## 📚 Learn More

```powershell

- Ollama: https://ollama.com# Delete everything (Kubernetes + Azure resources)

- Open-WebUI: https://openwebui.com.\scripts\cleanup.ps1 -Prefix "kubecon"

- Azure AKS GPU: https://docs.microsoft.com/azure/aks/gpu-cluster

# Keep AKS cluster, delete only K8s resources

---.\scripts\cleanup.ps1 -Prefix "kubecon" -KeepResourceGroup



**Ready to Deploy?** Run `.\scripts\deploy.ps1` and you're 15 minutes away from your own GPU-powered LLM! 🚀# No confirmation prompt

.\scripts\cleanup.ps1 -Prefix "kubecon" -Force
```

---

## **Demo Script**

For booth presentations at KubeCon, follow the **5-minute guided script**:

📄 **[docs/demo-script.md](docs/demo-script.md)**

**Key Talking Points:**
1. Azure Files Premium provides low-latency model loading
2. ReadWriteMany enables horizontal LLM scaling
3. CSI driver = native Kubernetes experience
4. Pod restarts don't require model re-downloads
5. Production-ready with monitoring and security

---

## **Cost Estimate**

| **Resource** | **Configuration** | **Monthly Cost (USD)** |
|-------------|------------------|----------------------|
| AKS System Nodes | 2x Standard_DS3_v2 | ~$280 |
| AKS GPU Nodes | 2x Standard_NC6s_v3 (T4) | ~$1,800 |
| Azure Files Premium | 100GB | ~$25 |
| Azure Files Standard | 5GB | ~$1 |
| Load Balancer + Public IP | | ~$5 |
| Log Analytics | 5GB ingestion | ~$15 |
| Key Vault | | ~$0.03 |
| **Total** | | **~$2,126/month** |

**Cost Optimization:**
- Use spot instances for GPU nodes (60-80% savings)
- Scale down to 1 GPU node when idle
- Delete environment between demo sessions

---

## **Troubleshooting**

Common issues and solutions:

| **Problem** | **Solution** |
|------------|-------------|
| Pod stuck in Pending | Check GPU quota: `az vm list-usage --location westus2` |
| PVC not binding | Verify CSI driver: `kubectl get pods -n kube-system \| Select-String "csi-azurefile"` |
| Model download fails | Check Hugging Face token in Key Vault |
| Slow inference | Verify GPU allocation: `kubectl exec -n ollama ollama-0 -- nvidia-smi` |
| LoadBalancer IP pending | Wait 3-5 minutes or check subscription quota |

📄 **Full troubleshooting guide:** [docs/troubleshooting.md](docs/troubleshooting.md)

---

## **Technical Details**

### **Storage Performance**

**Azure Files Premium (100GB):**
- **IOPS:** Up to 100,000
- **Throughput:** Up to 10 GB/s
- **Latency:** <10ms (99th percentile)
- **Protocol:** SMB 3.0 with encryption

**Model Load Times (from cold start):**
- Phi-3.5 (2.3GB): 4-6 seconds
- Llama-3.1-8B (4.7GB): 8-12 seconds
- Llama-3.1-70B (40GB): 60-90 seconds

### **GPU Specifications**

**Standard_NC6s_v3 (T4):**
- GPU: 1x NVIDIA Tesla T4 (16GB VRAM)
- CPU: 6 vCPU (Intel Xeon E5-2690 v4)
- RAM: 112GB
- Storage: 736GB NVMe SSD (local)

**Standard_NC24ads_A100_v4 (A10):**
- GPU: 1x NVIDIA A100 (80GB VRAM)
- CPU: 24 vCPU (AMD EPYC 7V12)
- RAM: 220GB
- Storage: 1.8TB NVMe SSD (local)

### **Scalability**

**Horizontal Scaling (Multiple Ollama Replicas):**
```yaml
# ollama-statefulset.yaml
spec:
  replicas: 3  # Scale from 1 to 3
```

**Behavior:**
- All replicas share same Azure Files PVC (ReadWriteMany)
- No model duplication = cost savings
- Load balanced via Service

---

## **Resources**

### **Documentation**
- [Azure Files CSI Driver](https://github.com/kubernetes-sigs/azurefile-csi-driver)
- [AKS GPU Node Pools](https://learn.microsoft.com/azure/aks/gpu-cluster)
- [Ollama Documentation](https://github.com/ollama/ollama)
- [Open-WebUI](https://github.com/open-webui/open-webui)

### **Related Demos**
- [Azure ML on AKS](https://github.com/Azure-Samples/azureml-examples)
- [Ray on AKS](https://github.com/Azure/AKS-Construction)
- [KubeFlow on Azure](https://www.kubeflow.org/docs/azure/)

### **Support**
- Azure Support: https://aka.ms/azuresupport
- AKS Issues: https://github.com/Azure/AKS/issues
- CSI Driver Issues: https://github.com/kubernetes-sigs/azurefile-csi-driver/issues

---

## **Security Considerations**

### **Implemented**
- ✅ Secrets stored in Azure Key Vault (not Git)
- ✅ Managed Identity for Key Vault access
- ✅ RBAC on AKS cluster (Azure AD integration)
- ✅ Encryption at rest (Azure Files default)
- ✅ Encryption in transit (SMB 3.0)
- ✅ Network isolation (ClusterIP for Ollama)

### **Production Hardening (TODO)**
- [ ] Private AKS cluster (no public API server)
- [ ] Azure Firewall for egress filtering
- [ ] Network policies (restrict pod-to-pod traffic)
- [ ] Pod Security Standards (restricted mode)
- [ ] Image scanning (Defender for Containers)
- [ ] TLS for WebUI (cert-manager + Let's Encrypt)

---

## **Contributing**

This is a demo project for KubeCon NA 2025. Feedback and improvements welcome!

**Contact:** Azure Files Team @ Microsoft Booth

---

## **License**

MIT License - See individual component licenses:
- Ollama: MIT
- Open-WebUI: MIT
- Azure Files CSI Driver: Apache 2.0

---

**Enjoy the demo! 🚀**
