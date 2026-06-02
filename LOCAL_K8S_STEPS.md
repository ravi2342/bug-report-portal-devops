# Local Kubernetes (Minikube) - Quick Setup

---

## 1. Prerequisites

```bash
# Install tools (macOS)
brew install docker kubectl minikube

# Verify installed
docker --version
kubectl version --client
minikube version
```

---

## 2. Start Minikube

```bash
# Start cluster
minikube start --cpus=4 --memory=8192

# Verify running
kubectl cluster-info
kubectl get nodes
```

---

## 3. Configure Secrets

Edit `k8s/app-secret.template.yaml`:

```yaml
stringData:
  POSTGRES_PASSWORD: localpass123
  PORTAL_LOGIN_PASSWORD: admin123
  AUTH_COOKIE_SECRET: local-secret-key
  DATABASE_URL: postgresql://postgres:localpass123@postgres:5432/bugreportportal
```

⚠️ This is for LOCAL TESTING ONLY. See PROD_K8S_STEPS.md for production secrets.

---

## 4. Deploy

```bash
# Apply all manifests
kubectl apply -k k8s/

# Verify pods running
kubectl get pods -n bug-report-portal
kubectl get all -n bug-report-portal
```

---

## 5. Access Application

```bash
# Option 1: Port-forward
kubectl port-forward svc/bug-report-portal-app 3000:3000 -n bug-report-portal
# http://localhost:3000

# Option 2: Minikube service
minikube service bug-report-portal-app -n bug-report-portal
```

**Login:** admin / admin123

---

## 6. View Logs

```bash
# App logs
kubectl logs -f deployment/bug-report-portal-app -n bug-report-portal

# Database logs
kubectl logs -f deployment/postgres -n bug-report-portal

# Pod details
kubectl describe pod <pod-name> -n bug-report-portal
```

---

## 7. Database Access

```bash
# From host (port-forward first)
kubectl port-forward svc/postgres 5432:5432 -n bug-report-portal
psql -h localhost -U postgres -d bugreportportal
# Password: localpass123

# From pod
kubectl exec -it deployment/postgres -n bug-report-portal -- \
  psql -U postgres -d bugreportportal
```

---

## 8. Cleanup

```bash
# Remove all resources (keep data)
kubectl delete -k k8s/

# Stop Minikube
minikube stop

# Remove cluster completely
minikube delete
```

---

## Quick Commands

```bash
kubectl get pods -n bug-report-portal         # List pods
kubectl logs -f <pod> -n bug-report-portal    # Follow logs
kubectl exec -it <pod> -n bug-report-portal -- sh  # Shell into pod
kubectl describe pod <pod> -n bug-report-portal    # Pod details
kubectl get events -n bug-report-portal       # Recent events
```

---

See [PROD_K8S_STEPS.md](PROD_K8S_STEPS.md) for production deployment.
