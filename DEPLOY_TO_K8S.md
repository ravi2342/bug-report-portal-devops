# Manual Kubernetes Deployment to Minikube

After Jenkins successfully pushes image to Docker Hub, use these commands to deploy locally.

## Prerequisites
- Minikube running: `minikube status`
- kubectl configured: `kubectl cluster-info`
- Latest image tag from Jenkins build (check Jenkins console output)

## Step 1: Get Latest Image Tag from Jenkins

From Jenkins build output, find the line:
```
IMAGE_TAG: demu147/bugreportportal:1.0.0-XX
```

Note the tag (e.g., `1.0.0-12`)

## Step 2: Deploy to Minikube

```bash
cd /Users/demu/bug-report-portal-devops

# Set image tag from Jenkins build
export IMAGE_TAG="demu147/bugreportportal:1.0.0-12"

# Verify namespace exists
kubectl get namespace bug-report-portal

# Apply database layer first
kubectl apply -f k8s/postgres-pvc.yaml -n bug-report-portal
kubectl apply -f k8s/postgres-deployment.yaml -n bug-report-portal
kubectl apply -f k8s/postgres-service.yaml -n bug-report-portal

# Wait for postgres to be ready
kubectl rollout status deployment/postgres -n bug-report-portal --timeout=120s

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

## Step 3: Access Application

```bash
# Port-forward to service
kubectl port-forward -n bug-report-portal svc/bug-report-portal-app 3000:3000

# In another terminal, visit:
# http://localhost:3000
```

## Step 4: Verify Deployment

```bash
# Check pod status
kubectl get pods -n bug-report-portal -w

# View application logs
kubectl logs -n bug-report-portal -l app=bug-report-portal-app -f

# Describe pod for events
kubectl describe pod -n bug-report-portal <POD_NAME>
```

## Troubleshooting

**Pod stuck in CrashLoopBackOff?**
```bash
kubectl logs -n bug-report-portal <POD_NAME> --previous
```

**Image pull errors?**
```bash
# Verify image exists on Docker Hub
docker pull demu147/bugreportportal:1.0.0-12

# Check imagePullPolicy
kubectl get deployment -n bug-report-portal bug-report-portal-app -o jsonpath='{.spec.template.spec.containers[0].imagePullPolicy}'
```

**Database connectivity issues?**
```bash
# Verify postgres is running
kubectl get pods -n bug-report-portal | grep postgres

# Check postgres logs
kubectl logs -n bug-report-portal <POSTGRES_POD_NAME>
```

## Next Steps

Once deployment is verified:
1. Test application web interface
2. Verify database connectivity
3. Consider updating Jenkinsfile to run these commands directly (requires Jenkins-K8s network setup)
4. Document any required changes to manifests or pipeline
