# Testing Guide: Bug Report Portal CI/CD Pipeline with Kind

---

## ✅ **Quick Start**

**Prerequisites:** Complete [KIND_SETUP.md](KIND_SETUP.md) first!

This guide assumes:
- ✅ Kind cluster created and running
- ✅ Kubernetes resources deployed (`kubectl apply -k k8s/`)
- ✅ Docker Desktop & Jenkins running
- ✅ Kubeconfig modified for Jenkins access

**Then proceed with:** Jenkins build trigger (Part 1) → Verify deployment (Part 2)

---

## 📚 **Documentation Quick Reference**

| Need Help With | See This Guide |
|----------------|----------------|
| **First time setup** (all OS) | [LOCAL_TESTING_COMPLETE_GUIDE.md](LOCAL_TESTING_COMPLETE_GUIDE.md) |
| **Kind cluster setup** | [KIND_SETUP.md](KIND_SETUP.md) |
| **Understanding test layers** | [COMPLETE_TESTING.md](COMPLETE_TESTING.md) |
| **End-to-end pipeline explained** | [E2E_DEPLOYMENT.md](E2E_DEPLOYMENT.md) |
| **Quick commands reference** | [QUICK_REFERENCE.md](QUICK_REFERENCE.md) |
| **Troubleshooting errors** | [ERROR_FIXES.md](ERROR_FIXES.md) |

---

## Prerequisites: Complete KIND_SETUP.md First ✅

Before using this guide, ensure you have completed [KIND_SETUP.md](KIND_SETUP.md) which covers:

✅ Install Kind & kubectl  
✅ Create Kubernetes cluster  
✅ Deploy resources via Kustomize  
✅ Modify kubeconfig for Jenkins  
✅ Verify Jenkins can access cluster  

**If not completed yet:**
👉 Follow [KIND_SETUP.md](KIND_SETUP.md) first (~30 minutes)

Then return here to:
1. Trigger a build with Jenkins
2. Verify deployment
3. Access the application

---

## Part 1: Trigger Jenkins Build

### 1.1 Access Jenkins Dashboard
```
http://localhost:8080/jenkins
```

### 1.2 Run Pipeline with Full CI/CD

Click **"Build with Parameters"** and set:

| Parameter | Value | Purpose |
|-----------|-------|----------|
| `DO_PUSH` | `true` | Push Docker image to Docker Hub |
| `DO_DEPLOY` | `true` | Deploy to Kind cluster |
| `RUN_SONAR` | `false` | Skip SonarQube (optional, may timeout) |

### 1.3 Monitor Build Progress

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

## Part 2: Verify Kubernetes Deployment

### 2.1 Check Deployment Status
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

### 2.2 View Pod Logs
```bash
# Application logs
kubectl logs -n bug-report-portal -l app=bug-report-portal-app

# PostgreSQL logs
kubectl logs -n bug-report-portal -l app=postgres
```

### 2.3 Verify Image Version
```bash
kubectl get deployment -n bug-report-portal bug-report-portal-app -o yaml | grep image:
```

Expected: Should show Docker Hub image with specific build tag
```yaml
image: demu147/bugreportportal:1.0.0-11
```

---

## Part 3: Access the Application

### 3.1 Port Forward to Application (Run on Host Machine)

Run this command on your **macOS terminal** (NOT in Jenkins):

```bash
kubectl port-forward -n bug-report-portal svc/bug-report-portal-service 8888:3000 \
  --insecure-skip-tls-verify
```

**Why on host machine?**
- Port-forwards created inside containers are invisible to the host
- Your browser runs on macOS, not inside a container
- This is standard Kubernetes practice

### 3.2 Access the Application

Open your browser:
```
http://localhost:8888
```

**Login credentials:**
- Username: `admin`
- Password: `admin`

### 3.3 Verify Database Connection
```bash
# Check PostgreSQL connectivity from app pod
kubectl exec -n bug-report-portal -it <APP_POD_NAME> -- sh

# Inside pod, test database
echo "SELECT 1;" | psql -h postgres.bug-report-portal.svc.cluster.local -U postgres
```

---

## 🔧 Troubleshooting & Next Steps

**Having issues?** See the guides below:

| Problem | Reference |
|---------|-----------|
| Build fails in Jenkins | [ERROR_FIXES.md](ERROR_FIXES.md) |
| Deployment not ready | [QUICK_REFERENCE.md](QUICK_REFERENCE.md) |
| Want to understand all stages | [E2E_DEPLOYMENT.md](E2E_DEPLOYMENT.md) |
| Testing the application | [COMPLETE_TESTING.md](COMPLETE_TESTING.md) |

---

## Quick Reference Commands

```bash
# Monitor deployment
kubectl get pods -n bug-report-portal -w

# View application logs
kubectl logs -f -n bug-report-portal -l app=bug-report-portal-app

# View database logs
kubectl logs -f -n bug-report-portal -l app=postgres

# Describe pod for debugging
kubectl describe pod <POD_NAME> -n bug-report-portal

# Port forward database (if needed)
kubectl port-forward -n bug-report-portal svc/postgres 5432:5432 \
  --insecure-skip-tls-verify
```

---

## Cleanup (Optional)

```bash
# Delete application namespace (keeps cluster)
kubectl delete namespace bug-report-portal

# Delete Kind cluster entirely
kind delete cluster --name bug-report-portal

# Stop Jenkins and Docker Compose
docker-compose down
```

## 🆘 Full Error Reference

For detailed explanations of common issues and their solutions, see: **[ERROR_FIXES.md](ERROR_FIXES.md)**

This document covers:
- ❌ Build #28 connectivity failures (container DNS resolution)
- ❌ Shell syntax incompatibility (bash vs POSIX)
- ❌ Kubeconfig modification side effects
- ❌ Port-forward TLS certificate validation
- ❌ Application not accessible from browser

---

## 📚 See Also

For other questions, refer to:
