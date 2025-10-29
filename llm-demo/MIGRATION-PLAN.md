# Migration Plan: Horizontal Scaling with PGVector

## Overview
Migrate from ChromaDB (SQLite) to PGVector for shared vector database across multiple Open-WebUI replicas, and restructure storage to use Azure Files Premium for shared file storage.

## Current State
- ✅ PostgreSQL Flexible Server deployed: `shsorot-pg-u6nkmvc5rezpy.postgres.database.azure.com`
- ✅ Open-WebUI using PostgreSQL for application data
- ❌ ChromaDB (SQLite) on Azure Disk (RWO) - **not shareable**
- ❌ User uploads on Azure Disk (RWO) - **not shareable**
- ❌ Embedding models on Azure Disk (RWO) - **duplicated per pod**
- ⚠️ Open-WebUI: 1 replica only (cannot scale)

## Target State
- ✅ PGVector extension enabled on PostgreSQL
- ✅ Azure Files Premium (RWX) for all shared storage
- ✅ Open-WebUI: 2-3 replicas with shared storage
- ✅ All components shareable across pods

---

## Phase 1: Enable PGVector Extension (5 minutes)

### Step 1.1: Connect to PostgreSQL
```bash
# Get admin password from Key Vault
az keyvault secret show \
  --vault-name shsorot-kv-* \
  --name postgres-admin-password \
  --query value -o tsv

# Connect via psql or Azure Portal Query Editor
```

### Step 1.2: Enable Extensions
```sql
-- Connect to the openwebui database
\c openwebui

-- Enable pgvector extension
CREATE EXTENSION IF NOT EXISTS vector;

-- Enable uuid extension (useful for Open-WebUI)
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Verify extensions
\dx

-- Expected output:
--   Name     | Version |   Schema   |         Description          
-- -----------+---------+------------+------------------------------
--  plpgsql   | 1.0     | pg_catalog | PL/pgSQL procedural language
--  uuid-ossp | 1.1     | public     | generate universally unique identifiers (UUIDs)
--  vector    | 0.5.0   | public     | vector data type and ivfflat access method
```

**Alternative: Azure CLI Method**
```bash
az postgres flexible-server parameter set \
  --resource-group shsorot-rg \
  --server-name shsorot-pg-* \
  --name azure.extensions \
  --value VECTOR,UUID-OSSP
```

---

## Phase 2: Update Storage Architecture (No Downtime)

### Step 2.1: Create New Azure Files PVC for WebUI
**File:** `k8s/04-storage-webui-files.yaml` (replaces 04-storage-webui-disk.yaml)

This will store:
- Embedding model cache (1.6 GB) - shared read-only
- User uploads - shared read-write
- Image/audio cache - shared read-write

### Step 2.2: Remove Unused Storage Classes
**Delete:** `k8s/03-storage-standard.yaml` (unused Azure Files Standard)

**Keep:**
- `02-storage-premium.yaml` - Ollama models (still needed, RWX working fine)
- `03-storageclass-disk.yaml` - General disk class (for other workloads if needed)

---

## Phase 3: Migrate Open-WebUI Configuration (Brief Downtime ~2 min)

### Step 3.1: Update Deployment Manifest
**File:** `k8s/07-webui-deployment.yaml`

**Key Changes:**
1. Set `VECTOR_DB=pgvector`
2. Set `PGVECTOR_DB_URL` to PostgreSQL connection string
3. Change PVC from `open-webui-disk-pvc` to `open-webui-files-pvc`
4. Set `replicas: 1` initially (will scale in Phase 4)

### Step 3.2: Backup Existing Data (Optional)
```bash
# Backup ChromaDB SQLite file (if you have important RAG data)
kubectl exec -n ollama <pod-name> -- tar czf /tmp/backup.tar.gz /app/backend/data/vector_db

kubectl cp ollama/<pod-name>:/tmp/backup.tar.gz ./backup-chromadb.tar.gz
```

**Note:** Since this is a demo environment with no production data yet, backup may be skipped.

### Step 3.3: Deploy Updated Configuration
```powershell
# Apply new storage
kubectl delete -f k8s/04-storage-webui-disk.yaml
kubectl apply -f k8s/04-storage-webui-files.yaml

# Delete old WebUI deployment
kubectl delete deployment open-webui -n ollama

# Apply updated deployment
kubectl apply -f k8s/07-webui-deployment.yaml

# Watch pod startup
kubectl get pods -n ollama -w
```

**Expected Startup:**
1. Pod starts → downloads embedding model to Azure Files (~1-2 min)
2. Open-WebUI initializes PGVector tables in PostgreSQL
3. Pod becomes Ready

---

## Phase 4: Scale to Multiple Replicas (No Downtime)

### Step 4.1: Scale Deployment
**Update:** `k8s/07-webui-deployment.yaml` → `replicas: 3`

```powershell
# Scale via kubectl
kubectl scale deployment open-webui -n ollama --replicas=3

# Or re-apply manifest
kubectl apply -f k8s/07-webui-deployment.yaml
```

### Step 4.2: Verify Replica Behavior
```powershell
# Check all pods are ready
kubectl get pods -n ollama -l app=open-webui

# Expected output:
# NAME                          READY   STATUS    RESTARTS   AGE
# open-webui-xxxxx-aaaaa        1/1     Running   0          2m
# open-webui-xxxxx-bbbbb        1/1     Running   0          2m
# open-webui-xxxxx-ccccc        1/1     Running   0          2m

# Check PVC mount
kubectl exec -n ollama <pod-name> -- df -h | grep webui
```

