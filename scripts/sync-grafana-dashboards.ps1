# Sync Grafana Dashboards to Kubernetes ConfigMap
# This script keeps Grafana dashboards in sync with the Git repository

param(
    [string]$Namespace = "monitoring",
    [string]$ConfigMapName = "grafana-dashboards",
    [string]$DashboardPath = "dashboards",
    [switch]$RestartGrafana
)

$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent $scriptPath

Write-Host ""
Write-Host "=== Grafana Dashboard Sync ===" -ForegroundColor Cyan
Write-Host ""

# Check if dashboard directory exists
$dashboardDir = Join-Path $repoRoot $DashboardPath
if (-not (Test-Path $dashboardDir)) {
    Write-Host "✗ Dashboard directory not found: $dashboardDir" -ForegroundColor Red
    exit 1
}

# Find all dashboard JSON files
$dashboardFiles = Get-ChildItem -Path $dashboardDir -Filter "*.json" -File
if ($dashboardFiles.Count -eq 0) {
    Write-Host "✗ No dashboard JSON files found in $dashboardDir" -ForegroundColor Red
    exit 1
}

Write-Host "Found $($dashboardFiles.Count) dashboard(s):" -ForegroundColor Green
foreach ($file in $dashboardFiles) {
    Write-Host "  • $($file.Name)" -ForegroundColor Gray
}
Write-Host ""

# Check if namespace exists
$namespaceExists = kubectl get namespace $Namespace 2>$null
if (-not $namespaceExists) {
    Write-Host "✗ Namespace '$Namespace' not found" -ForegroundColor Red
    Write-Host "  Create the namespace first or check that monitoring stack is deployed" -ForegroundColor Yellow
    exit 1
}

# Delete existing ConfigMap if it exists
Write-Host "Checking for existing ConfigMap..." -ForegroundColor Yellow
$existingCM = kubectl get configmap $ConfigMapName -n $Namespace 2>$null
if ($existingCM) {
    Write-Host "  Deleting existing ConfigMap '$ConfigMapName'..." -ForegroundColor Yellow
    kubectl delete configmap $ConfigMapName -n $Namespace 2>$null | Out-Null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  ✓ Old ConfigMap deleted" -ForegroundColor Green
    }
}
else {
    Write-Host "  No existing ConfigMap found (creating new)" -ForegroundColor Gray
}

Write-Host ""
Write-Host "Creating ConfigMap from dashboard files..." -ForegroundColor Yellow

# Build kubectl create configmap command
$cmArgs = @(
    "create", "configmap", $ConfigMapName,
    "--namespace", $Namespace
)

# Add each dashboard file
foreach ($file in $dashboardFiles) {
    $cmArgs += "--from-file=$($file.FullName)"
}

# Execute kubectl command
$result = & kubectl $cmArgs 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host "✓ ConfigMap '$ConfigMapName' created successfully" -ForegroundColor Green
}
else {
    Write-Host "✗ Failed to create ConfigMap" -ForegroundColor Red
    Write-Host "  Error: $result" -ForegroundColor Red
    exit 1
}

Write-Host ""

# Verify ConfigMap contents
Write-Host "Verifying ConfigMap contents..." -ForegroundColor Yellow
$cmData = kubectl get configmap $ConfigMapName -n $Namespace -o json 2>$null | ConvertFrom-Json
if ($cmData -and $cmData.data) {
    $dashboardCount = ($cmData.data | Get-Member -MemberType NoteProperty).Count
    Write-Host "✓ ConfigMap contains $dashboardCount dashboard(s)" -ForegroundColor Green
    foreach ($dashboardKey in ($cmData.data | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name)) {
        $size = [System.Text.Encoding]::UTF8.GetByteCount($cmData.data.$dashboardKey)
        Write-Host "  • $dashboardKey ($([Math]::Round($size/1KB, 1)) KB)" -ForegroundColor Gray
    }
}
else {
    Write-Host "⚠ Warning: Could not verify ConfigMap contents" -ForegroundColor Yellow
}

Write-Host ""

# Restart Grafana if requested
if ($RestartGrafana) {
    Write-Host "Restarting Grafana to load new dashboards..." -ForegroundColor Yellow

    # Find Grafana deployment
    $grafanaDeployment = kubectl get deployment -n $Namespace -o json 2>$null | ConvertFrom-Json |
        Select-Object -ExpandProperty items |
        Where-Object { $_.metadata.name -match "grafana" } |
        Select-Object -First 1

    if ($grafanaDeployment) {
        $deploymentName = $grafanaDeployment.metadata.name
        Write-Host "  Found Grafana deployment: $deploymentName" -ForegroundColor Gray

        $rolloutResult = kubectl rollout restart deployment/$deploymentName -n $Namespace 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  ✓ Grafana restart initiated" -ForegroundColor Green
            Write-Host ""
            Write-Host "  Waiting for rollout to complete..." -ForegroundColor Yellow

            $waitResult = kubectl rollout status deployment/$deploymentName -n $Namespace --timeout=120s 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-Host "  ✓ Grafana restarted successfully" -ForegroundColor Green
            }
            else {
                Write-Host "  ⚠ Rollout status check timed out or failed" -ForegroundColor Yellow
                Write-Host "  Grafana may still be restarting - check manually:" -ForegroundColor Gray
                Write-Host "    kubectl rollout status deployment/$deploymentName -n $Namespace" -ForegroundColor Gray
            }
        }
        else {
            Write-Host "  ✗ Failed to restart Grafana" -ForegroundColor Red
            Write-Host "  Error: $rolloutResult" -ForegroundColor Red
        }
    }
    else {
        Write-Host "  ✗ Grafana deployment not found in namespace '$Namespace'" -ForegroundColor Red
        Write-Host "  Available deployments:" -ForegroundColor Yellow
        kubectl get deployments -n $Namespace -o name
    }
}
else {
    Write-Host "ℹ️  Note: Grafana was not restarted. Dashboards will be available after next pod restart." -ForegroundColor Cyan
    Write-Host "  To restart Grafana now, run this script with -RestartGrafana flag" -ForegroundColor Gray
}

Write-Host ""
Write-Host "=== Dashboard Sync Complete ===" -ForegroundColor Green
Write-Host ""

if ($RestartGrafana) {
    Write-Host "Next steps:" -ForegroundColor Cyan
    Write-Host "  1. Wait ~30-60 seconds for Grafana to fully restart" -ForegroundColor Gray
    Write-Host "  2. Access Grafana dashboard" -ForegroundColor Gray
    Write-Host "  3. Dashboards should appear in the 'default' folder" -ForegroundColor Gray
    Write-Host ""
    Write-Host "To get Grafana URL:" -ForegroundColor Cyan
    Write-Host "  kubectl get svc -n $Namespace | Select-String grafana" -ForegroundColor Gray
}
else {
    Write-Host "To restart Grafana and load dashboards:" -ForegroundColor Cyan
    Write-Host "  .\scripts\sync-grafana-dashboards.ps1 -RestartGrafana" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Or restart manually:" -ForegroundColor Cyan
    Write-Host "  kubectl rollout restart deployment -n $Namespace -l app.kubernetes.io/name=grafana" -ForegroundColor Gray
}

Write-Host ""
