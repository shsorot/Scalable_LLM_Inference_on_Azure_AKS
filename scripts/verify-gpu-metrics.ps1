# GPU Metrics Verification Script# GPU Metrics Verification Script

param([string]$Namespace = "ollama")# Checks if DCGM GPU metrics are properly configured and accessible



Write-Host "`n========================================"param(

Write-Host "GPU Metrics Verification"    [string]$Namespace = "ollama"

Write-Host "========================================`n")



# Check 1: DCGM DaemonSetWrite-Host "`n========================================" -ForegroundColor Cyan

Write-Host "[1/4] Checking DCGM Exporter DaemonSet..."Write-Host "GPU Metrics Verification" -ForegroundColor Cyan

$dcgmPods = kubectl get pods -n $Namespace -l app.kubernetes.io/name=dcgm-exporter -o json | ConvertFrom-JsonWrite-Host "========================================`n" -ForegroundColor Cyan

$dcgmRunning = ($dcgmPods.items | Where-Object { $_.status.phase -eq "Running" }).Count

# Check 1: DCGM DaemonSet running

if ($dcgmRunning -gt 0) {Write-Host "[1/5] Checking DCGM Exporter DaemonSet..." -ForegroundColor Yellow

    Write-Host "  [OK] DCGM Exporter: $dcgmRunning pods running" -ForegroundColor Green$dcgmPods = kubectl get pods -n $Namespace -l app.kubernetes.io/name=dcgm-exporter -o json | ConvertFrom-Json

} else {$dcgmCount = $dcgmPods.items.Count

    Write-Host "  [FAIL] No DCGM pods running!" -ForegroundColor Red$dcgmRunning = ($dcgmPods.items | Where-Object { $_.status.phase -eq "Running" }).Count

    exit 1

}if ($dcgmRunning -gt 0) {

    Write-Host "  [OK] DCGM Exporter: $dcgmRunning/$dcgmCount pods running" -ForegroundColor Green

# Check 2: Service endpoints} else {

Write-Host "`n[2/4] Checking DCGM Service endpoints..."    Write-Host "  [FAIL] DCGM Exporter: No pods running!" -ForegroundColor Red

$endpoints = kubectl get endpoints -n $Namespace dcgm-exporter -o jsonpath='{.subsets[0].addresses[*].ip}'    exit 1

if ($endpoints) {}

    $endpointList = $endpoints -split ' '

    Write-Host "  [OK] Service endpoints: $($endpointList.Count) found" -ForegroundColor Green# Check 2: Service endpoints

    foreach ($ep in $endpointList) {Write-Host "`n[2/5] Checking DCGM Service endpoints..." -ForegroundColor Yellow

        Write-Host "     - $($ep):9400"$endpoints = kubectl get endpoints -n $Namespace dcgm-exporter -o jsonpath='{.subsets[0].addresses[*].ip}'

    }if ($endpoints) {

} else {    $endpointList = $endpoints -split ' '

    Write-Host "  [FAIL] No service endpoints!" -ForegroundColor Red    Write-Host "  ✅ Service endpoints: $($endpointList.Count) endpoints found" -ForegroundColor Green

    Write-Host "  Fix: kubectl apply -f k8s/13-dcgm-servicemonitor.yaml"    foreach ($ep in $endpointList) {

    exit 1        Write-Host "     - $($ep):9400" -ForegroundColor Gray

}    }

} else {

# Check 3: ServiceMonitor    Write-Host "  ❌ No service endpoints! Service selector may be incorrect." -ForegroundColor Red

Write-Host "`n[3/4] Checking Prometheus ServiceMonitor..."    Write-Host "     Run: kubectl get svc -n $Namespace dcgm-exporter -o yaml" -ForegroundColor Yellow

$sm = kubectl get servicemonitor -n monitoring dcgm-exporter -o json 2>$null | ConvertFrom-Json    Write-Host "     Verify selector matches: app.kubernetes.io/name=dcgm-exporter" -ForegroundColor Yellow

if ($sm) {    exit 1

    $selector = $sm.spec.selector.matchLabels.'app.kubernetes.io/name'}

    Write-Host "  [OK] ServiceMonitor configured" -ForegroundColor Green

    Write-Host "     - Selector: app.kubernetes.io/name=$selector"# Check 3: Test metrics endpoint

    Write-Host "     - Interval: $($sm.spec.endpoints[0].interval)"Write-Host "`n[3/5] Testing DCGM metrics endpoint..." -ForegroundColor Yellow

} else {$testPod = $dcgmPods.items[0].metadata.name

    Write-Host "  [WARN] ServiceMonitor not found" -ForegroundColor Yellow$testIP = $endpointList[0]

}

