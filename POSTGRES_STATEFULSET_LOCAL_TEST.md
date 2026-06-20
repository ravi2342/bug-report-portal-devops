# PostgreSQL StatefulSet Local Testing (Kind)

## Overview
- **Jenkins & SonarQube**: Run in docker-compose (local CI infrastructure)
- **Bug Report Portal App**: Deployed to Kind Kubernetes cluster
- **PostgreSQL**: StatefulSet in K8s (replaces docker-compose postgres)

This is the same architecture that will run on AWS EKS.

---

## Prerequisites
```bash
brew install kubectl kind docker
```

## Step 1: Start Local CI Infrastructure

```bash
cd /Users/demu/bug-report-portal-devops

# Start Jenkins and SonarQube (NOT postgres anymore)
docker compose up -d

# Wait for services
sleep 60
docker compose ps
```

**Expected output:**
```
jenkins    Running  8080 (CI/CD)
sonarqube  Running  9000 (Code Quality)
postgres   Running  5432 (SonarQube DB only)
```

## Step 2: Create Kind Cluster

```bash
# Create Kind cluster
kind create cluster --name bug-report-portal --config - <<EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: bug-report-portal
nodes:
  - role: control-plane
    image: kindest/node:v1.28.0
EOF

# Verify cluster
kubectl cluster-info
kubectl get nodes
```

## Step 3: Deploy App + PostgreSQL StatefulSet to Kind

```bash
# Apply all K8s manifests (includes postgres statefulset)
kubectl apply -k k8s/

# Wait for deployment
kubectl rollout status deployment/bug-report-portal-app -n bug-report-portal-dev

# Verify pods
kubectl get pods -n bug-report-portal-dev
```

**Expected output:**
```
NAME                                      READY   STATUS
postgres-0                                1/1     Running
bug-report-portal-app-xxxxx               1/1     Running
```

## Step 4: Verify PostgreSQL StatefulSet

```bash
# Check statefulset
kubectl get statefulset -n bug-report-portal-dev
kubectl describe statefulset postgres -n bug-report-portal-dev

# Check persistent volume claim
kubectl get pvc -n bug-report-portal-dev
kubectl describe pvc postgres-storage-postgres-0 -n bug-report-portal-dev

# Check postgres service
kubectl get svc postgres -n bug-report-portal-dev -o wide
```

## Step 5: Test Database Connection

```bash
# Port-forward to postgres
kubectl port-forward -n bug-report-portal-dev svc/postgres 5432:5432 &

# Connect to database (password: postgres)
psql -h localhost -U postgres -d bugreportportal

# Inside psql:
\dt                    # List tables
\q                     # Quit
```

**Expected tables (created by Prisma):**
```
BugReport
Comment  
ActivityLog
```

## Step 6: Test App Connectivity

```bash
# Port-forward to app
kubectl port-forward -n bug-report-portal-dev svc/bug-report-portal-service 3000:3000 &

# Test app
curl http://localhost:3000/login

# Expected: HTML login page (not 404 or connection error)
```

## Step 7: Run Jenkins Pipeline

1. Go to Jenkins: http://localhost:8080/jenkins
2. Create new Pipeline job or use existing
3. Configure to use this repository
4. Run build with parameters:
   - BRANCH: master
   - DOCKER_IMAGE_PATH: bugreportportal
   - DO_PUSH: true (if using Docker Hub)
   - DO_DEPLOY: true

**Pipeline stages:**
1. Clean → Checkout → Setup → Quality Gates → SonarQube
2. Build Docker Image
3. Security Scan (Trivy)
4. Push to Docker Hub
5. Deploy to Kind → Verify deployment

## Step 8: Verify Deployment

```bash
# Check if new image was pulled
kubectl get pods -n bug-report-portal-dev -o wide

# Check logs
kubectl logs -n bug-report-portal-dev deployment/bug-report-portal-app -f

# Expected: App listening on port 3000, connected to postgres
```

## Troubleshooting

### Postgres pod stuck in CrashLoopBackOff
```bash
kubectl logs -n bug-report-portal-dev postgres-0
kubectl describe pod postgres-0 -n bug-report-portal-dev
```

**Common issues:**
- PVC not bound: Check storage class availability
- Permission denied: Delete PVC and let StatefulSet recreate

### App can't connect to postgres
```bash
# Test from app pod
kubectl exec -it -n bug-report-portal-dev deployment/bug-report-portal-app -- bash
psql -h postgres -U postgres -d bugreportportal
```

### Prisma migrations failing
```bash
kubectl logs -n bug-report-portal-dev deployment/bug-report-portal-app -c db-migrate
```

**Common issues:**
- Database already exists but schema mismatch
- Missing migrations
- Postgres not ready (wait-for-postgres failed silently)

---

## Clean Up

```bash
# Delete Kind cluster
kind delete cluster --name bug-report-portal

# Stop docker-compose
docker compose down -v

# Kill port-forwards
pkill -f "kubectl port-forward"
```

---

## Next Steps

Once testing passes locally in Kind:
1. Push code to GitHub
2. Setup Terraform for AWS (EKS, ECR, EC2 Jenkins)
3. Deploy same manifests to EKS production cluster
4. Test end-to-end in AWS
