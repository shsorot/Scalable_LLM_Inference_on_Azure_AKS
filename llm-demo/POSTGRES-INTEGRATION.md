# PostgreSQL Integration for Open WebUI

## Overview

This deployment now uses **Azure Database for PostgreSQL Flexible Server** instead of SQLite for Open WebUI's database backend, providing better scalability, reliability, and multi-pod support.

## Architecture

### Components

1. **Azure PostgreSQL Flexible Server**
   - SKU: `Standard_B1ms` (Burstable, 1 vCore, 2 GiB RAM)
   - Storage: 32 GB (cost-optimized)
   - Backup: 7-day retention
   - High Availability: Disabled (for cost savings in demo/dev)
   - Cost: ~$13/month

2. **Azure Key Vault**
   - Stores PostgreSQL admin password
   - Stores full connection string
   - Unique name per region: `${prefix}${location}${uniqueString(...)}`

3. **Open WebUI**
   - Configured with `DATABASE_URL` environment variable
   - Connection string retrieved from Kubernetes secret
   - Automatic database migration on startup

## Deployment Flow

### 1. Password Generation
```powershell
# Generate secure 27-character password (24 alphanumeric + 3 special chars)
$PostgresPassword = -join ((48..57) + (65..90) + (97..122) | Get-Random -Count 24 | ForEach-Object {[char]$_})
$PostgresPassword = $PostgresPassword + "!@#"
```

### 2. Infrastructure Deployment
```bicep
// PostgreSQL module deployed via main.bicep
module postgres 'postgres.bicep' = {
  name: 'postgres-deployment'
  params: {
    prefix: prefix
    location: location
    administratorLogin: 'pgadmin'
    administratorPassword: postgresAdminPassword
    databaseName: 'openwebui'
  }
}
```

### 3. Secret Storage
```powershell
# Store in Key Vault
az keyvault secret set --vault-name $keyVaultName --name "postgres-admin-password" --value $PostgresPassword
az keyvault secret set --vault-name $keyVaultName --name "postgres-connection-string" --value $postgresConnectionString

# Store in Kubernetes
kubectl create secret generic ollama-secrets \
  --from-literal=postgres-connection-string=$postgresConnectionString
```

### 4. Open WebUI Configuration
```yaml
env:
  - name: DATABASE_URL
    valueFrom:
      secretKeyRef:
        name: ollama-secrets
        key: postgres-connection-string
```

## Connection String Format

```
postgresql://pgadmin:<password>@<server-fqdn>:5432/openwebui?sslmode=require
```

Example:
```
postgresql://pgadmin:Abc123XYZ!@#@myprefix-pg-abc123.postgres.database.azure.com:5432/openwebui?sslmode=require
```

## Key Vault Naming Strategy

### Problem
Key Vault names must be globally unique and purge protection is enabled by default. If a resource group is deleted and recreated, the Key Vault name might conflict with a soft-deleted vault.

### Solution
Include **location** in the unique name generation:

```bicep
var keyVaultName = take('${prefix}${location}${uniqueString(resourceGroup().id, location)}', 24)
```

**Benefits:**
- Each region gets a unique Key Vault name
- Recreating resource group in same region reuses same vault name
- Moving to different region creates new vault
- Max 24 characters (Key Vault limit)

**Example Names:**
- `shsorotnortheuropeaasby3` (northeurope)
- `shsorotwestus2xyz789qwe` (westus2)

## Security Features

1. **Password Complexity**
   - 27 characters (24 alphanumeric + 3 special)
   - Random generation using cryptographically secure RNG
   - Meets Azure PostgreSQL requirements

2. **Secure Storage**
   - Password never logged or displayed
   - Stored in Key Vault with RBAC
   - Connection string in Kubernetes secret

3. **Network Security**
   - SSL/TLS required (`sslmode=require`)
   - Firewall rule allows Azure services only
   - No public internet access by default

