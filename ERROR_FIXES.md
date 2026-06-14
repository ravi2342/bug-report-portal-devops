# Error Fixes - Quick Reference

## Issue #1: Jenkins Container Cannot Reach Kubernetes Cluster

**Error:** `error: unable to connect to the server: dial tcp 127.0.0.1:65148: connect refused`

**Root Cause:** Jenkins runs in a Docker container; `127.0.0.1` refers to container's own localhost, not the host machine where Kind cluster runs.

**Solution:** Replace `127.0.0.1` with `host.docker.internal` in kubeconfig
```bash
KUBE_SERVER=$(kubectl config view -o jsonpath='{.clusters[?(@.name=="kind-bug-report-portal")].cluster.server}')
KUBE_SERVER=$(echo "$KUBE_SERVER" | sed 's|127.0.0.1|host.docker.internal|g')
kubectl config set-cluster kind-bug-report-portal --server="$KUBE_SERVER"
```

**Status:** ✅ Fixed (Jenkinsfile handles this automatically)

---

## Issue #2: Shell Syntax Error - Bash vs POSIX sh

**Error:** `[[ -z ]]: not found`

**Root Cause:** Jenkinsfile used bash-specific syntax `[[ ]]`, but Jenkins default shell is POSIX `sh`.

**Solution:** Use POSIX-compatible syntax
```bash
# Before (bash-only):
if [[ -z "$KUBE_SERVER" ]]; then

# After (POSIX):
if [ -z "$KUBE_SERVER" ]; then
```

**Status:** ✅ Fixed

---

## Issue #3: Environment Variable Syntax Error

**Error:** `Environment variable values must either be single quoted, double quoted, or function calls`

**Root Cause:** Declarative pipeline's `environment` block cannot use `params` references or complex expressions.

**Solution:** Move IMAGE_TAG computation to script block
```groovy
stage('Checkout DevOps') {
  steps {
    script {
      // Compute at runtime, not compile-time
      def dockerImagePath = params.DOCKER_IMAGE_PATH ?: 'demu147/bugreportportal'
      def appVersion = sh(script: "...", returnStdout: true).trim()
      env.IMAGE_TAG = "docker.io/${dockerImagePath}:${appVersion}-${BUILD_NUMBER}"
    }
  }
}
```

