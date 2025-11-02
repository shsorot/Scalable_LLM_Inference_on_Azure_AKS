<#
.SYNOPSIS
    Quick benchmark runner with common scenarios

.DESCRIPTION
    Convenience script to run benchmarks with common configurations.
    Automatically sets up port-forwarding if needed.

.PARAMETER Scenario
    Scenario to run: SingleUser, MultiUser3, MultiUser5, AllScenarios

.PARAMETER UsePortForward
    Use kubectl port-forward instead of LoadBalancer IP

.PARAMETER OllamaEndpoint
    Direct Ollama endpoint (overrides port-forward)

.EXAMPLE
    .\run-benchmarks.ps1 -Scenario SingleUser -UsePortForward

.EXAMPLE
    .\run-benchmarks.ps1 -Scenario MultiUser5 -OllamaEndpoint "http://20.54.123.45:11434"
#>

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet("SingleUser", "MultiUser3", "MultiUser5", "TokensPerSecond", "AllScenarios")]
    [string]$Scenario = "AllScenarios",

    [Parameter(Mandatory=$false)]
    [switch]$UsePortForward,

    [Parameter(Mandatory=$false)]
    [string]$OllamaEndpoint = ""
)

$ErrorActionPreference = "Stop"

# Get the script directory for resolving relative paths
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Benchmark Runner" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Determine endpoint
$endpoint = $OllamaEndpoint
$portForwardJob = $null

if ([string]::IsNullOrEmpty($endpoint)) {
    if ($UsePortForward) {
        Write-Host "Setting up port-forward..." -ForegroundColor Yellow

        # Check if port-forward already exists
        $existingPortForward = Get-NetTCPConnection -LocalPort 11434 -State Listen -ErrorAction SilentlyContinue
        if ($existingPortForward) {
            Write-Host "  Port 11434 already in use. Using existing connection." -ForegroundColor Green
        }
        else {
            Write-Host "  Starting kubectl port-forward..." -ForegroundColor Yellow
            $portForwardJob = Start-Job -ScriptBlock {
                kubectl port-forward -n ollama service/ollama 11434:11434
            }
            Start-Sleep -Seconds 3
            Write-Host "  Port-forward established." -ForegroundColor Green
        }

        $endpoint = "http://localhost:11434"
    }
    else {
        Write-Host "Getting Ollama service endpoint..." -ForegroundColor Yellow
        try {
            $service = kubectl get svc -n ollama ollama -o json | ConvertFrom-Json
            $loadBalancerIP = $service.status.loadBalancer.ingress[0].ip

            if ([string]::IsNullOrEmpty($loadBalancerIP)) {
                Write-Host "  LoadBalancer IP not available. Falling back to port-forward." -ForegroundColor Yellow
                $portForwardJob = Start-Job -ScriptBlock {
                    kubectl port-forward -n ollama service/ollama 11434:11434
                }
                Start-Sleep -Seconds 3
                $endpoint = "http://localhost:11434"
            }
            else {
                $endpoint = "http://${loadBalancerIP}:11434"
                Write-Host "  Using LoadBalancer: $endpoint" -ForegroundColor Green
            }
        }
        catch {
            Write-Host "Could not determine Ollama endpoint. Use -OllamaEndpoint or -UsePortForward" -ForegroundColor Red
            exit 1
        }
    }
}

Write-Host ""
Write-Host "Endpoint: $endpoint" -ForegroundColor White
Write-Host "Scenario: $Scenario" -ForegroundColor White
Write-Host ""

# Create output directory with timestamp in the benchmarks folder
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$outputDir = Join-Path $scriptDir "results-$timestamp"
New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
Write-Host "Results will be saved to: $outputDir" -ForegroundColor Cyan
Write-Host ""

try {
    # Run scenarios
    switch ($Scenario) {
        "SingleUser" {
            Write-Host "Running Single User benchmark..." -ForegroundColor Yellow
            & "$scriptDir\single-user-benchmark.ps1" `
                -OllamaEndpoint $endpoint `
                -Model "llama3.1:8b" `
                -OutputFile "$outputDir\single-user.json"
        }

        "MultiUser3" {
            Write-Host "Running Multi-User (3 concurrent) benchmark..." -ForegroundColor Yellow
            & "$scriptDir\multi-user-benchmark.ps1" `
                -OllamaEndpoint $endpoint `
                -ConcurrentUsers 3 `
                -OutputFile "$outputDir\multi-user-3.json"
        }

        "MultiUser5" {
            Write-Host "Running Multi-User (5 concurrent) benchmark..." -ForegroundColor Yellow
            & "$scriptDir\multi-user-benchmark.ps1" `
                -OllamaEndpoint $endpoint `
                -ConcurrentUsers 5 `
                -OutputFile "$outputDir\multi-user-5.json"
        }

        "TokensPerSecond" {
            Write-Host "Running Tokens/Second benchmark..." -ForegroundColor Yellow
            & "$scriptDir\tokens-per-second-benchmark.ps1" `
                -OllamaEndpoint $endpoint `
                -Models @("phi3.5", "llama3.1:8b") `
                -PromptLengths @("Short", "Medium", "Long") `
                -OutputFile "$outputDir\tokens-per-second.json"
        }

        "AllScenarios" {
            Write-Host "Running all benchmark scenarios..." -ForegroundColor Yellow
            Write-Host ""

            Write-Host "[1/4] Single User benchmark..." -ForegroundColor Cyan
            & "$scriptDir\single-user-benchmark.ps1" `
                -OllamaEndpoint $endpoint `
                -Model "llama3.1:8b" `
                -OutputFile "$outputDir\single-user.json"

            Write-Host ""
            Write-Host "[2/4] Multi-User (3 concurrent) benchmark..." -ForegroundColor Cyan
            & "$scriptDir\multi-user-benchmark.ps1" `
                -OllamaEndpoint $endpoint `
                -ConcurrentUsers 3 `
                -OutputFile "$outputDir\multi-user-3.json"

            Write-Host ""
            Write-Host "[3/4] Multi-User (5 concurrent) benchmark..." -ForegroundColor Cyan
            & "$scriptDir\multi-user-benchmark.ps1" `
                -OllamaEndpoint $endpoint `
                -ConcurrentUsers 5 `
                -OutputFile "$outputDir\multi-user-5.json"

            Write-Host ""
            Write-Host "[4/4] Tokens/Second benchmark..." -ForegroundColor Cyan
            & "$scriptDir\tokens-per-second-benchmark.ps1" `
                -OllamaEndpoint $endpoint `
                -Models @("phi3.5", "llama3.1:8b") `
                -PromptLengths @("Short", "Medium", "Long") `
                -OutputFile "$outputDir\tokens-per-second.json"
        }
    }
}
finally {
    # Cleanup port-forward if we started it
    if ($portForwardJob) {
        Write-Host ""
        Write-Host "Cleaning up port-forward..." -ForegroundColor Yellow
        Stop-Job -Job $portForwardJob
        Remove-Job -Job $portForwardJob
        Write-Host "Port-forward stopped." -ForegroundColor Green
    }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "All benchmarks completed!" -ForegroundColor Green
Write-Host "Results saved to: $outputDir" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
