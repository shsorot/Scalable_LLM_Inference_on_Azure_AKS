# Benchmark Scripts

This folder contains scripts to measure model download and load performance in different scenarios.

## Prerequisites

- **PowerShell 7.x** (Windows/Linux/macOS)
- **Access to Ollama API endpoint** (e.g., via port-forward or LoadBalancer IP)
- **kubectl** configured (for port-forwarding if needed)

## Scripts

### 1. `single-user-benchmark.ps1`

Measures single user downloading and loading a single model.

**What it measures:**
- Model download time (pull from registry)
- Cold start load time (first inference)
- Warm start load time (subsequent inference)
- Token generation throughput

**Usage:**

```powershell
# Via port-forward
kubectl port-forward -n ollama service/ollama 11434:11434

# Run benchmark
.\single-user-benchmark.ps1 -OllamaEndpoint "http://localhost:11434" -Model "llama3.1:8b"

# Via LoadBalancer IP
.\single-user-benchmark.ps1 -OllamaEndpoint "http://20.54.123.45:11434" -Model "phi3.5"
```

**Parameters:**
- `-OllamaEndpoint` (required): Ollama API endpoint URL
- `-Model` (optional): Model name (default: `llama3.1:8b`)
- `-OutputFile` (optional): JSON output file (default: `single-user-results.json`)

**Output:**
```json
{
  "Timestamp": "2025-10-31 14:30:00",
  "Model": "llama3.1:8b",
  "OllamaEndpoint": "http://localhost:11434",
  "Measurements": {
    "DownloadTimeSeconds": 45.67,
    "LoadTimeColdSeconds": 18.32,
    "LoadTimeWarmSeconds": 2.14,
    "TotalTimeSeconds": 63.99,
    "TokensPerSecond": 42.5,
    "DownloadStatus": "Success",
    "LoadStatus": "Success"
  }
}
```

---

### 2. `tokens-per-second-benchmark.ps1`

Measures inference throughput (tokens/second) performance across different configurations.

**What it measures:**
- Tokens per second for different models (small to large)
- Performance impact of prompt length (short, medium, long, very long)
- Throughput under concurrent requests
- Statistical variance and consistency
- Model efficiency comparison

**Usage:**

```powershell
# Via port-forward - test default models
kubectl port-forward -n ollama service/ollama 11434:11434
.\tokens-per-second-benchmark.ps1 -OllamaEndpoint "http://localhost:11434"

# Test specific models with concurrent requests
.\tokens-per-second-benchmark.ps1 `
    -OllamaEndpoint "http://localhost:11434" `
    -Models @("phi3.5", "llama3.1:8b") `
    -ConcurrentRequests 3

# Test all prompt lengths
.\tokens-per-second-benchmark.ps1 `
    -OllamaEndpoint "http://localhost:11434" `
    -PromptLengths @("All") `
    -MeasurementRuns 10
```

**Parameters:**
- `-OllamaEndpoint` (required): Ollama API endpoint URL
- `-Models` (optional): Array of models to test (default: `phi3.5`, `gemma2:2b`, `llama3.1:8b`)
- `-PromptLengths` (optional): Test prompt lengths: `Short`, `Medium`, `Long`, `VeryLong`, `All`
- `-GenerationTokens` (optional): Target tokens to generate (default: 100)
- `-WarmupRuns` (optional): Warmup iterations (default: 2)
- `-MeasurementRuns` (optional): Measurement iterations (default: 5)
- `-ConcurrentRequests` (optional): Concurrent requests (default: 1)
- `-OutputFile` (optional): JSON output file (default: `tokens-per-second-results.json`)

**Output:**
```json
{
  "Timestamp": "2025-10-31 16:00:00",
  "Configuration": {
    "GenerationTokens": 100,
    "ConcurrentRequests": 1
  },
  "Summary": {
    "OverallAverageTokensPerSecond": 42.5,
    "OverallMinTokensPerSecond": 38.2,
    "OverallMaxTokensPerSecond": 47.8,
    "TotalTests": 9,
    "TotalSamples": 45
  },
  "ModelResults": [
    {
      "Model": "llama3.1:8b",
      "PromptResults": [
        {
          "PromptLength": "Short",
          "Statistics": {
            "AverageTokensPerSecond": 43.2,
            "StdDevTokensPerSecond": 1.8
          }
        }
      ]
    }
  ]
}
```

---

### 3. `multi-user-benchmark.ps1`

