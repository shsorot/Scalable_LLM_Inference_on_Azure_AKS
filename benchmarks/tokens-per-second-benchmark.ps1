<#
.SYNOPSIS
    Benchmark tokens per second performance for different models and configurations

.DESCRIPTION
    Measures inference throughput (tokens/second) across different:
    - Models (small to large)
    - Prompt lengths (short, medium, long)
    - Generation lengths
    - Concurrent requests

    Useful for comparing GPU performance, model efficiency, and resource utilization.

.PARAMETER OllamaEndpoint
    Ollama API endpoint (e.g., http://ollama-service.ollama.svc.cluster.local:11434)

.PARAMETER Models
    Array of models to test (default: common models)

.PARAMETER PromptLengths
    Prompt length categories to test: Short, Medium, Long, VeryLong

.PARAMETER GenerationTokens
    Target number of tokens to generate (default: 100)

.PARAMETER WarmupRuns
    Number of warmup runs before measurement (default: 2)

.PARAMETER MeasurementRuns
    Number of measurement runs to average (default: 5)

.PARAMETER ConcurrentRequests
    Test with N concurrent requests (default: 1)

.PARAMETER OutputFile
    Path to save benchmark results (default: tokens-per-second-results.json)

.EXAMPLE
    .\tokens-per-second-benchmark.ps1 -OllamaEndpoint "http://localhost:11434"

.EXAMPLE
    .\tokens-per-second-benchmark.ps1 -OllamaEndpoint "http://localhost:11434" -Models @("phi3.5", "llama3.1:8b") -ConcurrentRequests 3
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$OllamaEndpoint,

    [Parameter(Mandatory=$false)]
    [string[]]$Models = @("phi3.5", "gemma2:2b", "llama3.1:8b"),

    [Parameter(Mandatory=$false)]
    [ValidateSet("Short", "Medium", "Long", "VeryLong", "All")]
    [string[]]$PromptLengths = @("Short", "Medium", "Long"),

    [Parameter(Mandatory=$false)]
    [int]$GenerationTokens = 100,

    [Parameter(Mandatory=$false)]
    [int]$WarmupRuns = 2,

    [Parameter(Mandatory=$false)]
    [int]$MeasurementRuns = 5,

    [Parameter(Mandatory=$false)]
    [int]$ConcurrentRequests = 1,

    [Parameter(Mandatory=$false)]
    [string]$OutputFile = "tokens-per-second-results.json"
)

$ErrorActionPreference = "Stop"

# Prompt templates by length
$prompts = @{
    Short = "Explain quantum computing in one sentence."
    Medium = @"
Explain quantum computing and its potential applications. Include information about qubits,
superposition, and entanglement. Describe how quantum computers differ from classical computers.
"@
    Long = @"
Write a comprehensive explanation of quantum computing technology. Cover the following topics:
1. Basic principles of quantum mechanics relevant to computing (superposition, entanglement, interference)
2. How qubits differ from classical bits and their implementation methods
3. Quantum gates and quantum circuits
4. Major quantum algorithms (Shor's, Grover's, quantum annealing)
5. Current challenges in quantum computing (decoherence, error correction, scalability)
6. Practical applications in cryptography, drug discovery, optimization, and machine learning
7. Current state of quantum computers and future outlook
Provide technical depth while remaining accessible.
"@
    VeryLong = @"
Provide an in-depth analysis of quantum computing technology covering all major aspects:

FUNDAMENTALS:
- Quantum mechanics principles: superposition, entanglement, interference, measurement
- Quantum information theory and quantum bits (qubits)
- Bloch sphere representation and quantum state space
- Quantum decoherence and environmental interactions

HARDWARE & IMPLEMENTATION:
- Superconducting qubits (transmons, flux qubits)
- Trapped ion quantum computers
- Photonic quantum computing
- Topological qubits and Majorana fermions
- Neutral atom arrays and Rydberg gates
- Silicon spin qubits
- Comparison of implementation approaches

QUANTUM ALGORITHMS:
- Shor's algorithm for integer factorization
- Grover's search algorithm
- Quantum Fourier transform
- Variational quantum eigensolver (VQE)
- Quantum approximate optimization algorithm (QAOA)
- Quantum machine learning algorithms

ERROR CORRECTION & FAULT TOLERANCE:
- Quantum error correction codes (surface codes, stabilizer codes)
- Logical vs physical qubits
- Error rates and fidelity requirements
- Fault-tolerant quantum computing thresholds

APPLICATIONS:
- Cryptography and post-quantum security
- Drug discovery and molecular simulation
- Financial modeling and risk analysis
- Optimization problems
- Machine learning and AI enhancement
- Materials science

CURRENT STATE & FUTURE:
- NISQ (Noisy Intermediate-Scale Quantum) era
- Quantum supremacy/advantage demonstrations
- Roadmaps from major quantum computing companies
- Timeline projections for practical quantum computers
- Economic impact and market forecasts

Include technical details, mathematical formulations where appropriate, and cite recent developments in the field.
"@
}

