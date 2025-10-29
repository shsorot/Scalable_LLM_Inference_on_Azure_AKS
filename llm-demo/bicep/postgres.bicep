// Azure Database for PostgreSQL Flexible Server
// Cost-optimized for demo workloads

targetScope = 'resourceGroup'

@description('Unique prefix for resources')
param prefix string

@description('Azure region')
param location string

@description('PostgreSQL admin username')
param administratorLogin string = 'pgadmin'

@description('PostgreSQL admin password')
@secure()
param administratorPassword string

@description('Database name for Open WebUI')
param databaseName string = 'openwebui'

@description('Tags for resources')
param tags object = {}

// PostgreSQL Flexible Server name
var postgresServerName = '${prefix}-pg-${uniqueString(resourceGroup().id)}'

// === PostgreSQL Flexible Server ===
resource postgresServer 'Microsoft.DBforPostgreSQL/flexibleServers@2023-03-01-preview' = {
  name: postgresServerName
  location: location
  tags: tags
  sku: {
    name: 'Standard_B1ms'  // Burstable, 1 vCore, 2 GiB RAM - Most cost-effective
    tier: 'Burstable'
  }
  properties: {
    administratorLogin: administratorLogin
    administratorLoginPassword: administratorPassword
    version: '16'
    storage: {
      storageSizeGB: 32  // Minimum size
      autoGrow: 'Disabled'  // Keep costs predictable
    }
    backup: {
      backupRetentionDays: 7  // Minimum retention
      geoRedundantBackup: 'Disabled'  // Disable geo-redundancy for cost savings
    }
    highAvailability: {
      mode: 'Disabled'  // No HA for demo
    }
    availabilityZone: '1'  // Single zone for cost savings
    createMode: 'Default'
  }
}

// === Firewall Rules ===
// Allow all Azure services and resources (includes AKS pods)
resource allowAzureServices 'Microsoft.DBforPostgreSQL/flexibleServers/firewallRules@2023-03-01-preview' = {
  parent: postgresServer
  name: 'AllowAllAzureServicesAndResourcesWithinAzureIps'
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
}

// === Database ===
resource database 'Microsoft.DBforPostgreSQL/flexibleServers/databases@2023-03-01-preview' = {
  parent: postgresServer
  name: databaseName
  properties: {
    charset: 'UTF8'
    collation: 'en_US.utf8'
  }
}

// === Outputs ===
output postgresServerName string = postgresServer.name
output postgresServerFqdn string = postgresServer.properties.fullyQualifiedDomainName
output postgresAdminUsername string = administratorLogin
output postgresDatabaseName string = databaseName
output connectionString string = 'postgresql://${administratorLogin}@${postgresServer.name}:<password>@${postgresServer.properties.fullyQualifiedDomainName}:5432/${databaseName}?sslmode=require'
