# Benchmark Scripts

This directory contains PowerShell scripts for performance testing and GPU stress testing of the Ollama inference platform.

## Overview

The benchmark scripts help you:
- Validate GPU utilization under load
- Measure inference throughput (tokens/second and requests/second)
- Monitor GPU metrics (memory, utilization, power, temperature)
- Identify performance bottlenecks
- Test platform resiliency

## Scripts

### 1. simple-stress-test.ps1

Batch-based load testing script that runs a fixed number of requests with specified concurrency.

**Usage:**
```powershell
.\simple-stress-test.ps1 -Concurrent 5 -TotalRequests 100 -Model "tinyllama"
```

**Parameters:**
- `-Concurrent`: Number of concurrent requests (default: 5)
- `-TotalRequests`: Total number of requests to send (default: 100)
- `-Model`: Ollama model to test (default: "tinyllama")
- `-OllamaUrl`: Ollama API endpoint (default: "http://localhost:11434")

**Example:**
```powershell
# Test with 10 concurrent requests, 200 total requests
.\simple-stress-test.ps1 -Concurrent 10 -TotalRequests 200 -Model "phi3.5"

# Test with larger model
.\simple-stress-test.ps1 -Concurrent 5 -TotalRequests 50 -Model "gpt-oss"
```

### 2. gpu-stress-test.ps1

Time-based continuous load testing that runs for a specified duration.

**Usage:**
```powershell
.\gpu-stress-test.ps1 -ConcurrentRequests 5 -DurationSeconds 120 -Model "tinyllama"
```

**Parameters:**
- `-ConcurrentRequests`: Number of concurrent request workers (default: 5)
- `-DurationSeconds`: Test duration in seconds (default: 120)
- `-Model`: Ollama model to test (default: "tinyllama")
- `-OllamaUrl`: Ollama API endpoint (default: "http://localhost:11434")

**Example:**
```powershell
# Run 5-minute stress test with 10 workers
.\gpu-stress-test.ps1 -ConcurrentRequests 10 -DurationSeconds 300 -Model "llama3.1:8b"

# Intensive test with large model
.\gpu-stress-test.ps1 -ConcurrentRequests 8 -DurationSeconds 600 -Model "deepseek-r1"
```

## GPU Metrics Collection

Both scripts now include **automatic GPU metrics collection** during test execution:

### Metrics Tracked
- **Peak GPU Memory Usage**: Maximum VRAM consumed during the test (MB/GB)
- **Peak GPU Utilization**: Maximum GPU compute usage (%)
- **Peak Power Draw**: Maximum power consumption (Watts)
- **Peak Temperature**: Maximum GPU temperature (°C)
- **Sample Count**: Number of metric samples collected

### How It Works
1. Script discovers the first available Ollama pod
2. Starts background job to collect nvidia-smi data every 5 seconds
3. Tracks peak values throughout the test duration
4. Displays metrics in the final summary

### Example Output
```
=== Final Statistics ===
Total Requests: 150
Successful: 150
Failed: 0
Total Tokens Generated: 22500
Average Request Duration: 1250ms
Requests per Second: 1.25
Tokens per Second: 187.5
Test Duration: 120.5 seconds

=== GPU Metrics ===
Peak GPU Memory: 8192.50 MB (8.00 GB)
Peak GPU Utilization: 98.5%
Peak Power Draw: 65.3 W
Peak Temperature: 72.0 °C
Samples Collected: 24
```

### Requirements
- Ollama pods must be running in the `ollama` namespace
- Pods must be labeled with `app=ollama`
- nvidia-smi must be available in the Ollama container
- kubectl must have access to execute commands in the pods

## Model Considerations

### Small Models (< 3GB)
- **Examples**: tinyllama, phi3.5, gemma2:2b
- **Load Time**: 5-10 seconds
- **Memory Usage**: 1-3 GB VRAM
- **Recommended Concurrency**: 10-20 workers
- **Inference Speed**: Fast (200-400 tokens/s with concurrency)

### Medium Models (3-8GB)
- **Examples**: llama3.1:8b, mistral:7b
- **Load Time**: 15-25 seconds
- **Memory Usage**: 5-8 GB VRAM
- **Recommended Concurrency**: 5-10 workers
- **Inference Speed**: Moderate (100-200 tokens/s with concurrency)

### Large Models (> 8GB)
- **Examples**: gpt-oss (13GB), deepseek-r1 (8GB)
- **Load Time**: 60-90 seconds
- **Memory Usage**: 8-13 GB VRAM
- **Recommended Concurrency**: 3-5 workers
- **Inference Speed**: Slower (50-150 tokens/s with concurrency)

**Note**: Scripts automatically use 180-second timeouts to accommodate large model loading times.

## Monitoring During Tests

### Grafana Dashboard
Access your Grafana dashboard to monitor real-time metrics:
```powershell
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80
# Open http://localhost:3000
# Default credentials: admin / prom-operator
```

