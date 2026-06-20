# Kubernetes Deployment Troubleshooting

## Issue: Service Cannot Be Modified

### Symptom
```
The Service "postgres" is invalid: spec.clusterIPs[0]: Invalid value: ["None"]: may not change once set
```

### Root Cause
Kubernetes **Services have immutable fields**. Once a Service is created with a specific `clusterIP`, you cannot change it to a different value (including making it headless with `clusterIP: None`).

**Timeline:**
1. Build #80: Created Service with `clusterIP: <some-ip>` (old postgres Deployment setup)
2. Build #82: Tried to apply Service with `clusterIP: None` (new StatefulSet setup)
3. **Conflict**: Kubernetes rejects the change → deployment fails

### Manual Fix (One-time)
```bash
# Delete the old Service
kubectl delete service postgres -n bug-report-portal-dev

# Next Jenkins run will create the new Service
```

## Immutable Kubernetes Fields

### Services
- `spec.clusterIP` - Cannot change once set
- `spec.clusterIPs` - Cannot change once set
- `spec.ipFamilies` - Cannot change once set
- `spec.type` - Cannot change from ClusterIP → Headless

### StatefulSets
- `spec.serviceName` - Cannot change once set
- `spec.selector` - Cannot change once set

### Deployments
- `spec.selector` - Cannot change once set

## Prevention Strategy

**When migrating K8s resources:**
1. Use `kubectl delete <resource-type> <name> --ignore-not-found` to clean conflicting resources
2. Add a 2-3 second sleep between delete and apply
3. Automate cleanup in CI/CD pipeline instead of manual intervention

## Related Issues
- **PostgreSQL Deployment → StatefulSet**: Required cleanup of old Deployment + Service
- **Service type changes**: Requires delete + recreate

## Pod Communication Architecture

### How App Pod Connects to PostgreSQL StatefulSet

```
┌─────────────────────────────────────────────────────────────┐
│ KUBERNETES COMMUNICATION FLOW                               │
└─────────────────────────────────────────────────────────────┘

LAYER 1: DNS SERVICE DISCOVERY
├─ Headless Service: postgres (ClusterIP: None)
├─ DNS Name: postgres.bug-report-portal-dev.svc.cluster.local
└─ Resolves to: postgres-0 pod IP (e.g., 10.244.0.14)

LAYER 2: POD STARTUP SEQUENCE
├─ Init Container 1: wait-for-postgres
│  └─ Command: pg_isready -h postgres -p 5432
│  └─ Purpose: Verify postgres-0 is accepting connections
│  └─ Status: ✅ postgres:5432 - accepting connections
│
├─ Init Container 2: db-migrate
│  └─ Command: npx prisma migrate deploy
│  └─ Purpose: Create database schema (tables, indexes, constraints)
│  └─ Connects to: postgresql://postgres:postgres@postgres:5432/bugreportportal
│  └─ Status: ✅ Migrations applied (4 tables)
│
└─ App Container
   └─ Reads: DATABASE_URL env var
   └─ Connects to: postgresql://postgres:postgres@postgres:5432/bugreportportal
   └─ Service: postgres resolves to postgres-0
   └─ Status: ✅ App running on port 3000

LAYER 3: DATA PERSISTENCE
├─ StatefulSet: postgres (1 replica)
├─ Pod Name: postgres-0 (stable, predictable)
├─ Storage: postgres-storage-postgres-0 (10Gi PVC)
├─ Volume Mount: /var/lib/postgresql/data
└─ Status: ✅ Data survives pod restarts
```

### DNS Resolution Details

**Short name resolution (within same namespace):**
```bash
App pod resolves "postgres" → postgres.bug-report-portal-dev.svc.cluster.local
                            → 10.244.0.14 (postgres-0 pod IP)
```

**Verify DNS from inside pod:**
```bash
kubectl exec -n bug-report-portal-dev <app-pod> -- nslookup postgres
# Output: postgres.bug-report-portal-dev.svc.cluster.local → 10.244.0.14
```

### Why Headless Service for StatefulSet?

| Feature | Regular Service | Headless Service |
|---------|-----------------|-----------------|
| ClusterIP | Assigned (10.x.x.x) | None |
| Load Balancing | Yes (round-robin) | No |
| Pod DNS | Single VIP | Individual pod IPs |
| StatefulSet | ❌ Not suitable | ✅ Required |
| Use Case | Stateless apps | StatefulSets, databases |

**Why StatefulSet needs headless service:**
- StatefulSet pods need **stable, predictable DNS names**: `postgres-0.postgres`
- Regular service creates single VIP that load-balances across pods (bad for databases)
- Headless service maps each pod to its own DNS entry (good for persistence)

### StatefulSet vs Pod: Why Both Are Required

**Common misconception:** "Can't I just run a pod without StatefulSet?"

