# Benchmark Tools and Scripts

This document provides comprehensive documentation for the benchmark suite designed to measure LLM inference performance on Azure AKS.

## Overview

The benchmark suite consists of three complementary tools that measure different aspects of LLM deployment performance:

1. **Single User Benchmark** - Model download and load time baseline
2. **Tokens/Second Benchmark** - GPU inference throughput measurement
3. **Multi-User Benchmark** - Concurrent load and scaling behavior

## Quick Start

```powershell
# Set up access to Ollama service
kubectl port-forward -n ollama service/ollama 11434:11434

# Run all benchmarks
cd benchmarks
.\run-benchmarks.ps1 -Scenario AllScenarios -UsePortForward

# Results saved to: results-<timestamp>/
```

---

## Benchmark 1: Single User Model Download and Load Time

### Purpose
Establishes baseline performance for model download and initial load operations. Measures the one-time cost of getting a model ready for inference.

### What It Measures
- **Download Time** - Time to pull model from registry to storage (network + storage write)
- **Cold Start Load** - Time to load model into GPU memory (storage read + GPU initialization)
- **Warm Start Load** - Time to load already-cached model (GPU-only)
- **Token Throughput** - Inference speed during first generation

### Script
`single-user-benchmark.ps1`

### Usage

```powershell
# Basic usage with default model (llama3.1:8b)
.\single-user-benchmark.ps1 -OllamaEndpoint "http://localhost:11434"

# Test specific model
.\single-user-benchmark.ps1 `
    -OllamaEndpoint "http://localhost:11434" `
    -Model "phi3.5"

# Save to custom location
.\single-user-benchmark.ps1 `
    -OllamaEndpoint "http://localhost:11434" `
    -Model "mistral:7b" `
    -OutputFile "results/mistral-baseline.json"
```

### Parameters

| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| `OllamaEndpoint` | Yes | - | Ollama API endpoint URL |
| `Model` | No | `llama3.1:8b` | Model name to benchmark |
| `OutputFile` | No | `single-user-results.json` | Output file path |

### Output Format

```json
{
  "Timestamp": "2025-10-31 14:30:00",
  "Model": "llama3.1:8b",
  "OllamaEndpoint": "http://localhost:11434",
  "Measurements": {
    "DownloadTimeSeconds": 45.67,
    "DownloadStatus": "Success",
    "LoadTimeColdSeconds": 18.32,
    "LoadTimeWarmSeconds": 2.14,
    "LoadStatus": "Success",
    "TotalTimeSeconds": 63.99,
    "TokensPerSecond": 42.5
  }
}
```

### Interpreting Results

**Download Time (45s):**
- Network bandwidth from registry
- Storage write performance
- Model size dependent

**Cold Load Time (18s):**
- Storage read performance (first load)
- GPU memory allocation
- Model initialization

**Warm Load Time (2s):**
- Cached model, minimal storage I/O
- GPU-only operation
- Indicates GPU initialization overhead

**Tokens/Second (42.5):**
- GPU inference throughput
- Quick validation that model works correctly

### Expected Results (T4 GPU, North Europe)

| Model | Size | Download | Cold Load | Warm Load | Tokens/s |
|-------|------|----------|-----------|-----------|----------|
| phi3.5 | 2.3GB | 15-20s | 8-12s | 1-3s | 55-65 |
| gemma2:2b | 1.6GB | 10-15s | 6-10s | 1-3s | 60-70 |
| llama3.1:8b | 4.7GB | 35-50s | 16-20s | 2-4s | 40-50 |
| mistral:7b | 4.1GB | 30-45s | 14-18s | 2-4s | 42-52 |

**With Azure Files Premium:**
- Download: Limited by network (100-200 Mbps typical)
- Cold Load: 1-10ms latency, 400 MB/s throughput
- Warm Load: Mostly cached in system memory

---

## Benchmark 2: Tokens Per Second (Inference Throughput)

### Purpose
Measures GPU inference performance - the primary metric for ongoing LLM operations. This is the steady-state performance after models are loaded.

### What It Measures
- **Average Tokens/Second** - Primary throughput metric
- **Performance Consistency** - Standard deviation across runs
- **Prompt Length Impact** - How context size affects throughput
- **Concurrent Request Handling** - Throughput under parallel load
- **Model Efficiency Comparison** - Relative performance of different models

### Script
`tokens-per-second-benchmark.ps1`

### Usage

```powershell
# Basic throughput test with defaults
.\tokens-per-second-benchmark.ps1 -OllamaEndpoint "http://localhost:11434"