Simulates multiple concurrent users downloading and loading different models simultaneously.

**What it measures:**
- Overall duration for all concurrent operations
- Individual download times per user/model
- Individual load times per user/model
- Resource contention impact
- Success rate
- Statistical summary (average, min, max)

**Usage:**

```powershell
# Via port-forward
kubectl port-forward -n ollama service/ollama 11434:11434

# Run with 3 concurrent users (default models)
.\multi-user-benchmark.ps1 -OllamaEndpoint "http://localhost:11434" -ConcurrentUsers 3

# Run with 5 users and custom models
.\multi-user-benchmark.ps1 `
    -OllamaEndpoint "http://localhost:11434" `
    -ConcurrentUsers 5 `
    -Models @("phi3.5", "gemma2:2b", "mistral:7b", "llama3.1:8b")
```

**Parameters:**
- `-OllamaEndpoint` (required): Ollama API endpoint URL
- `-ConcurrentUsers` (optional): Number of concurrent users (default: 3)
- `-Models` (optional): Array of model names (default: `phi3.5`, `gemma2:2b`, `mistral:7b`, `llama3.1:8b`)
- `-OutputFile` (optional): JSON output file (default: `multi-user-results.json`)

**Output:**
```json
{
  "Timestamp": "2025-10-31 15:00:00",
  "OllamaEndpoint": "http://localhost:11434",
  "ConcurrentUsers": 3,
  "Models": ["phi3.5", "gemma2:2b", "mistral:7b"],
  "Summary": {
    "OverallDurationSeconds": 125.45,
    "TotalUsers": 3,
    "SuccessfulDownloads": 3,
    "SuccessfulLoads": 3,
    "SuccessRate": 100,
    "AverageDownloadTimeSeconds": 38.21,
    "MinDownloadTimeSeconds": 28.45,
    "MaxDownloadTimeSeconds": 52.10,
    "AverageLoadTimeSeconds": 16.78,
    "MinLoadTimeSeconds": 12.34,
    "MaxLoadTimeSeconds": 22.15,
    "AverageThroughputTokensPerSecond": 39.5
  },
  "IndividualResults": [...]
}
```

---

## Example Workflow

### Scenario 1: Compare Storage Performance

**Test Azure Files Premium:**
```powershell
# Ensure models are using Azure Files storage
kubectl get pvc -n ollama

# Run single user benchmark
.\single-user-benchmark.ps1 -OllamaEndpoint "http://localhost:11434" -Model "llama3.1:8b"
```

**Test Local Storage (if available):**
```powershell
# Modify storage class in deployment
# Re-run benchmark and compare results
```

### Scenario 2: Measure Horizontal Scaling Impact

```powershell
# Test with 1 user
.\multi-user-benchmark.ps1 -OllamaEndpoint "http://localhost:11434" -ConcurrentUsers 1

# Test with 3 users
.\multi-user-benchmark.ps1 -OllamaEndpoint "http://localhost:11434" -ConcurrentUsers 3

# Test with 5 users
.\multi-user-benchmark.ps1 -OllamaEndpoint "http://localhost:11434" -ConcurrentUsers 5

# Compare OverallDurationSeconds and success rates
```

### Scenario 3: Different Model Sizes

```powershell
# Small models
.\multi-user-benchmark.ps1 `
    -OllamaEndpoint "http://localhost:11434" `
    -Models @("phi3.5", "gemma2:2b") `
    -ConcurrentUsers 3

# Large models
.\multi-user-benchmark.ps1 `
    -OllamaEndpoint "http://localhost:11434" `
    -Models @("llama3.1:8b", "mistral:7b", "deepseek-r1") `
    -ConcurrentUsers 3
```

### Scenario 4: Measure Tokens/Second Performance

```powershell
# Compare model inference speed
.\tokens-per-second-benchmark.ps1 `
    -OllamaEndpoint "http://localhost:11434" `
    -Models @("phi3.5", "gemma2:2b", "llama3.1:8b", "mistral:7b")

# Test impact of prompt length on throughput
.\tokens-per-second-benchmark.ps1 `
    -OllamaEndpoint "http://localhost:11434" `
    -Models @("llama3.1:8b") `
    -PromptLengths @("Short", "Medium", "Long", "VeryLong") `
    -MeasurementRuns 10

