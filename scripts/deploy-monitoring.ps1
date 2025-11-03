# Deploy Monitoring Stack (Prometheus + Grafana)
# Comprehensive observability for LLM platform with GPU metrics
#
# ⚠️ NOTE: This functionality is now integrated into deploy.ps1 (Step 8)
# This standalone script is kept for manual monitoring deployment only.
# For new deployments, monitoring is automatically included.
#
# Usage: .\deploy-monitoring.ps1 [-SkipHelm] [-GrafanaPassword <password>] [-GeneratePassword]

param(
    [switch]$SkipHelm,                              # Skip Helm installation
    [string]$GrafanaPassword = "",                  # Grafana admin password (optional, will generate if not provided)
    [switch]$GeneratePassword,                      # Generate random Grafana password
    [switch]$ImportDashboards                       # Import pre-configured dashboards
)

# Function to generate secure random password
function New-RandomPassword {
    param(
        [int]$Length = 16
    )
    $chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*"
    $password = -join ((1..$Length) | ForEach-Object { $chars[(Get-Random -Maximum $chars.Length)] })
    return $password
}

# Generate password if requested or not provided
if ($GeneratePassword -or [string]::IsNullOrEmpty($GrafanaPassword)) {
    $GrafanaPassword = New-RandomPassword -Length 16
    Write-Host "[INFO] Generated random Grafana password" -ForegroundColor Yellow
}

# Color output functions
function Write-Header { param($Message) Write-Host "`n=== $Message ===" -ForegroundColor Cyan }
function Write-Info { param($Message) Write-Host "[INFO] $Message" -ForegroundColor Blue }
function Write-Success { param($Message) Write-Host "[SUCCESS] $Message" -ForegroundColor Green }
function Write-Warning { param($Message) Write-Host "[WARNING] $Message" -ForegroundColor Yellow }
function Write-Error { param($Message) Write-Host "[ERROR] $Message" -ForegroundColor Red }

Write-Host @"

============================================
  Monitoring Stack Deployment
  Prometheus + Grafana + DCGM
============================================
Grafana Password  : $GrafanaPassword
Namespace         : monitoring
============================================

"@ -ForegroundColor Cyan

# Pre-flight checks
Write-Header "Pre-Flight Checks"

# Check kubectl
if (-not (Get-Command kubectl -ErrorAction SilentlyContinue)) {
    Write-Error "kubectl not found. Please install kubectl first."
    exit 1
}
Write-Success "kubectl installed: $(kubectl version --client --short 2>$null)"

# Check helm
if (-not $SkipHelm) {
    if (-not (Get-Command helm -ErrorAction SilentlyContinue)) {
        Write-Error "Helm not found. Installing Helm..."
        # Install Helm on Windows
        winget install Helm.Helm
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Failed to install Helm. Install manually: https://helm.sh/docs/intro/install/"
            exit 1
        }
    }
    Write-Success "Helm installed: $(helm version --short)"
}

# Check cluster connection
$context = kubectl config current-context 2>$null
if (-not $context) {
    Write-Error "Not connected to Kubernetes cluster. Run 'az aks get-credentials' first."
    exit 1
}
Write-Success "Connected to cluster: $context"

# Create namespace
Write-Header "Creating Monitoring Namespace"
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
Write-Success "Namespace 'monitoring' ready"

# Add Helm repositories
if (-not $SkipHelm) {
    Write-Header "Adding Helm Repositories"

    Write-Info "Adding prometheus-community repo..."
    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts

    Write-Info "Adding grafana repo..."
    helm repo add grafana https://grafana.github.io/helm-charts

    Write-Info "Updating Helm repos..."
    helm repo update

    Write-Success "Helm repositories updated"
}

# Create Prometheus values file
Write-Header "Configuring Prometheus Stack"
$prometheusValues = @"
# Prometheus + Grafana Stack Configuration
# Optimized for GPU monitoring and LLM workloads

