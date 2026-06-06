# Testing Guide: Bug Report Portal CI/CD Pipeline

## Prerequisites
- Docker Desktop installed
- Minikube installed
- kubectl configured
- Jenkins running via docker-compose
- Git configured with GitHub credentials

---

## Part 1: Local Kubernetes Setup (Minikube)

### 1.1 Start Minikube
```bash
minikube start --driver=docker
```

**Verify:**
```bash
kubectl cluster-info
kubectl get nodes
```

Expected output:
```
Kubernetes control plane is running at https://127.0.0.1:xxxxx
NAME       STATUS   ROLES           AGE   VERSION
minikube   Ready    control-plane   Xs    v1.33.1
```

### 1.2 Create Kubernetes Namespace
```bash
kubectl create namespace bug-report-portal
kubectl get namespaces
```

Expected output:
```
NAME                STATUS   AGE
bug-report-portal   Active   Xs
default             Active   Xs
...
```

---

## Part 2: Jenkins Pipeline Configuration

### 2.1 Configure Kubeconfig for Jenkins

Jenkins runs in Docker and needs access to Minikube cluster.

**Option A: Copy kubeconfig to Jenkins container**
```bash
# Copy minikube kubeconfig to Jenkins
docker cp ~/.kube/config jenkins:/var/jenkins_home/.kube/config

# Verify in Jenkins
docker exec jenkins cat /var/jenkins_home/.kube/config
```

**Option B: Configure Jenkins credentials**
1. Go to **Jenkins UI** → Manage Jenkins → Manage Credentials
2. Add credentials for Kubernetes API (if custom auth needed)
3. For Minikube, local kubeconfig usually works out of the box

### 2.2 Verify Jenkins Can Access Kubernetes
```bash
# SSH into Jenkins container
docker exec -it jenkins bash

# Test kubectl connection
kubectl cluster-info
kubectl get namespaces
```

Expected: Should see bug-report-portal namespace

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
| `DO_DEPLOY` | `true` | Deploy to Kubernetes cluster |
| `RUN_SONAR` | `true` | Run SonarQube code analysis |

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

### 7.2 Stop Minikube
```bash
minikube stop
```

### 7.3 Stop Jenkins (Optional)
```bash
docker-compose down
```

---

## Troubleshooting

### Issue: kubectl cannot connect to Kubernetes
**Solution:**
```bash
# Set kubeconfig path
export KUBECONFIG=$HOME/.kube/config

# Or specify in command
kubectl --kubeconfig=$HOME/.kube/config get namespaces
```

### Issue: Image not pulling from Docker Hub
**Solution:**
```bash
# Create image pull secret (if repo is private)
kubectl create secret docker-registry dockerhub-secret \
  --docker-server=docker.io \
  --docker-username=demu147 \
  --docker-password=<your-token> \
  --docker-email=your@email.com \
  -n bug-report-portal
```

Then update `app-deployment.yaml` to reference it:
```yaml
spec:
  imagePullSecrets:
    - name: dockerhub-secret
```

### Issue: Jenkins cannot access Minikube from Docker container
**Solution:**
```bash
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
