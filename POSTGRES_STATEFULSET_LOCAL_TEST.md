# PostgreSQL StatefulSet - Local Testing

Test PostgreSQL StatefulSet locally in Kind cluster before moving to AWS EKS.

## Quick Start (5 minutes)

### Step 1: Start CI Infrastructure
```bash
cd /Users/demu/bug-report-portal-devops
docker compose up -d  # Jenkins + SonarQube (+ postgres for SonarQube only)
sleep 60
docker compose ps
```

### Step 2: Create Kind Cluster
```bash
kind create cluster --name bug-report-portal --config - <<EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: bug-report-portal
nodes:
  - role: control-plane
    image: kindest/node:v1.28.0
EOF
```

### Step 3: Deploy App + PostgreSQL StatefulSet
```bash
kubectl apply -k k8s/
kubectl rollout status deployment/bug-report-portal-app -n bug-report-portal-dev
kubectl get pods -n bug-report-portal-dev
```

Expected: `postgres-0` and `bug-report-portal-app-*` in Running state.

## Testing & Verification

### Verify StatefulSet
```bash
kubectl get statefulset -n bug-report-portal-dev
kubectl get pvc -n bug-report-portal-dev
```

### Test Database Connection
```bash
kubectl port-forward -n bug-report-portal-dev svc/postgres 5432:5432 &
psql -h localhost -U postgres -d bugreportportal
# Inside psql: \dt (list tables), \q (quit)
```

### Test App
```bash
kubectl port-forward -n bug-report-portal-dev svc/bug-report-portal-service 3000:3000 &
curl http://localhost:3000/login
```

## Troubleshooting

| Issue | Command |
|-------|---------|
| Postgres not ready | `kubectl logs -n bug-report-portal-dev postgres-0` |
| App can't connect | `kubectl logs -n bug-report-portal-dev deployment/bug-report-portal-app -c db-migrate` |
| PVC not bound | `kubectl describe pvc -n bug-report-portal-dev` |

## Cleanup

```bash
kind delete cluster --name bug-report-portal
docker compose down -v
pkill -f "kubectl port-forward"
```