**Answer:** ❌ No - they serve different purposes:

```
┌─────────────────────────────────────────────────────────────┐
│ WHAT IS A STATEFULSET?                                      │
└─────────────────────────────────────────────────────────────┘

StatefulSet = CONTROLLER/BLUEPRINT
├─ Manages pod lifecycle
├─ Ensures desired state (always 1 replica running)
├─ Handles pod restarts if crashed
├─ Manages persistent storage (PVCs)
├─ Provides stable pod naming (postgres-0, postgres-1, etc.)
└─ Enables scaling (add more replicas easily)

Pod = ACTUAL RUNNING CONTAINER
├─ The executable database process
├─ Lives at pod IP: 10.244.0.14
├─ Runs PostgreSQL service
├─ Mounts storage from PVC
└─ Created and managed by StatefulSet
```

**Relationship:**
```
You apply: StatefulSet manifest
           ↓
Kubernetes creates: Pod (postgres-0)
           ↓
Pod runs: PostgreSQL process
```

**Comparison Table:**

| Aspect | StatefulSet Only | Pod Only | Both (Correct) |
|--------|------------------|----------|----------------|
| **Pod crashes** | ✅ Auto-restarts | ❌ Stays dead | ✅ Auto-restarts |
| **Node goes down** | ✅ Reschedules pod | ❌ Pod lost | ✅ Pod rescheduled |
| **Scale to 2 replicas** | ✅ Creates postgres-1 | ❌ Manual work | ✅ Automatic |
| **Persistent storage** | ✅ PVC per pod | ❌ No persistence | ✅ Data survives |
| **Pod naming** | ✅ Stable: postgres-0 | ❌ Random names | ✅ Predictable DNS |
| **Update strategy** | ✅ Controlled rollout | ❌ Manual | ✅ Automatic |
| **Production ready** | ✅ Yes | ❌ No | ✅ Yes |

**Real Example - What Happens When Pod Crashes:**

```
SCENARIO 1: Without StatefulSet (Just Pod)
┌─ Pod postgres-0 crashes
├─ Pod status: CrashLoopBackOff ❌
├─ Database offline ❌
└─ MANUAL fix required: kubectl delete pod, manual recreation

SCENARIO 2: With StatefulSet (Correct)
┌─ Pod postgres-0 crashes
├─ StatefulSet detects: "Should have 1 pod, but have 0" ✅
├─ StatefulSet immediately: Creates new postgres-0
├─ New pod: Mounts same PVC (postgres-storage-postgres-0)
├─ Data: Automatically restored from PVC ✅
├─ Database: Back online in 30-60 seconds ✅
└─ AUTOMATIC - no manual intervention needed
```

**Verify Both Are Running:**
```bash
# Check StatefulSet (the controller)
kubectl get statefulsets -n bug-report-portal-dev postgres
# Output: NAME=postgres, READY=1/1, AGE=6h

# Check Pod (the actual container)
kubectl get pods -n bug-report-portal-dev postgres-0
# Output: NAME=postgres-0, READY=1/1, STATUS=Running

# StatefulSet owns the Pod
kubectl get pod postgres-0 -n bug-report-portal-dev -o jsonpath='{.metadata.ownerReferences[0].name}'
# Output: postgres (the StatefulSet name)
```

**Key Differences from Deployment:**

| Feature | Deployment | StatefulSet |
|---------|-----------|------------|
| Pod naming | Random (app-5d49c557fd-d75lt) | Ordinal (postgres-0, postgres-1) |
| Stable DNS | ❌ No | ✅ Yes |
| PVC binding | ❌ Shared PVC | ✅ Per-pod PVCs |
| Scaling | ⚡ Fast, any order | 📊 Sequential (0 → 1 → 2) |
| Use case | Stateless apps | Databases, caches, stateful apps |

**Why PostgreSQL Needs StatefulSet:**
1. **Stable identity** - Pod name never changes (postgres-0)
2. **Persistent storage** - Each pod gets own PVC
3. **Single-writer** - Only one postgres-0 runs at a time
4. **Data durability** - Crash recovery via PVC
5. **High availability** - Can add replicas in future (postgres-0, postgres-1, etc.)



### Common Communication Issues

| Issue | Symptom | Root Cause | Fix |
|-------|---------|-----------|-----|
| Pod not starting | ImagePullBackOff | Docker image not available | Check image repo, credentials |
| Init container timeout | Pod pending > 5min | postgres-0 not ready in time | Increase timeout or check postgres logs |
| Connection refused | App logs: "postgres refused" | postgres-0 service/pod down | Check postgres pod status, PVC binding |
| DNS not resolving | nslookup postgres fails | CoreDNS issue or wrong namespace | Check CoreDNS pod, verify namespace label |
| Database locked | Prisma migration fails | Another migration running or corrupted schema | Scale down app, run `prisma migrate resolve` |

