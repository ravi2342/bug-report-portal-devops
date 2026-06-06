# Testing Guide: Bug Report Portal CI/CD Pipeline with Kind

## Prerequisites

### Required Tools
Before starting, ensure you have both **Kind AND kubectl** installed:

**Kind** - Creates Kubernetes clusters
```bash
brew install kind
kind version
# Output: kind v0.32.0 go1.23.2 darwin/arm64
```

**kubectl** - Interacts with Kubernetes clusters (REQUIRED by Kind)
```bash
brew install kubectl
kubectl version --client
# Output: Client Version: v1.33.1
```

**Why both are needed:**
- Kind creates the cluster (server)
- kubectl communicates with the cluster (client)
- Without kubectl, you cannot deploy or manage applications

### Other Prerequisites
- Docker Desktop installed
- Jenkins running via docker-compose
- Git configured with GitHub credentials

---

## Part 1: Local Kubernetes Setup (Kind)

### 1.1 Create Kind Cluster
```bash
kind create cluster --name bug-report-portal --wait 2m
```

**Verify:**
```bash
kubectl cluster-info
kubectl get nodes
```

Expected output:
```
Kubernetes control plane is running at https://127.0.0.1:xxxxx
NAME                              STATUS   ROLES           AGE   VERSION
bug-report-portal-control-plane   Ready    control-plane   Xs    v1.36.1
```

### 1.2 Create Kubernetes Resources (Automatic)
```bash
# Kustomize automatically creates the namespace + all resources
kubectl apply -k k8s/
```

**What gets created automatically:**
- Namespace: `bug-report-portal`
- ConfigMap, Secret, PVC
- PostgreSQL deployment + service
- App deployment + service + ingress

**No manual namespace creation needed** ✅ (unlike Minikube)

**Verify:**
```bash
kubectl get namespaces
kubectl get all -n bug-report-portal
```

Expected output:
```
NAME                 STATUS   AGE
bug-report-portal    Active   Xs
default              Active   Xs
...
```

---

## Part 2: Jenkins Pipeline Configuration

### 2.1 Understand & Configure Kubeconfig

**What is Kubeconfig?**
- Configuration file (`~/.kube/config`) that tells kubectl how to connect to Kubernetes
- Contains cluster address, certificates, and user info
- Kind creates it automatically when cluster is created

**Problem:** Kind cluster uses `127.0.0.1` (localhost), but Jenkins runs in Docker container:
```
127.0.0.1 on host machine ≠ 127.0.0.1 inside Docker container (different network!)
```

**Solution:** Modify kubeconfig to use `host.docker.internal` instead:

```bash
# Step 1: Check current kubeconfig
cat ~/.kube/config | grep "server:"
# Output: server: https://127.0.0.1:65148  ← Problem!

# Step 2: Modify to use host.docker.internal
kubectl config view --raw | sed 's/127\.0\.0\.1/host.docker.internal/g' > ~/.kube/config

# Step 3: Verify change
cat ~/.kube/config | grep "server:"
# Output: server: https://host.docker.internal:65148  ← Fixed!
```

**Why docker-compose.yml mounts kubeconfig:**
```yaml
jenkins:
  volumes:
    - ~/.kube:/root/.kube:ro        # Mount modified kubeconfig
  environment:
    KUBECONFIG: /root/.kube/config  # Tell Jenkins where to find it
```

Now Jenkins container can:
1. Read the modified kubeconfig file
2. Find `host.docker.internal:65148` (the Kind cluster)
3. Connect successfully! ✅

**Verify from Jenkins:**
```bash
# Modify server address for Jenkins container access
kubectl config view --raw | sed 's/127\.0\.0\.1/host.docker.internal/g' > ~/.kube/config
```

### 2.2 Verify Jenkins Can Access Kind
```bash
# Test from Jenkins container
docker exec jenkins kubectl --insecure-skip-tls-verify cluster-info

# Should output:
# Kubernetes control plane is running at https://host.docker.internal:xxxxx
```

---

## Part 3: Trigger Jenkins Build

### 3.1 Access Jenkins Dashboard
```
http://localhost:8080/jenkins
```

