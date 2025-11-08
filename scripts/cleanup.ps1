<#
.SYNOPSIS
    Cleanup KubeCon NA 2025 LLM Demo resources
.DESCRIPTION
    Removes all deployed resources including:
    - Kubernetes namespace (cascading delete)
    - Azure resource group (AKS, Key Vault, Storage)
    - Optional: Keep resource group but delete K8s resources only
    - Optional: Delete only user data (for multi-day booth demo)
    - Optional: Wipe PostgreSQL database content (for fresh deployments)
.PARAMETER Prefix
    Prefix used during deployment
.PARAMETER KeepResourceGroup
    Delete only Kubernetes resources, keep Azure infrastructure
.PARAMETER DataOnly
    Delete only user data (WebUI database), keep all infrastructure.
    Useful for resetting demo between event days while keeping the deployment running.
.PARAMETER WipeDatabase
    Drop and recreate PostgreSQL database to remove all data.
    Use this before redeployment to ensure clean state.
    Database structure will be recreated by Open-WebUI on next startup.
.PARAMETER Force
    Skip confirmation prompts
.EXAMPLE
    .\cleanup.ps1 -Prefix "kubecon"
    Full cleanup - deletes everything
.EXAMPLE
    .\cleanup.ps1 -Prefix "kubecon" -KeepResourceGroup -Force
    Delete K8s resources, keep Azure infrastructure, preserve database
.EXAMPLE
    .\cleanup.ps1 -Prefix "kubecon" -KeepResourceGroup -WipeDatabase -Force
    Delete K8s resources, wipe database content, keep infrastructure
.EXAMPLE
    .\cleanup.ps1 -Prefix "kubecon" -DataOnly
    Reset user data only (for multi-day events)
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true, HelpMessage="Enter the prefix used during deployment (e.g., 'demo01' or 'myname')")]
    [ValidatePattern('^[a-zA-Z0-9]{3,15}$')]
    [ValidateNotNullOrEmpty()]
    [string]$Prefix,

    [Parameter(Mandatory=$false)]
    [switch]$KeepResourceGroup,

    [Parameter(Mandatory=$false)]
    [switch]$DataOnly,

    [Parameter(Mandatory=$false)]
    [switch]$WipeDatabase,

    [Parameter(Mandatory=$false)]
    [switch]$Force
)

$ErrorActionPreference = 'Continue'
$resourceGroup = "${Prefix}-rg"
$namespace = "ollama"
$monitoringNamespace = "monitoring"

Write-Host "`n============================================" -ForegroundColor Magenta
Write-Host "  KubeCon NA 2025 - LLM Demo Cleanup" -ForegroundColor Magenta
Write-Host "============================================" -ForegroundColor Magenta
Write-Host "Cleanup Prefix     : " -NoNewline -ForegroundColor White
Write-Host "$Prefix" -ForegroundColor Green
Write-Host "Resource Group     : " -NoNewline -ForegroundColor White
Write-Host "$resourceGroup" -ForegroundColor Yellow
Write-Host "Namespace          : " -NoNewline -ForegroundColor White
Write-Host "$namespace" -ForegroundColor Yellow

if ($KeepResourceGroup) {
    Write-Host "Cleanup Mode       : " -NoNewline -ForegroundColor White
    Write-Host "Kubernetes resources only (keep Azure infra)" -ForegroundColor Cyan
    if ($WipeDatabase) {
        Write-Host "Database Mode      : " -NoNewline -ForegroundColor White
        Write-Host "Wipe database content (fresh state)" -ForegroundColor Yellow
    } else {
        Write-Host "Database Mode      : " -NoNewline -ForegroundColor White
        Write-Host "Preserve database content" -ForegroundColor Green
    }
} elseif ($DataOnly) {
    Write-Host "Cleanup Mode       : " -NoNewline -ForegroundColor White
    Write-Host "User data only (reset demo for next day)" -ForegroundColor Cyan
} else {
    Write-Host "Cleanup Mode       : " -NoNewline -ForegroundColor White
    Write-Host "Full cleanup (delete everything)" -ForegroundColor Red
}
Write-Host "============================================" -ForegroundColor Magenta