# Prometheus configuration
prometheus:
  prometheusSpec:
    # Enable service discovery for all ServiceMonitors
    serviceMonitorSelectorNilUsesHelmValues: false
    podMonitorSelectorNilUsesHelmValues: false

    # Retention and storage
    retention: 7d
    storageSpec:
      volumeClaimTemplate:
        spec:
          accessModes: ["ReadWriteOnce"]
          resources:
            requests:
              storage: 20Gi

    # Resource limits
    resources:
      requests:
        cpu: 500m
        memory: 2Gi
      limits:
        cpu: 2000m
        memory: 8Gi

    # Scrape interval
    scrapeInterval: 30s
    evaluationInterval: 30s

    # Additional scrape configs for DCGM
    additionalScrapeConfigs:
      - job_name: 'dcgm-exporter'
        kubernetes_sd_configs:
          - role: pod
            namespaces:
              names:
                - ollama
        relabel_configs:
          - source_labels: [__meta_kubernetes_pod_label_app_kubernetes_io_name]
            action: keep
            regex: dcgm-exporter
          - source_labels: [__meta_kubernetes_pod_ip]
            action: replace
            target_label: __address__
            replacement: '$1:9400'

# Grafana configuration
grafana:
  enabled: true

  # Admin credentials
  adminPassword: $GrafanaPassword

  # Service configuration (LoadBalancer for external access)
  service:
    type: LoadBalancer
    port: 80
    annotations:
      service.beta.kubernetes.io/azure-load-balancer-health-probe-request-path: /api/health

  # Persistence for dashboards
  persistence:
    enabled: true
    size: 10Gi

  # Resource limits
  resources:
    requests:
      cpu: 250m
      memory: 512Mi
    limits:
      cpu: 500m
      memory: 1Gi

  # Data sources (auto-configured)
  datasources:
    datasources.yaml:
      apiVersion: 1
      datasources:
        - name: Prometheus
          type: prometheus
          url: http://monitoring-kube-prometheus-prometheus.monitoring.svc:9090
          isDefault: true
          access: proxy

  # Dashboard providers
  dashboardProviders:
    dashboardproviders.yaml:
      apiVersion: 1
      providers:
        - name: 'default'
          orgId: 1
          folder: ''
          type: file
          disableDeletion: false
          editable: true
          options:
            path: /var/lib/grafana/dashboards/default
        - name: 'gpu'
          orgId: 1
          folder: 'GPU Monitoring'
          type: file
          disableDeletion: false
          editable: true
          options:
            path: /var/lib/grafana/dashboards/gpu
        - name: 'llm'
          orgId: 1
          folder: 'LLM Platform'
          type: file
          disableDeletion: false
          editable: true
          options:
            path: /var/lib/grafana/dashboards/llm

  # Pre-load dashboards
  dashboards:
    default:
      kubernetes-cluster:
        gnetId: 15398
        revision: 1
        datasource: Prometheus
      node-exporter:
        gnetId: 1860
        revision: 33
        datasource: Prometheus
    gpu:
      nvidia-dcgm:
        gnetId: 12239
        revision: 2
        datasource: Prometheus

# Alertmanager (optional, can be disabled)
alertmanager:
  enabled: true
  alertmanagerSpec:
    resources:
      requests:
        cpu: 100m
        memory: 128Mi
      limits:
        cpu: 200m
        memory: 256Mi

# Node Exporter (for node-level metrics)
nodeExporter:
  enabled: true

# Kube State Metrics (for K8s object metrics)
kubeStateMetrics:
  enabled: true

# Prometheus Operator
prometheusOperator:
  resources:
    requests:
      cpu: 100m
      memory: 128Mi
    limits:
      cpu: 200m
      memory: 256Mi
"@

$valuesPath = "$PSScriptRoot\prometheus-values.yaml"
$prometheusValues | Out-File -FilePath $valuesPath -Encoding UTF8
Write-Success "Prometheus values saved to: $valuesPath"

# Install/Upgrade Prometheus Stack
Write-Header "Installing Prometheus + Grafana Stack"
Write-Info "This takes 3-5 minutes..."

$ErrorActionPreference = 'Continue'
$helmOutput = helm upgrade --install monitoring prometheus-community/kube-prometheus-stack `
    --namespace monitoring `
    --values $valuesPath `
    --wait `
    --timeout 10m 2>&1
$helmExitCode = $LASTEXITCODE
$ErrorActionPreference = 'Stop'