# Compare multiple models
.\tokens-per-second-benchmark.ps1 `
    -OllamaEndpoint "http://localhost:11434" `
    -Models @("phi3.5", "gemma2:2b", "llama3.1:8b", "mistral:7b")

# Test prompt length impact
.\tokens-per-second-benchmark.ps1 `
    -OllamaEndpoint "http://localhost:11434" `
    -Models @("llama3.1:8b") `
    -PromptLengths @("Short", "Medium", "Long", "VeryLong") `
    -MeasurementRuns 10

# Test concurrent throughput
.\tokens-per-second-benchmark.ps1 `
    -OllamaEndpoint "http://localhost:11434" `
    -Models @("llama3.1:8b") `
    -ConcurrentRequests 3 `
    -MeasurementRuns 10

# High-precision measurement
.\tokens-per-second-benchmark.ps1 `
    -OllamaEndpoint "http://localhost:11434" `
    -WarmupRuns 5 `
    -MeasurementRuns 20
```

### Parameters

| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| `OllamaEndpoint` | Yes | - | Ollama API endpoint URL |
| `Models` | No | `phi3.5`, `gemma2:2b`, `llama3.1:8b` | Array of models to test |
| `PromptLengths` | No | `Short`, `Medium`, `Long` | Prompt length categories |
| `GenerationTokens` | No | 100 | Target tokens to generate |
| `WarmupRuns` | No | 2 | Warmup iterations before measurement |
| `MeasurementRuns` | No | 5 | Number of measurement iterations |
| `ConcurrentRequests` | No | 1 | Number of concurrent requests |
| `OutputFile` | No | `tokens-per-second-results.json` | Output file path |

### Prompt Length Categories

| Category | Characters | Description | Use Case |
|----------|------------|-------------|----------|
| **Short** | ~55 | Single sentence | Quick queries, simple tasks |
| **Medium** | ~250 | Paragraph with context | Standard interactions |
| **Long** | ~800 | Detailed instructions | Complex prompts, RAG context |
| **VeryLong** | ~2,500 | Multi-paragraph context | Maximum context scenarios |

### Output Format

```json
{
  "Timestamp": "2025-10-31 16:00:00",
  "Configuration": {
    "GenerationTokens": 100,
    "WarmupRuns": 2,
    "MeasurementRuns": 5,
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
          "PromptCharacters": 55,
          "Statistics": {
            "AverageTokensPerSecond": 43.2,
            "MinTokensPerSecond": 41.1,
            "MaxTokensPerSecond": 45.8,
            "StdDevTokensPerSecond": 1.8,
            "AverageDurationSeconds": 2.31,
            "SampleSize": 5
          }
        }
      ]
    }
  ]
}
```

### Interpreting Results

**Average Tokens/Second:**
- Primary metric for inference performance
- T4 GPU with 7-8B models: 40-50 tok/s expected
- Higher is better

**Standard Deviation:**
- Consistency indicator
- <5% of average = Stable, good
- >10% of average = Variable, investigate
- >20% of average = Problem (thermal throttling, resource contention)

**Prompt Length Impact:**
- Longer prompts typically show 10-20% lower throughput
- Due to increased context processing
- Expected behavior, not a problem

**Concurrent Requests:**
- Should scale linearly up to GPU saturation
- 1 req: 45 tok/s → 3 reqs: ~135 tok/s total = Good (100% efficiency)
- 1 req: 45 tok/s → 3 reqs: ~90 tok/s total = Saturated (~67% efficiency)

