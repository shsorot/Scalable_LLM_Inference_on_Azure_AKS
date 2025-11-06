# Complete Demo Guide - Scalable LLM Inference on Azure AKS

This guide walks you through a complete demonstration of the LLM platform, from deployment to stress testing and resiliency verification.

---

## Table of Contents

1. [Deployment Options](#1-deployment-options)
2. [Launch Application & Grafana Dashboard](#2-launch-application--grafana-dashboard)
3. [Admin Setup & User Management](#3-admin-setup--user-management)
4. [GPU Stress Testing with Benchmarks](#4-gpu-stress-testing-with-benchmarks)
5. [Resiliency Demonstration](#5-resiliency-demonstration)

---

## 1. Deployment Options

The platform supports two storage backends for model storage, each with different cost/performance characteristics.

### Option A: Azure Files Premium (Default - Best Performance)

**Characteristics:**
- **Performance**: Sub-10ms latency, high throughput
- **Cost**: ~$200/month for 1TB
- **Best For**: Production workloads requiring consistent performance
- **Access Mode**: ReadWriteMany (RWX) - multiple pods can read/write simultaneously

**Deploy Command:**

```powershell
# Clone the repository
git clone https://github.com/shsorot/Scalable_LLM_Inference_on_Azure_AKS.git
cd Scalable_LLM_Inference_on_Azure_AKS

# Deploy with Azure Files Premium (default)
.\scripts\deploy.ps1 `
    -Prefix "demo" `
    -Location "westus2" `
    -HuggingFaceToken "hf_xxxxxxxxxxxxxxxxxxxxx" `
    -StorageBackend "AzureFiles"
```

### Option B: Azure Blob Storage with BlobFuse2 (Cost Optimized)

**Characteristics:**
- **Performance**: Streaming mode, slightly higher latency
- **Cost**: ~$26/month for 1TB (87% cheaper than Azure Files)
- **Best For**: Development, testing, cost-sensitive scenarios
- **Access Mode**: ReadWriteMany via BlobFuse2 driver

**Deploy Command:**

```powershell
# Deploy with Azure Blob Storage
.\scripts\deploy.ps1 `
    -Prefix "demo" `
    -Location "westus2" `
    -HuggingFaceToken "hf_xxxxxxxxxxxxxxxxxxxxx" `
    -StorageBackend "BlobStorage"
```

### Deployment Timeline

| Step | Duration | What's Happening |
|------|----------|------------------|
| Azure Infrastructure | 8-10 min | AKS cluster, PostgreSQL, Storage, Key Vault |
| Kubernetes Resources | 2-3 min | Namespaces, PVCs, Services, Deployments |
| Model Pre-loading | 5-7 min | Downloading 6 models (~34GB total) |
| Monitoring Stack | 2-3 min | Prometheus + Grafana deployment |
| **Total** | **15-20 min** | Complete deployment |

### What Gets Deployed

**Infrastructure:**
- AKS Cluster (Kubernetes 1.31+)
  - 2x GPU nodes (NC4as_T4_v3 with NVIDIA T4)
  - 2x System nodes (Standard_D2s_v3)
- Azure PostgreSQL Flexible Server with PGVector extension
- Azure Storage (Files or Blob based on choice)
- Azure Key Vault for secrets management

**Applications:**
- Ollama LLM server (StatefulSet with GPU scheduling)
- Open-WebUI chat interface (3 replicas for HA)
- NVIDIA Device Plugin for GPU support
- DCGM Exporter for GPU metrics

**Monitoring:**
- Prometheus (7-day retention, 20GB storage)
- Grafana with pre-configured dashboards
- Custom metrics for GPU-based autoscaling

**Pre-loaded Models (6 total, ~34GB):**
- `phi3.5` - 2.3 GB (Microsoft, fast inference)
- `gemma2:2b` - 1.6 GB (Google, efficient small model)
- `llama3.1:8b` - 4.7 GB (Meta, balanced performance)
- `mistral:7b` - 4.1 GB (Mistral AI, good general purpose)
- `gpt-oss` - 13 GB (Large model, high quality)
- `deepseek-r1` - 8 GB (DeepSeek, reasoning focused)

---

## 2. Launch Application & Grafana Dashboard

After deployment completes, you'll see a summary with URLs and credentials.

### Access Open-WebUI

**Get the External IP:**

```powershell
# Get Open-WebUI service IP
kubectl get svc open-webui -n ollama

# Expected output:
# NAME         TYPE           CLUSTER-IP      EXTERNAL-IP      PORT(S)        AGE
# open-webui   LoadBalancer   10.100.123.45   20.123.45.67    80:31234/TCP   10m
```

**Access the Application:**

1. Open browser to: `http://<EXTERNAL-IP>`
2. You should see the Open-WebUI login/signup page

### Access Grafana Dashboard

**Get Grafana External IP:**

```powershell
# Get Grafana service IP
kubectl get svc -n monitoring

# Look for:
# NAME                                  TYPE           CLUSTER-IP      EXTERNAL-IP      PORT(S)
# monitoring-grafana                    LoadBalancer   10.100.234.56   20.234.56.78    80:32001/TCP
```

**Login to Grafana:**

1. Open browser to: `http://<GRAFANA-EXTERNAL-IP>`
2. Username: `admin`
3. Password: Retrieved from Key Vault or deployment output

**Retrieve Grafana Password:**

```powershell
# Get password from Key Vault (replace <prefix> with your deployment prefix)
$keyVaultName = "<prefix>-kv-<random>"

# List Key Vaults in your resource group to find the exact name
az keyvault list --resource-group "<prefix>-rg" --query "[].name" -o table

# Get Grafana password
az keyvault secret show --vault-name $keyVaultName --name "grafana-admin-password" --query value -o tsv
```

### Import Pre-configured Dashboards

The deployment includes two dashboards:

**1. GPU Monitoring Dashboard** (`dashboards/gpu-monitoring.json`)

Shows:
- GPU utilization percentage
- GPU memory usage (used/total)
- GPU temperature
- Power consumption
- Active processes

**2. LLM Platform Overview** (`dashboards/llm-platform-overview.json`)

Shows:
- Request rates and throughput
- Ollama pod metrics (CPU, memory, GPU)
- Open-WebUI replica status
- Autoscaling events
- Model inference latency

**Import Dashboards:**

1. In Grafana, go to **Dashboards** → **Import**
2. Click **Upload JSON file**
3. Select `dashboards/gpu-monitoring.json` → **Import**
4. Repeat for `dashboards/llm-platform-overview.json`

---

## 3. Admin Setup & User Management

Open-WebUI provides a flexible authentication and authorization system.

### Create Admin Account (First User)

The **first user** to sign up automatically becomes the admin.

**Steps:**

1. Navigate to `http://<EXTERNAL-IP>`
2. Click **Sign up** button
3. Enter:
   - **Name**: Your display name
   - **Email**: admin@example.com
   - **Password**: Choose a secure password
4. Click **Create Account**
5. You are now logged in as the admin user

**Admin Privileges:**
- Access to admin panel
- User management
- Model visibility settings
- System configuration

### Enable Public Sign-up

By default, new user signups may require admin approval. To allow anyone to sign up:

**Via Environment Variable (Recommended):**

Edit `k8s/07-webui-deployment.yaml`:

```yaml
env:
  - name: WEBUI_AUTH
    value: "True"  # Keep authentication enabled

  # Add this to allow public signups without approval
  - name: ENABLE_SIGNUP
    value: "True"

  # Optional: Disable admin approval requirement
  - name: DEFAULT_USER_ROLE
    value: "user"  # New users get 'user' role by default
```

Apply the changes:

```powershell
kubectl apply -f k8s/07-webui-deployment.yaml
kubectl rollout restart deployment/open-webui -n ollama
```

**Via Admin Panel:**

1. Login as admin
2. Go to **Admin Panel** (gear icon → Admin Panel)
3. Navigate to **Settings** → **General**
4. Enable **Allow user signups**
5. Optionally disable **Require admin approval for new signups**
6. Click **Save**

### Make Models Public (Available to All Users)

Models are already configured as public via environment variables:

```yaml
# In k8s/07-webui-deployment.yaml
env:
  - name: ENABLE_MODEL_FILTER
    value: "False"  # All models available to all users

  - name: BYPASS_MODEL_ACCESS_CONTROL
    value: "True"   # No per-user model restrictions
```

**Verify Model Visibility:**

1. Login as any user
2. Click the **model dropdown** in the chat interface
3. All 6 pre-loaded models should appear:
   - phi3.5
   - gemma2:2b
   - llama3.1:8b
   - mistral:7b
   - gpt-oss:latest
   - deepseek-r1:latest

**Alternative: Manual Model Permissions (If needed)**

If you need to grant specific users access to specific models:

1. Login as admin
2. Go to **Admin Panel** → **Models**
3. For each model:
   - Click **Edit**
   - Under **Access Control**, select users or groups
   - Set **Public** toggle to make it available to everyone
4. Click **Save**

### Approve User Sign-up Requests

If admin approval is enabled:

**Steps:**

1. Login as admin
2. Go to **Admin Panel** → **Users**
3. You'll see pending requests with status **Pending Approval**
4. Review user details
5. Click **Approve** or **Deny**
6. Approved users will receive email notification (if SMTP configured)

**Bulk Approval:**

1. Select multiple pending users (checkbox)
2. Click **Actions** → **Approve Selected**

### User Roles

| Role | Permissions |
|------|-------------|
| **Admin** | Full system access, user management, model management |
| **User** | Chat with models, upload documents, manage own data |
| **Pending** | Awaiting admin approval (if required) |

---

## 4. GPU Stress Testing with Benchmarks

The platform includes two stress testing scripts for GPU validation.

### Prerequisites

1. Ensure deployment is complete
2. Models are pre-loaded (verify with `kubectl exec -n ollama ollama-0 -- ollama list`)
3. Open a PowerShell terminal in the project root directory

### Script 1: Simple Stress Test (Batch-Based)

**Purpose:** Run a fixed number of requests with configurable concurrency.

**Location:** `benchmarks/simple-stress-test.ps1`

**Basic Usage:**

```powershell
# Run 100 requests with 5 concurrent connections
.\benchmarks\simple-stress-test.ps1 -Concurrent 5 -TotalRequests 100 -Model "tinyllama"
```

**Parameters:**

| Parameter | Default | Description |
|-----------|---------|-------------|
| `-Concurrent` | 5 | Number of simultaneous requests |
| `-TotalRequests` | 100 | Total requests to send |
| `-Model` | tinyllama | Model name to test |
| `-OllamaUrl` | http://localhost:11434 | Ollama API endpoint |

**Example Test Scenarios:**

```powershell
# Light Load - Test basic GPU functionality
.\benchmarks\simple-stress-test.ps1 -Concurrent 3 -TotalRequests 50 -Model "phi3.5"

# Medium Load - Test sustained performance
.\benchmarks\simple-stress-test.ps1 -Concurrent 8 -TotalRequests 200 -Model "llama3.1:8b"

# Heavy Load - Test large model under stress
.\benchmarks\simple-stress-test.ps1 -Concurrent 10 -TotalRequests 300 -Model "gpt-oss:latest"
```

**Expected Output:**

```
=== Ollama Stress Test ===
Model: llama3.1:8b
Concurrent: 5
Total Requests: 100
Ollama URL: http://localhost:11434

Starting port-forward to Ollama service...
Testing connection to Ollama...
[OK] Connected to Ollama
Available models: phi3.5, llama3.1:8b, mistral:7b, gemma2:2b, gpt-oss:latest, deepseek-r1:latest

Warming up GPU with a test query...
[OK] GPU warmed up successfully

=== Starting Stress Test ===
Processing batch 1/20 (5 requests)...
Processing batch 2/20 (5 requests)...
...

=== Final Statistics ===
Total Requests: 100
Successful: 100
Failed: 0
Total Tokens Generated: 20,000
Average Request Duration: 1,850ms
Requests per Second: 1.2
Tokens per Second: 185.3
Test Duration: 83.4 seconds

=== Stress Test Complete ===
```

### Script 2: GPU Stress Test (Time-Based)

**Purpose:** Continuously stress GPU for a specific duration with real-time statistics.

**Location:** `benchmarks/gpu-stress-test.ps1`

**Basic Usage:**

```powershell
# Run continuous stress for 2 minutes with 5 concurrent workers
.\benchmarks\gpu-stress-test.ps1 -ConcurrentRequests 5 -DurationSeconds 120 -Model "llama3.1:8b"
```

**Parameters:**

| Parameter | Default | Description |
|-----------|---------|-------------|
| `-ConcurrentRequests` | 5 | Number of concurrent workers |
| `-DurationSeconds` | 120 | Test duration in seconds |
| `-Model` | tinyllama | Model name to test |
| `-OllamaUrl` | http://localhost:11434 | Ollama API endpoint |

**Example Test Scenarios:**

```powershell
# Short Burst - Quick validation
.\benchmarks\gpu-stress-test.ps1 -ConcurrentRequests 3 -DurationSeconds 60 -Model "phi3.5"

# Standard Load - 5 minutes sustained
.\benchmarks\gpu-stress-test.ps1 -ConcurrentRequests 8 -DurationSeconds 300 -Model "llama3.1:8b"

# Heavy Load - Large model stress test
.\benchmarks\gpu-stress-test.ps1 -ConcurrentRequests 10 -DurationSeconds 600 -Model "gpt-oss:latest"
```

**Expected Output:**

```
=== Ollama GPU Stress Test ===
Model: llama3.1:8b
Concurrent Requests: 5
Duration: 120 seconds
Ollama URL: http://localhost:11434

Starting port-forward to Ollama service...
Testing connection to Ollama...
[OK] Connected to Ollama

Warming up GPU with model load...
[OK] Model loaded on GPU

=== Starting GPU Stress Test ===
Monitor your Grafana dashboard now!

[00:05] Requests: 8 (OK:8 FAIL:0) | Tokens: 1,600 | Avg: 1,850ms | Rate: 1.6 req/s, 320 tok/s
[00:10] Requests: 15 (OK:15 FAIL:0) | Tokens: 3,000 | Avg: 1,820ms | Rate: 1.5 req/s, 300 tok/s
[00:15] Requests: 23 (OK:23 FAIL:0) | Tokens: 4,600 | Avg: 1,805ms | Rate: 1.5 req/s, 307 tok/s
...
[02:00] Requests: 144 (OK:144 FAIL:0) | Tokens: 28,800 | Avg: 1,795ms | Rate: 1.2 req/s, 240 tok/s

Waiting for workers to complete...

=== Final Statistics ===
Total Requests: 144
Successful: 144
Failed: 0
Total Tokens Generated: 28,800
Average Request Duration: 1,795ms
Requests per Second: 1.2
Tokens per Second: 240
Test Duration: 120.3 seconds

=== GPU Stress Test Complete ===
Check nvidia-smi for GPU metrics:
  kubectl exec -n ollama ollama-0 -- nvidia-smi
```

### Monitor GPU Usage in Grafana

**During the stress test:**

1. Open Grafana dashboard: `http://<GRAFANA-IP>`
2. Navigate to **GPU Monitoring** dashboard
3. Watch real-time metrics:
   - **GPU Utilization**: Should increase to 60-90%
   - **GPU Memory**: Will show model loaded (2-13GB depending on model)
   - **GPU Temperature**: Should rise from idle (~30°C) to active (~50-70°C)
   - **Power Draw**: Will increase from idle (~9W) to active (~30-50W)

**Check GPU State via kubectl:**

```powershell
# View nvidia-smi output
kubectl exec -n ollama ollama-0 -- nvidia-smi

# Expected output during load:
# +-----------------------------------------------------------------------------+
# | NVIDIA-SMI 570.172.08   Driver Version: 570.172.08   CUDA Version: 12.8  |
# |-------------------------------+----------------------+----------------------+
# | GPU  Name        Persistence-M| Bus-Id        Disp.A | Volatile Uncorr. ECC |
# | Fan  Temp  Perf  Pwr:Usage/Cap|         Memory-Usage | GPU-Util  Compute M. |
# |===============================+======================+======================|
# |   0  Tesla T4            On   | 00000001:00:00.0 Off |                    0 |
# | N/A   57C    P0    28W /  70W |   5003MiB / 16384MiB |     75%      Default |
# +-------------------------------+----------------------+----------------------+
#
# +-----------------------------------------------------------------------------+
# | Processes:                                                                  |
# |  GPU   GI   CI        PID   Type   Process name                  GPU Memory |
# |        ID   ID                                                   Usage      |
# |=============================================================================|
# |    0   N/A  N/A     12345      C   /usr/bin/ollama                 5001MiB |
# +-----------------------------------------------------------------------------+

# View continuous GPU monitoring (updates every 2 seconds)
kubectl exec -n ollama ollama-0 -- watch -n 2 nvidia-smi
```

### Expected Performance Metrics (Tesla T4)

| Metric | Idle | Light Load | Heavy Load |
|--------|------|------------|------------|
| **GPU Utilization** | 0% | 40-60% | 70-95% |
| **GPU Memory** | 0 MiB | 2-5 GB | 5-13 GB |
| **Temperature** | 30-35°C | 45-55°C | 55-70°C |
| **Power Draw** | 9-12W | 20-35W | 35-55W |
| **Tokens/Second** | N/A | 150-250 | 180-220 |
| **Requests/Second** | N/A | 1-2 | 0.8-1.5 |

### Troubleshooting

**Issue: GPU memory not increasing**

```powershell
# Check if Ollama is using GPU
kubectl exec -n ollama ollama-0 -- nvidia-smi

# If GPU shows 0 MiB usage, check Ollama logs
kubectl logs -n ollama ollama-0 -f

# Verify GPU resources are allocated
kubectl describe pod -n ollama ollama-0 | grep -A5 "nvidia.com/gpu"
```

**Issue: Port-forward fails**

```powershell
# Kill existing port-forwards
Get-Process -Name kubectl | Where-Object {$_.CommandLine -like "*port-forward*"} | Stop-Process -Force

# Re-run the script
.\benchmarks\simple-stress-test.ps1 -Concurrent 5 -TotalRequests 100
```

**Issue: High failure rate**

```powershell
# Check Ollama pod health
kubectl get pods -n ollama

# Check for resource constraints
kubectl top pods -n ollama

# Reduce concurrency
.\benchmarks\simple-stress-test.ps1 -Concurrent 3 -TotalRequests 50
```

---

## 5. Resiliency Demonstration

Demonstrate the platform's high availability and fault tolerance by simulating pod failures during active inference.

### Scenario: Kill Pods During Complex Query

This demonstrates:
- StatefulSet/Deployment resilience
- Kubernetes automatic pod recovery
- Shared storage benefits (model persistence)
- Multi-replica Open-WebUI for zero downtime

### Prerequisites

1. Ensure both Ollama and Open-WebUI pods are running
2. Open Grafana dashboard for monitoring
3. Open the Open-WebUI chat interface in a browser

### Step 1: Start a Complex Query

**In the Open-WebUI:**

1. Select a large model: `gpt-oss:latest` (13GB model)
2. Enter a complex prompt that will take 30-60 seconds to complete:

```
Please write a comprehensive 2000-word essay explaining the architecture of Kubernetes,
including details about the control plane, worker nodes, etcd, API server, scheduler,
controller manager, kubelet, kube-proxy, and how they all work together. Include
examples of how pod scheduling works and how services provide networking.
```

3. Click **Send** and watch the response start streaming

### Step 2: Kill Open-WebUI Pod During Response

**Open a new PowerShell terminal:**

```powershell
# Get current Open-WebUI pods
kubectl get pods -n ollama -l app=open-webui

# Example output:
# NAME                          READY   STATUS    RESTARTS   AGE
# open-webui-6c9c8d558f-abc123  1/1     Running   0          10m
# open-webui-6c9c8d558f-def456  1/1     Running   0          10m
# open-webui-6c9c8d558f-ghi789  1/1     Running   0          10m

# Delete one pod while response is streaming
kubectl delete pod open-webui-6c9c8d558f-abc123 -n ollama

# Watch pod recovery
kubectl get pods -n ollama -l app=open-webui -w
```

**What Happens:**

1. **Immediate Impact**:
   - The browser connection may briefly pause or show reconnecting
   - LoadBalancer redirects traffic to remaining replicas (2 of 3 still healthy)

2. **User Experience**:
   - If using the killed pod's connection: Session may reset, prompt response lost
   - If using other replicas: **No interruption** - response continues normally
   - New users: Automatically routed to healthy pods

3. **Recovery**:
   - Kubernetes immediately creates a new Open-WebUI pod
   - New pod pulls image (~30 seconds)
   - Pod becomes Ready and joins LoadBalancer pool (~1-2 minutes)
   - Service returns to 3/3 replicas

**Verify Recovery:**

```powershell
# Check pod status
kubectl get pods -n ollama -l app=open-webui

# Expected output after 1-2 minutes:
# NAME                          READY   STATUS    RESTARTS   AGE
# open-webui-6c9c8d558f-abc123  1/1     Running   0          45s   <- New pod
# open-webui-6c9c8d558f-def456  1/1     Running   0          10m
# open-webui-6c9c8d558f-ghi789  1/1     Running   0          10m
```

### Step 3: Kill Ollama Pod During Response

**This is more dramatic - tests StatefulSet recovery and shared storage.**

**Start a new complex query:**

```
Explain the entire history of artificial intelligence from 1950 to 2025, including
key milestones, important researchers, breakthrough algorithms, and the evolution
from symbolic AI to modern deep learning and large language models. Include details
about the AI winters and recent advances.
```

**While response is streaming:**

```powershell
# Get Ollama pod
kubectl get pods -n ollama -l app=ollama

# Example output:
# NAME       READY   STATUS    RESTARTS   AGE
# ollama-0   1/1     Running   0          20m

# Delete the Ollama pod
kubectl delete pod ollama-0 -n ollama --force --grace-period=0

# Watch recovery (Ollama is a StatefulSet, so it recreates with same name)
kubectl get pods -n ollama -l app=ollama -w
```

**What Happens:**

1. **Immediate Impact**:
   - Current inference request **terminates immediately**
   - All Open-WebUI connections to Ollama fail
   - Users see error: "Connection to Ollama lost" or timeout

2. **Recovery Process**:
   - Kubernetes StatefulSet controller detects pod deletion
   - Immediately creates new `ollama-0` pod (same name, same identity)
   - Pod scheduled to GPU node (~10 seconds)
   - Container starts, mounts existing Azure Files volume with models (~5 seconds)
   - **Models already available** (no re-download needed - thanks to shared storage!)
   - Ollama API becomes ready (~15-20 seconds total)

3. **User Recovery**:
   - Refresh the Open-WebUI page or start a new query
   - Select model and try the same prompt again
   - **Response resumes** - model still loaded in storage, no re-download

**Verify Recovery:**

```powershell
# Check Ollama pod status
kubectl get pods -n ollama -l app=ollama

# Expected output after ~30 seconds:
# NAME       READY   STATUS    RESTARTS   AGE
# ollama-0   1/1     Running   0          28s   <- New pod, same name

# Verify models are still available (no re-download!)
kubectl exec -n ollama ollama-0 -- ollama list

# Expected output:
# NAME              ID            SIZE      MODIFIED
# phi3.5:latest     abc123def     2.3 GB    5 minutes ago
# llama3.1:8b       def456ghi     4.7 GB    5 minutes ago
# mistral:7b        ghi789jkl     4.1 GB    5 minutes ago
# gemma2:2b         jkl012mno     1.6 GB    5 minutes ago
# gpt-oss:latest    mno345pqr     13 GB     5 minutes ago
# deepseek-r1       pqr678stu     8 GB      5 minutes ago

# Check GPU is being used
kubectl exec -n ollama ollama-0 -- nvidia-smi
```

### Step 4: Monitor Recovery in Grafana

**During and after pod failures:**

1. Open **LLM Platform Overview** dashboard
2. Observe:
   - **Pod Count Drop**: Ollama or Open-WebUI replica count drops briefly
   - **Request Rate**: Temporary dip in request rate during Ollama restart
   - **Recovery Spike**: Pod count returns to normal
   - **GPU Memory**: Remains stable (model persisted in shared storage)

3. Check **GPU Monitoring** dashboard:
   - GPU utilization drops to 0% during Ollama pod restart
   - GPU memory may drop briefly as process restarts
   - Temperature decreases during idle period
   - All metrics return to normal when pod is Ready

### Step 5: Verify High Availability Claims

**Open-WebUI Zero-Downtime Test:**

```powershell
# Run continuous requests while deleting pods
# Terminal 1: Start stress test
.\benchmarks\simple-stress-test.ps1 -Concurrent 3 -TotalRequests 200 -Model "llama3.1:8b"

# Terminal 2: Delete Open-WebUI pods one by one
kubectl delete pod -n ollama -l app=open-webui --field-selector status.phase=Running --force --grace-period=0
```

**Expected Result:**
- Stress test continues with **minimal failures** (1-3 requests might timeout)
- 97-99% success rate even during pod deletions
- LoadBalancer seamlessly routes to healthy replicas

**Ollama Stateful Recovery Test:**

```powershell
# Terminal 1: Get list of models BEFORE deletion
kubectl exec -n ollama ollama-0 -- ollama list > before.txt

# Terminal 2: Delete Ollama pod
kubectl delete pod ollama-0 -n ollama --force --grace-period=0

# Terminal 3: Wait for recovery and check models AFTER
kubectl wait --for=condition=ready pod/ollama-0 -n ollama --timeout=120s
kubectl exec -n ollama ollama-0 -- ollama list > after.txt

# Terminal 4: Compare - should be identical!
Compare-Object (Get-Content before.txt) (Get-Content after.txt)

# Expected output: No differences (both files identical)
```

### Step 6: Kill Both Simultaneously (Ultimate Chaos Test)

**WARNING: This will cause temporary service outage (30-60 seconds)**

```powershell
# Delete ALL Open-WebUI pods
kubectl delete pods -n ollama -l app=open-webui --force --grace-period=0

# Immediately delete Ollama pod
kubectl delete pod ollama-0 -n ollama --force --grace-period=0

# Watch recovery
kubectl get pods -n ollama -w
```

**What Happens:**

1. **Total Service Outage**: All inference requests fail for ~30-60 seconds
2. **Kubernetes Responds**:
   - Open-WebUI Deployment immediately creates 3 new pods (parallel)
   - Ollama StatefulSet creates new ollama-0 pod
3. **Recovery Order**:
   - Ollama comes up first (~30 seconds)
   - Open-WebUI pods become Ready (~45-60 seconds)
   - Service fully restored

**Verify Full Recovery:**

```powershell
# Check all pods are Running
kubectl get pods -n ollama

# Expected output:
# NAME                          READY   STATUS    RESTARTS   AGE
# ollama-0                      1/1     Running   0          1m
# open-webui-6c9c8d558f-xxxxx   1/1     Running   0          1m
# open-webui-6c9c8d558f-yyyyy   1/1     Running   0          1m
# open-webui-6c9c8d558f-zzzzz   1/1     Running   0          1m

# Test inference
kubectl exec -n ollama ollama-0 -- ollama run llama3.1:8b "Hello, are you working?"

# Access Open-WebUI and verify chat works
Start-Process "http://$(kubectl get svc open-webui -n ollama -o jsonpath='{.status.loadBalancer.ingress[0].ip}')"
```

### Key Takeaways from Resiliency Demo

| Aspect | Demonstration | Technology Enabler |
|--------|---------------|-------------------|
| **Zero Downtime for Web Tier** | Delete Open-WebUI pods → service continues | Kubernetes Deployment (3 replicas) + LoadBalancer |
| **Fast Recovery for Inference** | Delete Ollama pod → back online in 30s | StatefulSet + Azure Files Premium (persistent models) |
| **No Data Loss** | Pod deletion → models still available | Shared storage (ReadWriteMany PVC) |
| **Automatic Healing** | Kubernetes self-heals all failures | Kubernetes controllers (Deployment, StatefulSet) |
| **Session Resilience** | Conversation state persists | PostgreSQL backend for user data and chat history |

---

## Bonus: Advanced Demo Scenarios

### Scenario 1: Autoscaling Under Load

**Demonstrate GPU-based Horizontal Pod Autoscaling:**

```powershell
# Check current HPA status
kubectl get hpa -n ollama

# Expected output:
# NAME         REFERENCE           TARGETS      MINPODS   MAXPODS   REPLICAS   AGE
# ollama-hpa   StatefulSet/ollama  25%/80%      1         3         1          10m

# Generate sustained load
.\benchmarks\gpu-stress-test.ps1 -ConcurrentRequests 20 -DurationSeconds 600 -Model "gpt-oss:latest"

# In another terminal, watch autoscaling
kubectl get hpa -n ollama -w

# Watch new Ollama pods being created
kubectl get pods -n ollama -w

# Expected: After GPU utilization crosses 80%, HPA scales from 1 → 2 → 3 replicas
```

### Scenario 2: Cost Optimization with Spot Instances

**Show cost savings with Azure Spot VMs:**

```powershell
# Check node pool configuration
az aks nodepool show --resource-group <prefix>-rg --cluster-name <prefix>-aks --name gpu

# Look for "scaleSetPriority": "Spot"
# This demonstrates 70-80% cost savings on GPU nodes
```

### Scenario 3: Multi-Model Performance Comparison

**Benchmark all 6 models back-to-back:**

```powershell
$models = @("phi3.5", "gemma2:2b", "llama3.1:8b", "mistral:7b", "gpt-oss:latest", "deepseek-r1:latest")

foreach ($model in $models) {
    Write-Host "`n=== Testing $model ===`n" -ForegroundColor Cyan
    .\benchmarks\simple-stress-test.ps1 -Concurrent 5 -TotalRequests 50 -Model $model
    Start-Sleep -Seconds 10
}

# Compare tokens/second across models
# Smaller models (phi3.5, gemma2:2b) = 300-400 tok/s
# Medium models (llama3.1, mistral) = 180-250 tok/s
# Large models (gpt-oss, deepseek-r1) = 120-180 tok/s
```

---

## Summary Checklist

Use this checklist during your demo:

- [ ] **Deployment**
  - [ ] Choose storage backend (Azure Files or Blob)
  - [ ] Run deploy.ps1 with correct parameters
  - [ ] Wait 15-20 minutes for complete deployment
  - [ ] Note external IPs for Open-WebUI and Grafana

- [ ] **Access & Setup**
  - [ ] Open Open-WebUI in browser
  - [ ] Create admin account (first user)
  - [ ] Verify all 6 models are available
  - [ ] Login to Grafana with admin credentials
  - [ ] Import GPU monitoring and platform dashboards

- [ ] **User Management**
  - [ ] Enable public signup (if desired)
  - [ ] Configure model visibility (already public by default)
  - [ ] Test user signup and approval workflow

- [ ] **GPU Stress Testing**
  - [ ] Run simple-stress-test.ps1 with light load
  - [ ] Monitor GPU metrics in Grafana
  - [ ] Run gpu-stress-test.ps1 with sustained load
  - [ ] Verify GPU utilization increases to 60-90%
  - [ ] Check nvidia-smi output shows process and memory

- [ ] **Resiliency**
  - [ ] Start complex query in Open-WebUI
  - [ ] Delete one Open-WebUI pod → verify minimal impact
  - [ ] Delete Ollama pod → verify fast recovery (<30s)
  - [ ] Confirm models still available (no re-download)
  - [ ] Test simultaneous deletion of all pods
  - [ ] Verify Grafana shows recovery metrics

- [ ] **Cleanup (After Demo)**
  - [ ] Run `.\scripts\cleanup.ps1 -Prefix <your-prefix>`
  - [ ] Confirm resource group deletion in Azure Portal

---

## Additional Resources

- **Architecture Details**: See `ARCHITECTURE.md`
- **Troubleshooting Guide**: See `docs/TROUBLESHOOTING-GPU-WEBUI.md`
- **Monitoring Setup**: See `docs/MONITORING.md`
- **Autoscaling Details**: See `docs/AUTOSCALING.md`
- **Benchmark Documentation**: See `benchmarks/README.md`

---

## Support

For issues or questions:
- GitHub Issues: https://github.com/shsorot/Scalable_LLM_Inference_on_Azure_AKS/issues
- Email: [Your contact]

**End of Demo Guide**
