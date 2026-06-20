# Jenkins E2E Testing Guide - PostgreSQL StatefulSet

Complete end-to-end testing with Jenkins pipeline using PostgreSQL StatefulSet.

## One-Time Setup

### Step 1: Create Kind Cluster (ONE-TIME)

```bash
kind create cluster --name bug-report-portal --wait 2m
```

**This cluster persists and can be reused for multiple Jenkins runs.**

**Verify:**
```bash
kubectl cluster-info --context kind-bug-report-portal
kubectl get nodes
```

---

## For Each Jenkins Run

### Step 1: Stop & Start Docker Compose

```bash
cd /Users/demu/bug-report-portal-devops
docker compose down
docker compose up -d
sleep 60
docker compose ps
```

**Expected services:**
- Jenkins: port 8080 ✅
- SonarQube: port 9000 ✅
- PostgreSQL: port 5432 (for SonarQube) ✅

### Step 2: Get Jenkins Admin Password

```bash
docker compose exec -T jenkins cat /var/jenkins_home/secrets/initialAdminPassword
```

### Step 3: Access Jenkins

1. Open: http://localhost:8080/jenkins
2. Use password from Step 2
3. Complete setup wizard (skip plugins for now)

### Step 4: Create Jenkins Pipeline Job

1. **New Item** → Name: `bug-report-portal-test`
2. **Pipeline** project type
3. **Definition:** Pipeline script from SCM
4. **SCM:** Git
   - Repository URL: `https://github.com/ravi2342/bugreportportal-devops.git`
   - Credentials: (none for public repo)
   - Branch: `*/feature/postgres-statefulset`
   - Script Path: `Jenkinsfile`
5. **Save**

### Step 5: Run Pipeline with Parameters

1. **Build with Parameters**
2. Set parameters:
   ```
   BRANCH: feature/postgres-statefulset
   GITHUB_REPO_URL: https://github.com/ravi2342/bugreportportal.git
   DOCKER_IMAGE_PATH: demu147/bugreportportal
   DO_PUSH: ✓ (checked)
   DO_DEPLOY: ✓ (checked)
   RUN_SONAR: ✗ (unchecked - optional)
   TARGET_ENV: dev
   REGISTRY_CREDENTIALS_ID: dockerhub-creds-pat
   ```
3. **Build Now**

### Step 6: Monitor Pipeline

**Watch stages:**
```
Stage 1-5: Clean → Checkout → Setup → Quality Gates
Stage 6: SonarQube (skipped if RUN_SONAR=false)
Stage 7: Build Docker Image
Stage 8: Security Scan (Trivy)
Stage 9: Push to Docker Hub
Stage 10: Deploy to Kubernetes
Stage 11: Notify
```

**Typical time:** 3-5 minutes

### Step 7: Verify Deployment

**Check pods:**
```bash
kubectl get pods -n bug-report-portal-dev
```

**Expected output:**
```
NAME                                     READY   STATUS    RESTARTS   AGE
postgres-0                               1/1     Running   0          XXs
bug-report-portal-app-xxxxx              1/1     Running   0          XXs
```

**Verify StatefulSet:**
```bash
kubectl get statefulset -n bug-report-portal-dev
```

**Verify PVC (persistence):**
```bash
kubectl get pvc -n bug-report-portal-dev
```

### Step 8: Test Database

```bash
# Check tables created by Prisma
kubectl exec -it postgres-0 -n bug-report-portal-dev -- psql -U postgres -d bugreportportal -c "\dt"
```

**Expected tables:**
```
ActivityLog
BugReport
Comment
_prisma_migrations
```

### Step 9: Test App Connectivity

```bash
# Port-forward to app
kubectl port-forward -n bug-report-portal-dev svc/bug-report-portal-service 3000:3000 &

# Test app
curl http://localhost:3000/login

# Stop port-forward
pkill -f "kubectl port-forward"
```

## Troubleshooting

| Issue | Command to Debug |
|-------|------------------|
| Pod stuck in Init | `kubectl describe pod <pod-name> -n bug-report-portal-dev` |
| Image pull error | `kubectl logs <pod-name> -n bug-report-portal-dev` |
| Postgres not ready | `kubectl logs postgres-0 -n bug-report-portal-dev` |
| App connection error | `kubectl logs -n bug-report-portal-dev deployment/bug-report-portal-app -c db-migrate` |

## Verification Checklist

- [ ] Kind cluster created and ready (one-time)
- [ ] docker-compose services running (Jenkins, SonarQube)
- [ ] Jenkins pipeline completed successfully
- [ ] postgres-0 pod running (StatefulSet)
- [ ] bug-report-portal-app pod running
- [ ] PVC bound to postgres-0
- [ ] Database tables exist (ActivityLog, BugReport, Comment)
- [ ] App responds to curl request

## Running Multiple Times

**To run Jenkins pipeline again with same cluster:**

```bash
# Stop and restart docker-compose
docker compose down
docker compose up -d
sleep 60

# Run Jenkins job again (cluster already exists)
# Jenkins → Build with Parameters → Run
```

**No need to recreate the Kind cluster** - it persists across docker-compose restarts ✅

## Next Steps

After successful E2E test:

1. **Merge to master:**
   ```bash
   git checkout master
   git merge feature/postgres-statefulset
   git push origin master
   ```

2. **Move to AWS EKS:**
   - Update kubeconfig for EKS cluster
   - Run Jenkins job with same parameters
   - Same manifests work (kubectl apply -k k8s/)

## Cleanup

```bash
# Delete Kind cluster (only when done testing)
kind delete cluster --name bug-report-portal

# Stop docker-compose
docker compose down -v

# Kill port-forwards
pkill -f "kubectl port-forward"
```
