<#
.SYNOPSIS
    Common functions library for LLM Infrastructure scripts

.DESCRIPTION
    Shared functions for logging, error handling, and common operations
    used across all deployment and management scripts.

    Usage: . .\scripts\Common.ps1
#>

#region Logging Functions

function Write-StepHeader {
    <#
    .SYNOPSIS
        Write a section header with formatting
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message
    )

    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host $Message -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
}

function Write-Success {
    <#
    .SYNOPSIS
        Write a success message
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message
    )

    Write-Host "[OK] $Message" -ForegroundColor Green
}

function Write-Info {
    <#
    .SYNOPSIS
        Write an informational message
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message
    )

    Write-Host "[INFO] $Message" -ForegroundColor Yellow
}

function Write-ErrorMsg {
    <#
    .SYNOPSIS
        Write an error message (non-terminating)
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message
    )

    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

function Write-Warning {
    <#
    .SYNOPSIS
        Write a warning message
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message
    )

    Write-Host "[WARN] $Message" -ForegroundColor Yellow
}

#endregion

#region Validation Functions

function Test-Prerequisites {
    <#
    .SYNOPSIS
        Check if required tools are installed
    #>
    param(
        [Parameter(Mandatory=$false)]
        [string[]]$Tools = @('kubectl', 'az')
    )

    $allFound = $true

    foreach ($tool in $Tools) {
        $command = Get-Command $tool -ErrorAction SilentlyContinue
        if ($command) {
            Write-Success "$tool found: $($command.Source)"
        }
        else {
            Write-ErrorMsg "$tool not found in PATH"
            $allFound = $false
        }
    }

    return $allFound
}

function Test-AzureConnection {
    <#
    .SYNOPSIS
        Verify Azure CLI is authenticated
    #>

    try {
        $account = az account show 2>&1 | ConvertFrom-Json
        if ($account) {
            Write-Success "Azure CLI authenticated as: $($account.user.name)"
            Write-Info "Subscription: $($account.name) ($($account.id))"
            return $true
        }
    }
    catch {
        Write-ErrorMsg "Azure CLI not authenticated. Run: az login"
        return $false
    }

    return $false
}

function Test-KubernetesConnection {
    <#
    .SYNOPSIS
        Verify kubectl can connect to cluster
    #>

    try {
        $clusterInfo = kubectl cluster-info 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Success "kubectl connected to cluster"
            return $true
        }
        else {
            Write-ErrorMsg "kubectl cannot connect to cluster"
            Write-ErrorMsg $clusterInfo
            return $false
        }
    }
    catch {
        Write-ErrorMsg "kubectl error: $($_.Exception.Message)"
        return $false
    }
}

#endregion

#region Azure Functions

function Get-AKSCredentials {
    <#
    .SYNOPSIS
        Get AKS cluster credentials
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$ResourceGroup,

        [Parameter(Mandatory=$true)]
        [string]$ClusterName
    )

    Write-Info "Getting AKS credentials..."
    az aks get-credentials --resource-group $ResourceGroup --name $ClusterName --overwrite-existing

    if ($LASTEXITCODE -eq 0) {
        Write-Success "AKS credentials configured"
        return $true
    }
    else {
        Write-ErrorMsg "Failed to get AKS credentials"
        return $false
    }
}

#endregion

#region Kubernetes Functions

function Wait-ForPodReady {
    <#
    .SYNOPSIS
        Wait for a pod to be ready
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Namespace,

        [Parameter(Mandatory=$true)]
        [string]$LabelSelector,

        [Parameter(Mandatory=$false)]
        [int]$TimeoutSeconds = 300
    )

    Write-Info "Waiting for pod with label $LabelSelector in namespace $Namespace..."

    $startTime = Get-Date
    $timeout = $startTime.AddSeconds($TimeoutSeconds)

    while ((Get-Date) -lt $timeout) {
        $pods = kubectl get pods -n $Namespace -l $LabelSelector -o json 2>&1 | ConvertFrom-Json

        if ($pods.items -and $pods.items.Count -gt 0) {
            $ready = $true
            foreach ($pod in $pods.items) {
                $conditions = $pod.status.conditions | Where-Object { $_.type -eq "Ready" }
                if (-not $conditions -or $conditions.status -ne "True") {
                    $ready = $false
                    break
                }
            }

            if ($ready) {
                Write-Success "Pod(s) ready"
                return $true
            }
        }

        Write-Host "." -NoNewline
        Start-Sleep -Seconds 5
    }

    Write-Host ""
    Write-ErrorMsg "Timeout waiting for pod"
    return $false
}

