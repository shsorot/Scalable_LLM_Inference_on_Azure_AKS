// Main deployment orchestrator for KubeCon NA 2025 LLM Demo
// Deploys: AKS with GPU node pool + Azure Key Vault + Storage

targetScope = 'resourceGroup'

@description('Unique prefix for all resources (3-15 alphanumeric characters)')
@minLength(3)
@maxLength(15)
param prefix string

@description('Azure region for deployment')
@allowed([
  'northeurope'
  'westus2'
  'eastus'
])
param location string = 'northeurope'

@description('GPU VM SKU for AKS node pool')
@allowed([
  'Standard_NC4as_T4_v3'     // T4 GPU - 1x NVIDIA T4 (16GB), 4 vCPU, 28GB RAM
  'Standard_NC8as_T4_v3'     // T4 GPU - 1x NVIDIA T4 (16GB), 8 vCPU, 56GB RAM
  'Standard_NC16as_T4_v3'    // T4 GPU - 1x NVIDIA T4 (16GB), 16 vCPU, 110GB RAM
  'Standard_NV6ads_A10_v5'   // A10 GPU - 1/6 NVIDIA A10 (4GB), 6 vCPU, 55GB RAM
])
param gpuVmSize string = 'Standard_NC8as_T4_v3'

@description('Number of GPU nodes')
@minValue(1)
@maxValue(5)
param gpuNodeCount int = 2

@description('Hugging Face API token for model downloads')
@secure()
param huggingFaceToken string

@description('PostgreSQL administrator password')
@secure()
param postgresAdminPassword string

@description('Kubernetes version')
param kubernetesVersion string = '1.31'

@description('Tags for all resources')
param tags object = {
  Project: 'KubeCon-NA-2025'
  Component: 'LLM-Demo'
  ManagedBy: 'Bicep'
  Team: 'Azure-Files'
}

// === Variables ===
var aksName = '${prefix}-aks'
// Key Vault name includes location to ensure uniqueness per region
// Note: Max 24 chars, alphanumeric only
var keyVaultName = take('${prefix}${location}${uniqueString(resourceGroup().id, location)}', 24)
var logAnalyticsName = '${prefix}-logs'
var managedIdentityName = '${prefix}-aks-identity'

// === Managed Identity for AKS ===
resource aksIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: managedIdentityName
  location: location
  tags: tags
}

// Grant the AKS identity "Managed Identity Operator" role over itself (required for kubelet identity)
resource managedIdentityOperatorRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(aksIdentity.id, 'ManagedIdentityOperator', resourceGroup().id)
  scope: aksIdentity
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'f1a07417-d97a-45cb-824c-7a7467783830') // Managed Identity Operator
    principalId: aksIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

// === Log Analytics Workspace ===
resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: logAnalyticsName
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
    features: {
      enableLogAccessUsingOnlyResourcePermissions: true
    }
  }
}

// === Azure Key Vault ===
resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: keyVaultName
  location: location
  tags: tags
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: subscription().tenantId
    enableRbacAuthorization: true
    enableSoftDelete: true
    softDeleteRetentionInDays: 7
    enablePurgeProtection: null // Let Azure decide based on existing vault state
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Allow'
    }
  }
}

// Store HF token in Key Vault
resource hfTokenSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'huggingface-token'
  properties: {
    value: huggingFaceToken
    contentType: 'text/plain'
    attributes: {
      enabled: true
    }
  }
}

// Grant AKS identity Key Vault Secrets User role
resource kvSecretUserRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(keyVault.id, aksIdentity.id, 'Key Vault Secrets User')
  scope: keyVault
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4633458b-17de-408a-b874-0445c86b69e6') // Key Vault Secrets User
    principalId: aksIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

// === AKS Cluster ===
module aks 'aks.bicep' = {
  name: 'aks-deployment'
  params: {
    aksName: aksName
    location: location
    kubernetesVersion: kubernetesVersion
    managedIdentityId: aksIdentity.id
    logAnalyticsId: logAnalytics.id
    gpuVmSize: gpuVmSize
    gpuNodeCount: gpuNodeCount
    tags: tags
  }
  dependsOn: [
    managedIdentityOperatorRole  // Ensure role assignment completes before AKS creation
  ]
}

// === Azure Database for PostgreSQL ===
module postgres 'postgres.bicep' = {
  name: 'postgres-deployment'
  params: {
    prefix: prefix
    location: location
    administratorLogin: 'pgadmin'
    administratorPassword: postgresAdminPassword
    databaseName: 'openwebui'
    tags: tags
  }
}

// === Outputs ===
output aksClusterName string = aks.outputs.aksName
output aksName string = aks.outputs.aksName
output aksResourceId string = aks.outputs.aksResourceId
output keyVaultName string = keyVault.name
output keyVaultId string = keyVault.id
output logAnalyticsWorkspaceId string = logAnalytics.id
output managedIdentityClientId string = aksIdentity.properties.clientId
output managedIdentityPrincipalId string = aksIdentity.properties.principalId
output premiumStorageAccountName string = ''  // Not deployed in this version
output standardStorageAccountName string = ''  // Not deployed in this version
output postgresServerName string = postgres.outputs.postgresServerName
output postgresServerFqdn string = postgres.outputs.postgresServerFqdn
output postgresAdminUsername string = postgres.outputs.postgresAdminUsername
output postgresDatabaseName string = postgres.outputs.postgresDatabaseName
output postgresConnectionString string = postgres.outputs.connectionString
