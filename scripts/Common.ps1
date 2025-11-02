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
