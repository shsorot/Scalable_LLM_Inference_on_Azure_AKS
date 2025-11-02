<#
.SYNOPSIS
    Test Ollama API connectivity

.DESCRIPTION
    Simple diagnostic script to verify Ollama API is accessible
    and responding correctly.

.PARAMETER OllamaEndpoint
    Ollama API endpoint to test (default: http://localhost:11434)

.EXAMPLE
    .\test-connection.ps1
    .\test-connection.ps1 -OllamaEndpoint "http://20.54.123.45:11434"
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$OllamaEndpoint = "http://localhost:11434"
)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Ollama API Connection Test" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Testing endpoint: $OllamaEndpoint" -ForegroundColor White
Write-Host ""

# Test 1: Basic connectivity
Write-Host "[1/4] Testing basic connectivity..." -ForegroundColor Yellow
try {
    $response = Invoke-WebRequest -Uri "$OllamaEndpoint/api/tags" -Method Get -TimeoutSec 10 -UseBasicParsing
    Write-Host "  [OK] Connection successful (Status: $($response.StatusCode))" -ForegroundColor Green
}
catch {
    Write-Host "  [FAIL] Connection failed: $_" -ForegroundColor Red
    Write-Host ""
    Write-Host "Troubleshooting steps:" -ForegroundColor Yellow
    Write-Host "  1. Verify Ollama pods are running: kubectl get pods -n ollama" -ForegroundColor White
    Write-Host "  2. Check service: kubectl get svc -n ollama" -ForegroundColor White
    Write-Host "  3. Start port-forward: kubectl port-forward -n ollama service/ollama 11434:11434" -ForegroundColor White
    Write-Host "  4. Test locally: curl http://localhost:11434/api/tags" -ForegroundColor White
    exit 1
}

# Test 2: Parse response
Write-Host "[2/4] Parsing API response..." -ForegroundColor Yellow
try {
    $data = $response.Content | ConvertFrom-Json
    $modelCount = ($data.models | Measure-Object).Count
    Write-Host "  [OK] Response parsed successfully" -ForegroundColor Green
    Write-Host "  [OK] Found $modelCount models installed" -ForegroundColor Green

    if ($modelCount -gt 0) {
        Write-Host ""
        Write-Host "  Installed models:" -ForegroundColor Cyan
        foreach ($model in $data.models) {
            $sizeInGB = [math]::Round($model.size / 1073741824, 2)
            Write-Host "    - $($model.name) (Size: $($sizeInGB))" -ForegroundColor White
        }
    }
}
catch {
    Write-Host "  [FAIL] Failed to parse response: $_" -ForegroundColor Red
    exit 1
}

# Test 3: Test generate API (if models exist)
if ($modelCount -gt 0) {
    Write-Host ""
    Write-Host "[3/4] Testing generation API..." -ForegroundColor Yellow
    $testModel = $data.models[0].name

    try {
        $generateBody = @{
            model = $testModel
            prompt = "Hello"
            stream = $false
        } | ConvertTo-Json -Compress

        $generateResponse = Invoke-RestMethod `
            -Uri "$OllamaEndpoint/api/generate" `
            -Method Post `
            -Body $generateBody `
            -ContentType "application/json" `
            -TimeoutSec 60 `
            -UseBasicParsing

        Write-Host "  [OK] Generation API works" -ForegroundColor Green
        Write-Host "  [OK] Test model: $testModel" -ForegroundColor Green
        Write-Host "  [OK] Response: $($generateResponse.response)" -ForegroundColor Green

        if ($generateResponse.eval_count -and $generateResponse.eval_duration) {
            $tokensPerSecond = $generateResponse.eval_count / ($generateResponse.eval_duration / 1000000000)
            Write-Host "  [OK] Performance: $([math]::Round($tokensPerSecond, 2)) tokens/second" -ForegroundColor Green
        }
    }
    catch {
        Write-Host "  [FAIL] Generation test failed: $_" -ForegroundColor Red
    }
}
else {
    Write-Host ""
    Write-Host "[3/4] Skipping generation test (no models installed)" -ForegroundColor Yellow
}

# Test 4: Check API version
Write-Host ""
Write-Host "[4/4] Checking API version..." -ForegroundColor Yellow
try {
    $versionResponse = Invoke-RestMethod -Uri "$OllamaEndpoint/api/version" -Method Get -TimeoutSec 10 -UseBasicParsing -ErrorAction SilentlyContinue
    Write-Host "  [OK] Ollama version: $($versionResponse.version)" -ForegroundColor Green
}
catch {
    Write-Host "  [WARN] Could not determine version (non-critical)" -ForegroundColor Yellow
}

# Summary
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "[OK] Ollama API is accessible and working" -ForegroundColor Green
Write-Host "[OK] Ready to run benchmarks" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "  1. Single user: .\single-user-benchmark.ps1 -OllamaEndpoint '$OllamaEndpoint'" -ForegroundColor White
Write-Host "  2. Tokens/sec: .\tokens-per-second-benchmark.ps1 -OllamaEndpoint '$OllamaEndpoint'" -ForegroundColor White
Write-Host "  3. Multi-user: .\multi-user-benchmark.ps1 -OllamaEndpoint '$OllamaEndpoint'" -ForegroundColor White
Write-Host "  4. All scenarios: .\run-benchmarks.ps1 -OllamaEndpoint '$OllamaEndpoint'" -ForegroundColor White