### 3.2 Run Pipeline with Full CI/CD

Click **"Build with Parameters"** and set:

| Parameter | Value | Purpose |
|-----------|-------|---------|
| `DO_PUSH` | `true` | Push Docker image to Docker Hub |
| `DO_DEPLOY` | `true` | Deploy to Kind cluster |
| `RUN_SONAR` | `false` | Skip SonarQube (optional, may timeout) |

![Build Parameters](./docs/build-params.png)

### 3.3 Monitor Build Progress

Watch the build stages:
1. ✅ **Clean Workspace** 
2. ✅ **Checkout** - Clone from GitHub
3. ✅ **Build Metadata** - Generate version info
4. ✅ **Install Dependencies** - npm install
5. ✅ **Lint** - Code quality check
6. ✅ **Run Tests** - Unit tests
7. ✅ **SonarQube Scan** - Code analysis
8. ✅ **Build Docker Image** - Create container image
9. ✅ **Trivy Security Scan** - Vulnerability scan
10. ✅ **Push Image to Registry** - Upload to Docker Hub
11. ✅ **Deploy to Kubernetes** - Apply k8s manifests + set image + rollout
12. ✅ **Health Check** - Verify deployment health
13. ✅ **Cleanup & Report** - Final cleanup

---

## Part 4: Verify Kubernetes Deployment

### 4.1 Check Deployment Status
```bash
kubectl get deployments -n bug-report-portal
kubectl get pods -n bug-report-portal
```

Expected output:
```
NAME                        READY   UP-TO-DATE   AVAILABLE   AGE
bug-report-portal-app       1/1     1            1           Xs
postgres                    1/1     1            1           Xs

NAME                                    READY   STATUS    RESTARTS   AGE
bug-report-portal-app-xxxxx              1/1     Running   0          Xs
postgres-xxxxx                           1/1     Running   0          Xs
```

### 4.2 View Pod Logs
```bash
# Application logs
kubectl logs -n bug-report-portal -l app=bug-report-portal-app

# PostgreSQL logs
kubectl logs -n bug-report-portal -l app=postgres
```

### 4.3 Verify Image Version
```bash
kubectl get deployment -n bug-report-portal bug-report-portal-app -o yaml | grep image:
```

Expected: Should show Docker Hub image with specific build tag
```yaml
image: demu147/bugreportportal:1.0.0-11
```

---

## Part 5: Access the Application

### 5.1 Port Forward to Application
```bash
kubectl port-forward -n bug-report-portal svc/bug-report-portal-app 3000:3000
```

### 5.2 Access Web Interface
```
http://localhost:3000
```

### 5.3 Check Database Connection
```bash
# Port forward PostgreSQL
kubectl port-forward -n bug-report-portal svc/postgres 5432:5432

# Connect from local machine
psql -h localhost -U postgres -d bugreportportal
```

---

## Part 6: Verify Docker Hub Image

### 6.1 Check Image on Docker Hub
```bash
# List your images
docker pull demu147/bugreportportal:1.0.0-11

# Verify image exists
docker images | grep demu147/bugreportportal
```

Visit: https://hub.docker.com/r/demu147/bugreportportal

---

## Part 7: Clean Up

### 7.1 Delete Kubernetes Deployment
```bash
kubectl delete namespace bug-report-portal
```

### 7.2 Delete Kind Cluster
```bash
kind delete cluster --name bug-report-portal
```

### 7.3 Stop Jenkins (Optional)
```bash
docker-compose down
```

---

## Troubleshooting

### Issue: `kubectl cluster-info` fails from Jenkins container
**Error:** "tls: failed to verify certificate: x509: certificate is valid for..."
**Cause:** Kind certificates don't include `host.docker.internal` in SAN
**Solution:**
```bash
# Jenkins Jenkinsfile Deploy stage uses this flag:
kubectl --insecure-skip-tls-verify cluster-info
# This is acceptable for development/local testing
```