# Expand "All" if specified
if ($PromptLengths -contains "All") {
    $PromptLengths = @("Short", "Medium", "Long", "VeryLong")
}

# Results object
$results = @{
    Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    OllamaEndpoint = $OllamaEndpoint
    Configuration = @{
        GenerationTokens = $GenerationTokens
        WarmupRuns = $WarmupRuns
        MeasurementRuns = $MeasurementRuns
        ConcurrentRequests = $ConcurrentRequests
    }
    ModelResults = @()
    Summary = @{}
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Tokens/Second Performance Benchmark" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Endpoint: $OllamaEndpoint"
Write-Host "Models: $($Models -join ', ')"
Write-Host "Prompt lengths: $($PromptLengths -join ', ')"
Write-Host "Generation target: $GenerationTokens tokens"
Write-Host "Concurrent requests: $ConcurrentRequests"
Write-Host ""

# Function to call Ollama API
function Invoke-OllamaAPI {
    param(
        [string]$Endpoint,
        [string]$Path,
        [hashtable]$Body = @{},
        [string]$Method = "Post"
    )

    $uri = "$Endpoint$Path"

    try {
        $params = @{
            Uri = $uri
            Method = $Method
            TimeoutSec = 600
            UseBasicParsing = $true
        }

        # Add body for methods that support them
        if ($Method -in @("Post", "Delete") -and $Body -and $Body.Count -gt 0) {
            $jsonBody = $Body | ConvertTo-Json -Depth 10 -Compress
            $params.Body = $jsonBody
            $params.ContentType = "application/json"
        }

        $response = Invoke-RestMethod @params
        return $response
    }
    catch {
        Write-Warning "API call failed: $_"
        return $null
    }
}

# Scriptblock for concurrent execution
$benchmarkScriptBlock = {
    param(
        [string]$Endpoint,
        [string]$ModelName,
        [string]$Prompt,
        [int]$MaxTokens
    )

    function Invoke-OllamaAPIInternal {
        param(
            [string]$Endpoint,
            [string]$Path,
            [hashtable]$Body
        )

        $uri = "$Endpoint$Path"
        $jsonBody = $Body | ConvertTo-Json -Depth 10 -Compress

        try {
            $params = @{
                Uri = $uri
                Method = "Post"
                Body = $jsonBody
                ContentType = "application/json"
                TimeoutSec = 600
                UseBasicParsing = $true
            }
            $response = Invoke-RestMethod @params
            return $response
        }
        catch {
            return $null
        }
    }

    $start = Get-Date
    $generateBody = @{
        model = $ModelName
        prompt = $Prompt
        stream = $false
        options = @{
            num_predict = $MaxTokens
        }
    }

    $response = Invoke-OllamaAPIInternal -Endpoint $Endpoint -Path "/api/generate" -Body $generateBody
    $end = Get-Date

    if ($response -and $response.eval_count -and $response.eval_duration) {
        return @{
            Success = $true
            DurationSeconds = ($end - $start).TotalSeconds
            TokensGenerated = $response.eval_count
            EvalDurationNs = $response.eval_duration
            TokensPerSecond = $response.eval_count / ($response.eval_duration / 1000000000)
            PromptEvalCount = $response.prompt_eval_count
            PromptEvalDurationNs = $response.prompt_eval_duration
        }
    }

    return @{ Success = $false }
}

# Test each model
foreach ($model in $Models) {
    Write-Host ""
    Write-Host "Testing Model: $model" -ForegroundColor Yellow
    Write-Host "--------------------------------------"

    $modelResult = @{
        Model = $model
        PromptResults = @()
    }

    # Ensure model is loaded
    Write-Host "  Loading model..." -ForegroundColor Cyan
    $loadBody = @{
        model = $model
        prompt = "Hi"
        stream = $false
    }
    Invoke-OllamaAPI -Endpoint $OllamaEndpoint -Path "/api/generate" -Body $loadBody | Out-Null
    Start-Sleep -Seconds 2

    # Test each prompt length
    foreach ($promptLength in $PromptLengths) {
        Write-Host ""
        Write-Host "  Prompt Length: $promptLength" -ForegroundColor Cyan

        $prompt = $prompts[$promptLength]

        $promptResult = @{
            PromptLength = $promptLength
            PromptCharacters = $prompt.Length
            WarmupResults = @()
            MeasurementResults = @()
            Statistics = @{}
        }

        # Warmup runs
        Write-Host "    Warming up ($WarmupRuns runs)..." -ForegroundColor Gray
        for ($i = 1; $i -le $WarmupRuns; $i++) {
            if ($ConcurrentRequests -eq 1) {
                $result = & $benchmarkScriptBlock -Endpoint $OllamaEndpoint -ModelName $model -Prompt $prompt -MaxTokens $GenerationTokens
                if ($result.Success) {
                    $promptResult.WarmupResults += $result
                }
            }
            else {
                # Concurrent warmup
                $jobs = @()
                for ($j = 0; $j -lt $ConcurrentRequests; $j++) {
                    $jobs += Start-Job -ScriptBlock $benchmarkScriptBlock -ArgumentList $OllamaEndpoint, $model, $prompt, $GenerationTokens
                }
                $jobs | Wait-Job | Out-Null
                foreach ($job in $jobs) {
                    $result = Receive-Job -Job $job
                    if ($result.Success) {
                        $promptResult.WarmupResults += $result
                    }
                    Remove-Job -Job $job
                }
            }
        }

        # Measurement runs
        Write-Host "    Measuring ($MeasurementRuns runs)..." -ForegroundColor Gray
        for ($i = 1; $i -le $MeasurementRuns; $i++) {
            if ($ConcurrentRequests -eq 1) {
                $result = & $benchmarkScriptBlock -Endpoint $OllamaEndpoint -ModelName $model -Prompt $prompt -MaxTokens $GenerationTokens
                if ($result.Success) {
                    $promptResult.MeasurementResults += $result
                    Write-Host "      Run $i/$MeasurementRuns : $([math]::Round($result.TokensPerSecond, 2)) tok/s" -ForegroundColor Gray
                }
            }
            else {
                # Concurrent measurement
                Write-Host "      Run $i/$MeasurementRuns (concurrent=$ConcurrentRequests)..." -ForegroundColor Gray
                $jobs = @()
                for ($j = 0; $j -lt $ConcurrentRequests; $j++) {
                    $jobs += Start-Job -ScriptBlock $benchmarkScriptBlock -ArgumentList $OllamaEndpoint, $model, $prompt, $GenerationTokens
                }
                $jobs | Wait-Job | Out-Null
                foreach ($job in $jobs) {
                    $result = Receive-Job -Job $job
                    if ($result.Success) {
                        $promptResult.MeasurementResults += $result
                        Write-Host "        Request: $([math]::Round($result.TokensPerSecond, 2)) tok/s" -ForegroundColor Gray
                    }
                    Remove-Job -Job $job
                }
            }
        }

        # Calculate statistics
        if ($promptResult.MeasurementResults.Count -gt 0) {
            $tokensPerSecond = $promptResult.MeasurementResults | ForEach-Object { $_.TokensPerSecond }
            $durations = $promptResult.MeasurementResults | ForEach-Object { $_.DurationSeconds }

            $promptResult.Statistics = @{
                AverageTokensPerSecond = [math]::Round(($tokensPerSecond | Measure-Object -Average).Average, 2)
                MinTokensPerSecond = [math]::Round(($tokensPerSecond | Measure-Object -Minimum).Minimum, 2)
                MaxTokensPerSecond = [math]::Round(($tokensPerSecond | Measure-Object -Maximum).Maximum, 2)
                StdDevTokensPerSecond = [math]::Round([Math]::Sqrt((($tokensPerSecond | ForEach-Object {[Math]::Pow(($_ - ($tokensPerSecond | Measure-Object -Average).Average), 2)} | Measure-Object -Sum).Sum / $tokensPerSecond.Count)), 2)
                AverageDurationSeconds = [math]::Round(($durations | Measure-Object -Average).Average, 2)
                SampleSize = $promptResult.MeasurementResults.Count
            }

            Write-Host ""
            Write-Host "    Results:" -ForegroundColor Green
            Write-Host "      Average: $($promptResult.Statistics.AverageTokensPerSecond) tok/s" -ForegroundColor Green
            Write-Host "      Min: $($promptResult.Statistics.MinTokensPerSecond) tok/s"
            Write-Host "      Max: $($promptResult.Statistics.MaxTokensPerSecond) tok/s"
            Write-Host "      StdDev: $($promptResult.Statistics.StdDevTokensPerSecond) tok/s"
            Write-Host "      Duration: $($promptResult.Statistics.AverageDurationSeconds)s"
        }

        $modelResult.PromptResults += $promptResult
    }

    $results.ModelResults += $modelResult
}

# Calculate overall summary
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

$allResults = $results.ModelResults | ForEach-Object { $_.PromptResults } | ForEach-Object { $_.Statistics }

if ($allResults.Count -gt 0) {
    $avgTps = ($allResults.AverageTokensPerSecond | Measure-Object -Average).Average
    $minTps = ($allResults.MinTokensPerSecond | Measure-Object -Minimum).Minimum
    $maxTps = ($allResults.MaxTokensPerSecond | Measure-Object -Maximum).Maximum

    $results.Summary = @{
        OverallAverageTokensPerSecond = [math]::Round($avgTps, 2)
        OverallMinTokensPerSecond = [math]::Round($minTps, 2)
        OverallMaxTokensPerSecond = [math]::Round($maxTps, 2)
        TotalTests = $allResults.Count
        TotalSamples = ($allResults.SampleSize | Measure-Object -Sum).Sum
    }

    Write-Host ""
    Write-Host "Overall Performance:" -ForegroundColor Yellow
    Write-Host "  Average across all tests: $($results.Summary.OverallAverageTokensPerSecond) tok/s" -ForegroundColor Green
    Write-Host "  Minimum observed: $($results.Summary.OverallMinTokensPerSecond) tok/s"
    Write-Host "  Maximum observed: $($results.Summary.OverallMaxTokensPerSecond) tok/s"
    Write-Host "  Total tests: $($results.Summary.TotalTests)"
    Write-Host "  Total samples: $($results.Summary.TotalSamples)"

    # Per-model summary
    Write-Host ""
    Write-Host "Per-Model Summary:" -ForegroundColor Yellow
    foreach ($modelResult in $results.ModelResults) {
        $modelStats = $modelResult.PromptResults | ForEach-Object { $_.Statistics }
        $modelAvg = [math]::Round(($modelStats.AverageTokensPerSecond | Measure-Object -Average).Average, 2)
        Write-Host "  $($modelResult.Model): $modelAvg tok/s average" -ForegroundColor Cyan
    }

    # Per-prompt-length summary
    Write-Host ""
    Write-Host "Per-Prompt-Length Summary:" -ForegroundColor Yellow
    foreach ($promptLength in $PromptLengths) {
        $promptStats = $results.ModelResults | ForEach-Object { $_.PromptResults | Where-Object { $_.PromptLength -eq $promptLength } } | ForEach-Object { $_.Statistics }
        if ($promptStats.Count -gt 0) {
            $promptAvg = [math]::Round(($promptStats.AverageTokensPerSecond | Measure-Object -Average).Average, 2)
            Write-Host "  $promptLength prompts: $promptAvg tok/s average" -ForegroundColor Cyan
        }
    }
}

Write-Host ""

# Save results
$results | ConvertTo-Json -Depth 10 | Out-File -FilePath $OutputFile -Encoding utf8
Write-Host "Results saved to: $OutputFile" -ForegroundColor Cyan
Write-Host ""