# Start port-forward in background

# Check 4: Test metrics$portForwardJob = Start-Job -ScriptBlock {

Write-Host "`n[4/4] Testing DCGM metrics endpoint..."    param($ns, $pod)

$testPod = $dcgmPods.items[0].metadata.name    kubectl port-forward -n $ns pod/$pod 9400:9400 2>$null

} -ArgumentList $Namespace, $testPod

$job = Start-Job -ScriptBlock {

    param($ns, $pod)Start-Sleep -Seconds 3

    kubectl port-forward -n $ns pod/$pod 9400:9400 2>$null

} -ArgumentList $Namespace, $testPodtry {

    $metricsResponse = Invoke-RestMethod -Uri "http://localhost:9400/metrics" -TimeoutSec 5 -ErrorAction Stop

Start-Sleep -Seconds 3    $gpuUtilMetric = $metricsResponse | Select-String "DCGM_FI_DEV_GPU_UTIL" | Select-Object -First 1

    $memUsedMetric = $metricsResponse | Select-String "DCGM_FI_DEV_FB_USED" | Select-Object -First 1

try {

    $metrics = Invoke-RestMethod -Uri "http://localhost:9400/metrics" -TimeoutSec 5    if ($gpuUtilMetric -and $memUsedMetric) {

    $gpuUtil = $metrics | Select-String "DCGM_FI_DEV_GPU_UTIL"        Write-Host "  ✅ Metrics endpoint accessible and returning GPU data" -ForegroundColor Green

            Write-Host "     Sample: $($gpuUtilMetric.ToString().Substring(0, [Math]::Min(80, $gpuUtilMetric.Length)))" -ForegroundColor Gray

    if ($gpuUtil) {    } else {

        Write-Host "  [OK] Metrics endpoint accessible" -ForegroundColor Green        Write-Host "  ⚠️  Metrics endpoint accessible but GPU metrics not found" -ForegroundColor Yellow

        Write-Host "     Sample: GPU Utilization metrics found"    }

    } else {} catch {

        Write-Host "  [WARN] Endpoint accessible but no GPU metrics" -ForegroundColor Yellow    Write-Host "  ❌ Cannot access metrics endpoint: $_" -ForegroundColor Red

    }} finally {

} catch {    Stop-Job -Job $portForwardJob -ErrorAction SilentlyContinue

    Write-Host "  [FAIL] Cannot access metrics: $_" -ForegroundColor Red    Remove-Job -Job $portForwardJob -ErrorAction SilentlyContinue

} finally {}

    Stop-Job -Job $job -ErrorAction SilentlyContinue

    Remove-Job -Job $job -ErrorAction SilentlyContinue# Check 4: ServiceMonitor configuration

}Write-Host "`n[4/5] Checking Prometheus ServiceMonitor..." -ForegroundColor Yellow

$serviceMonitor = kubectl get servicemonitor -n monitoring dcgm-exporter -o json 2>$null | ConvertFrom-Json

# Summaryif ($serviceMonitor) {

Write-Host "`n========================================"    $smSelector = $serviceMonitor.spec.selector.matchLabels.'app.kubernetes.io/name'

Write-Host "Verification Complete"    $smInterval = $serviceMonitor.spec.endpoints[0].interval

