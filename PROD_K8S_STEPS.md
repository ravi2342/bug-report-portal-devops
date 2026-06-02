# Production Kubernetes - Quick Setup

---

## 1. Prerequisites

```bash
# Cluster access
kubectl config use-context <your-cluster>
kubectl cluster-info
kubectl get nodes

# Container registry access
# AWS ECR, Azure ACR, Google GCR, Docker Hub, or private registry
```

---

## 2. Update Secrets (IMPORTANT!)

Edit `k8s/app-secret.template.yaml` with strong passwords:

```bash
# Generate strong values
openssl rand -base64 32    # For passwords
openssl rand -hex 32       # For secrets
```

```yaml
stringData:
  POSTGRES_PASSWORD: <strong-password>
  PORTAL_LOGIN_PASSWORD: <strong-password>
  AUTH_COOKIE_SECRET: <random-hex>
  DATABASE_URL: postgresql://postgres:<password>@postgres:5432/bugreportportal
```

⚠️ **NEVER** commit secrets to Git. Store securely (AWS Secrets Manager, Vault, etc.).

---

## 3. Choose Database Option

**Option A: In-Cluster PostgreSQL**
- Use manifests as-is
- Update `postgres-pvc.yaml` storage size if needed
- Simple but less resilient

**Option B: Managed Database (Recommended)**
- AWS RDS, Azure Database, Google Cloud SQL, etc.
- Update `DATABASE_URL` in secret
- Remove `postgres-*.yaml` manifests from `kustomization.yaml`

```yaml
# kustomization.yaml - remove these:
# - postgres-pvc.yaml
# - postgres-deployment.yaml
# - postgres-service.yaml
```

---

## 4. Configure App Deployment

Edit `k8s/app-deployment.yaml`:

```yaml
spec:
  replicas: 3  # For high availability
  template:
    spec:
      containers:
      - name: app
        image: <registry>/bug-report-portal-app:v1.0.0  # Pin version!
        resources:
          requests:
            cpu: 100m
            memory: 256Mi
          limits:
            cpu: 500m
            memory: 512Mi
        livenessProbe:
          httpGet:
            path: /login
            port: 3000
          initialDelaySeconds: 30
        readinessProbe:
          httpGet:
            path: /login
            port: 3000
          initialDelaySeconds: 5
```

---

## 5. Configure Ingress (HTTPS)

Edit `k8s/ingress.yaml`:

```yaml
spec:
  tls:
  - hosts:
    - portal.company.com        # ⚠️ CHANGE THIS
    secretName: portal-tls
  rules:
  - host: portal.company.com    # ⚠️ CHANGE THIS
    http:
      paths:
      - path: /
        backend:
          service:
            name: bug-report-portal-app
            port:
              number: 3000
```

**Prerequisites:**
- Ingress controller running (nginx, etc.)
- Cert-manager for TLS (Let's Encrypt)
- DNS A record configured

---

## 6. Setup Private Registry Access (if needed)

```bash
# Create image pull secret
kubectl create secret docker-registry regcred \
  --docker-server=<registry> \
  --docker-username=<username> \
  --docker-password=<password> \
  -n bug-report-portal
```

Add to `app-deployment.yaml`:

```yaml
spec:
  template:
    spec:
      imagePullSecrets:
      - name: regcred
```

---

## 7. Deploy

```bash
# Review what will be deployed
kubectl apply -k k8s/ --dry-run=client -o yaml | less

# Deploy to production
kubectl apply -k k8s/

# Watch rollout
kubectl rollout status deployment/bug-report-portal-app -n bug-report-portal
kubectl get pods -n bug-report-portal -w
```

---

## 8. Verify

```bash
# Check all resources
kubectl get all -n bug-report-portal

# Check ingress (wait for IP)
kubectl get ingress -n bug-report-portal -o wide

# Check logs
kubectl logs -f deployment/bug-report-portal-app -n bug-report-portal

# Configure DNS once ingress IP is ready
# Add A record: portal.company.com -> <ingress-ip>

# Test HTTPS
curl https://portal.company.com/login
```

---

## 9. Update & Rollback

```bash
# Update image
kubectl set image deployment/bug-report-portal-app \
  app=<registry>/bug-report-portal-app:v1.0.1 \
  -n bug-report-portal

# Rollback if issues
kubectl rollout undo deployment/bug-report-portal-app -n bug-report-portal
```

---

## 10. Backup & Cleanup

```bash
# Backup current state
kubectl get all -n bug-report-portal -o yaml > backup.yaml

# Delete namespace (deletes all resources)
kubectl delete namespace bug-report-portal
```

---

## Production Checklist

- [ ] Secrets are strong (generated with openssl)
- [ ] Secrets stored securely (not in Git)
- [ ] Image pushed to registry with version tag (not `latest`)
- [ ] Replicas set to 3+ for HA
- [ ] Health probes configured
- [ ] Ingress configured with valid domain
- [ ] HTTPS/TLS enabled
- [ ] Database backup strategy documented
- [ ] Monitoring/logging configured

---

See [LOCAL_K8S_STEPS.md](LOCAL_K8S_STEPS.md) for local Minikube testing first.
