# Quick Start Guide: Migration to PGVector + Horizontal Scaling

## Files Created/Modified

### New Files:
- ✅ `MIGRATION-PLAN.md` - Comprehensive migration documentation
- ✅ `k8s/04-storage-webui-files.yaml` - New Azure Files Premium PVC (20GB, RWX)
- ✅ `scripts/migrate-to-pgvector.ps1` - Automated migration script
- ✅ `scripts/validate-migration.ps1` - Post-migration validation
- ✅ `scripts/enable-pgvector.sql` - SQL script for PostgreSQL extension

### Modified Files:
- ✅ `k8s/07-webui-deployment.yaml` - Updated with PGVector config + 3 replicas
- ✅ `scripts/deploy.ps1` - Updated storage deployment logic

### Removed/Deprecated:
- ❌ `k8s/03-storage-standard.yaml` - Unused Azure Files Standard (will be deleted)
- ❌ `k8s/04-storage-webui-disk.yaml` - Old Azure Disk config (will be backed up)

---

## Quick Execution Steps (30-40 minutes)

### Step 1: Enable PGVector Extension (5 minutes)

```powershell
# Get PostgreSQL connection details
az postgres flexible-server list --resource-group shsorot-rg --query "[].{Name:name,FQDN:fullyQualifiedDomainName}" -o table

# Get admin password
$pgPassword = az keyvault secret show `
  --vault-name $(az keyvault list --resource-group shsorot-rg --query "[0].name" -o tsv) `
  --name postgres-admin-password `
  --query value -o tsv

Write-Host "Admin password: $pgPassword"
```

**Option A: Azure Portal (Recommended)**
1. Go to Azure Portal → PostgreSQL Flexible Server → `shsorot-pg-*`
2. Click "Databases" → Select `openwebui`
3. Click "Query editor (preview)"
4. Login with username: `pgadmin` and the password from above
5. Run the SQL from `scripts/enable-pgvector.sql`

**Option B: psql Command Line**
```bash
# Install psql if not available: https://www.postgresql.org/download/
psql -h shsorot-pg-*.postgres.database.azure.com -U pgadmin -d openwebui

# Then run:
CREATE EXTENSION IF NOT EXISTS vector;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
\dx
\q
```

---

### Step 2: Run Migration Script (10-15 minutes)

```powershell
cd d:\temp\kubecon-na-booth-demo\llm-demo

# Full migration (with prompts)
.\scripts\migrate-to-pgvector.ps1 -Prefix "shsorot" -TargetReplicas 3

# Or auto-approve (skip confirmations)
.\scripts\migrate-to-pgvector.ps1 -Prefix "shsorot" -TargetReplicas 3 -AutoApprove

# If you already enabled PGVector manually:
.\scripts\migrate-to-pgvector.ps1 -Prefix "shsorot" -TargetReplicas 3 -SkipPGVector -AutoApprove
```

**What the script does:**
1. ✅ Backs up existing ChromaDB data (optional)
2. ✅ Scales Open-WebUI to 0 replicas
3. ✅ Deletes old Azure Disk PVC
4. ✅ Creates new Azure Files Premium PVC (RWX)
5. ✅ Applies updated deployment with PGVector config
6. ✅ Scales up to 3 replicas
7. ✅ Validates all pods are Ready

---

### Step 3: Validate Migration (10 minutes)

```powershell
# Run comprehensive validation
.\scripts\validate-migration.ps1 -Prefix "shsorot"
```

**Validation checks:**
- ✅ All pods are in Ready state
- ✅ PVC is bound with ReadWriteMany (RWX) access
- ✅ `VECTOR_DB=pgvector` environment variable set
- ✅ PGVECTOR_DB_URL configured
- ✅ Storage mounted on all pods
- ✅ Embedding model cache shared across pods
- ✅ PostgreSQL connectivity
- ✅ No critical errors in logs
- ✅ Service endpoint accessible
- ✅ Pod distribution across nodes

---

### Step 4: Manual Testing (10 minutes)

#### Test 4.1: Get Service IP
```powershell
kubectl get svc open-webui -n ollama

# Example output:
# NAME         TYPE           CLUSTER-IP     EXTERNAL-IP    PORT(S)        AGE
# open-webui   LoadBalancer   10.0.123.45    20.76.xx.xx    8080:30123/TCP 10m
```

#### Test 4.2: Access Web UI
1. Open browser: `http://<EXTERNAL-IP>:8080`
2. Create admin account (first user becomes admin)
3. Login

#### Test 4.3: Verify Multi-Replica RAG
1. **Upload a document:**
   - Click "+" → "Upload files"
   - Upload a PDF or text file
   - Wait for processing