### Performance Guidelines (T4 GPU)

| Model Size | Expected tok/s | Good Variance | Warning Signs |
|------------|----------------|---------------|---------------|
| 2-3GB | 50-65 | <3 tok/s | <45 tok/s or >10% variance |
| 4-5GB | 40-50 | <2.5 tok/s | <35 tok/s or >8% variance |
| 7-8GB | 35-45 | <2 tok/s | <30 tok/s or >8% variance |
| 13GB+ | 25-35 | <2 tok/s | <20 tok/s or >10% variance |

**Diagnostic Guide:**

✅ **Good Performance:**
- Variance <5% of average
- Linear scaling with 2-3 concurrent requests
- Minimal prompt length impact (<15%)

⚠️ **Investigate:**
- Variance >10% → Check for resource contention or thermal issues
- Poor concurrent scaling (<60% efficiency) → GPU or memory bottleneck
- Very low tok/s → Verify GPU allocation with `kubectl describe node`

❌ **Problem Indicators:**
- Variance >20% → Unstable environment, thermal throttling likely
- Zero concurrent benefit → Single GPU queue, no parallelism
- Declining performance over time → Thermal throttling confirmed

---

## Benchmark 3: Multi-User Concurrent Operations

### Purpose
Simulates real-world scenarios with multiple users concurrently downloading and loading different models. Measures system behavior under parallel load.

### What It Measures
- **Overall Duration** - Wall-clock time for all concurrent operations
- **Individual Timings** - Per-user download and load times
- **Success Rate** - Reliability under concurrent load
- **Resource Contention** - Impact of parallelism on individual performance
- **Scaling Efficiency** - How well the system handles increasing users

### Script
`multi-user-benchmark.ps1`

### Usage

```powershell
# Basic concurrent test with 3 users
.\multi-user-benchmark.ps1 `
    -OllamaEndpoint "http://localhost:11434" `
    -ConcurrentUsers 3

# Test with 5 users and custom models
.\multi-user-benchmark.ps1 `
    -OllamaEndpoint "http://localhost:11434" `
    -ConcurrentUsers 5 `
    -Models @("phi3.5", "gemma2:2b", "mistral:7b", "llama3.1:8b")

# Scaling test
.\multi-user-benchmark.ps1 -OllamaEndpoint "http://localhost:11434" -ConcurrentUsers 1
.\multi-user-benchmark.ps1 -OllamaEndpoint "http://localhost:11434" -ConcurrentUsers 3
.\multi-user-benchmark.ps1 -OllamaEndpoint "http://localhost:11434" -ConcurrentUsers 5
# Then compare results to analyze scaling efficiency
```

### Parameters

| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| `OllamaEndpoint` | Yes | - | Ollama API endpoint URL |
| `ConcurrentUsers` | No | 3 | Number of concurrent users |
| `Models` | No | `phi3.5`, `gemma2:2b`, `mistral:7b`, `llama3.1:8b` | Models to test |
| `OutputFile` | No | `multi-user-results.json` | Output file path |

### Output Format

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
  "IndividualResults": [
    {
      "UserId": 1,
      "Model": "phi3.5",
      "Measurements": {
        "DownloadTimeSeconds": 28.45,
        "DownloadStatus": "Success",
        "LoadTimeSeconds": 12.34,
        "LoadStatus": "Success",
        "TotalTimeSeconds": 40.79,
        "TokensPerSecond": 58.2
      }
    }
  ]
}
```

### Interpreting Results

**Overall Duration vs Individual Times:**
- Measures actual parallelism benefit
- Perfect parallelism: Overall = Max(individual times)
- Serial execution: Overall = Sum(individual times)

**Example Analysis:**
```
Single user: 63s total (45s download + 18s load)
3 concurrent users: 125s overall

Expected if serial: 3 × 63s = 189s
Actual: 125s
Benefit: 64s saved (34% reduction)
Efficiency: (189 / 125) = 1.51x speedup (50% efficiency)
```

