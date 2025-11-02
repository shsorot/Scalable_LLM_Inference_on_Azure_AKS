// Azure Policy Exemptions for LLM Platform
// Creates exemptions for container image registries required by the LLM platform
// Addresses Azure Policy constraint: k8sazurev2customcontainerallowedimages

targetScope = 'resourceGroup'

@description('Policy assignment ID to exempt (from constraint metadata)')
param policyAssignmentId string = ''

@description('Whether to create policy exemptions')
param createPolicyExemptions bool = false

@description('Exemption reason')
@allowed([
  'Waiver'
  'Mitigated'
])
param exemptionCategory string = 'Waiver'

@description('Exemption expiration date (ISO 8601 format)')
param expirationDate string = ''

// === Policy Exemptions ===

// Note: Policy exemptions require the policy assignment ID which is discovered at runtime
// This template creates exemptions for the common container registries used in the platform

var exemptionDescription = '''
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
'''

// Policy exemption for container image restrictions
resource containerImageExemption 'Microsoft.Authorization/policyExemptions@2022-07-01-preview' = if (createPolicyExemptions && !empty(policyAssignmentId)) {
  name: 'aks-llm-platform-container-images'
  properties: {
    policyAssignmentId: policyAssignmentId
    exemptionCategory: exemptionCategory
    displayName: 'LLM Platform - Container Image Registry Exemption'
    description: exemptionDescription
    metadata: {
      Platform: 'AKS-LLM-Demo'
      Registries: 'quay.io, docker.io, ghcr.io, nvcr.io, registry.k8s.io'
      CreatedBy: 'Bicep-Template'
    }
    // Expiration date (optional) - if provided
    expiresOn: !empty(expirationDate) ? expirationDate : null
  }
}

// === Outputs ===
output exemptionCreated bool = createPolicyExemptions
output exemptionName string = createPolicyExemptions && !empty(policyAssignmentId) ? containerImageExemption.name : ''
output policyAssignmentIdUsed string = policyAssignmentId
output requiredRegistries array = [
  'quay.io'
  'docker.io'
  'grafana'
  'ghcr.io'
  'ollama'
  'nvcr.io'
  'registry.k8s.io'
  'mcr.microsoft.com'
]