function Get-PodName {
    <#
    .SYNOPSIS
        Get pod name by label selector
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Namespace,

        [Parameter(Mandatory=$true)]
        [string]$LabelSelector
    )

    $pods = kubectl get pods -n $Namespace -l $LabelSelector -o jsonpath='{.items[0].metadata.name}' 2>&1

    if ($LASTEXITCODE -eq 0 -and $pods) {
        return $pods
    }

    return $null
}

#endregion

#region Password & Security Functions

function New-RandomPassword {
    <#
    .SYNOPSIS
        Generate a secure random password
    #>
    param(
        [Parameter(Mandatory=$false)]
        [int]$Length = 16,

        [Parameter(Mandatory=$false)]
        [switch]$IncludeSpecialChars
    )

    $chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    if ($IncludeSpecialChars) {
        $chars += "!@#$%^&*"
    }

    $password = -join ((1..$Length) | ForEach-Object {
        $chars[(Get-Random -Maximum $chars.Length)]
    })

    return $password
}

function Get-KeyVaultSecret {
    <#
    .SYNOPSIS
        Get a secret from Azure Key Vault with error handling
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$VaultName,

        [Parameter(Mandatory=$true)]
        [string]$SecretName
    )

    try {
        $secret = az keyvault secret show `
            --vault-name $VaultName `
            --name $SecretName `
            --query value -o tsv 2>$null

        if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($secret)) {
            return $secret
        }
    }
    catch {
        # Secret doesn't exist or access denied
    }

    return $null
}

function Set-KeyVaultRBACAccess {
    <#
    .SYNOPSIS
        Assign Key Vault Secrets Officer role to current user
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$VaultName,

        [Parameter(Mandatory=$true)]
        [string]$ResourceGroup,

        [Parameter(Mandatory=$false)]
        [int]$WaitSeconds = 30
    )

    Write-Info "Assigning Key Vault Secrets Officer role..."

    $currentUserId = az ad signed-in-user show --query id -o tsv
    $keyVaultResourceId = az keyvault show `
        --name $VaultName `
        --resource-group $ResourceGroup `
        --query id -o tsv

    az role assignment create `
        --assignee $currentUserId `
        --role "Key Vault Secrets Officer" `
        --scope $keyVaultResourceId `
        --output none 2>&1 | Out-Null

    if ($LASTEXITCODE -eq 0) {
        Write-Success "Key Vault Secrets Officer role assigned"
        Write-Info "Waiting $WaitSeconds seconds for RBAC propagation..."
        Start-Sleep -Seconds $WaitSeconds
        return $true
    }
    else {
        Write-Warning "Failed to assign role (may already exist). Waiting for propagation..."
        Start-Sleep -Seconds ([math]::Max($WaitSeconds / 2, 15))
        return $false
    }
}

#endregion

#region Helm Functions