## Complete Pod Communication Verification Checklist

Run through all 11 steps to verify end-to-end communication:

### Step 1: Verify Service Endpoints
```bash
kubectl get endpoints -n bug-report-portal-dev postgres
# Output: postgres   10.244.0.14:5432
```
✅ Service has endpoint pointing to postgres pod

### Step 2: Verify Pod Labels Match Service Selector
```bash
# Check service selector
kubectl get svc postgres -n bug-report-portal-dev -o jsonpath='{.spec.selector}'
# Output: {"app":"postgres"}

# Check pod labels
kubectl get pod postgres-0 -n bug-report-portal-dev -o jsonpath='{.metadata.labels}'
# Output: Should contain "app":"postgres"
```
✅ Service selector matches pod labels

### Step 3: Verify Database Tables Created
```bash
kubectl exec -n bug-report-portal-dev postgres-0 -- \
  psql -U postgres -d bugreportportal -c \
  "SELECT table_name FROM information_schema.tables WHERE table_schema='public' ORDER BY table_name;"
# Expected tables: ActivityLog, BugReport, Comment, _prisma_migrations
```
✅ All 4 tables created by Prisma migrations

### Step 4: Check Pod Health Status
```bash
kubectl get pods -n bug-report-portal-dev -o wide
# Both pods should show: STATUS=Running, READY=1/1
```
✅ postgres-0 and bug-report-portal-app both Running

### Step 5: Verify Liveness Probe Configuration
```bash
kubectl get pod postgres-0 -n bug-report-portal-dev -o jsonpath='{.spec.containers[0].livenessProbe}' | jq
# Output shows: command=["/bin/sh", "-c", "pg_isready -U postgres"]
# failureThreshold=3, periodSeconds=10, initialDelaySeconds=30
```
✅ Probes configured and running every 10 seconds

### Step 6: Test DNS Resolution
```bash
kubectl exec -n bug-report-portal-dev <app-pod> -- nslookup postgres
# Output: postgres.bug-report-portal-dev.svc.cluster.local → 10.244.0.14
```
✅ DNS resolves postgres to postgres-0 pod IP

### Step 7: Verify PVC Binding
```bash
kubectl get pvc -n bug-report-portal-dev
# postgres-storage-postgres-0 should show: STATUS=Bound, CAPACITY=10Gi
```
✅ 10Gi persistent storage bound and ready

### Step 8: Check Init Container Logs
```bash
# Check wait-for-postgres init container
kubectl logs -n bug-report-portal-dev <app-pod> -c wait-for-postgres
# Expected: "postgres:5432 - accepting connections"

# Check db-migrate init container
kubectl logs -n bug-report-portal-dev <app-pod> -c db-migrate
# Expected: "Migrations applied"
```
✅ Both init containers executed successfully

### Step 9: Verify App Connection String
```bash
kubectl exec -n bug-report-portal-dev <app-pod> -- env | grep DATABASE_URL
# Output: DATABASE_URL=postgresql://postgres:postgres@postgres:5432/bugreportportal
```
✅ App has correct connection string configured

### Step 10: Check Event Logs for Errors
```bash
kubectl get events -n bug-report-portal-dev --sort-by='.lastTimestamp'
# Should show mostly "Normal" events, no "Warning" for postgres/app pods
```
✅ No connection errors in event logs

### Step 11: Test Connection Latency
```bash
for i in {1..3}; do \
  kubectl exec -n bug-report-portal-dev postgres-0 -- psql -U postgres -c "SELECT NOW();" 2>/dev/null; \
done
# All queries should return timestamp in < 150ms
```
✅ Connection latency low (< 150ms in-cluster)

### Quick Status Summary
```bash
# One-liner to check everything
echo "StatefulSet:" && kubectl get statefulsets -n bug-report-portal-dev && \
echo "" && echo "Pods:" && kubectl get pods -n bug-report-portal-dev && \
echo "" && echo "Services:" && kubectl get svc -n bug-report-portal-dev && \
echo "" && echo "PVCs:" && kubectl get pvc -n bug-report-portal-dev
```

**All 11 checks passing = Healthy Pod Communication** ✅

## Best Practices

### For Major Architecture Changes
```bash
# Option 1: Clean namespace and redeploy (loses data)
kubectl delete namespace bug-report-portal-dev
kubectl apply -k .

# Option 2: Selective cleanup (preserves PVCs and data)
kubectl delete deployment,service --all -n bug-report-portal-dev
sleep 3
kubectl apply -k .
```

### For Testing New Features
Always use feature branches with `DEVOPS_BRANCH` parameter:
```
Jenkins Build with Parameters:
- DEVOPS_BRANCH: feature/postgres-statefulset
- DO_DEPLOY: true
```

This tests K8s changes before merging to master and avoids production issues.
