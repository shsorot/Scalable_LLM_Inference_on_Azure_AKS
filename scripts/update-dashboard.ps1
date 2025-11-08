#!/usr/bin/env pwsh
# Updates Grafana dashboards by re-uploading JSON files via API

param(
    [string]$DashboardFile = "",
    [string]$Namespace = "monitoring"
)

$ErrorActionPreference = "Stop"

Write-Host "`n=== Updating Grafana Dashboard ===" -ForegroundColor Cyan

# Port-forward to Grafana
Write-Host "Setting up port-forward to Grafana..." -ForegroundColor Yellow
$portForwardJob = Start-Job -ScriptBlock {
    param($ns)
    kubectl port-forward -n $ns svc/monitoring-grafana 3000:80
} -ArgumentList $Namespace

Start-Sleep -Seconds 5

try {
    # Get Grafana credentials
    Write-Host "Retrieving Grafana admin password..." -ForegroundColor Yellow
    $grafanaSecret = kubectl get secret -n $Namespace monitoring-grafana -o json | ConvertFrom-Json
    $grafanaPassword = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($grafanaSecret.data.'admin-password'))

    $grafanaUrl = "http://localhost:3000"
    $credentials = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("admin:$grafanaPassword"))
    $headers = @{
        "Authorization" = "Basic $credentials"
        "Content-Type" = "application/json"
    }

    # Test connection
    Write-Host "Testing Grafana connection..." -ForegroundColor Yellow
    $null = Invoke-RestMethod -Method Get -Uri "$grafanaUrl/api/health" -Headers $headers
    Write-Host "✓ Connected to Grafana`n" -ForegroundColor Green

    # Get dashboard files
    $dashboardDir = Join-Path $PSScriptRoot ".." "dashboards"

    if ($DashboardFile) {
        $fullPath = Join-Path $dashboardDir $DashboardFile
        if (-not (Test-Path $fullPath)) {
            throw "Dashboard file not found: $fullPath"
        }
        $dashboardFiles = @(Get-Item $fullPath)
    }
    else {
        $dashboardFiles = Get-ChildItem -Path $dashboardDir -Filter "*.json"
    }

    if ($dashboardFiles.Count -eq 0) {
        throw "No dashboard files found in $dashboardDir"
    }

    Write-Host "Uploading $($dashboardFiles.Count) dashboard(s)...`n" -ForegroundColor Yellow

    foreach ($file in $dashboardFiles) {
        Write-Host "Uploading $($file.Name)..." -ForegroundColor Cyan

        try {
            $dashboardJson = Get-Content -Path $file.FullName -Raw | ConvertFrom-Json
            $payload = @{
                dashboard = $dashboardJson
                overwrite = $true
            } | ConvertTo-Json -Depth 100

            $result = Invoke-RestMethod -Method Post `
                -Uri "$grafanaUrl/api/dashboards/db" `
                -Headers $headers `
                -Body $payload

            Write-Host "  ✓ Uploaded: $($result.url)" -ForegroundColor Green
        }
        catch {
            Write-Host "  ✗ Failed: $_" -ForegroundColor Red
        }
    }

    Write-Host "`n=== Dashboard Update Complete ===" -ForegroundColor Green
    Write-Host "Refresh your Grafana browser to see changes`n" -ForegroundColor Yellow
}
finally {
    Write-Host "Cleaning up port-forward..." -ForegroundColor Gray
    Stop-Job $portForwardJob -ErrorAction SilentlyContinue
    Remove-Job $portForwardJob -ErrorAction SilentlyContinue
}