**Success Rate:**
- 100% = Excellent, system handles load well
- 90-99% = Good, occasional failures acceptable
- <90% = Poor, investigate resource limits or timeouts

**Min vs Max Times:**
- Similar times (within 20%) = Good parallelism, minimal contention
- High variance (>50% difference) = Resource contention or sequential bottleneck

### Scaling Efficiency Analysis

Run with increasing concurrent users and analyze:

| Users | Overall Duration | Efficiency | Assessment |
|-------|-----------------|------------|------------|
| 1 | 63s | 100% (baseline) | - |
| 3 | 125s | 50% | Good parallelism |
| 5 | 180s | 35% | Moderate contention |
| 10 | 400s | 16% | Heavy contention |

**Efficiency Calculation:**
```
Efficiency = (Users × SingleUserTime) / (Users × OverallDuration)
```

**Guidelines:**
- >70% efficiency = Excellent scaling
- 50-70% efficiency = Good scaling
- 30-50% efficiency = Acceptable, some contention
- <30% efficiency = Poor scaling, bottleneck present

---

## Convenience Scripts

### run-benchmarks.ps1

Wrapper script for common benchmark scenarios with automatic endpoint detection.

**Usage:**

```powershell
# Single scenario
.\run-benchmarks.ps1 -Scenario SingleUser -UsePortForward
.\run-benchmarks.ps1 -Scenario TokensPerSecond -UsePortForward
.\run-benchmarks.ps1 -Scenario MultiUser3 -OllamaEndpoint "http://20.54.123.45:11434"

# Run all benchmarks
.\run-benchmarks.ps1 -Scenario AllScenarios -UsePortForward
```

**Scenarios:**
- `SingleUser` - Single user baseline only
- `TokensPerSecond` - Throughput measurement only
- `MultiUser3` - 3 concurrent users
- `MultiUser5` - 5 concurrent users
- `AllScenarios` - All of the above

**Features:**
- Automatic LoadBalancer IP detection
- Port-forward management
- Timestamped result folders
- Clean output organization

### compare-results.ps1

Analyzes and compares results across multiple benchmark runs.

**Usage:**

```powershell
# Compare single-user results
.\compare-results.ps1 -ResultFiles @(
    "results-20251031-120000\single-user.json",
    "results-20251031-130000\single-user.json"
)

# Compare all results in a folder
.\compare-results.ps1 -ResultFiles (Get-ChildItem -Path results-* -Filter "*.json" -Recurse).FullName

# Save comparison report
.\compare-results.ps1 `
    -ResultFiles @("results-1\tokens-per-second.json", "results-2\tokens-per-second.json") `
    -OutputFile "comparison-report.json"
```

**Output:**
- Tabular comparison of all runs
- Statistical summary (average, min, max, standard deviation)
- Scaling efficiency analysis (for multi-user results)
- Performance trend identification

---

## Common Benchmark Workflows

### Workflow 1: Initial Performance Validation

**Goal:** Verify the deployment is performing as expected.

```powershell
# 1. Establish baseline
.\single-user-benchmark.ps1 -OllamaEndpoint "http://localhost:11434" -Model "llama3.1:8b"

# 2. Measure steady-state throughput
.\tokens-per-second-benchmark.ps1 -OllamaEndpoint "http://localhost:11434"

# Expected results for T4 GPU:
# - Cold load: 16-20s
# - Tokens/s: 40-50
# If results are significantly worse, investigate GPU allocation or node issues
```

### Workflow 2: Storage Performance Comparison

**Goal:** Compare Azure Files vs alternative storage.