function Deploy-HelmChart {
    <#
    .SYNOPSIS
        Deploy or upgrade a Helm chart with standard error handling
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$ReleaseName,

        [Parameter(Mandatory=$true)]
        [string]$Chart,

        [Parameter(Mandatory=$true)]
        [string]$Namespace,

        [Parameter(Mandatory=$false)]
        [hashtable]$Values = @{},

        [Parameter(Mandatory=$false)]
        [string]$ValuesFile,

        [Parameter(Mandatory=$false)]
        [int]$TimeoutMinutes = 10
    )

    $helmArgs = @(
        "upgrade", "--install", $ReleaseName, $Chart,
        "--namespace", $Namespace,
        "--wait",
        "--timeout", "${TimeoutMinutes}m"
    )

    # Add values from hashtable
    foreach ($key in $Values.Keys) {
        $helmArgs += @("--set", "$key=$($Values[$key])")
    }

    # Add values file if provided
    if ($ValuesFile -and (Test-Path $ValuesFile)) {
        $helmArgs += @("-f", $ValuesFile)
    }

    Write-Info "Deploying Helm chart: $ReleaseName ($Chart)..."
    $ErrorActionPreference = 'Continue'
    $output = & helm $helmArgs 2>&1
    $exitCode = $LASTEXITCODE
    $ErrorActionPreference = 'Stop'

    if ($exitCode -ne 0) {
        Write-ErrorMsg "Helm deployment failed for $ReleaseName"
        Write-Host $output -ForegroundColor Red
        return $false
    }

    Write-Success "Helm chart deployed: $ReleaseName"
    return $true
}

function Get-HelmReleaseStatus {
    <#
    .SYNOPSIS
        Get the status of a Helm release
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$ReleaseName,

        [Parameter(Mandatory=$true)]
        [string]$Namespace
    )

    $releases = helm list -n $Namespace -o json 2>$null | ConvertFrom-Json
    $release = $releases | Where-Object { $_.name -eq $ReleaseName }

    if ($release) {
        return @{
            Name = $release.name
            Status = $release.status
            Revision = $release.revision
            Updated = $release.updated
        }
    }

    return $null
}

#endregion

#region Azure Deployment Functions

function Get-DeploymentOutput {
    <#
    .SYNOPSIS
        Get outputs from an Azure deployment
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$ResourceGroup,

        [Parameter(Mandatory=$false)]
        [string]$DeploymentName = "main"
    )

    Write-Info "Retrieving deployment outputs..."

    $output = az deployment group show `
        --name $DeploymentName `
        --resource-group $ResourceGroup `
        --query 'properties.outputs' `
        --output json

    if ($LASTEXITCODE -ne 0) {
        Write-ErrorMsg "Failed to retrieve deployment outputs"
        return $null
    }

    try {
        $deployment = $output | ConvertFrom-Json
        Write-Success "Deployment outputs retrieved"
        return $deployment
    }
    catch {
        Write-ErrorMsg "Failed to parse deployment output"
        return $null
    }
}

#endregion

#region Utility Functions

function Confirm-Action {
    <#
    .SYNOPSIS
        Prompt user for confirmation
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message,

        [Parameter(Mandatory=$false)]
        [switch]$Force
    )

    if ($Force) {
        return $true
    }

    Write-Host "`n$Message (yes/no): " -ForegroundColor Yellow -NoNewline
    $response = Read-Host

    return ($response -eq 'yes' -or $response -eq 'y')
}

function Format-ByteSize {
    <#
    .SYNOPSIS
        Format bytes to human-readable size
    #>
    param(
        [Parameter(Mandatory=$true)]
        [long]$Bytes
    )

    if ($Bytes -ge 1GB) {
        return "{0:N2} GB" -f ($Bytes / 1GB)
    }
    elseif ($Bytes -ge 1MB) {
        return "{0:N2} MB" -f ($Bytes / 1MB)
    }
    elseif ($Bytes -ge 1KB) {
        return "{0:N2} KB" -f ($Bytes / 1KB)
    }
    else {
        return "$Bytes bytes"
    }
}

function Get-ElapsedTime {
    <#
    .SYNOPSIS
        Get elapsed time in human-readable format
    #>
    param(
        [Parameter(Mandatory=$true)]
        [datetime]$StartTime
    )

    $elapsed = (Get-Date) - $StartTime

    if ($elapsed.TotalMinutes -ge 1) {
        return "{0:N1} minutes" -f $elapsed.TotalMinutes
    }
    else {
        return "{0:N0} seconds" -f $elapsed.TotalSeconds
    }
}

#endregion