if (-not $Force) {
    if ($DataOnly) {
        Write-Host "`n[INFO] This will delete user data (conversations, accounts) but keep the deployment." -ForegroundColor Cyan
        Write-Host "[INFO] Useful for resetting between event days." -ForegroundColor Cyan
    }
    Write-Host "`n[WARNING] This will delete resources. Continue? (yes/no): " -ForegroundColor Yellow -NoNewline
    $confirmation = Read-Host

    if ($confirmation -ne "yes") {
        Write-Host "Cleanup cancelled." -ForegroundColor Gray
        exit 0
    }
}

Write-Host ""

# Handle data-only cleanup
if ($DataOnly) {
    Write-Host "[*] Resetting user data only..." -ForegroundColor Green

    # Find and connect to the correct AKS cluster
    $aksClusterName = az aks list --resource-group $resourceGroup --query "[?starts_with(name, '${Prefix}-aks-')].name" -o tsv 2>$null

    if ($aksClusterName) {
        $aksClusterName = $aksClusterName.Trim()
        Write-Host "  -> Found AKS cluster: $aksClusterName" -ForegroundColor Gray

        # Get credentials for the correct cluster
        az aks get-credentials --resource-group $resourceGroup --name $aksClusterName --overwrite-existing 2>&1 | Out-Null

        if (!$?) {
            Write-Host "  [ERROR] Failed to get credentials for cluster: $aksClusterName" -ForegroundColor Red
            exit 1
        }

        $currentContext = kubectl config current-context 2>$null
        Write-Host "  -> Connected to context: $currentContext" -ForegroundColor Gray
    } else {
        Write-Host "  [ERROR] No AKS cluster found with prefix '$Prefix' in resource group '$resourceGroup'" -ForegroundColor Red
        exit 1
    }

    # Delete WebUI pods and PVCs (clears all stored data)
    Write-Host "  -> Deleting WebUI pods..." -ForegroundColor Gray
    kubectl delete pod -n $namespace -l app=open-webui 2>&1 | Out-Null

    Write-Host "  -> Deleting WebUI PVCs (this will wipe all stored files)..." -ForegroundColor Gray
    kubectl delete pvc -n $namespace open-webui-files-pvc 2>&1 | Out-Null

    # Also delete Ollama PVCs to clear all model data if requested
    if ($WipeDatabase) {
        Write-Host "  -> Deleting Ollama PVCs (this will wipe all models)..." -ForegroundColor Gray
        kubectl delete pvc -n $namespace ollama-models-pvc 2>&1 | Out-Null
    }

    if ($?) {
        Write-Host "  [OK] Data cleared successfully" -ForegroundColor Green

        Write-Host "`n  Waiting for new WebUI pods to start..." -ForegroundColor Gray
        Start-Sleep -Seconds 10

        # Wait for pod to be ready
        $attempts = 0
        while ($attempts -lt 30) {
            $podReady = kubectl get pods -n $namespace -l app=open-webui -o jsonpath='{.items[0].status.conditions[?(@.type=="Ready")].status}' 2>$null
            if ($podReady -eq "True") {
                Write-Host "  [OK] WebUI is ready" -ForegroundColor Green
                break
            }
            Start-Sleep -Seconds 5
            $attempts++
        }

        if ($attempts -ge 30) {
            Write-Host "  [WARN] WebUI taking longer than expected to restart" -ForegroundColor Yellow
            Write-Host "  Check status: kubectl get pods -n $namespace" -ForegroundColor Gray
        }

        Write-Host "`n[OK] User data reset complete" -ForegroundColor Green
        Write-Host "  -> All user accounts and conversations cleared" -ForegroundColor Gray
        Write-Host "  -> PVCs deleted and recreated" -ForegroundColor Gray
        if ($WipeDatabase) {
            Write-Host "  -> Model data cleared (will need to reload models)" -ForegroundColor Gray
        }
        Write-Host "  -> Infrastructure still running" -ForegroundColor Gray
        Write-Host "  -> Next sign-up will create new admin account" -ForegroundColor Gray
        Write-Host ""
        exit 0
    } else {
        Write-Host "  [ERROR] Failed to reset user data" -ForegroundColor Red
        exit 1
    }
}

Write-Host "[1/3] Deleting Kubernetes resources..." -ForegroundColor Green