# Measure throughput under concurrent load
.\tokens-per-second-benchmark.ps1 `
    -OllamaEndpoint "http://localhost:11434" `
    -Models @("llama3.1:8b") `
    -ConcurrentRequests 3 `
    -MeasurementRuns 10
```

### Scenario 5: Compare Storage Configurations

```powershell
# Baseline with Azure Files Premium
.\tokens-per-second-benchmark.ps1 -OllamaEndpoint "http://localhost:11434" -Models @("llama3.1:8b")

# Switch storage to local NVMe (if testing different infrastructure)
# Reconfigure storage class, redeploy
# Re-run benchmark

# Compare results
.\compare-results.ps1 -ResultFiles @(
    "results-azure-files\tokens-per-second-results.json",
    "results-local-nvme\tokens-per-second-results.json"
)
```

---

## Port Forwarding for Testing

If your Ollama service is not exposed via LoadBalancer:

```powershell
# Forward Ollama service to localhost
kubectl port-forward -n ollama service/ollama 11434:11434

# In another terminal, run benchmarks
.\single-user-benchmark.ps1 -OllamaEndpoint "http://localhost:11434"
```

---

## Interpreting Results

### Single User Benchmark

- **Download Time**: Network and storage write performance
- **Load Time (Cold)**: Storage read performance + GPU initialization
- **Load Time (Warm)**: Cached model, GPU-only time
- **Tokens/Second**: GPU inference performance

### Tokens/Second Benchmark

- **Average Tokens/Second**: Primary throughput metric
  - **40-50 tok/s** = Good for T4 GPU with 7-8B models
  - **20-30 tok/s** = Expected for larger models or longer prompts
  - **<20 tok/s** = May indicate GPU contention or thermal throttling
- **Standard Deviation**: Consistency indicator
  - **<5% of average** = Stable performance
  - **>10% of average** = Variable performance, investigate resource contention
- **Prompt Length Impact**: Longer prompts → slightly lower tok/s (more context to process)
- **Concurrent Requests**: Throughput should scale linearly up to GPU saturation
  - 1 request: 45 tok/s → 3 requests: ~135 tok/s total = good
  - 1 request: 45 tok/s → 3 requests: ~90 tok/s total = GPU bottleneck

**Example Analysis:**
```text
Model: llama3.1:8b
Short prompts: 43.2 tok/s ± 1.8 (4.2% variance) ✓ Stable
Medium prompts: 41.5 tok/s ± 2.3 (5.5% variance) ✓ Good
Long prompts: 38.7 tok/s ± 4.1 (10.6% variance) ⚠ Higher variance

Interpretation: Storage I/O is not the bottleneck (variance is low).
GPU compute is the limiting factor (expected for inference).
```

### Multi-User Benchmark

- **Overall Duration**: Wall-clock time for all concurrent operations
- **Success Rate**: Reliability under concurrent load
- **Average vs Max Times**: Indicates resource contention
  - Similar times = good parallelism
  - High variance = resource bottleneck

**Example Analysis:**
```text
Single user: 45s download + 18s load = 63s total
3 concurrent users: 125s overall (not 189s) = good parallelism
Max download time: 52s (vs 45s single) = minimal contention
```

### Comparative Analysis

**Question: Does storage choice impact inference performance?**

Compare tokens/second results across storage configurations:
- Azure Files Premium: 42.5 tok/s average
- Local NVMe: 42.3 tok/s average
- Difference: 0.2 tok/s (0.5%) = **Storage is NOT the bottleneck**

The GPU compute is the limiting factor during inference, not storage I/O. Model loading happens once; inference runs for minutes/hours.

---

## Common Issues

### Timeout Errors
Models are large (2-40GB). Increase timeout if needed:
```powershell
# Scripts have 3600s timeout by default
# Check network bandwidth to Ollama service
```

### Connection Refused
```powershell
# Verify Ollama service is running
kubectl get pods -n ollama

# Verify endpoint
kubectl get svc -n ollama ollama
```

### Model Already Exists
Scripts automatically delete models before benchmarking for clean measurements.

---

## Output Files

Results are saved as JSON files in the current directory:
- `single-user-results.json`
- `multi-user-results.json`

You can specify custom output paths:
```powershell
.\single-user-benchmark.ps1 -OutputFile "../temp/benchmark-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
```

---

## Energy Efficiency Note

Per project guidelines, benchmarks are designed to be energy efficient:
- Minimal retries and polling
- Clean up models after testing
- Reuse warm connections where possible
- Avoid unnecessary API calls