2. **Test cross-replica access:**
   - Refresh browser multiple times (F5)
   - Each refresh may hit a different pod
   - Verify document still appears in "Documents" section
   - ✅ **Proves PGVector sharing works!**

3. **Test RAG query:**
   - Start new chat
   - Click "#" → Select your uploaded document
   - Ask a question about the document content
   - Verify answer uses document context
   - ✅ **Proves vector embeddings are shared!**

#### Test 4.4: Check Pod Logs
```powershell
# Watch logs from all replicas
kubectl logs -n ollama -l app=open-webui --tail=50 -f

# Check specific pod
kubectl get pods -n ollama -l app=open-webui
kubectl logs -n ollama <pod-name> --tail=100
```

---

## Architecture After Migration

### Before (Single Replica - Not Scalable):
```
┌──────────────┐
│  Open-WebUI  │  replicas: 1
│    Pod       │  ❌ Cannot scale
└──────────────┘
       │
       ▼
┌──────────────┐      ┌──────────────┐
│ Azure Disk   │      │ ChromaDB     │
│ (RWO)        │      │ (SQLite)     │
│ 10GB         │      │ Local only   │
└──────────────┘      └──────────────┘
```

### After (Multi-Replica - Scalable):
```
┌──────────────┐  ┌──────────────┐  ┌──────────────┐
│  Open-WebUI  │  │  Open-WebUI  │  │  Open-WebUI  │
│   Pod 1      │  │   Pod 2      │  │   Pod 3      │
└──────────────┘  └──────────────┘  └──────────────┘
       │                 │                 │
       └─────────────────┼─────────────────┘
                         ▼
              ┌────────────────────┐
              │  Azure Files       │
              │  Premium (RWX)     │
              │  20GB shared       │
              │  - Models: 1.6GB   │
              │  - Uploads: shared │
              └────────────────────┘
                         │
         ┌───────────────┴───────────────┐
         ▼                               ▼
┌─────────────────┐          ┌─────────────────┐
│  PostgreSQL     │          │  PGVector       │
│  Application DB │          │  Vector DB      │
│  (users, chats) │          │  (embeddings)   │
└─────────────────┘          └─────────────────┘
```

---

## Configuration Changes Summary

### Environment Variables Added:
```yaml
VECTOR_DB: "pgvector"
PGVECTOR_DB_URL: <postgres-connection-string>
PGVECTOR_CREATE_EXTENSION: "false"
PGVECTOR_INITIALIZE_MAX_VECTOR_LENGTH: "384"
PGVECTOR_POOL_SIZE: "10"
PGVECTOR_POOL_MAX_OVERFLOW: "5"
PGVECTOR_POOL_TIMEOUT: "30"
PGVECTOR_POOL_RECYCLE: "3600"
```

### Storage Changes:
```yaml
# Old:
  claimName: open-webui-disk-pvc     # Azure Disk (RWO)
  storageClassName: azuredisk-premium-retain
  storage: 10Gi

# New:
  claimName: open-webui-files-pvc    # Azure Files (RWX)
  storageClassName: azurefile-premium-llm
  storage: 20Gi
  accessModes: [ReadWriteMany]
```

### Replica Scaling:
```yaml
# Old:
  replicas: 1

# New:
  replicas: 3
```

---

## Troubleshooting

### Issue: Pods stuck in ContainerCreating
```powershell
kubectl describe pod -n ollama <pod-name>

# Common cause: PVC not bound
kubectl get pvc -n ollama

# Fix: Check storage class exists
kubectl get sc azurefile-premium-llm
```

### Issue: Pods crash with "Failed to connect to PostgreSQL"
```powershell
# Check secret exists
kubectl get secret ollama-secrets -n ollama

# Verify connection string
kubectl get secret ollama-secrets -n ollama -o jsonpath='{.data.postgres-connection-string}' | base64 -d

# Test connectivity from pod
kubectl exec -n ollama <pod-name> -- nslookup shsorot-pg-*.postgres.database.azure.com
```

### Issue: "relation 'document_chunk' does not exist"
```sql
-- Connect to PostgreSQL and check:
\c openwebui
\dt

-- If table doesn't exist, it will be auto-created by Open-WebUI on first RAG operation
-- Or manually create:
-- Open-WebUI will handle table creation automatically when VECTOR_DB=pgvector
```

### Issue: Embedding model download taking long time
```powershell
# Check if model already exists
kubectl exec -n ollama <pod-name> -- ls -lh /app/backend/data/cache/embedding/models/

# If empty, wait for download (1-2 minutes on Azure Files Premium)
kubectl logs -n ollama <pod-name> --tail=50 -f | Select-String "embedding"
```