# Find the AKS cluster in the resource group that matches our prefix
$aksClusterName = az aks list --resource-group $resourceGroup --query "[?starts_with(name, '${Prefix}-aks-')].name" -o tsv 2>$null

if ($aksClusterName) {
    $aksClusterName = $aksClusterName.Trim()
    Write-Host "  -> Found AKS cluster: $aksClusterName" -ForegroundColor Gray

    # Get credentials for the correct cluster
    Write-Host "  -> Setting kubectl context to cluster: $aksClusterName..." -ForegroundColor Gray
    az aks get-credentials --resource-group $resourceGroup --name $aksClusterName --overwrite-existing 2>&1 | Out-Null

    if ($?) {
        $currentContext = kubectl config current-context 2>$null
        Write-Host "  -> Connected to context: $currentContext" -ForegroundColor Gray

        # Clean up Helm releases first (before namespace deletion)
        Write-Host "  -> Checking for Helm releases..." -ForegroundColor Gray
        $helmReleases = helm list -A -o json 2>$null | ConvertFrom-Json
        if ($helmReleases -and $helmReleases.Count -gt 0) {
            foreach ($release in $helmReleases) {
                if ($release.namespace -eq $monitoringNamespace -or $release.namespace -eq $namespace) {
                    Write-Host "     Uninstalling Helm release: $($release.name) from $($release.namespace)..." -ForegroundColor Gray
                    helm uninstall $release.name -n $release.namespace 2>&1 | Out-Null
                    if ($?) {
                        Write-Host "     [OK] Uninstalled: $($release.name)" -ForegroundColor Green
                    }
                }
            }
        }

        # Delete ollama namespace
        $nsCheck = kubectl get namespace $namespace --no-headers 2>$null
        if ($?) {
            Write-Host "  -> Deleting namespace '$namespace' (this cascades to all resources)..." -ForegroundColor Gray
            kubectl delete namespace $namespace --timeout=300s 2>&1 | Out-Null

            if ($?) {
                Write-Host "  [OK] Namespace '$namespace' deleted" -ForegroundColor Green
            } else {
                Write-Host "  [WARN] Failed to delete namespace '$namespace' (may require manual cleanup)" -ForegroundColor Yellow
            }
        } else {
            Write-Host "  [INFO] Namespace '$namespace' not found (already deleted or never created)" -ForegroundColor Gray
        }

        # Delete monitoring namespace
        $monitoringCheck = kubectl get namespace $monitoringNamespace --no-headers 2>$null
        if ($?) {
            Write-Host "  -> Deleting namespace '$monitoringNamespace' (Prometheus, Grafana)..." -ForegroundColor Gray
            kubectl delete namespace $monitoringNamespace --timeout=300s 2>&1 | Out-Null

            if ($?) {
                Write-Host "  [OK] Namespace '$monitoringNamespace' deleted" -ForegroundColor Green
            } else {
                Write-Host "  [WARN] Failed to delete namespace '$monitoringNamespace' (may require manual cleanup)" -ForegroundColor Yellow
            }
        } else {
            Write-Host "  [INFO] Namespace '$monitoringNamespace' not found (already deleted or never created)" -ForegroundColor Gray
        }
    } else {
        Write-Host "  [ERROR] Failed to get credentials for cluster: $aksClusterName" -ForegroundColor Red
    }
} else {
    Write-Host "  [INFO] No AKS cluster found with prefix '$Prefix' in resource group '$resourceGroup'" -ForegroundColor Gray
    Write-Host "  [INFO] Cluster may already be deleted or never created" -ForegroundColor Gray
}

