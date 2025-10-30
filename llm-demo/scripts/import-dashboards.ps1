# Import Custom Dashboards to Grafana
# Uploads pre-configured dashboards for GPU and LLM monitoring
#
# ⚠️ NOTE: This functionality is now integrated into deploy.ps1 (Step 8)
# This standalone script is kept for manual dashboard import only.
# For new deployments, dashboards are automatically imported.
#
# Usage: .\import-dashboards.ps1 [-GrafanaUrl <url>] [-GrafanaPassword <password>]

param(
    [string]$GrafanaUrl = "",                       # Auto-detect if not provided
    [string]$GrafanaPassword = "admin123!",         # Must match deploy-monitoring.ps1
    [string]$GrafanaUser = "admin"
)

# Color output functions
function Write-Header { param($Message) Write-Host "`n=== $Message ===" -ForegroundColor Cyan }
function Write-Info { param($Message) Write-Host "[INFO] $Message" -ForegroundColor Blue }
function Write-Success { param($Message) Write-Host "[SUCCESS] $Message" -ForegroundColor Green }
function Write-Warning { param($Message) Write-Host "[WARNING] $Message" -ForegroundColor Yellow }
function Write-Error { param($Message) Write-Host "[ERROR] $Message" -ForegroundColor Red }

Write-Header "Grafana Dashboard Import"

# Get Grafana URL if not provided
if (-not $GrafanaUrl) {
    Write-Info "Auto-detecting Grafana URL..."

    $svc = kubectl get svc -n monitoring monitoring-grafana -o json 2>$null | ConvertFrom-Json
    if ($svc -and $svc.status.loadBalancer.ingress) {
        $grafanaIp = $svc.status.loadBalancer.ingress[0].ip
        if ($grafanaIp) {
            $GrafanaUrl = "http://$grafanaIp"
            Write-Success "Detected Grafana URL: $GrafanaUrl"
        }
    }

    if (-not $GrafanaUrl) {
        Write-Warning "Could not auto-detect Grafana URL. Using port-forward..."
        Write-Info "Starting port-forward to Grafana (background process)..."

        # Kill any existing port-forward on 3000
        Get-Process | Where-Object {$_.ProcessName -eq "kubectl" -and $_.CommandLine -like "*port-forward*3000*"} | Stop-Process -Force -ErrorAction SilentlyContinue

        # Start new port-forward
        Start-Process -FilePath "kubectl" -ArgumentList "port-forward -n monitoring svc/monitoring-grafana 3000:80" -WindowStyle Hidden
        Start-Sleep -Seconds 5

        $GrafanaUrl = "http://localhost:3000"
        Write-Success "Using port-forward: $GrafanaUrl"
    }
}

# Test Grafana connection
Write-Header "Testing Grafana Connection"
$auth = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("${GrafanaUser}:${GrafanaPassword}"))
$headers = @{
    "Authorization" = "Basic $auth"
    "Content-Type" = "application/json"
}

try {
    $health = Invoke-RestMethod -Uri "$GrafanaUrl/api/health" -Method Get -ErrorAction Stop
    Write-Success "Connected to Grafana (version: $($health.version))"
} catch {
    Write-Error "Failed to connect to Grafana at $GrafanaUrl"
    Write-Error "Error: $_"
    Write-Info "Make sure Grafana is running and password is correct"
    Write-Info "Default password: admin123!"
    exit 1
}

# Get dashboard files
$dashboardDir = Join-Path $PSScriptRoot "..\dashboards"
if (-not (Test-Path $dashboardDir)) {
    Write-Error "Dashboard directory not found: $dashboardDir"
    exit 1
}

$dashboardFiles = Get-ChildItem -Path $dashboardDir -Filter "*.json"
if ($dashboardFiles.Count -eq 0) {
    Write-Warning "No dashboard files found in $dashboardDir"
    exit 0
}

Write-Info "Found $($dashboardFiles.Count) dashboard(s) to import"

# Import each dashboard
Write-Header "Importing Dashboards"

foreach ($file in $dashboardFiles) {
    Write-Info "Importing: $($file.Name)"

    try {
        # Read dashboard JSON
        $dashboardJson = Get-Content -Path $file.FullName -Raw | ConvertFrom-Json

        # Wrap in Grafana import format
        $importPayload = @{
            dashboard = $dashboardJson
            overwrite = $true
            inputs = @()
        } | ConvertTo-Json -Depth 100

        # Import dashboard
        $response = Invoke-RestMethod -Uri "$GrafanaUrl/api/dashboards/db" -Method Post -Headers $headers -Body $importPayload -ErrorAction Stop

        Write-Success "✓ Imported: $($file.BaseName) (UID: $($response.uid))"
        Write-Info "  URL: $GrafanaUrl/d/$($response.uid)"

    } catch {
        Write-Error "✗ Failed to import $($file.Name): $_"
    }
}

# List all dashboards
Write-Header "Available Dashboards"

try {
    $dashboards = Invoke-RestMethod -Uri "$GrafanaUrl/api/search?type=dash-db" -Method Get -Headers $headers

    foreach ($dashboard in $dashboards) {
        Write-Host "  📊 $($dashboard.title)" -ForegroundColor Cyan
        Write-Host "     $GrafanaUrl/d/$($dashboard.uid)" -ForegroundColor Gray
    }

    Write-Host ""
    Write-Success "Total dashboards: $($dashboards.Count)"

} catch {
    Write-Warning "Could not list dashboards: $_"
}

Write-Host @"

========================================
  DASHBOARD IMPORT COMPLETE
========================================

Grafana URL: $GrafanaUrl
Username   : $GrafanaUser
Password   : $GrafanaPassword

📊 Imported Dashboards:
"@ -ForegroundColor Green

foreach ($file in $dashboardFiles) {
    Write-Host "   ✓ $($file.BaseName)" -ForegroundColor Green
}

Write-Host @"

🎯 Quick Access:
   1. Open: $GrafanaUrl
   2. Login with credentials above
   3. Browse dashboards from left menu
   4. Or search for 'LLM' or 'GPU'

"@ -ForegroundColor Cyan

# Offer to open browser
$openBrowser = Read-Host "Open Grafana in browser now? (y/n)"
if ($openBrowser -eq 'y' -or $openBrowser -eq 'Y') {
    Start-Process $GrafanaUrl
}