Write-Host "========================================`n"

    if ($smSelector -eq "dcgm-exporter") {

Write-Host "Next Steps:"        Write-Host "  ✅ ServiceMonitor configured correctly" -ForegroundColor Green

Write-Host "  1. Port-forward to Grafana:"        Write-Host "     - Selector: app.kubernetes.io/name=$smSelector" -ForegroundColor Gray

Write-Host "     kubectl port-forward -n monitoring svc/monitoring-grafana 3000:80"        Write-Host "     - Scrape interval: $smInterval" -ForegroundColor Gray

Write-Host "  2. Access: http://localhost:3000"    } else {

Write-Host "  3. Check GPU dashboards for metrics"        Write-Host "  ⚠️  ServiceMonitor selector unexpected: $smSelector" -ForegroundColor Yellow

Write-Host "  4. Wait 1-2 minutes if metrics are missing (Prometheus scrape interval)`n"    }

} else {
    Write-Host "  ⚠️  ServiceMonitor not found in 'monitoring' namespace" -ForegroundColor Yellow
}

# Check 5: Prometheus targets
Write-Host "`n[5/5] Checking Prometheus targets..." -ForegroundColor Yellow
Write-Host "  ℹ️  Note: Prometheus scrapes every 30s, metrics may take 1-2 minutes to appear" -ForegroundColor Cyan

# Try to query Prometheus API
$prometheusJob = Start-Job -ScriptBlock {
    kubectl port-forward -n monitoring svc/monitoring-kube-prometheus-prometheus 9090:9090 2>$null
}

Start-Sleep -Seconds 3

try {
    $targets = Invoke-RestMethod -Uri "http://localhost:9090/api/v1/targets" -TimeoutSec 5 -ErrorAction Stop
    $dcgmTargets = $targets.data.activeTargets | Where-Object { $_.labels.job -like "*dcgm*" }

    if ($dcgmTargets) {
        $upTargets = ($dcgmTargets | Where-Object { $_.health -eq "up" }).Count
        $totalTargets = $dcgmTargets.Count

        if ($upTargets -eq $totalTargets -and $upTargets -gt 0) {
            Write-Host "  ✅ Prometheus targets: $upTargets/$totalTargets UP" -ForegroundColor Green
            foreach ($target in $dcgmTargets) {
                $instance = $target.labels.instance
                $health = if ($target.health -eq "up") { "UP" } else { "DOWN" }
                $color = if ($target.health -eq "up") { "Green" } else { "Red" }
                Write-Host "     - $instance : $health" -ForegroundColor $color
            }
        } else {
            Write-Host "  ⚠️  Prometheus targets: $upTargets/$totalTargets UP (some targets down)" -ForegroundColor Yellow
        }
    } else {
        Write-Host "  ⚠️  No DCGM targets found in Prometheus" -ForegroundColor Yellow
        Write-Host "     Wait 1-2 minutes for Prometheus to discover targets" -ForegroundColor Gray
    }
} catch {
    Write-Host "  ⚠️  Cannot query Prometheus API (this is normal if Prometheus is not running)" -ForegroundColor Yellow
    Write-Host "     Error: $_" -ForegroundColor Gray
} finally {
    Stop-Job -Job $prometheusJob -ErrorAction SilentlyContinue
    Remove-Job -Job $prometheusJob -ErrorAction SilentlyContinue
}

# Summary
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Verification Complete!" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

Write-Host "Next Steps:" -ForegroundColor Yellow
Write-Host "  1. Access Grafana dashboard" -ForegroundColor White
Write-Host "     kubectl port-forward -n monitoring svc/monitoring-grafana 3000:80" -ForegroundColor Gray
Write-Host "     Open: http://localhost:3000" -ForegroundColor Gray
Write-Host ""
Write-Host "  2. Navigate to GPU monitoring dashboard" -ForegroundColor White
Write-Host "     Look for panels showing:" -ForegroundColor Gray
Write-Host "     - GPU Utilization (%)" -ForegroundColor Gray
Write-Host "     - GPU Memory Used (MB)" -ForegroundColor Gray
Write-Host "     - GPU Temperature (C)" -ForegroundColor Gray
Write-Host ""
Write-Host "  3. If metrics are missing, wait 1-2 minutes for Prometheus to scrape" -ForegroundColor White
Write-Host ""