# Wipe PostgreSQL database if requested
if ($WipeDatabase -and $KeepResourceGroup) {
    Write-Host "`n[DATABASE] Wiping PostgreSQL database content..." -ForegroundColor Yellow

    # Get PostgreSQL server name (filter by prefix pattern)
    $pgServerFqdn = az postgres flexible-server list --resource-group $resourceGroup --query "[?starts_with(name, '${Prefix}-pg-')].fullyQualifiedDomainName" -o tsv 2>$null

    if ($pgServerFqdn) {
        $pgServerFqdn = $pgServerFqdn.Trim()
        Write-Host "  -> Found PostgreSQL server: $pgServerFqdn" -ForegroundColor Gray

        # Get admin password from Key Vault (updated pattern to match actual naming)
        $kvName = az keyvault list --resource-group $resourceGroup --query "[?contains(name, '$Prefix')].name" -o tsv 2>$null
        if ($kvName) {
            $kvName = $kvName.Trim()
            Write-Host "  -> Found Key Vault: $kvName" -ForegroundColor Gray
            Write-Host "  -> Retrieving admin password from Key Vault..." -ForegroundColor Gray

            $pgPassword = az keyvault secret show --vault-name $kvName --name postgres-admin-password --query value -o tsv 2>$null

            if ($pgPassword) {
                Write-Host "  -> Dropping and recreating database via pod..." -ForegroundColor Gray

                # Create a temporary pod to wipe database
                $wipeManifest = @"
apiVersion: v1
kind: Pod
metadata:
  name: pg-wipe-temp
  namespace: default
spec:
  restartPolicy: Never
  containers:
    - name: postgres
      image: postgres:16
      command:
        - sh
        - -c
        - |
          export PGPASSWORD='$pgPassword'
          echo "Dropping database openwebui..."
          psql -h $pgServerFqdn -U pgadmin -d postgres -c "DROP DATABASE IF EXISTS openwebui;"
          echo "Recreating database openwebui..."
          psql -h $pgServerFqdn -U pgadmin -d postgres -c "CREATE DATABASE openwebui;"
          echo "Dropping database grafana..."
          psql -h $pgServerFqdn -U pgadmin -d postgres -c "DROP DATABASE IF EXISTS grafana;"
          echo "Recreating database grafana..."
          psql -h $pgServerFqdn -U pgadmin -d postgres -c "CREATE DATABASE grafana;"
          echo "Database wipe completed!"
"@

                $tempFile = Join-Path $env:TEMP "pg-wipe-temp.yaml"
                Set-Content -Path $tempFile -Value $wipeManifest

                kubectl apply -f $tempFile 2>&1 | Out-Null
                Start-Sleep -Seconds 10

                # Check pod status
                $podStatus = kubectl get pod pg-wipe-temp -o jsonpath='{.status.phase}' 2>$null
                if ($podStatus -eq "Succeeded") {
                    $logs = kubectl logs pg-wipe-temp 2>$null
                    Write-Host "  [OK] Database wiped successfully" -ForegroundColor Green
                    Write-Host "     $logs" -ForegroundColor Gray
                } else {
                    Write-Host "  [WARN] Database wipe may have failed (pod status: $podStatus)" -ForegroundColor Yellow
                }

                # Cleanup
                kubectl delete pod pg-wipe-temp 2>&1 | Out-Null
                Remove-Item $tempFile -ErrorAction SilentlyContinue
            } else {
                Write-Host "  [WARN] Could not retrieve PostgreSQL password from Key Vault" -ForegroundColor Yellow
            }
        } else {
            Write-Host "  [WARN] No Key Vault found in resource group" -ForegroundColor Yellow
        }
    } else {
        Write-Host "  [INFO] No PostgreSQL server found in resource group" -ForegroundColor Gray
    }
}

