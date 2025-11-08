param(
    [Parameter(Mandatory=$true)]
    [string]$GrafanaPassword,

    [Parameter(Mandatory=$true)]
    [string]$PostgresPassword,

    [Parameter(Mandatory=$true)]
    [string]$PostgresServerFqdn,

    [Parameter(Mandatory=$true)]
    [string]$PostgresAdminUsername
)

$ErrorActionPreference = "Stop"

Write-Host "[INFO] Deploying Monitoring Stack (Prometheus + Grafana)" -ForegroundColor Cyan

# Check if namespace exists
$existingNs = kubectl get namespaces -o json 2>$null | ConvertFrom-Json
$monitoringExists = $existingNs.items | Where-Object { $_.metadata.name -eq "monitoring" }

if (-not $monitoringExists) {
    Write-Host "[INFO] Creating monitoring namespace..." -ForegroundColor Cyan
    kubectl create namespace monitoring 2>&1 | Out-Null
}

# Add Helm repo
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts 2>&1 | Out-Null
helm repo update 2>&1 | Out-Null
Write-Host "[OK] Helm repository updated" -ForegroundColor Green

# Create monitoring values file
$monitoringValuesFile = Join-Path $env:TEMP "monitoring-values.yaml"
$monitoringValues = @"
defaultTolerations: &commonTolerations
  - key: CriticalAddonsOnly
    operator: Equal
    value: "true"
    effect: NoSchedule

prometheusOperator:
  tolerations: *commonTolerations
  admissionWebhooks:
    patch:
      tolerations: *commonTolerations

prometheus:
  prometheusSpec:
    serviceMonitorSelectorNilUsesHelmValues: false
    retention: 7d
    storageSpec:
      volumeClaimTemplate:
        spec:
          accessModes: ["ReadWriteOnce"]
          resources:
            requests:
              storage: 20Gi
    tolerations: *commonTolerations

grafana:
  adminPassword: $GrafanaPassword
  service:
    type: LoadBalancer
  persistence:
    enabled: true
    type: pvc
    storageClassName: azurefile-premium-llm
    accessModes:
      - ReadWriteOnce
    size: 10Gi
  env:
    GF_DATABASE_TYPE: postgres
    GF_DATABASE_HOST: $PostgresServerFqdn`:5432
    GF_DATABASE_NAME: grafana
    GF_DATABASE_USER: $PostgresAdminUsername
    GF_DATABASE_PASSWORD: $PostgresPassword
    GF_DATABASE_SSL_MODE: require
  initChownData:
    enabled: false
  tolerations: *commonTolerations

alertmanager:
  alertmanagerSpec:
    tolerations: *commonTolerations

kube-state-metrics:
  tolerations: *commonTolerations

prometheus-node-exporter:
  tolerations:
    - operator: Exists
"@

Set-Content -Path $monitoringValuesFile -Value $monitoringValues

Write-Host "[INFO] Installing kube-prometheus-stack (this may take 5-10 minutes)..." -ForegroundColor Cyan
$ErrorActionPreference = 'Continue'
$helmOutput = helm upgrade --install monitoring prometheus-community/kube-prometheus-stack `
    --namespace monitoring `
    -f $monitoringValuesFile `
    --wait `
    --timeout 10m 2>&1
$helmExitCode = $LASTEXITCODE
$ErrorActionPreference = 'Stop'

# Check for Azure Policy warnings
$policyWarnings = $helmOutput | Select-String -Pattern "azurepolicy.*has not been allowed"
if ($policyWarnings) {
    Write-Host "[INFO] Note: Azure Policy warnings detected (audit mode, not blocking deployment)" -ForegroundColor Cyan
}

# Verify deployment
$helmStatus = helm list -n monitoring -o json 2>$null | ConvertFrom-Json
$deploymentSuccess = $helmStatus | Where-Object { $_.name -eq "monitoring" -and $_.status -eq "deployed" }

if ($deploymentSuccess) {
    Write-Host "[OK] Monitoring stack deployed successfully" -ForegroundColor Green
    return $true
} else {
    Write-Host "[ERROR] Monitoring stack deployment failed" -ForegroundColor Red
    Write-Host "[INFO] Helm output:" -ForegroundColor Cyan
    $helmOutput | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }
    return $false
}