### Issue: Pod ImagePullBackOff
**Error:** Cannot pull image from Docker Hub
**Solution:**
```bash
# Verify image was pushed
docker pull demu147/bugreportportal:1.0.0-XX

# Check image pull status
kubectl describe pod -n bug-report-portal <POD_NAME>

# If private repo, create docker-registry secret:
kubectl create secret docker-registry dockerhub-secret \
  --docker-server=docker.io \
  --docker-username=demu147 \
  --docker-password=<your-token> \
  --docker-email=your@email.com \
  -n bug-report-portal
```

### Issue: Jenkins cannot access Kind cluster
**Error:** "couldn't get current server API group list"
**Cause:** Kubeconfig server address not set to `host.docker.internal`
**Solution:**
```bash
# Update kubeconfig in docker-compose.yml volumes:
volumes:
  - ~/.kube:/root/.kube:ro

# Update server address in ~/.kube/config:
kubectl config set-cluster kind-bug-report-portal --server=https://host.docker.internal:PORT

# Verify from Jenkins:
docker exec jenkins kubectl --insecure-skip-tls-verify cluster-info
```

### Issue: Pod stuck in Init state
**Error:** Application pod waiting for postgres
**Solution:**
```bash
# Check init container logs
kubectl logs -n bug-report-portal <POD_NAME> -c <INIT_CONTAINER_NAME>

# Verify postgres is running
kubectl get pods -n bug-report-portal | grep postgres

# Wait for postgres
kubectl wait --for=condition=Ready pod -l app=postgres -n bug-report-portal --timeout=300s
```

### Issue: SonarQube scan timeout (optional)
**Cause:** JavaScript analysis can take 10+ minutes on first run
**Solution:**
```bash
# Build with RUN_SONAR=false to skip:
# Jenkins → Build with Parameters → RUN_SONAR=false → Build
```

### Issue: Want to return to Minikube later?
**Note:** Minikube is no longer configured. If needed:
```bash
# Install Minikube
brew install minikube

# Start cluster
minikube start --driver=docker

# However, Jenkins cannot access Minikube from Docker Compose
# (network isolation issue - use Kind instead)
```
# Check Jenkins kubeconfig location
docker exec jenkins cat /var/jenkins_home/.kube/config

# If missing, copy from host
docker cp ~/.kube/config jenkins:/var/jenkins_home/.kube/config

# Verify connectivity
docker exec jenkins kubectl cluster-info
```

### Issue: Deployment stuck in pending
**Solution:**
```bash
# Check pod events
kubectl describe pod <pod-name> -n bug-report-portal

# Check node resources
kubectl describe nodes

# Check image pull status
kubectl get events -n bug-report-portal
```

---

## Quick Reference Commands

```bash
# Start full stack
minikube start --driver=docker
docker-compose up -d
kubectl create namespace bug-report-portal

# Monitor build
kubectl get pods -n bug-report-portal -w

# View logs
kubectl logs -f -n bug-report-portal -l app=bug-report-portal-app

# Port forward
kubectl port-forward -n bug-report-portal svc/bug-report-portal-app 3000:3000

# Stop everything
kubectl delete namespace bug-report-portal
minikube stop
docker-compose down
```

---

## Expected Pipeline Output

### Successful Build Summary
```
╔════════════════════════════════════════╗
║   PIPELINE EXECUTION SUMMARY           ║
╠════════════════════════════════════════╣
║ Status:           SUCCESS              ║
║ Build #:          11                   ║
║ Duration:         ~2-3 minutes         ║
║ Image Tag:        demu147/bugreportportal:1.0.0-11
║ Docker Push:      ✓ Success            ║
║ Kubernetes Deploy:✓ Success            ║
║ Rollout Status:   ✓ Ready              ║
╚════════════════════════════════════════╝
```

---

## Next Steps

1. ✅ Minikube running
2. ✅ Namespace created
3. → **Trigger Jenkins build with DO_DEPLOY=true**
4. → Verify pods are running
5. → Test application via port-forward
6. → Check Docker Hub image
7. → Review k8s manifests applied

For more details, see:
- [Jenkinsfile](./Jenkinsfile)
- [k8s/app-deployment.yaml](./k8s/app-deployment.yaml)
- [k8s/kustomization.yaml](./k8s/kustomization.yaml)
