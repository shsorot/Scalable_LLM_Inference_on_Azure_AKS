<#
.SYNOPSIS
    Set all Ollama models to public in Open-WebUI database

.DESCRIPTION
    Updates the PostgreSQL database to set all models as public/accessible to all users.
    This script directly modifies the Open-WebUI database to change model visibility.

.PARAMETER Namespace
    Kubernetes namespace where Open-WebUI and PostgreSQL are deployed

.EXAMPLE
    .\set-models-public.ps1

.EXAMPLE
    .\set-models-public.ps1 -Namespace "ollama"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$Namespace = "ollama"
)

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Open-WebUI Model Visibility Fixer" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Get PostgreSQL connection string from secret
Write-Host "Retrieving PostgreSQL connection string..." -ForegroundColor Gray
$connString = kubectl get secret ollama-secrets -n $Namespace -o jsonpath='{.data.postgres-connection-string}' | ForEach-Object { [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($_)) }

if (-not $connString) {
    Write-Error "Failed to retrieve PostgreSQL connection string from secret"
    exit 1
}

Write-Host "  Connection string retrieved" -ForegroundColor Green

# Get Open-WebUI pod
Write-Host "Finding Open-WebUI pod..." -ForegroundColor Gray
$webuiPod = kubectl get pods -n $Namespace -l app=open-webui -o jsonpath='{.items[0].metadata.name}'

if (-not $webuiPod) {
    Write-Error "No Open-WebUI pod found"
    exit 1
}

Write-Host "  Pod: $webuiPod" -ForegroundColor Green

# Create Python script to update database
$pythonScript = @'
#!/usr/bin/env python3
"""
Set all models to public in Open-WebUI database
"""
import sys
import psycopg2

if len(sys.argv) < 2:
    print("Usage: python script.py <connection_string>")
    sys.exit(1)

conn_str = sys.argv[1]

try:
    print("Connecting to Open-WebUI database...")
    conn = psycopg2.connect(conn_str)
    cur = conn.cursor()

    # Check if model table exists
    cur.execute("""
        SELECT EXISTS (
            SELECT FROM information_schema.tables
            WHERE table_schema = 'public'
            AND table_name = 'model'
        )
    """)

    table_exists = cur.fetchone()[0]

    if not table_exists:
        print("[INFO] Model table does not exist yet (fresh deployment)")
        print("[INFO] Models will be created as public when first accessed")
        sys.exit(0)

    # Get current model count
    cur.execute("SELECT COUNT(*) FROM model")
    model_count = cur.fetchone()[0]

    print(f"[INFO] Found {model_count} models in database")

    if model_count == 0:
        print("[INFO] No models in database yet")
        print("[INFO] With ENABLE_MODEL_FILTER=False, all models will be accessible")
        sys.exit(0)

    # Check current visibility
    cur.execute("""
        SELECT id, name,
               COALESCE(meta->>'is_public', 'false') as is_public,
               COALESCE(meta->>'is_active', 'true') as is_active
        FROM model
    """)

    models = cur.fetchall()

    print("\n[CURRENT STATE]")
    for model in models:
        print(f"  Model: {model[1]}")
        print(f"    is_public: {model[2]}")
        print(f"    is_active: {model[3]}")

    # Update all models to public
    print("\n[UPDATING] Setting all models to public...")

    cur.execute("""
        UPDATE model
        SET meta = jsonb_set(
            COALESCE(meta, '{}'::jsonb),
            '{is_public}',
            'true'::jsonb
        )
    """)

    updated_count = cur.rowcount
    conn.commit()

    print(f"[SUCCESS] Updated {updated_count} models to public")

    # Verify
    cur.execute("""
        SELECT id, name,
               COALESCE(meta->>'is_public', 'false') as is_public
        FROM model
    """)

    models = cur.fetchall()

    print("\n[VERIFICATION]")
    all_public = True
    for model in models:
        is_public = model[2] == 'true'
        status = "✓ Public" if is_public else "✗ Private"
        print(f"  {model[1]}: {status}")
        if not is_public:
            all_public = False

    if all_public:
        print("\n[SUCCESS] All models are now public!")
    else:
        print("\n[WARNING] Some models are still private")
        sys.exit(1)

    cur.close()
    conn.close()

except psycopg2.Error as e:
    print(f"[ERROR] Database error: {e}")
    sys.exit(1)
except Exception as e:
    print(f"[ERROR] Unexpected error: {e}")
    sys.exit(1)
'@

# Save script to temp file
$tempScript = [System.IO.Path]::GetTempFileName() + ".py"
$pythonScript | Out-File -FilePath $tempScript -Encoding UTF8

Write-Host "`nUpdating model visibility in database..." -ForegroundColor Yellow

try {
    # Encode the Python script in base64
    Write-Host "Encoding script..." -ForegroundColor Gray
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($pythonScript)
    $base64Script = [System.Convert]::ToBase64String($bytes)

    # Create the script in the pod using base64
    Write-Host "Creating script in pod..." -ForegroundColor Gray
    kubectl exec -n $Namespace $webuiPod -- bash -c "echo '$base64Script' | base64 -d > /tmp/set-models-public.py"

    # Install psycopg2 if needed
    Write-Host "Installing dependencies..." -ForegroundColor Gray
    kubectl exec -n $Namespace $webuiPod -- pip install -q psycopg2-binary 2>&1 | Out-Null

    # Run the script
    Write-Host "Running database update..." -ForegroundColor Gray
    $result = kubectl exec -n $Namespace $webuiPod -- python3 /tmp/set-models-public.py "$connString"

    Write-Host $result

    # Cleanup
    kubectl exec -n $Namespace $webuiPod -- rm -f /tmp/set-models-public.py
    Remove-Item $tempScript -Force

    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "Model Visibility Update Complete!" -ForegroundColor Green
    Write-Host "========================================`n" -ForegroundColor Cyan

    Write-Host "Next steps:" -ForegroundColor Yellow
    Write-Host "1. Access Open-WebUI at http://132.164.240.138" -ForegroundColor Gray
    Write-Host "2. Verify models are visible to all users" -ForegroundColor Gray
    Write-Host "3. With ENABLE_MODEL_FILTER=False, all models should be accessible`n" -ForegroundColor Gray
}
catch {
    Write-Error "Failed to update model visibility: $_"
    Remove-Item $tempScript -Force -ErrorAction SilentlyContinue
    exit 1
}
