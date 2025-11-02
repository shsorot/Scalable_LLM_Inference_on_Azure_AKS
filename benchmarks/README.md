# Benchmark Suite# Benchmark Scripts



Comprehensive LLM benchmarking tool for Ollama inference testing on Azure AKS.This folder contains scripts to measure model download and load performance in different scenarios.



## Quick Start## Prerequisites



```powershell- **PowerShell 7.x** (Windows/Linux/macOS)

# 1. Start port-forward to Ollama service- **Access to Ollama API endpoint** (e.g., via port-forward or LoadBalancer IP)

kubectl port-forward -n ollama service/ollama 11434:11434- **kubectl** configured (for port-forwarding if needed)



# 2. Test connection## Scripts

.\benchmark.ps1 -Mode Connection -OllamaEndpoint "http://localhost:11434"

### 1. `single-user-benchmark.ps1`

# 3. Run benchmarks

.\benchmark.ps1 -Mode AllModels -OllamaEndpoint "http://localhost:11434"Measures single user downloading and loading a single model.



# 4. Generate HTML report**What it measures:**

.\benchmark.ps1 -Mode Report- Model download time (pull from registry)

```- Cold start load time (first inference)

- Warm start load time (subsequent inference)

## Features- Token generation throughput



- **Single Model Testing**: Measure cold start, warm start, and throughput**Usage:**

- **All Models Testing**: Automatically benchmark all available models

- **Multi-User Testing**: Simulate concurrent user load```powershell

- **Connection Testing**: Verify Ollama API connectivity# Via port-forward

- **HTML Reports**: Beautiful visual reports with performance metricskubectl port-forward -n ollama service/ollama 11434:11434

- **Result Comparison**: Compare results from specific benchmark runs

# Run benchmark

## Usage.\single-user-benchmark.ps1 -OllamaEndpoint "http://localhost:11434" -Model "llama3.1:8b"



### 1. Test Connection# Via LoadBalancer IP

.\single-user-benchmark.ps1 -OllamaEndpoint "http://20.54.123.45:11434" -Model "phi3.5"

```powershell```

.\benchmark.ps1 -Mode Connection -OllamaEndpoint "http://localhost:11434"

```**Parameters:**

- `-OllamaEndpoint` (required): Ollama API endpoint URL

### 2. Single Model Benchmark- `-Model` (optional): Model name (default: `llama3.1:8b`)

- `-OutputFile` (optional): JSON output file (default: `single-user-results.json`)

```powershell

.\benchmark.ps1 -Mode SingleModel -Model "mistral:7b" -OllamaEndpoint "http://localhost:11434"**Output:**

``````json

{

### 3. All Models Benchmark  "Timestamp": "2025-10-31 14:30:00",

  "Model": "llama3.1:8b",

```powershell  "OllamaEndpoint": "http://localhost:11434",