# Check for Azure Policy warnings in output (informational only)
$policyWarnings = $helmOutput | Select-String -Pattern "azurepolicy.*has not been allowed"
if ($policyWarnings) {
    Write-Info "Note: Azure Policy warnings detected (audit mode, not blocking deployment):"
    $policyWarnings | ForEach-Object {
        $line = $_.Line
        # Extract image name from warning
        if ($line -match "Container image ([^\s]+)") {
            Write-Info "  - Image: $($matches[1])"
        }
    }
    Write-Info "These warnings are from Azure Policy in audit/warn mode and do not affect deployment."
}

# Verify actual deployment by checking Helm release status
$helmStatus = helm list -n monitoring -o json 2>$null | ConvertFrom-Json
$deploymentSuccess = $helmStatus | Where-Object { $_.name -eq "monitoring" -and $_.status -eq "deployed" }

if ($deploymentSuccess) {
    Write-Success "Prometheus + Grafana stack installed"
    if ($policyWarnings) {
        Write-Info "To resolve policy warnings, you can either:"
        Write-Info "  1. Use mirrored images from Azure Container Registry (ACR)"
        Write-Info "  2. Request Azure Policy exemption using: .\scripts\create-policy-exemption.ps1"
    }
} else {
    Write-Error "Failed to install Prometheus stack"
    Write-Info "Helm output:"
    $helmOutput | ForEach-Object { Write-Host "  $_" }
    exit 1
}

# Create ServiceMonitor for DCGM Exporter
Write-Header "Configuring DCGM Exporter Monitoring"

$dcgmServiceMonitor = @"
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: dcgm-exporter
  namespace: monitoring
  labels:
    app.kubernetes.io/name: dcgm-exporter
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: dcgm-exporter
  namespaceSelector:
    matchNames:
      - ollama
  endpoints:
    - port: metrics
      interval: 30s
      path: /metrics
"@

$dcgmServiceMonitor | kubectl apply -f -
Write-Success "DCGM ServiceMonitor created"

# Create ServiceMonitor for Ollama
Write-Header "Configuring Ollama Monitoring"

$ollamaServiceMonitor = @"
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: ollama-metrics
  namespace: monitoring
  labels:
    app.kubernetes.io/name: ollama
spec:
  selector:
    matchLabels:
      app: ollama
  namespaceSelector:
    matchNames:
      - ollama
  endpoints:
    - port: http
      interval: 30s
      path: /metrics
"@

$ollamaServiceMonitor | kubectl apply -f -
Write-Success "Ollama ServiceMonitor created"

# Create ServiceMonitor for Open-WebUI
$webuiServiceMonitor = @"
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: open-webui-metrics
  namespace: monitoring
  labels:
    app.kubernetes.io/name: open-webui
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: open-webui
  namespaceSelector:
    matchNames:
      - ollama
  endpoints:
    - port: http
      interval: 30s
      path: /metrics
"@

$webuiServiceMonitor | kubectl apply -f -
Write-Success "Open-WebUI ServiceMonitor created"

# Wait for Grafana to be ready
Write-Header "Waiting for Grafana to be Ready"
Write-Info "Waiting for Grafana pod (max 5 minutes)..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=grafana -n monitoring --timeout=300s

if ($LASTEXITCODE -ne 0) {
    Write-Warning "Grafana pod not ready yet. Check status with: kubectl get pods -n monitoring"
} else {
    Write-Success "Grafana is ready"
}

# Get Grafana URL
Write-Header "Getting Grafana Access Information"

Write-Info "Waiting for LoadBalancer IP (max 3 minutes)..."
$maxWait = 180
$elapsed = 0
$grafanaIp = $null

while ($elapsed -lt $maxWait) {
    $svc = kubectl get svc -n monitoring monitoring-grafana -o json | ConvertFrom-Json
    if ($svc.status.loadBalancer.ingress) {
        $grafanaIp = $svc.status.loadBalancer.ingress[0].ip
        if ($grafanaIp) {
            break
        }
    }
    Start-Sleep -Seconds 5
    $elapsed += 5
}

if ($grafanaIp) {
    Write-Success "Grafana LoadBalancer IP: $grafanaIp"
} else {
    Write-Warning "LoadBalancer IP not assigned yet. Check with: kubectl get svc -n monitoring monitoring-grafana"
    # Try port-forward as fallback
    Write-Info "You can use port-forward: kubectl port-forward -n monitoring svc/monitoring-grafana 3000:80"
}