**Status:** ✅ Fixed (Build #60+)

---

## Issue #4: Kubernetes Deployment Image Mismatch

**Error:** `Kustomize unable to find image to patch`

**Root Cause:** Jenkinsfile passed `deploymentName: 'bug-report-portal-app'` (K8s resource name), but kustomize needs the Docker image name `'bugreportportal'`.

**Solution:** Use correct image name
```groovy
k8sDeploy(
  imageTag: "${env.IMAGE_TAG}",
  deploymentName: 'bugreportportal',  # ← Docker image name, not K8s resource name
  ...
)
```

**Mapping:**
- kustomization.yaml: `images.name = 'bugreportportal'` ✓
- app-deployment.yaml: `container.image = 'bugreportportal'` ✓
- Jenkinsfile parameter: `deploymentName = 'bugreportportal'` ✓

**Status:** ✅ Fixed (Commit 97665f8)

---

## Issue #5: SonarCloud Scanning 0 Files

**Error:** `SonarQube analysis shows 0 files indexed`

**Root Cause:** Misconfigured paths in sonar-project.properties and missing `-Dsonar.projectBaseDir` parameter.

**Solution:** Fix configuration
```properties
# sonar-project.properties
sonar.sources=app
sonar.organization=ravi2342
sonar.projectBaseDir=..
```

```groovy
# Jenkinsfile
sonarScan(
  hostUrl: params.SONAR_HOST_URL,
  projectKey: params.SONAR_PROJECT_KEY,
  tokenCredId: params.SONAR_TOKEN_CREDENTIALS_ID,
  waitForQualityGate: true
)
```

**Status:** ✅ Fixed (69 files indexed)

---

## Issue #6: Postgres only has `_prisma_migrations` table — schema never applied

**Error (from app pod logs):**
```
❌ [Dashboard] Prisma error: The table `public.BugReport` does not exist in the
   current database.
```

**Symptom in cluster:**
```bash
kubectl -n bug-report-portal-dev exec deploy/postgres -- \
  psql -U postgres -d bugreportportal -c "\dt"
# Only _prisma_migrations is listed; BugReport / Comment / ActivityLog missing
```

**Root Cause (two bugs stacked):**

1. The `init-database` init container in `k8s/app-deployment.yaml` ran:
   ```bash
   npx prisma db push --skip-generate --accept-data-loss
   ```
   `--skip-generate` is **not** a valid flag for `prisma db push` (it only
   applies to `prisma migrate dev`). The Prisma CLI exits non-zero, but the
   surrounding shell echo (`echo "✅ Database schema initialized"`) runs anyway
   and the initContainer reports success. Only the `_prisma_migrations`
   bookkeeping table is created — from the Prisma engine's connect-time
   handshake — before the CLI bails out.

2. Even if the flag had been valid, `prisma db push` is a dev-only shortcut
   that syncs the schema without recording any migration history. That breaks
   forward compatibility with `prisma migrate deploy` in the main container.

3. (Companion bug in the app repo) `.dockerignore` excluded `prisma/migrations`,
   so the main container's `npx prisma migrate deploy` printed
   `No migration found in prisma/migrations` and applied nothing. See
   [bugreportportal/docs/PRISMA_MIGRATIONS_DOCKERIGNORE.md](https://github.com/ravi2342/bugreportportal/blob/master/docs/PRISMA_MIGRATIONS_DOCKERIGNORE.md).

**Solution:** Replace the broken init container with one that uses the correct,
production-grade Prisma command. In `k8s/app-deployment.yaml`:

```yaml
- name: db-migrate
  image: bugreportportal
  imagePullPolicy: Always
  command:
    - sh
    - -c
    - |
      cd /app
      echo "🔄 Applying Prisma migrations..."
      npx prisma migrate deploy
      echo "✅ Migrations applied"
  envFrom:
    - configMapRef:
        name: bug-report-portal-config
    - secretRef:
        name: bug-report-portal-secrets
```

Why `prisma migrate deploy`:
- Uses the `_prisma_migrations` history table — idempotent across pod restarts
- Production-recommended by Prisma docs (vs. `db push` which is dev-only)
- Pairs with migration files now included in the image (companion fix)

**One-time DB baseline (only needed if your DB was created by the broken
`db push` path before this fix):**

```bash
POD=$(kubectl -n bug-report-portal-dev get pod -l app=bug-report-portal-app -o jsonpath='{.items[0].metadata.name}')
kubectl -n bug-report-portal-dev exec "$POD" -c app -- sh -c '
  cd /app
  for m in $(ls prisma/migrations | grep -v migration_lock); do
    npx prisma migrate resolve --applied "$m"
  done
'
```

This tells Prisma "the schema is already at HEAD; don't re-apply these"
without dropping any data. Future `migrate deploy` runs become no-ops.

**Status:** ✅ Fixed (commit `9d5eb9d` — init container replaced)

---

## Issue #7: Uploaded screenshots disappear after every deploy

**Symptom:** Create an incident with a screenshot. UI shows the image. Trigger
another Jenkins build (or `kubectl delete pod ...`). Open the same incident —
the DB row is still there but the `<img>` is a broken link, and
`/app/uploads/` is empty in the new pod.

**Root Cause:** `k8s/app-deployment.yaml` mounted `/app/uploads/` from an
`emptyDir` volume:

```yaml
volumes:
  - name: uploads
    emptyDir: {}   # lives only as long as the pod
```

`emptyDir` is bound to the **pod lifecycle**, not the node. Any pod replacement
(rolling update, eviction, `kubectl delete pod`) wipes the directory. The
Postgres rows survive (they live in `postgres-pvc`), so the DB ends up
referencing filenames that no longer exist on disk.

**Solution:** Back `/app/uploads/` with a dedicated PVC so files persist across
all pod restarts and image rollouts. New manifest `k8s/uploads-pvc.yaml`:

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: uploads-pvc
  namespace: bug-report-portal-dev
spec:
  accessModes: [ReadWriteOnce]
  resources:
    requests:
      storage: 1Gi
```

And in `k8s/app-deployment.yaml`:

```yaml
volumes:
  - name: uploads
    persistentVolumeClaim:
      claimName: uploads-pvc
```

Also added to `k8s/kustomization.yaml` so `kubectl apply -k k8s/` provisions it
automatically.

**One-time cost:** The first deploy after this change starts with an empty PVC,
so any screenshots that were previously stored in the old `emptyDir` are gone.
This is a single-occurrence transition. All future uploads persist forever.

**Scaling caveat:** `ReadWriteOnce` only supports **one pod** at a time. If you
ever scale to `replicas: 2+`, switch to `ReadWriteMany` (NFS / cloud file
share) or move uploads to object storage (S3 / MinIO).

**Demo reset:** See the new "Reset Demo Data (Clean Slate)" section in
[QUICK_REFERENCE.md](QUICK_REFERENCE.md) for the one-liner that truncates the
DB and clears the uploads PVC for a fresh demo.

**Status:** ✅ Fixed (uploads PVC + manifest updates)

---

## Verification Checklist

- [x] Build completes without syntax errors
- [x] kubectl connectivity from Jenkins container
- [x] IMAGE_TAG computed correctly at runtime
- [x] Kustomize image patching succeeds
- [x] SonarQube analysis scans app code
- [x] Docker image builds with correct tag
- [x] Kubernetes deployment receives correct image
- [x] No hardcoded Docker Hub usernames
- [x] All parameters come from Jenkins job configuration