```powershell
# Baseline with Azure Files Premium
.\single-user-benchmark.ps1 -OllamaEndpoint "http://localhost:11434" -OutputFile "azure-files-baseline.json"
.\tokens-per-second-benchmark.ps1 -OllamaEndpoint "http://localhost:11434" -OutputFile "azure-files-throughput.json"

# Switch to alternative storage (e.g., local NVMe)
# Reconfigure storage class, redeploy pods

# Re-run benchmarks
.\single-user-benchmark.ps1 -OllamaEndpoint "http://localhost:11434" -OutputFile "nvme-baseline.json"
.\tokens-per-second-benchmark.ps1 -OllamaEndpoint "http://localhost:11434" -OutputFile "nvme-throughput.json"

# Compare results
.\compare-results.ps1 -ResultFiles @("azure-files-baseline.json", "nvme-baseline.json")
.\compare-results.ps1 -ResultFiles @("azure-files-throughput.json", "nvme-throughput.json")

# Expected findings:
# - Load time: Azure Files 18s, NVMe 6s (12s difference)
# - Tokens/s: Azure Files 42.5, NVMe 42.3 (0.2 difference - negligible)
# Conclusion: Storage choice impacts load time but NOT inference throughput
```

### Workflow 3: Scaling Behavior Analysis

**Goal:** Understand how system performs under increasing load.

```powershell
# Test with increasing concurrency
.\multi-user-benchmark.ps1 -OllamaEndpoint "http://localhost:11434" -ConcurrentUsers 1 -OutputFile "scale-1.json"
.\multi-user-benchmark.ps1 -OllamaEndpoint "http://localhost:11434" -ConcurrentUsers 3 -OutputFile "scale-3.json"
.\multi-user-benchmark.ps1 -OllamaEndpoint "http://localhost:11434" -ConcurrentUsers 5 -OutputFile "scale-5.json"
.\multi-user-benchmark.ps1 -OllamaEndpoint "http://localhost:11434" -ConcurrentUsers 10 -OutputFile "scale-10.json"

# Compare results
.\compare-results.ps1 -ResultFiles (Get-ChildItem -Filter "scale-*.json").FullName

# Analyze scaling efficiency:
# 1 user: 63s, 100% efficiency (baseline)
# 3 users: 125s, 50% efficiency (good)
# 5 users: 180s, 35% efficiency (acceptable)
# 10 users: 400s, 16% efficiency (bottleneck identified)
```

### Workflow 4: Model Selection

**Goal:** Choose the optimal model for your use case.

```powershell
# Compare models for throughput and quality trade-off
.\tokens-per-second-benchmark.ps1 `
    -OllamaEndpoint "http://localhost:11434" `
    -Models @("phi3.5", "gemma2:2b", "llama3.1:8b", "mistral:7b", "deepseek-r1") `
    -MeasurementRuns 10

# Results will show:
# - phi3.5: 55-65 tok/s (fastest, smaller model)
# - gemma2:2b: 60-70 tok/s (fastest, smallest)
# - llama3.1:8b: 40-50 tok/s (balanced)
# - mistral:7b: 42-52 tok/s (balanced)
# - deepseek-r1: 25-35 tok/s (slower, larger, may have better quality)

# Decision factors:
# - Speed requirement: Choose gemma2:2b or phi3.5
# - Quality requirement: Choose llama3.1:8b or mistral:7b
# - Specialized tasks: Evaluate deepseek-r1 despite lower throughput
```

### Workflow 5: Continuous Performance Monitoring

**Goal:** Track performance over time to detect degradation.

```powershell
# Weekly/monthly performance check
$timestamp = Get-Date -Format "yyyyMMdd"
.\run-benchmarks.ps1 -Scenario AllScenarios -UsePortForward

# Move results to monitoring folder
Move-Item -Path "results-*" -Destination "performance-tracking\$timestamp"

# Compare against baseline
.\compare-results.ps1 -ResultFiles @(
    "performance-tracking\baseline\tokens-per-second.json",
    "performance-tracking\$timestamp\tokens-per-second.json"
)

# Alert if performance degraded >10%
# Investigate: thermal issues, resource contention, configuration drift
```

---

## Environment Setup

### Prerequisites

```powershell
# PowerShell 7.x
$PSVersionTable.PSVersion  # Should be 7.x