---

## Rollback Procedure (If Needed)

### Quick Rollback:
```powershell
# Scale down
kubectl scale deployment open-webui -n ollama --replicas=0

# Restore old configuration
kubectl apply -f k8s/04-storage-webui-disk.yaml.backup
kubectl apply -f k8s/07-webui-deployment.yaml.backup

# Scale up
kubectl scale deployment open-webui -n ollama --replicas=1
```

### Full Rollback with Data:
```powershell
# Restore ChromaDB backup
kubectl cp ./chromadb-backup-*.tar.gz ollama/<pod-name>:/tmp/backup.tar.gz
kubectl exec -n ollama <pod-name> -- tar xzf /tmp/backup.tar.gz -C /
```

---

## Performance Monitoring

### Check Connection Pool Usage:
```sql
-- Connect to PostgreSQL
\c openwebui

-- View active connections
SELECT count(*), usename, application_name 
FROM pg_stat_activity 
WHERE datname = 'openwebui' 
GROUP BY usename, application_name;

-- Expected: ~10-15 connections per WebUI pod (3 pods = 30-45 connections)
```

### Check Vector Operations:
```sql
-- Count documents
SELECT collection_name, COUNT(*) 
FROM document_chunk 
GROUP BY collection_name;

-- Check vector dimensions
SELECT collection_name, array_length(vector, 1) as dimensions 
FROM document_chunk 
LIMIT 5;
```

### Monitor Storage Usage:
```powershell
kubectl exec -n ollama <pod-name> -- df -h | Select-String webui

# Check embedding model size
kubectl exec -n ollama <pod-name> -- du -sh /app/backend/data/cache/embedding
```

---

## Next Steps After Migration

1. **Implement HPA (Horizontal Pod Autoscaler)**
   ```yaml
   apiVersion: autoscaling/v2
   kind: HorizontalPodAutoscaler
   metadata:
     name: open-webui-hpa
   spec:
     scaleTargetRef:
       apiVersion: apps/v1
       kind: Deployment
       name: open-webui
     minReplicas: 1
     maxReplicas: 20
     metrics:
     - type: Resource
       resource:
         name: cpu
         target:
           type: Utilization
           averageUtilization: 70
   ```

2. **Add Monitoring (Prometheus + Grafana)**
   - Deploy Prometheus via Helm
   - Configure ServiceMonitors for Open-WebUI
   - Create Grafana dashboards
   - Set up alerts

3. **Load Testing**
   - Use tools like `k6` or `locust`
   - Test with 200 concurrent users
   - Monitor replica scaling behavior
   - Tune HPA parameters

4. **Documentation**
   - Update README.md with new architecture
   - Document scaling procedures
   - Create runbook for operations team

---

## Success Criteria Checklist

- [ ] PGVector extension enabled in PostgreSQL
- [ ] Migration script completed successfully
- [ ] All validation tests pass (0 failures)
- [ ] 3 Open-WebUI replicas running
- [ ] All pods in Ready state (1/1)
- [ ] PVC bound with RWX access mode
- [ ] Document upload visible across all replicas
- [ ] RAG queries work from any replica
- [ ] No errors in pod logs
- [ ] Service endpoint accessible
- [ ] Embedding model cache shared (not duplicated)
- [ ] PostgreSQL connection pool healthy

---

## Support & References

**Documentation:**
- [PGVector GitHub](https://github.com/pgvector/pgvector)
- [Open-WebUI Docs](https://docs.openwebui.com/)
- [Azure PostgreSQL Flexible Server](https://learn.microsoft.com/en-us/azure/postgresql/flexible-server/)
- [Azure Files Premium](https://learn.microsoft.com/en-us/azure/storage/files/storage-files-planning)

**Commands Reference:**
```powershell
# Check migration status
kubectl get all -n ollama

# Watch pod status
kubectl get pods -n ollama -l app=open-webui -w

# Get logs
kubectl logs -n ollama -l app=open-webui --tail=100 -f

# Check PVC
kubectl get pvc -n ollama
kubectl describe pvc open-webui-files-pvc -n ollama

# Test service
kubectl get svc open-webui -n ollama
curl http://<external-ip>:8080/health

# PostgreSQL queries
kubectl exec -n ollama <pod-name> -- env | grep PGVECTOR
```

---

**Ready to migrate? Run:**
```powershell
.\scripts\migrate-to-pgvector.ps1 -Prefix "shsorot" -TargetReplicas 3 -AutoApprove
```