4. **RBAC**
   - Key Vault uses Azure RBAC (not access policies)
   - Kubernetes secrets namespace-isolated

## Cost Optimization

### PostgreSQL Configuration
```bicep
sku: {
  name: 'Standard_B1ms'
  tier: 'Burstable'
}
storage: {
  storageSizeGB: 32
  autoGrow: 'Disabled'  // Fixed size
}
backup: {
  backupRetentionDays: 7
  geoRedundantBackup: 'Disabled'
}
highAvailability: {
  mode: 'Disabled'
}
```

**Monthly Cost Estimate:** ~$13 USD
- Compute: B1ms (1 vCore) ~ $10/month
- Storage: 32 GB ~ $3/month
- Backup: 7-day local ~ included

### When to Scale Up
- **B2ms (2 vCore, 4 GiB):** Production workloads with more concurrent users
- **D-series (General Purpose):** High-performance production
- **Enable HA:** Mission-critical production

## Database Schema

Open WebUI automatically creates and manages these tables:
- `user` - User accounts and authentication
- `auth` - Session tokens and OAuth
- `chat` - Chat history and conversations
- `message` - Individual chat messages
- `document` - Uploaded documents
- `file` - File metadata
- `model` - Model configurations
- `prompt` - Prompt templates
- `tag` - Tags and categories
- `memory` - Persistent memory/context

### Migration
On first startup, Open WebUI runs Alembic migrations to create the schema.

## Troubleshooting

### Connection Issues

**Symptom:** Open WebUI pod fails to start with database connection errors

**Checks:**
```powershell
# 1. Verify PostgreSQL server is running
az postgres flexible-server show --resource-group <rg> --name <server-name>

# 2. Check connection string in Kubernetes
kubectl get secret ollama-secrets -n ollama -o jsonpath='{.data.postgres-connection-string}' | base64 -d

# 3. Test connection from pod
kubectl run psql-test -n ollama --rm -it --image=postgres:15 -- \
  psql "postgresql://pgadmin:<password>@<server>.postgres.database.azure.com:5432/openwebui?sslmode=require"

# 4. Check Open WebUI logs
kubectl logs -n ollama -l app=open-webui --tail=100
```

### Password Retrieval

```powershell
# From Key Vault
az keyvault secret show --vault-name <vault-name> --name postgres-admin-password --query value -o tsv

# From Kubernetes
kubectl get secret ollama-secrets -n ollama -o jsonpath='{.data.postgres-connection-string}' | base64 -d
```

### Firewall Issues

**Symptom:** Connection timeout or "no pg_hba.conf entry"

**Solution:** Verify firewall rule exists
```powershell
az postgres flexible-server firewall-rule list --resource-group <rg> --server-name <server>

# Should see: AllowAllAzureServicesAndResourcesWithinAzureIps
```

### Database Reset

**WARNING:** This deletes all data!

```sql
-- Connect as admin
psql "postgresql://pgadmin:<password>@<server>:5432/openwebui?sslmode=require"

-- Drop and recreate database
DROP DATABASE openwebui;
CREATE DATABASE openwebui WITH ENCODING 'UTF8';
```

Then restart Open WebUI pods to re-run migrations:
```powershell
kubectl rollout restart deployment/open-webui -n ollama
```

## Backup and Recovery

### Automated Backups
- **Retention:** 7 days
- **Type:** Full backups daily
- **Location:** Same region
- **Geo-redundancy:** Disabled (cost optimization)

### Manual Backup
```powershell
# Using pg_dump
kubectl run pgdump -n ollama --rm -it --image=postgres:15 -- \
  pg_dump "postgresql://pgadmin:<password>@<server>:5432/openwebui?sslmode=require" > backup.sql

# Or from local machine (if pg_dump installed)
pg_dump "postgresql://pgadmin:<password>@<server>:5432/openwebui?sslmode=require" -f backup.sql
```