# kubectl configured
kubectl get nodes

# Access to Ollama service (one of):
# Option 1: Port-forward
kubectl port-forward -n ollama service/ollama 11434:11434

# Option 2: LoadBalancer IP
kubectl get svc -n ollama ollama
# Use LoadBalancer IP in -OllamaEndpoint parameter
```

### Permissions Required

- Read access to Ollama service
- Ability to create port-forward (if using that method)
- Write access to local filesystem for results

---

## Troubleshooting

### Connection Issues

**Symptom:** "Connection refused" or timeout errors

**Quick Diagnostic:**
```powershell
# Run the connection test script
.\test-connection.ps1

# Or test with specific endpoint
.\test-connection.ps1 -OllamaEndpoint "http://20.54.123.45:11434"
```

**Manual Solutions:**
```powershell
# Verify Ollama pods are running
kubectl get pods -n ollama

# Check service endpoint
kubectl get svc -n ollama ollama

# Test connectivity with port-forward
kubectl port-forward -n ollama service/ollama 11434:11434

# In another terminal, test the API
curl http://localhost:11434/api/tags

# Or use PowerShell
Invoke-RestMethod -Uri "http://localhost:11434/api/tags" -Method Get
```

### Slow Downloads

**Symptom:** Model downloads taking much longer than expected

**Solutions:**
```powershell
# Check network bandwidth to pod
kubectl exec -n ollama ollama-0 -- sh -c "time curl -o /dev/null https://registry.ollama.ai/v2/"

# Verify no rate limiting
# Check Azure Files Premium throughput (should be ~400 MB/s)

# Consider pre-loading models
kubectl exec -n ollama ollama-0 -- ollama pull llama3.1:8b
```

### Inconsistent Results

**Symptom:** High variance (>15%) in tokens/second measurements

**Possible Causes:**
```powershell
# 1. Thermal throttling
# Check GPU temperature
kubectl exec -n ollama ollama-0 -- nvidia-smi

# 2. Resource contention
# Check for other GPU workloads
kubectl get pods -A -o wide | grep gpu

# 3. Spot VM evictions
# Check node events
kubectl describe node <node-name>

# Solution: Increase WarmupRuns and MeasurementRuns
.\tokens-per-second-benchmark.ps1 -WarmupRuns 5 -MeasurementRuns 20
```

### PowerShell Job Failures

**Symptom:** Multi-user benchmark fails with job errors

**Solutions:**
```powershell
# Check PowerShell version
$PSVersionTable.PSVersion  # Must be 7.0+

# Reduce concurrent users
.\multi-user-benchmark.ps1 -ConcurrentUsers 2

# Check for timeout issues
# Increase timeout in script if models are very large (>10GB)
```

---

## Best Practices

### 1. Consistent Testing Conditions

✅ **Do:**
- Run benchmarks on same infrastructure
- Use same time of day (avoid peak hours)
- Warm up cluster before critical measurements
- Document cluster configuration

❌ **Don't:**
- Mix Spot and Standard VM results
- Compare different GPU types directly
- Run during cluster maintenance windows
- Test with other workloads running

### 2. Statistical Rigor

✅ **Do:**
- Use multiple measurement runs (5-10 minimum)
- Include warmup runs to eliminate cold start effects
- Calculate and report standard deviation
- Discard outliers (>3 standard deviations) if justified

❌ **Don't:**
- Rely on single measurement
- Skip warmup runs
- Cherry-pick best results
- Ignore high variance

### 3. Result Interpretation

✅ **Do:**
- Compare like with like (same model, same prompt)
- Consider confidence intervals
- Look for trends across multiple runs
- Document environmental factors

❌ **Don't:**
- Over-interpret small differences (<5%)
- Ignore variance in favor of averages
- Make conclusions from single outlier
- Compare results from different dates without context

### 4. Energy Efficiency

✅ **Do:**
- Clean up models after testing
- Stop port-forwards when done
- Use appropriate measurement run counts (don't over-test)
- Batch benchmark runs

❌ **Don't:**
- Leave multiple concurrent benchmarks running
- Test same configuration repeatedly without reason
- Keep unused models loaded
- Run benchmarks continuously in production

---

## Output File Management

### Organization Strategy

```
benchmarks/
├── results-20251031-140000/    # Timestamped runs
│   ├── single-user.json
│   ├── tokens-per-second.json
│   ├── multi-user-3.json
│   └── multi-user-5.json
├── baseline/                   # Reference results
│   ├── azure-files-baseline.json
│   └── azure-files-throughput.json
└── comparisons/               # Comparison reports
    └── storage-comparison-20251031.json