Key metrics to watch:
- GPU Memory Usage (should increase to model size + working memory)
- GPU Utilization (should spike to 80-100% during inference)
- GPU Power Draw (should be near 70W under load)
- GPU Temperature (should be 65-85°C under sustained load)
- Pod CPU/Memory usage

### nvidia-smi Direct Check
```powershell
# Check current GPU state
kubectl exec -n ollama ollama-0 -- nvidia-smi

# Watch GPU metrics in real-time (Linux/WSL)
kubectl exec -n ollama ollama-0 -- watch -n 1 nvidia-smi

# Detailed GPU info
kubectl exec -n ollama ollama-0 -- nvidia-smi -q
```

## Performance Baselines

### Tesla T4 GPU (16GB VRAM)

#### tinyllama
- Load Time: 5-8 seconds
- Memory: ~1.2 GB
- 10 concurrent workers: 200-250 tokens/s

#### phi3.5
- Load Time: 8-12 seconds
- Memory: ~2.5 GB
- 10 concurrent workers: 180-220 tokens/s

#### llama3.1:8b
- Load Time: 20-25 seconds
- Memory: ~6 GB
- 5 concurrent workers: 120-160 tokens/s

#### gpt-oss
- Load Time: 70-90 seconds
- Memory: ~13 GB
- 3 concurrent workers: 60-90 tokens/s

## Troubleshooting

### "Failed to load model" with Timeout
**Problem**: Large models exceed the default timeout during warmup.

**Solution**: Scripts now use 180-second timeouts. If still failing:
1. Try with a smaller model first to verify connectivity
2. Check if Ollama pod has sufficient memory
3. Verify GPU is accessible: `kubectl exec -n ollama ollama-0 -- nvidia-smi`

### "GPU metrics collection unavailable"
**Problem**: Script cannot collect GPU metrics.

**Possible Causes**:
1. Ollama pods not running or not labeled correctly
2. kubectl cannot access the pods
3. nvidia-smi not available in container

**Solution**:
```powershell
# Verify pods are running
kubectl get pods -n ollama -l app=ollama

# Test nvidia-smi access
kubectl exec -n ollama ollama-0 -- nvidia-smi

# Check pod labels
kubectl get pods -n ollama --show-labels
```

### Low GPU Utilization
**Problem**: GPU utilization stays below 50% during tests.

**Possible Causes**:
1. Not enough concurrent requests
2. Model too small for available concurrency
3. CPU/network bottleneck
4. Pod resource limits too restrictive

**Solution**:
1. Increase concurrent workers: `-Concurrent 15` or `-ConcurrentRequests 15`
2. Use a larger model
3. Check pod resource requests/limits in the StatefulSet

### High Failure Rate
**Problem**: Many requests fail during the test.

**Possible Causes**:
1. Out of GPU memory
2. Pod resource limits exceeded
3. Network timeouts
4. Model not properly loaded

**Solution**:
1. Reduce concurrency
2. Use a smaller model
3. Check pod logs: `kubectl logs -n ollama ollama-0`
4. Verify model exists: `kubectl exec -n ollama ollama-0 -- ollama list`

## Integration with CI/CD

Both scripts can be used in automated pipelines:

```powershell
# Run quick validation test (exits with code 1 on failure)
.\simple-stress-test.ps1 -Concurrent 5 -TotalRequests 50 -Model "tinyllama"
if ($LASTEXITCODE -ne 0) {
    Write-Error "Benchmark failed"
    exit 1
}

# Parse output for metrics validation
$output = .\gpu-stress-test.ps1 -ConcurrentRequests 5 -DurationSeconds 60 -Model "phi3.5"
if ($output -match "Peak GPU Utilization: (\d+\.\d+)%") {
    $utilization = [double]$Matches[1]
    if ($utilization -lt 50) {
        Write-Warning "GPU utilization too low: $utilization%"
    }
}
```

## Best Practices

1. **Start Small**: Begin with small models (tinyllama, phi3.5) to verify setup
2. **Gradual Increase**: Increase concurrency gradually to find optimal settings
3. **Monitor First Load**: First model load is always slower (downloads and caches)
4. **Use Grafana**: Keep Grafana dashboard open during tests for real-time monitoring
5. **Check Logs**: Review Ollama pod logs if experiencing issues
6. **Resource Planning**: Ensure GPU node has sufficient memory for model + overhead
7. **Cooldown**: Allow GPU to cool between intensive tests (check temperature)

## Related Documentation

- [Autoscaling Guide](../docs/AUTOSCALING.md) - Configure HPA for Ollama and WebUI
- [Monitoring Guide](../docs/MONITORING.md) - Set up Grafana dashboards
- [Demo Guide](../DEMO-GUIDE.md) - Complete demonstration walkthrough
- [Architecture](../ARCHITECTURE.md) - System architecture and design

## Support

For issues or questions:
1. Check pod logs: `kubectl logs -n ollama <pod-name>`
2. Verify GPU access: `kubectl exec -n ollama ollama-0 -- nvidia-smi`
3. Review [Troubleshooting Guide](../docs/TROUBLESHOOTING-GPU-WEBUI.md)
