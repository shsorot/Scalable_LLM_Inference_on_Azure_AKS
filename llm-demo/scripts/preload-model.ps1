<#
.SYNOPSIS
    Pre-download LLM model into Ollama server
.DESCRIPTION
    Executes model download inside Ollama pod to pre-populate storage
    This avoids waiting during live demo
.PARAMETER ModelName
    Ollama model name (e.g., llama3.1:8b, phi3.5, mistral)
.PARAMETER Namespace
    Kubernetes namespace where Ollama is deployed
.EXAMPLE
    .\preload-model.ps1 -ModelName "llama3.1:8b" -Namespace "ollama"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ModelName,

    [Parameter(Mandatory = $false)]
    [string]$Namespace = "ollama"
)

$ErrorActionPreference = 'Stop'

Write-Host "`n=== Pre-loading LLM Model: $ModelName ===" -ForegroundColor Cyan

# Find Ollama pod
Write-Host "Finding Ollama pod..." -ForegroundColor Gray
$podName = kubectl get pod -n $Namespace -l app=ollama -o jsonpath='{.items[0].metadata.name}' 2>$null

if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($podName)) {
    throw "Ollama pod not found in namespace '$Namespace'. Is it running?"
}

Write-Host "  Found pod: $podName" -ForegroundColor Gray

# Check if model already exists
Write-Host "Checking if model is already downloaded..." -ForegroundColor Gray
$existingModels = kubectl exec -n $Namespace $podName -- ollama list 2>$null

if ($existingModels -match $ModelName) {
    Write-Host "  Model '$ModelName' already exists. Skipping download." -ForegroundColor Yellow
    Write-Host "  To force re-download, delete the model first:" -ForegroundColor Gray
    Write-Host "    kubectl exec -n $Namespace $podName -- ollama rm $ModelName" -ForegroundColor Gray
    exit 0
}

# Download model
Write-Host "Downloading model: $ModelName" -ForegroundColor Gray
Write-Host "  This will take several minutes depending on model size..." -ForegroundColor Gray
Write-Host "  Model sizes: phi3.5=2.3GB, llama3.1:8b=4.7GB, llama3.1:70b=40GB" -ForegroundColor Gray
Write-Host ""

# Run download with output streaming
$startTime = Get-Date
kubectl exec -n $Namespace $podName -- ollama pull $ModelName

if ($LASTEXITCODE -ne 0) {
    throw "Failed to download model '$ModelName'"
}

$duration = (Get-Date) - $startTime
Write-Host ""
Write-Host "Model '$ModelName' downloaded successfully in $($duration.TotalSeconds) seconds" -ForegroundColor Green

# Verify model is loaded
Write-Host "Verifying model installation..." -ForegroundColor Gray
$models = kubectl exec -n $Namespace $podName -- ollama list 2>$null

if ($models -match $ModelName) {
    Write-Host "  Model verified in Ollama" -ForegroundColor Gray

    # Show model info
    Write-Host "`nModel details:" -ForegroundColor Gray
    kubectl exec -n $Namespace $podName -- ollama show $ModelName 2>$null | Select-Object -First 10
} else {
    Write-Host "  Model not found in list. May need manual verification." -ForegroundColor Yellow
}

Write-Host "`nModel pre-loading complete!" -ForegroundColor Green
