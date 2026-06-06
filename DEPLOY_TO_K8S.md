# Kubernetes Deployment to Kind Cluster

## Overview
With the Kind setup, Jenkins can now deploy automatically via the CI/CD pipeline.

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
kubectl get namespace bug-report-portal || kubectl apply -k k8s/

# Navigate to k8s directory
cd k8s

# Update app image using Kustomize
kustomize edit set image bugreportportal=${IMAGE_TAG}

# Apply all manifests with updated image
kubectl apply -k .

# Wait for application to rollout
kubectl rollout status deployment/bug-report-portal-app -n bug-report-portal --timeout=120s

# Verify deployment
kubectl get pods -n bug-report-portal
kubectl get deployment -n bug-report-portal bug-report-portal-app -o yaml | grep -A 3 "image:"
```

---

## Step 3: Access Application

```bash
# Port-forward to service
kubectl port-forward -n bug-report-portal svc/bug-report-portal-app 3000:3000

# In another terminal, visit:
# http://localhost:3000
```

---

## Step 4: Verify Deployment

```bash
# Check pod status
kubectl get pods -n bug-report-portal -w

# View application logs
kubectl logs -n bug-report-portal -l app=bug-report-portal-app -f

# Describe pod for events
kubectl describe pod -n bug-report-portal <POD_NAME>
```

---

## Troubleshooting

**Pod stuck in CrashLoopBackOff?**
```bash
kubectl logs -n bug-report-portal <POD_NAME> --previous
```

**Image pull errors (ImagePullBackOff)?**
```bash
# Verify image exists on Docker Hub
docker pull demu147/bugreportportal:1.0.0-15

# Check imagePullPolicy in deployment
kubectl get deployment -n bug-report-portal bug-report-portal-app -o jsonpath='{.spec.template.spec.containers[0].imagePullPolicy}'
```

**Database connectivity issues?**
```bash
# Verify postgres is running
kubectl get pods -n bug-report-portal | grep postgres

# Check postgres logs
kubectl logs -n bug-report-portal <POSTGRES_POD_NAME>

# Test postgres connectivity
kubectl exec -it -n bug-report-portal <APP_POD_NAME> -- psql -h postgres -U postgres -d bugreportportal -c "SELECT 1"
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