# Get Prometheus URL (ClusterIP)
$prometheusUrl = "http://monitoring-kube-prometheus-prometheus.monitoring.svc:9090"
Write-Info "Prometheus URL (internal): $prometheusUrl"

# Display summary
Write-Host @"

========================================
  MONITORING STACK DEPLOYED
========================================

"@ -ForegroundColor Green

Write-Host "📊 Grafana Dashboard" -ForegroundColor Cyan
if ($grafanaIp) {
    Write-Host "   URL: http://$grafanaIp" -ForegroundColor White
} else {
    Write-Host "   URL: Pending (check with 'kubectl get svc -n monitoring monitoring-grafana')" -ForegroundColor Yellow
}
Write-Host "   Username: admin" -ForegroundColor White
Write-Host "   Password: $GrafanaPassword" -ForegroundColor White

Write-Host "`n📈 Prometheus" -ForegroundColor Cyan
Write-Host "   URL (internal): $prometheusUrl" -ForegroundColor White
Write-Host "   Port-forward: kubectl port-forward -n monitoring svc/monitoring-kube-prometheus-prometheus 9090:9090" -ForegroundColor Gray

Write-Host "`n🔔 Alertmanager" -ForegroundColor Cyan
Write-Host "   Port-forward: kubectl port-forward -n monitoring svc/monitoring-kube-prometheus-alertmanager 9093:9093" -ForegroundColor Gray

Write-Host "`n📦 Installed Components:" -ForegroundColor Cyan
Write-Host "   ✅ Prometheus (metrics collection)" -ForegroundColor Green
Write-Host "   ✅ Grafana (visualization)" -ForegroundColor Green
Write-Host "   ✅ Alertmanager (alerting)" -ForegroundColor Green
Write-Host "   ✅ Node Exporter (node metrics)" -ForegroundColor Green
Write-Host "   ✅ Kube State Metrics (K8s metrics)" -ForegroundColor Green
Write-Host "   ✅ DCGM ServiceMonitor (GPU metrics)" -ForegroundColor Green

Write-Host "`n🎨 Pre-Loaded Dashboards:" -ForegroundColor Cyan
Write-Host "   - Kubernetes Cluster Overview (ID: 15398)" -ForegroundColor White
Write-Host "   - Node Exporter Full (ID: 1860)" -ForegroundColor White
Write-Host "   - NVIDIA DCGM Exporter (ID: 12239)" -ForegroundColor White

Write-Host "`n🔧 Useful Commands:" -ForegroundColor Cyan
Write-Host "   # View all monitoring pods" -ForegroundColor Gray
Write-Host "   kubectl get pods -n monitoring" -ForegroundColor White
Write-Host "" -ForegroundColor Gray
Write-Host "   # Check ServiceMonitors" -ForegroundColor Gray
Write-Host "   kubectl get servicemonitors -n monitoring" -ForegroundColor White
Write-Host "" -ForegroundColor Gray
Write-Host "   # Port-forward Grafana (if LoadBalancer pending)" -ForegroundColor Gray
Write-Host "   kubectl port-forward -n monitoring svc/monitoring-grafana 3000:80" -ForegroundColor White
Write-Host "" -ForegroundColor Gray
Write-Host "   # View Prometheus targets" -ForegroundColor Gray
Write-Host "   kubectl port-forward -n monitoring svc/monitoring-kube-prometheus-prometheus 9090:9090" -ForegroundColor White
Write-Host "   # Then open: http://localhost:9090/targets" -ForegroundColor White

Write-Host "`n📚 Next Steps:" -ForegroundColor Cyan
Write-Host "   1. Open Grafana dashboard" -ForegroundColor White
Write-Host "   2. Explore pre-loaded dashboards" -ForegroundColor White
Write-Host "   3. Import additional dashboards from grafana.com" -ForegroundColor White
Write-Host "   4. Run load test: .\test-scaling.ps1 -LoadTest" -ForegroundColor White
Write-Host "   5. Watch metrics update in real-time!" -ForegroundColor White

Write-Host "`n========================================`n" -ForegroundColor Green

# Optional: Open Grafana in browser
if ($grafanaIp) {
    $openBrowser = Read-Host "Open Grafana in browser now? (y/n)"
    if ($openBrowser -eq 'y' -or $openBrowser -eq 'Y') {
        Start-Process "http://$grafanaIp"
    }
}
