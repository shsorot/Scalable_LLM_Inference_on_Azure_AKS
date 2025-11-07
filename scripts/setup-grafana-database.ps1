param(
    [Parameter(Mandatory=$true)]
    [string]$KeyVaultName,

    [Parameter(Mandatory=$true)]
    [string]$PostgresServerFqdn,

    [Parameter(Mandatory=$true)]
    [string]$PostgresAdminUsername
)

$ErrorActionPreference = "Stop"

Write-Host "[INFO] Creating Grafana database in PostgreSQL..." -ForegroundColor Cyan

$pgPassword = az keyvault secret show --vault-name $KeyVaultName --name postgres-admin-password --query value -o tsv 2>$null

if ([string]::IsNullOrWhiteSpace($pgPassword)) {
    Write-Host "[WARNING] Could not retrieve PostgreSQL password from Key Vault" -ForegroundColor Yellow
    Write-Host "[WARNING] Grafana database creation skipped" -ForegroundColor Yellow
    exit 0
}

$grafanaDbPodManifest = @"
apiVersion: v1
kind: Pod
metadata:
  name: grafana-db-setup
  namespace: ollama
spec:
  restartPolicy: Never
  nodeSelector:
    workload: system
  tolerations:
    - key: CriticalAddonsOnly
      operator: Equal
      value: "true"
      effect: NoSchedule
  containers:
    - name: psql
      image: postgres:16
      resources:
        requests:
          cpu: "100m"
          memory: "128Mi"
        limits:
          cpu: "500m"
          memory: "256Mi"
      command:
        - sh
        - -c
        - |
          export PGPASSWORD='$pgPassword'
          echo "Connecting to PostgreSQL..."
          psql -h $PostgresServerFqdn -U $PostgresAdminUsername -d postgres -c "SELECT 1 FROM pg_database WHERE datname = 'grafana'" | grep -q 1 || \
          psql -h $PostgresServerFqdn -U $PostgresAdminUsername -d postgres -c "CREATE DATABASE grafana;" || exit 1
          echo "Grafana database ready!"
"@

$tempGrafanaDbPodFile = Join-Path $env:TEMP "grafana-db-setup-pod.yaml"
Set-Content -Path $tempGrafanaDbPodFile -Value $grafanaDbPodManifest

try {
    kubectl delete pod grafana-db-setup -n ollama --ignore-not-found=true 2>$null | Out-Null
    Start-Sleep -Seconds 2

    Write-Host "[INFO] Running Grafana database setup pod..." -ForegroundColor Cyan
    kubectl apply -f $tempGrafanaDbPodFile | Out-Null

    Write-Host "[INFO] Waiting for database creation..." -ForegroundColor Cyan
    $maxWait = 60
    $elapsed = 0
    $podCompleted = $false

    while ($elapsed -lt $maxWait -and -not $podCompleted) {
        Start-Sleep -Seconds 3
        $elapsed += 3

        $podStatus = kubectl get pod grafana-db-setup -n ollama -o jsonpath='{.status.phase}' 2>$null
        if ($podStatus -eq "Succeeded") {
            $podCompleted = $true
            $logs = kubectl logs grafana-db-setup -n ollama 2>$null
            Write-Host $logs -ForegroundColor Gray
            Write-Host "[OK] Grafana database created successfully" -ForegroundColor Green
        } elseif ($podStatus -eq "Failed") {
            $logs = kubectl logs grafana-db-setup -n ollama 2>$null
            Write-Host "[WARNING] Pod failed. Logs: $logs" -ForegroundColor Yellow
            break
        }
    }

    if (-not $podCompleted) {
        Write-Host "[WARNING] Grafana database setup pod did not complete in time" -ForegroundColor Yellow
    }

    kubectl delete pod grafana-db-setup -n ollama --ignore-not-found=true 2>$null | Out-Null
    Remove-Item $tempGrafanaDbPodFile -ErrorAction SilentlyContinue

} catch {
    Write-Host "[WARNING] Failed to create Grafana database: $_" -ForegroundColor Yellow
}