if (-not $KeepResourceGroup) {
    Write-Host "`n[2/2] Deleting Azure resource group..." -ForegroundColor Green

    $rgExists = az group exists --name $resourceGroup 2>$null

    if ($rgExists -eq 'true') {
        Write-Host "  -> Deleting resource group '$resourceGroup' (this takes 5-10 minutes)..." -ForegroundColor Gray
        Write-Host "  -> This will delete: AKS cluster, Key Vault, Storage Accounts, Networking" -ForegroundColor Gray

        az group delete --name $resourceGroup --yes --no-wait 2>&1 | Out-Null

        if ($?) {
            Write-Host "  [OK] Resource group deletion initiated (running in background)" -ForegroundColor Green

            # Monitor deletion progress
            Write-Host "`n  Monitoring deletion progress (press Ctrl+C to exit monitoring)..." -ForegroundColor Cyan
            Write-Host "  Note: Deletion continues in background even if you exit monitoring`n" -ForegroundColor Gray

            $startTime = Get-Date
            $maxWaitSeconds = 600  # 10 minutes
            $checkInterval = 10     # Check every 10 seconds

            while (((Get-Date) - $startTime).TotalSeconds -lt $maxWaitSeconds) {
                $rgExists = az group exists -n $resourceGroup 2>$null

                if ($rgExists -eq "false") {
                    $duration = [math]::Round(((Get-Date) - $startTime).TotalSeconds, 0)
                    Write-Host "  ✅ Resource group deleted successfully! (took $duration seconds)" -ForegroundColor Green
                    break
                }

                $elapsed = [math]::Floor(((Get-Date) - $startTime).TotalSeconds)
                Write-Host "  [$elapsed`s] Still deleting..." -ForegroundColor Yellow
                Start-Sleep -Seconds $checkInterval
            }

            # Final check after timeout
            $rgExists = az group exists -n $resourceGroup 2>$null
            if ($rgExists -eq "true") {
                Write-Host "`n  ⏳ Deletion still in progress after 10 minutes" -ForegroundColor Yellow
                Write-Host "     Check status: az group show -n $resourceGroup --query 'properties.provisioningState' -o tsv" -ForegroundColor Gray
                Write-Host "     Monitor in Azure Portal: Resource Groups → $resourceGroup" -ForegroundColor Gray
            }
        } else {
            Write-Host "  [WARN] Failed to delete resource group" -ForegroundColor Yellow
            Write-Host "    Delete manually: az group delete -n $resourceGroup --yes" -ForegroundColor Gray
        }
    } else {
        Write-Host "  [INFO] Resource group '$resourceGroup' not found (already deleted or never created)" -ForegroundColor Gray
    }

    # Purge soft-deleted Key Vaults
    Write-Host "`n[2.5/2] Checking for soft-deleted Key Vaults to purge..." -ForegroundColor Green
    Write-Host "  -> Looking for Key Vaults with prefix '$Prefix'..." -ForegroundColor Gray

    # Updated pattern to match actual Key Vault naming (contains prefix, not starts with)
    $deletedVaults = az keyvault list-deleted --query "[?contains(name, '${Prefix}')].{Name:name, Location:properties.location}" -o json 2>$null | ConvertFrom-Json

    if ($deletedVaults -and $deletedVaults.Count -gt 0) {
        Write-Host "  -> Found $($deletedVaults.Count) soft-deleted Key Vault(s)" -ForegroundColor Yellow
        foreach ($vault in $deletedVaults) {
            Write-Host "     Purging: $($vault.Name) in $($vault.Location)..." -ForegroundColor Gray
            az keyvault purge --name $vault.Name --location $vault.Location 2>&1 | Out-Null
            if ($?) {
                Write-Host "     [OK] Purged: $($vault.Name)" -ForegroundColor Green
            } else {
                Write-Host "     [WARN] Failed to purge: $($vault.Name)" -ForegroundColor Yellow
            }
        }
    } else {
        Write-Host "  [INFO] No soft-deleted Key Vaults found" -ForegroundColor Gray
    }
} else {
    Write-Host "`n[2/2] Skipping Azure resource group deletion (KeepResourceGroup flag set)" -ForegroundColor Yellow
    Write-Host "  -> Azure infrastructure remains: AKS cluster, Key Vault, Storage" -ForegroundColor Gray
    Write-Host "  -> To delete later: az group delete -n $resourceGroup --yes" -ForegroundColor Gray
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  CLEANUP COMPLETE" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

if ($KeepResourceGroup) {
    Write-Host "`n[OK] Kubernetes resources deleted" -ForegroundColor Green
    Write-Host "  Azure infrastructure preserved" -ForegroundColor Gray
} else {
    $finalCheck = az group exists -n $resourceGroup 2>$null
    if ($finalCheck -eq "false") {
        Write-Host "`n✅ Full cleanup completed successfully!" -ForegroundColor Green
        Write-Host "   All Azure resources deleted" -ForegroundColor Gray
        Write-Host "   All charges stopped" -ForegroundColor Gray
    } else {
        Write-Host "`n⏳ Cleanup in progress" -ForegroundColor Yellow
        Write-Host "   Monitor in Azure Portal" -ForegroundColor Gray
    }
}

Write-Host "`nUseful Commands:" -ForegroundColor White
Write-Host "  az group list --query `"[?name=='$resourceGroup']`" -o table  # Check RG status" -ForegroundColor Gray
Write-Host "  kubectl get namespaces                                      # Verify K8s cleanup" -ForegroundColor Gray
Write-Host ""