```

### Cleanup Strategy

```powershell
# Keep baseline results
# Archive monthly results
# Delete daily test runs after 30 days

# Example cleanup script
Get-ChildItem -Path "benchmarks/results-*" -Directory |
    Where-Object { $_.CreationTime -lt (Get-Date).AddDays(-30) } |
    Remove-Item -Recurse -Force
```

---

## Performance Targets

### Azure AKS with T4 GPU + Azure Files Premium

| Metric | Target | Good | Warning | Critical |
|--------|--------|------|---------|----------|
| **Download Time** (7-8GB model) | 35-50s | <60s | 60-90s | >90s |
| **Cold Load Time** (7-8GB model) | 16-20s | <25s | 25-35s | >35s |
| **Warm Load Time** | 2-4s | <5s | 5-10s | >10s |
| **Tokens/Second** (7-8GB model) | 40-50 | >35 | 25-35 | <25 |
| **Variance** (tok/s) | <5% | <8% | 8-15% | >15% |
| **Concurrent Scaling** (3 users) | >50% | >40% | 30-40% | <30% |
| **Success Rate** | 100% | >95% | 90-95% | <90% |

---

## Appendix: Example Results

### Example 1: Single User Baseline

```json
{
  "Timestamp": "2025-10-31 14:30:00",
  "Model": "llama3.1:8b",
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

**Analysis:** ✅ All metrics within expected range for T4 + Azure Files Premium.

### Example 2: Tokens/Second Results

```json
{
  "Summary": {
    "OverallAverageTokensPerSecond": 42.5,
    "OverallMinTokensPerSecond": 38.2,
    "OverallMaxTokensPerSecond": 47.8
  },
  "ModelResults": [{
    "Model": "llama3.1:8b",
    "PromptResults": [{
      "PromptLength": "Short",
      "Statistics": {
        "AverageTokensPerSecond": 43.2,
        "StdDevTokensPerSecond": 1.8
      }
    }]
  }]
}
```

**Analysis:** ✅ Excellent performance. 43.2 tok/s average with 1.8 stddev (4.2% variance) indicates stable, high-performance inference. GPU is primary bottleneck, not storage.

### Example 3: Multi-User Scaling

```json
{
  "ConcurrentUsers": 3,
  "Summary": {
    "OverallDurationSeconds": 125.45,
    "AverageDownloadTimeSeconds": 38.21,
    "MaxDownloadTimeSeconds": 52.10,
    "SuccessRate": 100
  }
}
```

**Analysis:** ✅ Good parallelism. Single user would take 189s total (3×63s). Concurrent execution: 125s. Efficiency: 50% (acceptable for 3 users). Max download time only 14% higher than average (minimal contention).

---

## Summary

The benchmark suite provides comprehensive performance measurement across three dimensions:

1. **One-time costs** (model download/load) → Single User Benchmark
2. **Steady-state performance** (inference throughput) → Tokens/Second Benchmark
3. **Scaling behavior** (concurrent operations) → Multi-User Benchmark

**Key Insight:** For LLM inference workloads, GPU compute is the primary bottleneck, not storage I/O. Storage choice impacts one-time load times but has negligible effect on ongoing inference throughput.

Use these benchmarks to:
- Validate deployment performance
- Compare storage configurations
- Identify bottlenecks
- Make informed cost/performance trade-offs
- Monitor performance over time
