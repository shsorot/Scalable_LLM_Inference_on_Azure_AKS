# Azure PostgreSQL Integration - Configuration Summary

## Overview
Open WebUI has been configured to use **Azure Database for PostgreSQL Flexible Server** instead of an in-cluster PostgreSQL deployment. This provides:

- **Fully managed database** - No maintenance overhead
- **Cost-effective** - Using Burstable B1ms tier (~$12/month)
- **Automatic backups** - 7-day retention
- **Built-in security** - SSL/TLS required, firewall rules
- **Separation of concerns** - Database persists independently of cluster

## Cost Optimization

The PostgreSQL deployment uses the most cost-effective configuration:

- **SKU**: `Standard_B1ms` (Burstable tier)
  - 1 vCore
  - 2 GiB RAM
  - Estimated cost: ~$12-15/month

- **Storage**: 32 GB (minimum)
  - Auto-grow disabled for predictable costs

- **Backup**: 7-day retention (minimum)
  - Geo-redundant backup disabled

- **High Availability**: Disabled
  - Not needed for demo workloads

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        AKS Cluster                          │
│                                                             │
│   ┌──────────────┐                                        │
│   │  Open-WebUI  │                                        │
│   │    Pod       │───┐                                    │
│   └──────────────┘   │                                    │
│                      │ PostgreSQL Connection              │
│                      │ (SSL/TLS required)                 │
└──────────────────────┼─────────────────────────────────────┘
                       │
                       ▼
            ┌──────────────────────┐
            │  Azure PostgreSQL    │
            │  Flexible Server     │
            │                      │
            │  • Burstable B1ms    │
            │  • 32 GB Storage     │
            │  • SSL Required      │
            │  • Azure Firewall    │
            └──────────────────────┘
```

## Configuration Changes

### 1. Bicep Infrastructure (`bicep/postgres.bicep`)
- New module deploying Azure PostgreSQL Flexible Server
- Firewall rule allowing all Azure services (includes AKS)
- Database `openwebui` automatically created

### 2. Main Bicep Template (`bicep/main.bicep`)
- Added `postgresAdminPassword` secure parameter
- Added postgres module deployment
- New outputs for PostgreSQL connection details

### 3. Deployment Script (`scripts/deploy.ps1`)
- Auto-generates secure PostgreSQL password if not provided
- Captures PostgreSQL outputs from deployment
- Creates Kubernetes secret with PostgreSQL connection string
- Connection string format: `postgresql://pgadmin:<password>@<fqdn>:5432/openwebui?sslmode=require`

### 4. WebUI Deployment (`k8s/07-webui-deployment.yaml`)
- `DATABASE_URL` now sourced from Kubernetes secret
- Reduced liveness/readiness probe delays (no waiting for in-cluster PostgreSQL startup)
- Updated comments to reflect Azure PostgreSQL usage

### 5. Removed Files
- In-cluster PostgreSQL no longer needed:
  - `k8s/06-postgres.yaml` (can be removed or kept for reference)

## Security

### Connection Security
- **SSL/TLS Required**: All connections must use encryption
- **Firewall Rules**: Only Azure services can connect
- **Password Complexity**: Auto-generated 24-character password
- **Secret Management**: Connection string stored in Kubernetes secret

### Credentials
- **Admin Username**: `pgadmin`
- **Admin Password**: Stored in:
  1. Kubernetes secret `ollama-secrets` (key: `postgres-connection-string`)
  2. Deployment script variable (not persisted)

## Deployment

### New Deployment
```powershell
.\scripts\deploy.ps1 `
    -Prefix "kubecon" `
    -Location "westus2" `
    -HuggingFaceToken "hf_xxxxx" `
    -AutoApprove
```

Password will be auto-generated.

### With Custom PostgreSQL Password
```powershell
.\scripts\deploy.ps1 `
    -Prefix "kubecon" `
    -Location "westus2" `
    -HuggingFaceToken "hf_xxxxx" `
    -PostgresPassword "YourSecurePassword123!" `
    -AutoApprove
```

## Verification

### 1. Check PostgreSQL Deployment
```powershell
# Get PostgreSQL server name
az postgres flexible-server list --resource-group <prefix>-rg --query "[].{Name:name, State:state, Version:version}" -o table

# Test connection (from Azure Cloud Shell or machine with psql)
psql "host=<server-fqdn> port=5432 dbname=openwebui user=pgadmin sslmode=require"
```

### 2. Check Open-WebUI Connection
```powershell
# View WebUI logs
kubectl logs -n ollama deployment/open-webui --tail=50

# Should see successful PostgreSQL connection
# Look for: "Connected to database" or similar message
```

### 3. Check Secret
```powershell
# View connection string (base64 encoded)
kubectl get secret ollama-secrets -n ollama -o jsonpath='{.data.postgres-connection-string}' | base64 -d
```

## Troubleshooting

### WebUI Can't Connect to PostgreSQL

1. **Check Firewall Rules**:
   ```powershell
   az postgres flexible-server firewall-rule list `
       --resource-group <prefix>-rg `
       --name <postgres-server-name> `
       -o table
   ```

2. **Verify Secret Exists**:
   ```powershell
   kubectl describe secret ollama-secrets -n ollama
   ```

3. **Check WebUI Logs**:
   ```powershell
   kubectl logs -n ollama deployment/open-webui --tail=100 | Select-String -Pattern "database|postgres|connection"
   ```

4. **Test from Pod**:
   ```powershell
   kubectl exec -n ollama deployment/open-webui -- sh -c "env | grep DATABASE"
   ```

### Performance Issues

- **Upgrade SKU**: Change to `Standard_B2s` (2 vCore, 4 GB RAM) - ~$30/month
- **Enable Connection Pooling**: Add `?pool_size=20` to connection string
- **Increase Storage**: Scale storage if needed (charged per GB)

## Migration from In-Cluster PostgreSQL

If you were using in-cluster PostgreSQL and want to migrate:

### 1. Backup Existing Data
```bash
kubectl exec -n ollama postgres-0 -- pg_dump -U openwebui openwebui > backup.sql
```

### 2. Deploy Azure PostgreSQL
Run the updated deployment script

### 3. Restore to Azure
```bash
psql "host=<fqdn> dbname=openwebui user=pgadmin sslmode=require" < backup.sql
```

### 4. Update WebUI
```bash
kubectl rollout restart deployment/open-webui -n ollama
```

## Cost Monitoring

Monitor PostgreSQL costs in Azure Portal:
1. Navigate to Cost Management + Billing
2. Filter by resource group: `<prefix>-rg`
3. Look for resource type: `Microsoft.DBforPostgreSQL/flexibleServers`

Expected monthly cost breakdown:
- Compute (B1ms): ~$12
- Storage (32 GB): ~$1.28
- Backup (7-day): Included
- **Total**: ~$13-15/month

## Additional Resources

- [Azure PostgreSQL Flexible Server Pricing](https://azure.microsoft.com/en-us/pricing/details/postgresql/flexible-server/)
- [Open-WebUI Database Documentation](https://docs.openwebui.com/getting-started/advanced-topics/database)
- [Azure PostgreSQL Flexible Server Limits](https://learn.microsoft.com/en-us/azure/postgresql/flexible-server/concepts-limits)