### Restore from Backup
```powershell
# Using psql
kubectl run psql -n ollama --rm -it --image=postgres:15 -- \
  psql "postgresql://pgadmin:<password>@<server>:5432/openwebui?sslmode=require" < backup.sql
```

### Point-in-Time Restore
```powershell
# Restore to specific timestamp (within 7-day retention)
az postgres flexible-server restore \
  --resource-group <rg> \
  --name <new-server-name> \
  --source-server <original-server> \
  --restore-time "2025-10-28T12:00:00Z"
```

## Monitoring

### Azure Portal
1. Navigate to PostgreSQL server
2. Check "Monitoring" blade:
   - CPU usage
   - Memory usage
   - Active connections
   - Storage usage

### Query Performance
```sql
-- Enable query statistics (run as admin)
ALTER SYSTEM SET track_activity_query_size = 1024;
ALTER SYSTEM SET pg_stat_statements.track = 'all';
SELECT pg_reload_conf();

-- View slow queries
SELECT query, mean_exec_time, calls
FROM pg_stat_statements
ORDER BY mean_exec_time DESC
LIMIT 10;
```

### Connection Monitoring
```sql
-- View active connections
SELECT * FROM pg_stat_activity WHERE datname = 'openwebui';

-- Kill long-running query
SELECT pg_terminate_backend(pid) FROM pg_stat_activity
WHERE state = 'active' AND query_start < NOW() - INTERVAL '1 hour';
```

## Migration from SQLite

If you have existing SQLite data to migrate:

### 1. Export from SQLite
```bash
# On old pod with SQLite
sqlite3 /app/backend/data/webui.db .dump > webui_dump.sql
```

### 2. Convert to PostgreSQL Format
```bash
# Remove SQLite-specific commands
sed -i '/PRAGMA/d' webui_dump.sql
sed -i 's/AUTOINCREMENT/SERIAL/g' webui_dump.sql
```

### 3. Import to PostgreSQL
```bash
psql "postgresql://pgadmin:<password>@<server>:5432/openwebui?sslmode=require" < webui_dump.sql
```

### 4. Update Open WebUI
Deploy new configuration with `DATABASE_URL` environment variable.

## Performance Tuning

### For Production Workloads

1. **Upgrade SKU**
   ```bicep
   sku: {
     name: 'Standard_D2ds_v5'  // 2 vCore, 8 GiB RAM
     tier: 'GeneralPurpose'
   }
   ```

2. **Enable Connection Pooling**
   - Use PgBouncer sidecar in Kubernetes
   - Or use Azure Database for PostgreSQL built-in pooling

3. **Tune Parameters**
   ```sql
   ALTER SYSTEM SET shared_buffers = '256MB';
   ALTER SYSTEM SET effective_cache_size = '1GB';
   ALTER SYSTEM SET maintenance_work_mem = '64MB';
   ALTER SYSTEM SET checkpoint_completion_target = 0.9;
   ```

4. **Enable High Availability**
   ```bicep
   highAvailability: {
     mode: 'ZoneRedundant'
   }
   ```

## Cleanup

The cleanup script automatically handles PostgreSQL deletion:

```powershell
.\scripts\cleanup.ps1 -Prefix <prefix>
```

**What gets deleted:**
- PostgreSQL Flexible Server (server + database)
- Key Vault secrets (soft-deleted for 7 days)
- Kubernetes secrets
- Resource group (if empty)

**What persists:**
- Key Vault (soft-deleted, can be purged manually)
- Backups (retained for 7 days after server deletion)

## References

- [Azure PostgreSQL Flexible Server Docs](https://learn.microsoft.com/en-us/azure/postgresql/flexible-server/)
- [Open WebUI Documentation](https://docs.openwebui.com/)
- [PostgreSQL Connection Strings](https://www.postgresql.org/docs/current/libpq-connect.html#LIBPQ-CONNSTRING)
- [Azure Key Vault Best Practices](https://learn.microsoft.com/en-us/azure/key-vault/general/best-practices)
