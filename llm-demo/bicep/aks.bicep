// AKS cluster with GPU node pool for LLM workloads
// Optimized for Azure Files CSI Driver and T4/A10 GPU inference

targetScope = 'resourceGroup'

@description('AKS cluster name')
param aksName string

@description('Azure region')
param location string

@description('Kubernetes version')
param kubernetesVersion string

@description('Managed Identity resource ID for AKS')
param managedIdentityId string

@description('Log Analytics workspace ID')
param logAnalyticsId string

@description('GPU VM SKU')
param gpuVmSize string

@description('GPU node count')
param gpuNodeCount int

@description('Resource tags')
param tags object

// === AKS Cluster ===
resource aks 'Microsoft.ContainerService/managedClusters@2024-05-01' = {
  name: aksName
  location: location
  tags: tags
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${managedIdentityId}': {}
    }
  }
  properties: {
    kubernetesVersion: kubernetesVersion
    dnsPrefix: '${aksName}-dns'

    // Network configuration - Azure CNI Overlay for efficiency
    networkProfile: {
      networkPlugin: 'azure'
      networkPluginMode: 'overlay'
      networkPolicy: 'azure'
      loadBalancerSku: 'standard'
      serviceCidr: '10.100.0.0/16'
      dnsServiceIP: '10.100.0.10'
      outboundType: 'loadBalancer'
    }

    // System node pool (non-GPU, for system pods)
    agentPoolProfiles: [
      {
        name: 'system'
        count: 2
        vmSize: 'Standard_DS3_v2'
        osDiskSizeGB: 128
        osDiskType: 'Managed'
        osType: 'Linux'
        mode: 'System'
        type: 'VirtualMachineScaleSets'
        enableAutoScaling: false
        maxPods: 30
        availabilityZones: []
        nodeTaints: [
          'CriticalAddonsOnly=true:NoSchedule' // Isolate system workloads
        ]
        nodeLabels: {
          'workload': 'system'
        }
      }
      {
        // GPU node pool for LLM inference
        name: 'gpu'
        count: gpuNodeCount
        vmSize: gpuVmSize
        osDiskSizeGB: 256 // Large disk for model caching
        osDiskType: 'Managed'
        osType: 'Linux'
        mode: 'User'
        type: 'VirtualMachineScaleSets'
        enableAutoScaling: false
        maxPods: 30
        availabilityZones: []
        nodeTaints: [
          'sku=gpu:NoSchedule' // Prevent non-GPU workloads
        ]
        nodeLabels: {
          'workload': 'llm'
          'gpu': 'true'
          'gpu-type': 'nvidia-t4'
        }
      }
    ]

    // Enable managed identity for AKS control plane
    identityProfile: {
      kubeletidentity: {
        resourceId: managedIdentityId
      }
    }

    // Add-ons
    addonProfiles: {
      omsagent: {
        enabled: true
        config: {
          logAnalyticsWorkspaceResourceID: logAnalyticsId
        }
      }
      azureKeyvaultSecretsProvider: {
        enabled: true
        config: {
          enableSecretRotation: 'true'
          rotationPollInterval: '2m'
        }
      }
      azurepolicy: {
        enabled: false // Disabled for demo simplicity
      }
    }

    // Storage profile - Enable Azure Files CSI driver
    storageProfile: {
      diskCSIDriver: {
        enabled: true
      }
      fileCSIDriver: {
        enabled: true // Critical for Azure Files integration
      }
      snapshotController: {
        enabled: true
      }
    }

    // Security settings
    apiServerAccessProfile: {
      enablePrivateCluster: false // Public for demo access
    }

    aadProfile: {
      managed: true
      enableAzureRBAC: true
    }

    // Disable local accounts (enforce AAD)
    disableLocalAccounts: false // Keep enabled for demo simplicity

    // Automatic upgrade settings
    autoUpgradeProfile: {
      upgradeChannel: 'none' // Manual control for demo stability
    }

    // Workload identity for pod-level Azure resource access
    oidcIssuerProfile: {
      enabled: true
    }
    securityProfile: {
      workloadIdentity: {
        enabled: true
      }
    }
  }
}

// === Outputs ===
output aksName string = aks.name
output aksResourceId string = aks.id
output aksNodeResourceGroup string = aks.properties.nodeResourceGroup
output aksFqdn string = aks.properties.fqdn
output aksOidcIssuerUrl string = aks.properties.oidcIssuerProfile.issuerURL
output aksOutboundIp string = aks.properties.networkProfile.loadBalancerProfile.effectiveOutboundIPs[0].id
