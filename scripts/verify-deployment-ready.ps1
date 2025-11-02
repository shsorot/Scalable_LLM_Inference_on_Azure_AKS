# Deployment Verification Script
# Ensures all fixes are in place for next deployment

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "DEPLOYMENT FILES VERIFICATION" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

$allGood = $true

# Check 1: Open-WebUI Deployment
Write-Host "[1/4] Checking Open-WebUI Deployment (k8s/07-webui-deployment.yaml)..." -ForegroundColor Yellow
$webuiFile = "k8s\07-webui-deployment.yaml"
if (Test-Path $webuiFile) {
    $content = Get-Content $webuiFile -Raw
    if ($content -match "ENABLE_MODEL_FILTER") {
        if ($content -match 'value:\s*"False"') {
            Write-Host "  [OK] ENABLE_MODEL_FILTER=False configured" -ForegroundColor Green
        } else {
            Write-Host "  [WARN] ENABLE_MODEL_FILTER found but value may be incorrect" -ForegroundColor Yellow
            $allGood = $false
        }
    } else {
        Write-Host "  [FAIL] ENABLE_MODEL_FILTER not found!" -ForegroundColor Red
        Write-Host "  Action: Add ENABLE_MODEL_FILTER=False to environment variables" -ForegroundColor Yellow
        $allGood = $false
    }
} else {
    Write-Host "  [FAIL] File not found: $webuiFile" -ForegroundColor Red
    $allGood = $false
}

# Check 2: DCGM ServiceMonitor
Write-Host "`n[2/4] Checking DCGM ServiceMonitor (k8s/13-dcgm-servicemonitor.yaml)..." -ForegroundColor Yellow
$dcgmFile = "k8s\13-dcgm-servicemonitor.yaml"
if (Test-Path $dcgmFile) {
    $content = Get-Content $dcgmFile -Raw
    if ($content -match 'app\.kubernetes\.io/name:\s*dcgm-exporter') {
        Write-Host "  [OK] Service selector correctly configured" -ForegroundColor Green
    } else {
        Write-Host "  [FAIL] Service selector incorrect!" -ForegroundColor Red
        Write-Host "  Action: Update selector to 'app.kubernetes.io/name: dcgm-exporter'" -ForegroundColor Yellow
        $allGood = $false
    }
} else {
    Write-Host "  [FAIL] File not found: $dcgmFile" -ForegroundColor Red
    $allGood = $false
}

# Check 3: Deploy Script Integration
Write-Host "`n[3/4] Checking Deploy Script (scripts/deploy.ps1)..." -ForegroundColor Yellow
$deployFile = "scripts\deploy.ps1"
if (Test-Path $deployFile) {
    $content = Get-Content $deployFile -Raw
    if ($content -match "Configuring Model Visibility") {
        if ($content -match "set-models-public\.ps1") {
            Write-Host "  [OK] Model visibility step integrated (Step 6.5)" -ForegroundColor Green
        } else {
            Write-Host "  [WARN] Model visibility step found but may be incomplete" -ForegroundColor Yellow
            $allGood = $false
        }
    } else {
        Write-Host "  [FAIL] Model visibility step not found!" -ForegroundColor Red
        Write-Host "  Action: Add Step 6.5 to call set-models-public.ps1" -ForegroundColor Yellow
        $allGood = $false
    }
} else {
    Write-Host "  [FAIL] File not found: $deployFile" -ForegroundColor Red
    $allGood = $false
}

# Check 4: Set Models Public Script
Write-Host "`n[4/4] Checking Set Models Public Script..." -ForegroundColor Yellow
$modelsScript = "scripts\set-models-public.ps1"
if (Test-Path $modelsScript) {
    $content = Get-Content $modelsScript -Raw
    if ($content -match "UPDATE model SET meta") {
        Write-Host "  [OK] set-models-public.ps1 exists with database update logic" -ForegroundColor Green
    } else {
        Write-Host "  [WARN] Script exists but may be incomplete" -ForegroundColor Yellow
        $allGood = $false
    }
} else {
    Write-Host "  [FAIL] File not found: $modelsScript" -ForegroundColor Red
    Write-Host "  Action: Create set-models-public.ps1 script" -ForegroundColor Yellow
    $allGood = $false
}

# Summary
Write-Host "`n========================================" -ForegroundColor Cyan
if ($allGood) {
    Write-Host "VERIFICATION PASSED" -ForegroundColor Green
    Write-Host "========================================`n" -ForegroundColor Cyan
    Write-Host "All deployment files are correctly configured!" -ForegroundColor Green
    Write-Host "`nNext deployment will include:" -ForegroundColor White
    Write-Host "  - Open-WebUI models accessible to all users (ENABLE_MODEL_FILTER=False)" -ForegroundColor Gray
    Write-Host "  - GPU metrics available in Grafana (DCGM Service fixed)" -ForegroundColor Gray
    Write-Host "  - Automatic model visibility configuration (Step 6.5)" -ForegroundColor Gray
} else {
    Write-Host "VERIFICATION FAILED" -ForegroundColor Red
    Write-Host "========================================`n" -ForegroundColor Cyan
    Write-Host "Some fixes are missing or incorrect." -ForegroundColor Red
    Write-Host "Review the messages above and apply necessary fixes." -ForegroundColor Yellow
}

Write-Host ""
