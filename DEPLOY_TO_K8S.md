# Kubernetes Deployment to Kind Cluster - Manual Guide

## ⚠️ When to Use This Guide

**Use this guide ONLY if:**
- ❌ Jenkins pipeline deployment fails (DO_DEPLOY=true didn't work)
- ✅ You want to deploy manually without Jenkins
- ✅ You need to troubleshoot deployment outside of pipeline

**Otherwise, use:**
- 👉 **[TESTING.md](TESTING.md)** - Automated deployment via Jenkins (Recommended)
- 👉 **[E2E_DEPLOYMENT.md](E2E_DEPLOYMENT.md)** - Complete pipeline walkthrough
- 👉 **[NAMESPACE_AND_DEPLOYMENT.md](NAMESPACE_AND_DEPLOYMENT.md)** - Namespace and environment configuration

---

## Overview

This guide provides **manual Kubernetes deployment** as a fallback when automated Jenkins deployment is not available or needed.

**Recommended:** Use Jenkins pipeline with `DO_DEPLOY=true` for automated deployment.

**Fallback:** Use this guide for manual deployment if Jenkins pipeline deployment fails.

---

## Prerequisites

### Kubeconfig (Important!)
**Kubeconfig** (`~/.kube/config`) is the configuration file that tells `kubectl` how to connect to your Kind cluster.

**Verify it's set up correctly:**
```bash
# Check if kubeconfig exists
cat ~/.kube/config | grep "server:"

# Should show: server: https://127.0.0.1:xxxxx (on host machine)
# NOT: host.docker.internal (that's only for Jenkins container)
```

**For host machine manual deployment:**
- Use default kubeconfig at `~/.kube/config`
- Kind created it automatically when cluster was created
- Contains cluster address, certificates, and auth info

### Other Prerequisites
- Kind cluster running: `kind get clusters` should show `bug-report-portal`
- kubectl configured: `kubectl cluster-info --context kind-bug-report-portal`
- Latest image tag from Jenkins build (check Jenkins console output)

---

## Step 1: Get Latest Image Tag from Jenkins

From Jenkins build output, find the line:
```
IMAGE_TAG: demu147/bugreportportal:1.0.0-XX
```

Note the tag (e.g., `1.0.0-15`)

---

## Step 2: Deploy to Kind Cluster

```bash
cd /Users/demu/bug-report-portal-devops

# Set image tag from Jenkins build
export IMAGE_TAG="demu147/bugreportportal:1.0.0-15"

# Switch to Kind context
kubectl config use-context kind-bug-report-portal

# Verify namespace exists (or create via kustomize)
kubectl get namespace bug-report-portal-dev || kubectl apply -k k8s/

# Navigate to k8s directory
cd k8s

# Update app image using Kustomize
kustomize edit set image bugreportportal=${IMAGE_TAG}

# Apply all manifests with updated image
kubectl apply -k .

# Wait for application to rollout
kubectl rollout status deployment/bug-report-portal-app -n bug-report-portal-dev --timeout=120s

# Verify deployment
kubectl get pods -n bug-report-portal-dev
kubectl get deployment -n bug-report-portal-dev bug-report-portal-app -o yaml | grep -A 3 "image:"
```

---

## Step 3: Access Application via Port-Forward

**Option A: Foreground (keep terminal open)**
```bash
kubectl port-forward -n bug-report-portal-dev svc/bug-report-portal-service 8888:3000 \
  --insecure-skip-tls-verify
```

**Option B: Background (recommended)**
```bash
kubectl port-forward -n bug-report-portal-dev svc/bug-report-portal-service 8888:3000 \
  --insecure-skip-tls-verify > ~/.kube/portforward.log 2>&1 &
```

**Then open browser:**
```
http://localhost:8888
```

**Login credentials:**
- Email/Username: admin
- Password: admin

---

## Step 4: Verify Deployment

```bash
# Check pod status
kubectl get pods -n bug-report-portal-dev -w

# View application logs
kubectl logs -n bug-report-portal-dev -l app=bug-report-portal-app -f

# Describe pod for events
kubectl describe pod -n bug-report-portal-dev <POD_NAME>
```

---

## Troubleshooting

**Pod stuck in CrashLoopBackOff?**
```bash
kubectl logs -n bug-report-portal-dev <POD_NAME> --previous
```

**Image pull errors (ImagePullBackOff)?**
```bash
# Verify image exists on Docker Hub
docker pull demu147/bugreportportal:1.0.0-15

# Check imagePullPolicy in deployment
kubectl get deployment -n bug-report-portal-dev bug-report-portal-app -o jsonpath='{.spec.template.spec.containers[0].imagePullPolicy}'
```

**Database connectivity issues?**
```bash
# Verify postgres is running
kubectl get pods -n bug-report-portal-dev | grep postgres

# Check postgres logs
kubectl logs -n bug-report-portal-dev <POSTGRES_POD_NAME>

# Test postgres connectivity
kubectl exec -it -n bug-report-portal-dev <APP_POD_NAME> -- psql -h postgres -U postgres -d bugreportportal -c "SELECT 1"
```

**Certificate validation error with kubectl?**
```bash
# Kind certificates issue - use insecure flag for local development
kubectl --insecure-skip-tls-verify get pods -n bug-report-portal

# Or set in kubeconfig permanently (not recommended for production)
kubectl config set-cluster kind-bug-report-portal --insecure-skip-tls-verify=true
```

---

## Automated Deployment (Recommended)

Instead of manual steps above, use Jenkins pipeline:

1. Go to Jenkins: `http://localhost:8080/jenkins`
2. Click "bug-report-portal" job
3. Click "Build with Parameters"
4. Set:
   - `DO_DEPLOY`: true
   - `DO_PUSH`: true
   - `RUN_SONAR`: false (optional)
5. Click "Build"

Jenkins will automatically execute all deployment steps!

---

## Next Steps

Once deployment is verified:
1. Test application web interface at http://localhost:3000
2. Verify database connectivity with application
3. Check application logs for any errors
4. Review Jenkins build console output for deployment details
