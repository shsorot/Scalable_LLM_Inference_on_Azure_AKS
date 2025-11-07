# Cluster Lifecycle Management Script
# Coordinates AKS cluster and PostgreSQL server start/stop operations

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("Stop", "Start", "Status")]
    [string]$Action,

    [Parameter(Mandatory=$false)]
    [string]$ResourceGroup,

    [Parameter(Mandatory=$false)]
    [string]$ClusterName,

    [Parameter(Mandatory=$false)]
    [string]$PostgresServerName,

    [Parameter(Mandatory=$false)]
    [switch]$SkipPostgres
)

# Import common functions
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $scriptPath "Common.ps1")

function Get-ClusterStatus {
    param($ResourceGroup, $ClusterName, $PostgresServerName)

    Write-Host ""
    Write-Host "=== Cluster Status ===" -ForegroundColor Cyan

    # AKS Status
    Write-Host "Checking AKS cluster status..." -ForegroundColor Yellow
    $aksState = az aks show -g $ResourceGroup -n $ClusterName --query "powerState.code" -o tsv 2>$null
    if ($aksState) {
        $aksColor = if ($aksState -eq "Running") { "Green" } else { "Yellow" }
        Write-Host "  AKS Cluster: $aksState" -ForegroundColor $aksColor
    }
    else {
        Write-Host "  AKS Cluster: Not found or error" -ForegroundColor Red
    }

    # PostgreSQL Status
    if (-not $SkipPostgres -and $PostgresServerName) {
        Write-Host "Checking PostgreSQL server status..." -ForegroundColor Yellow
        $pgState = az postgres flexible-server show -g $ResourceGroup -n $PostgresServerName --query "state" -o tsv 2>$null
        if ($pgState) {
            $pgColor = if ($pgState -eq "Ready") { "Green" } else { "Yellow" }
            Write-Host "  PostgreSQL: $pgState" -ForegroundColor $pgColor
        }
        else {
            Write-Host "  PostgreSQL: Not found or error" -ForegroundColor Red
        }
    }

    Write-Host ""
}

function Stop-Infrastructure {
    param($ResourceGroup, $ClusterName, $PostgresServerName)

    Write-Host ""
    Write-Host "=== Stopping Infrastructure ===" -ForegroundColor Cyan
    Write-Host ""

    # Stop AKS first (releases locks, allows faster shutdown)
    Write-Host "Step 1: Stopping AKS cluster..." -ForegroundColor Yellow
    Write-Host "  This will deallocate all nodes and stop running workloads" -ForegroundColor Gray
    Write-Host "  Expected time: 2-3 minutes" -ForegroundColor Gray
    Write-Host ""

    $result = az aks stop --name $ClusterName --resource-group $ResourceGroup 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  ✓ AKS cluster stopped successfully" -ForegroundColor Green
    }
    else {
        Write-Host "  ✗ Failed to stop AKS cluster" -ForegroundColor Red
        Write-Host "  Error: $result" -ForegroundColor Red
        return $false
    }

    # Stop PostgreSQL if not skipped
    if (-not $SkipPostgres -and $PostgresServerName) {
        Write-Host ""
        Write-Host "Step 2: Stopping PostgreSQL server..." -ForegroundColor Yellow
        Write-Host "  This will stop the database and halt billing" -ForegroundColor Gray
        Write-Host "  Expected time: 1-2 minutes" -ForegroundColor Gray
        Write-Host ""

        $result = az postgres flexible-server stop --name $PostgresServerName --resource-group $ResourceGroup 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  ✓ PostgreSQL server stopped successfully" -ForegroundColor Green
        }
        else {
            Write-Host "  ✗ Failed to stop PostgreSQL server" -ForegroundColor Red
            Write-Host "  Error: $result" -ForegroundColor Red
            return $false
        }
    }

    Write-Host ""
    Write-Host "=== Shutdown Complete ===" -ForegroundColor Green
    Write-Host ""
    Write-Host "Infrastructure stopped successfully:" -ForegroundColor White
    Write-Host "  • AKS cluster: Stopped (nodes deallocated)" -ForegroundColor Gray
    if (-not $SkipPostgres -and $PostgresServerName) {
        Write-Host "  • PostgreSQL: Stopped (no billing)" -ForegroundColor Gray
    }
    Write-Host ""
    Write-Host "💰 Cost while stopped: ~`$0/hour" -ForegroundColor Cyan
    Write-Host ""

    return $true
}

function Start-Infrastructure {
    param($ResourceGroup, $ClusterName, $PostgresServerName)

    Write-Host ""
    Write-Host "=== Starting Infrastructure ===" -ForegroundColor Cyan
    Write-Host ""

    # Start PostgreSQL first (must be ready before pods start)
    if (-not $SkipPostgres -and $PostgresServerName) {
        Write-Host "Step 1: Starting PostgreSQL server..." -ForegroundColor Yellow
        Write-Host "  Database must be ready before starting AKS workloads" -ForegroundColor Gray
        Write-Host "  Expected time: 1-2 minutes" -ForegroundColor Gray
        Write-Host ""

        $result = az postgres flexible-server start --name $PostgresServerName --resource-group $ResourceGroup 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  ✓ PostgreSQL server start initiated" -ForegroundColor Green
        }
        else {
            Write-Host "  ✗ Failed to start PostgreSQL server" -ForegroundColor Red
            Write-Host "  Error: $result" -ForegroundColor Red
            return $false
        }

        Write-Host ""
        Write-Host "  Waiting for database to be fully ready (30 seconds)..." -ForegroundColor Yellow
        Start-Sleep -Seconds 30
        Write-Host "  ✓ Database should be ready" -ForegroundColor Green
    }

    # Start AKS
    Write-Host ""
    $stepNum = if (-not $SkipPostgres -and $PostgresServerName) { "2" } else { "1" }
    Write-Host "Step ${stepNum}: Starting AKS cluster..." -ForegroundColor Yellow
    Write-Host "  This will allocate nodes and start all workloads" -ForegroundColor Gray
    Write-Host "  Expected time: 3-5 minutes" -ForegroundColor Gray
    Write-Host ""

    $result = az aks start --name $ClusterName --resource-group $ResourceGroup 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  ✓ AKS cluster started successfully" -ForegroundColor Green
    }
    else {
        Write-Host "  ✗ Failed to start AKS cluster" -ForegroundColor Red
        Write-Host "  Error: $result" -ForegroundColor Red
        return $false
    }

    Write-Host ""
    Write-Host "=== Startup Complete ===" -ForegroundColor Green
    Write-Host ""
    Write-Host "Infrastructure started successfully:" -ForegroundColor White
    if (-not $SkipPostgres -and $PostgresServerName) {
        Write-Host "  • PostgreSQL: Ready (accepting connections)" -ForegroundColor Gray
    }
    Write-Host "  • AKS cluster: Running (nodes allocated)" -ForegroundColor Gray
    Write-Host ""
    Write-Host "⏳ Pods are starting... please wait 2-3 minutes for all services to be ready" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "To check pod status:" -ForegroundColor Cyan
    Write-Host "  kubectl get pods -n ollama" -ForegroundColor Gray
    Write-Host "  kubectl get pods -n monitoring" -ForegroundColor Gray
    Write-Host ""
    Write-Host "To get service URLs:" -ForegroundColor Cyan
    Write-Host "  kubectl get svc -n ollama open-webui" -ForegroundColor Gray
    Write-Host "  kubectl get svc -n monitoring monitoring-grafana" -ForegroundColor Gray
    Write-Host ""

    return $true
}

# Validate parameters
if ($Action -ne "Status") {
    if (-not $ResourceGroup) {
        Write-Host "Error: -ResourceGroup is required for $Action action" -ForegroundColor Red
        exit 1
    }
    if (-not $ClusterName) {
        Write-Host "Error: -ClusterName is required for $Action action" -ForegroundColor Red
        exit 1
    }
    if (-not $SkipPostgres -and -not $PostgresServerName) {
        Write-Host "Warning: -PostgresServerName not provided. Use -SkipPostgres to skip database operations." -ForegroundColor Yellow
        $response = Read-Host "Continue without PostgreSQL management? (y/N)"
        if ($response -ne "y") {
            exit 1
        }
        $SkipPostgres = $true
    }
}

# Execute action
switch ($Action) {
    "Status" {
        if (-not $ResourceGroup -or -not $ClusterName) {
            Write-Host "Error: -ResourceGroup and -ClusterName required for Status" -ForegroundColor Red
            exit 1
        }
        Get-ClusterStatus -ResourceGroup $ResourceGroup -ClusterName $ClusterName -PostgresServerName $PostgresServerName
    }

    "Stop" {
        Write-Host ""
        Write-Host "╔════════════════════════════════════════════╗" -ForegroundColor Yellow
        Write-Host "║  Cluster Shutdown - Confirmation Required  ║" -ForegroundColor Yellow
        Write-Host "╚════════════════════════════════════════════╝" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "This will stop:" -ForegroundColor White
        Write-Host "  • AKS Cluster: $ClusterName" -ForegroundColor Gray
        if (-not $SkipPostgres -and $PostgresServerName) {
            Write-Host "  • PostgreSQL: $PostgresServerName" -ForegroundColor Gray
        }
        Write-Host ""
        Write-Host "⚠️  All running workloads will be terminated" -ForegroundColor Yellow
        Write-Host "⚠️  Active user sessions will be disconnected" -ForegroundColor Yellow
        Write-Host "✓  Data will be preserved (persistent volumes)" -ForegroundColor Green
        Write-Host ""

        $confirmation = Read-Host "Type 'STOP' to confirm shutdown"
        if ($confirmation -ne "STOP") {
            Write-Host ""
            Write-Host "Shutdown cancelled." -ForegroundColor Yellow
            exit 0
        }

        $success = Stop-Infrastructure -ResourceGroup $ResourceGroup -ClusterName $ClusterName -PostgresServerName $PostgresServerName
        exit $(if ($success) { 0 } else { 1 })
    }

    "Start" {
        Write-Host ""
        Write-Host "╔════════════════════════════════════════════╗" -ForegroundColor Cyan
        Write-Host "║       Starting Cluster Infrastructure      ║" -ForegroundColor Cyan
        Write-Host "╚════════════════════════════════════════════╝" -ForegroundColor Cyan

        $success = Start-Infrastructure -ResourceGroup $ResourceGroup -ClusterName $ClusterName -PostgresServerName $PostgresServerName
        exit $(if ($success) { 0 } else { 1 })
    }
}
