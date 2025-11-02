# Azure Policy Exemption Helper
# Discovers Azure Policy violations and creates exemptions for required container registries

param(
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroup,

    [Parameter(Mandatory=$true)]
    [string]$ClusterName,

    [switch]$Apply,  # If set, will create the exemptions. Otherwise just shows what would be done.

    [string]$ExemptionCategory = "Waiver",  # Waiver or Mitigated

    [int]$ExpirationDays = 365  # Days until exemption expires
)

# Color output functions
function Write-Header { param($Message) Write-Host "`n=== $Message ===" -ForegroundColor Cyan }
function Write-Info { param($Message) Write-Host "[INFO] $Message" -ForegroundColor Blue }
function Write-Success { param($Message) Write-Host "[SUCCESS] $Message" -ForegroundColor Green }
function Write-Warning { param($Message) Write-Host "[WARNING] $Message" -ForegroundColor Yellow }
function Write-Error { param($Message) Write-Host "[ERROR] $Message" -ForegroundColor Red }

Write-Host @"

============================================
  Azure Policy Exemption Helper
============================================
Resource Group : $ResourceGroup
Cluster Name   : $ClusterName
Mode           : $(if ($Apply) { "APPLY" } else { "DRY-RUN" })
============================================

"@ -ForegroundColor Cyan

# Get AKS credentials to check cluster
Write-Header "Checking Cluster Connection"
Write-Info "Getting AKS credentials..."
az aks get-credentials --resource-group $ResourceGroup --name $ClusterName --overwrite-existing --only-show-errors | Out-Null

if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to get AKS credentials"
    exit 1
}

Write-Success "Connected to cluster: $ClusterName"

# Check if Azure Policy is enabled
Write-Header "Checking Azure Policy Status"
$policyAddon = az aks show -g $ResourceGroup -n $ClusterName --query "addonProfiles.azurepolicy.enabled" -o tsv 2>$null

if ($policyAddon -ne "true") {
    Write-Warning "Azure Policy addon is not enabled on this cluster"
    Write-Info "No exemptions needed - cluster does not have Azure Policy enforcement"
    exit 0
}

Write-Success "Azure Policy addon is enabled"

# Check for constraint violations
Write-Header "Checking for Policy Violations"
Write-Info "Looking for container image policy constraints..."

$constraints = kubectl get k8sazurev2customcontainerallowedimages -o json 2>$null | ConvertFrom-Json

if ($null -eq $constraints -or $constraints.items.Count -eq 0) {
    Write-Warning "No k8sazurev2customcontainerallowedimages constraints found"
    Write-Info "The cluster may use different policy constraints"
    exit 0
}

foreach ($constraint in $constraints.items) {
    $name = $constraint.metadata.name
    $enforcementAction = $constraint.spec.enforcementAction
    $totalViolations = $constraint.status.totalViolations
    $policyAssignmentId = $constraint.metadata.annotations.'azure-policy-assignment-id'

    Write-Info "Constraint: $name"
    Write-Info "  Enforcement Action: $enforcementAction"
    Write-Info "  Total Violations: $totalViolations"

    if ($totalViolations -gt 0) {
        Write-Info "  Violations:"
        foreach ($violation in $constraint.status.violations) {
            Write-Host "    - $($violation.namespace)/$($violation.kind)/$($violation.name)" -ForegroundColor Yellow
            Write-Host "      $($violation.message)" -ForegroundColor Gray
        }
    }

    # Check if exemption already exists
    Write-Header "Checking for Existing Exemptions"
    Write-Info "Policy Assignment ID: $policyAssignmentId"

    $existingExemptions = az policy exemption list --resource-group $ResourceGroup --query "[?policyAssignmentId=='$policyAssignmentId']" -o json 2>$null | ConvertFrom-Json

    if ($existingExemptions.Count -gt 0) {
        Write-Success "Found existing exemption(s):"
        foreach ($exemption in $existingExemptions) {
            Write-Info "  - $($exemption.name): $($exemption.displayName)"
            Write-Info "    Category: $($exemption.exemptionCategory)"
            Write-Info "    Expires: $($exemption.expiresOn)"
        }
    } else {
        Write-Warning "No existing exemptions found"

        if ($Apply) {
            Write-Header "Creating Policy Exemption"

            # Calculate expiration date
            $expiresOn = (Get-Date).AddDays($ExpirationDays).ToString("yyyy-MM-ddTHH:mm:ssZ")

            $exemptionName = "llm-platform-container-images"
            $description = @"
Exemption for LLM Platform container registries.
The platform requires images from trusted third-party registries:
- quay.io (Prometheus, Grafana components)
- docker.io/grafana (Grafana)
- ghcr.io (Open-WebUI)
- ollama/ollama (Docker Hub)
- nvcr.io (NVIDIA DCGM Exporter)
- registry.k8s.io (Kubernetes components)

All images are from trusted, verified sources and are essential for platform operation.
Alternative: Mirror these images to Azure Container Registry (ACR).
"@

            Write-Info "Creating exemption: $exemptionName"
            Write-Info "Expiration: $expiresOn"

            $createResult = az policy exemption create `
                --name $exemptionName `
                --display-name "LLM Platform - Container Image Registry Exemption" `
                --policy-assignment $policyAssignmentId `
                --resource-group $ResourceGroup `
                --exemption-category $ExemptionCategory `
                --description $description `
                --expires-on $expiresOn `
                --metadata "Platform=AKS-LLM-Demo" "Registries=quay.io,docker.io,ghcr.io,nvcr.io,registry.k8s.io" `
                -o json 2>&1

            if ($LASTEXITCODE -eq 0) {
                Write-Success "Policy exemption created successfully"
                $exemption = $createResult | ConvertFrom-Json
                Write-Info "Exemption ID: $($exemption.id)"
            } else {
                Write-Error "Failed to create policy exemption"
                Write-Host $createResult -ForegroundColor Red
                exit 1
            }
        } else {
            Write-Info ""
            Write-Info "To create the exemption, run this script with -Apply:"
            Write-Info "  .\create-policy-exemption.ps1 -ResourceGroup $ResourceGroup -ClusterName $ClusterName -Apply"
        }
    }
}

Write-Header "Summary"
if ($Apply) {
    Write-Success "Policy exemptions have been created/verified"
} else {
    Write-Info "This was a dry-run. Use -Apply to create exemptions."
}

Write-Info ""
Write-Info "Alternative Solutions:"
Write-Info "  1. Mirror container images to Azure Container Registry (ACR)"
Write-Info "  2. Request Azure Policy modification to allow additional registries"
Write-Info "  3. Disable Azure Policy addon (not recommended for production)"
Write-Info ""