.\benchmark.ps1 -Mode AllModels -OllamaEndpoint "http://localhost:11434"  "Measurements": {

```    "DownloadTimeSeconds": 45.67,

    "LoadTimeColdSeconds": 18.32,

### 4. Multi-User Test    "LoadTimeWarmSeconds": 2.14,

    "TotalTimeSeconds": 63.99,

```powershell    "TokensPerSecond": 42.5,

.\benchmark.ps1 -Mode MultiUser -Model "mistral:7b" -Users 5 -OllamaEndpoint "http://localhost:11434"    "DownloadStatus": "Success",

```    "LoadStatus": "Success"

  }

### 5. Generate HTML Report}

```

```powershell

.\benchmark.ps1 -Mode Report---

```

### 2. `tokens-per-second-benchmark.ps1`

### 6. Compare Results

Measures inference throughput (tokens/second) performance across different configurations.

```powershell

.\benchmark.ps1 -Mode Compare -ResultsDir "results-20251102-192535"**What it measures:**

```- Tokens per second for different models (small to large)

- Performance impact of prompt length (short, medium, long, very long)

## Performance Baselines- Throughput under concurrent requests

- Statistical variance and consistency

Based on NVIDIA T4 GPU (Standard_NC8as_T4_v3):- Model efficiency comparison



| Model | Size | Cold Start | Warm Start | Throughput | Best Use Case |**Usage:**

|-------|------|-----------|-----------|------------|--------------|

| gemma2:2b | 1.6GB | ~13s | ~1s | 25+ tok/s | Fast responses |```powershell

| phi3.5 | 2.2GB | ~14s | ~2s | 20+ tok/s | Balanced |# Via port-forward - test default models

| mistral:7b | 4.4GB | ~17s | ~4s | 12+ tok/s | General purpose |kubectl port-forward -n ollama service/ollama 11434:11434

| llama3.1:8b | 4.9GB | ~26s | ~4s | 10+ tok/s | High quality |.\tokens-per-second-benchmark.ps1 -OllamaEndpoint "http://localhost:11434"

| deepseek-r1 | 5.2GB | ~40s | ~20s | 9+ tok/s | Reasoning |

| gpt-oss | 13GB | ~60s+ | ~5s | 12+ tok/s | Large context |# Test specific models with concurrent requests

.\tokens-per-second-benchmark.ps1 `

## File Structure    -OllamaEndpoint "http://localhost:11434" `

    -Models @("phi3.5", "llama3.1:8b") `

```    -ConcurrentRequests 3

benchmarks/

├── benchmark.ps1              # Main consolidated script# Test all prompt lengths

├── benchmark-report.html      # Generated HTML report.\tokens-per-second-benchmark.ps1 `

├── README.md                  # This file    -OllamaEndpoint "http://localhost:11434" `

└── results-YYYYMMDD-HHMMSS/  # Result directories    -PromptLengths @("All") `

    ├── model-name.json        # Individual model results    -MeasurementRuns 10

    ├── multi-user-X.json      # Multi-user test results```

    └── summary.json           # Summary of all tests

```**Parameters:**

- `-OllamaEndpoint` (required): Ollama API endpoint URL

## Best Practices- `-Models` (optional): Array of models to test (default: `phi3.5`, `gemma2:2b`, `llama3.1:8b`)

- `-PromptLengths` (optional): Test prompt lengths: `Short`, `Medium`, `Long`, `VeryLong`, `All`

### Connection Stability- `-GenerationTokens` (optional): Target tokens to generate (default: 100)

- `-WarmupRuns` (optional): Warmup iterations (default: 2)

Use persistent port-forward for multiple tests:- `-MeasurementRuns` (optional): Measurement iterations (default: 5)

- `-ConcurrentRequests` (optional): Concurrent requests (default: 1)

```powershell- `-OutputFile` (optional): JSON output file (default: `tokens-per-second-results.json`)

# Start in background

$job = Start-Job -ScriptBlock { **Output:**

    kubectl port-forward -n ollama service/ollama 11434:11434 ```json

}{

  "Timestamp": "2025-10-31 16:00:00",

# Run benchmarks  "Configuration": {

.\benchmark.ps1 -Mode AllModels -OllamaEndpoint "http://localhost:11434"    "GenerationTokens": 100,

    "ConcurrentRequests": 1

# Stop when done  },

$job | Stop-Job; $job | Remove-Job  "Summary": {

```    "OverallAverageTokensPerSecond": 42.5,

    "OverallMinTokensPerSecond": 38.2,

### Recommended Test Sequence    "OverallMaxTokensPerSecond": 47.8,

    "TotalTests": 9,

```powershell    "TotalSamples": 45

# 1. Verify connection  },

.\benchmark.ps1 -Mode Connection -OllamaEndpoint "http://localhost:11434"  "ModelResults": [

    {

# 2. Test all models      "Model": "llama3.1:8b",

.\benchmark.ps1 -Mode AllModels -OllamaEndpoint "http://localhost:11434"      "PromptResults": [

        {

# 3. Test multi-user          "PromptLength": "Short",

.\benchmark.ps1 -Mode MultiUser -Model "gemma2:2b" -Users 3 -OllamaEndpoint "http://localhost:11434"          "Statistics": {

            "AverageTokensPerSecond": 43.2,

# 4. Generate report            "StdDevTokensPerSecond": 1.8

.\benchmark.ps1 -Mode Report          }

```        }

      ]
    }
  ]
}
```

---

### 3. `run-benchmarks.ps1`

Convenience script to run common benchmark scenarios with automatic port-forwarding.

**What it does:**
- Automatically sets up kubectl port-forward if needed
- Runs predefined benchmark scenarios
- Organizes results in timestamped directories
- Supports all benchmark types in one command

**Usage:**

```powershell
# Run all scenarios (single-user, multi-user-3, multi-user-5, tokens-per-second)
.\run-benchmarks.ps1 -Scenario AllScenarios -UsePortForward

# Run only single user test
.\run-benchmarks.ps1 -Scenario SingleUser -UsePortForward

# Run with direct endpoint (no port-forward)
.\run-benchmarks.ps1 -Scenario MultiUser3 -OllamaEndpoint "http://20.54.123.45:11434"
```

**Parameters:**
- `-Scenario`: `SingleUser`, `MultiUser3`, `MultiUser5`, `TokensPerSecond`, or `AllScenarios`
- `-UsePortForward`: Automatically set up kubectl port-forward
- `-OllamaEndpoint`: Direct endpoint URL (overrides port-forward)

**Output:**
Results saved to `results-YYYYMMDD-HHMMSS/` directory with separate JSON files for each test.

---

### 4. `generate-report.ps1`

Generates a beautiful HTML report from all benchmark results.

**What it does:**
- Scans all `results-*` directories
- Aggregates metrics across all test runs
- Creates visual HTML report with tables and summary cards
- Color-codes performance metrics (good/average/poor)

**Usage:**

```powershell
# Generate report from all results
.\generate-report.ps1

# Open report in browser
Invoke-Item .\benchmark-report.html

# Custom output location
.\generate-report.ps1 -OutputFile "C:\reports\llm-benchmark-report.html"
```

**Report includes:**
- Summary statistics (total runs, tests, models)
- Single user performance table (all runs)
- Multi-user concurrent performance (3 and 5 users)
- Color-coded metrics for easy interpretation
- Responsive design for desktop and mobile

---

### 5. `compare-results.ps1`

Compare multiple benchmark result files side-by-side.

**Usage:**

```powershell
# Compare two single-user runs
.\compare-results.ps1 `
    -ResultFiles @("results-20251102-180750\single-user.json", "results-20251102-182723\single-user.json")

# Compare multi-user results
.\compare-results.ps1 `
    -ResultFiles @("results-*/multi-user-3.json")
```

---

### 6. `multi-user-benchmark.ps1`

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