---

## Phase 5: Validation & Testing

### Test 5.1: Verify PGVector Tables
```sql
-- Connect to PostgreSQL
\c openwebui

-- List PGVector tables
\dt

-- Expected tables:
-- document_chunk (created by Open-WebUI PGVector client)

-- Check vector column
\d document_chunk

-- Expected columns:
-- id | vector | collection_name | text | vmetadata
```

### Test 5.2: RAG Functionality Across Replicas
```bash
# Get pod names
POD1=$(kubectl get pods -n ollama -l app=open-webui -o jsonpath='{.items[0].metadata.name}')
POD2=$(kubectl get pods -n ollama -l app=open-webui -o jsonpath='{.items[1].metadata.name}')
POD3=$(kubectl get pods -n ollama -l app=open-webui -o jsonpath='{.items[2].metadata.name}')

# Test shared embedding model cache
kubectl exec -n ollama $POD1 -- ls /app/backend/data/cache/embedding/models/
kubectl exec -n ollama $POD2 -- ls /app/backend/data/cache/embedding/models/
# Should show same files
```

**Manual Test in Web UI:**
1. Access Open-WebUI: http://<external-ip>:8080
2. Upload a document (e.g., PDF) in one session
3. Refresh browser (may hit different pod via load balancer)
4. Verify document still appears in "Documents" section
5. Ask RAG question about the document
6. Verify answer references the document (proves PGVector sharing works)

### Test 5.3: Load Balancing
```bash
# Get service external IP
kubectl get svc open-webui -n ollama

# Make multiple requests
for i in {1..10}; do
  curl -s http://<external-ip>:8080/health | jq .
  sleep 1
done

# Check pod logs to see which pods handled requests
kubectl logs -n ollama -l app=open-webui --tail=20 --all-containers=true
```

---

## Rollback Plan (If Issues Occur)

### Rollback Step 1: Scale Down to 1 Replica
```powershell
kubectl scale deployment open-webui -n ollama --replicas=1
```

### Rollback Step 2: Revert to ChromaDB + Disk
```powershell
# Re-apply old configuration
kubectl apply -f k8s/04-storage-webui-disk.yaml
kubectl apply -f k8s/07-webui-deployment.yaml.backup

# Restore backup if needed
kubectl cp ./backup-chromadb.tar.gz ollama/<pod-name>:/tmp/backup.tar.gz
kubectl exec -n ollama <pod-name> -- tar xzf /tmp/backup.tar.gz -C /
```

---

## Performance Considerations

### PostgreSQL Connection Pooling
With 3 replicas, each pod will create ~5-10 PostgreSQL connections.

**Current Configuration:**
- Azure PostgreSQL Standard_B1ms: **50 max connections**
- 3 WebUI pods × 10 connections = 30 connections
- ✅ Within limits, should work fine

**If scaling beyond 5 replicas:** Consider upgrading PostgreSQL tier or implementing PgBouncer.

### Storage IOPS
- **Azure Files Premium 1 TiB:** 4,100 baseline IOPS, up to 110,000 burst IOPS
- ✅ More than sufficient for 3 replicas

---

## Cost Impact

### Before Migration:
- 1× Azure Disk Premium (10 GB): ~$1.54/month
- Azure Files Premium (1 TiB): ~$200/month (already provisioned)
- **Total:** ~$201.54/month

### After Migration:
- Azure Files Premium (1 TiB): ~$200/month (shared across all pods)
- **Removed:** Azure Disk Premium (no longer needed)
- **Total:** ~$200/month

**Savings:** ~$1.54/month (minimal, but cleaner architecture)

---

## Timeline

| Phase | Duration | Downtime | Risk Level |
|-------|----------|----------|-----------|
| Phase 1: Enable PGVector | 5 min | ❌ None | 🟢 Low |
| Phase 2: Storage Updates | 10 min | ❌ None | 🟢 Low |
| Phase 3: WebUI Migration | 5 min | ⚠️ 2-3 min | 🟡 Medium |
| Phase 4: Scale to 3 Replicas | 2 min | ❌ None | 🟢 Low |
| Phase 5: Validation | 15 min | ❌ None | 🟢 Low |
| **Total** | **~35-40 min** | **2-3 min** | 🟢 **Low Overall** |

---

## Success Criteria

✅ PGVector extension enabled on PostgreSQL
✅ Open-WebUI scaled to 3 replicas
✅ All pods in Running state
✅ User uploads visible across all replicas
✅ RAG documents queryable from any replica
✅ Embedding model cache shared (not duplicated)
✅ No errors in pod logs
✅ Health checks passing on all replicas
✅ Service load balancing traffic across pods

---

## Next Steps After Migration

1. **Phase 6: Implement HPA (Horizontal Pod Autoscaler)**
   - Auto-scale 1-20 replicas based on CPU
   - Target: 70% CPU utilization

2. **Phase 7: Add Monitoring**
   - Prometheus metrics
   - Grafana dashboards
   - Alert rules for pod failures

3. **Phase 8: Performance Testing**
   - Load test with 200 concurrent users
   - Validate response times
   - Tune replica counts

4. **Phase 9: Documentation**
   - Update README.md
   - Create scaling guide
   - Document troubleshooting procedures
