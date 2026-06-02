# SonarQube on Kubernetes - Setup Guide

Complete setup for SonarQube with PostgreSQL on Kubernetes.

---

## 📋 Prerequisites

- Kubernetes cluster (Minikube, EKS, AKS, GKE, etc.)
- `kubectl` CLI configured
- At least 2Gi memory available
- Storage class configured (for persistent volumes)

---

## 🚀 Deployment

### 1. Deploy SonarQube Stack

```bash
# Deploy SonarQube namespace, PostgreSQL, and SonarQube
kubectl apply -k k8s/sonarqube/

# Or individually:
kubectl apply -f k8s/sonarqube/namespace.yaml
kubectl apply -f k8s/sonarqube/postgres-*.yaml
kubectl apply -f k8s/sonarqube/sonarqube-*.yaml
```

### 2. Verify Deployment

```bash
# Check namespace
kubectl get namespace sonarqube

# Check pods
kubectl -n sonarqube get pods

# Expected output:
# sonarqube-postgres-xxx   1/1 Running
# sonarqube-xxx            1/1 Running

# Check services
kubectl -n sonarqube get svc

# Expected:
# sonarqube           LoadBalancer   10.x.x.x   <external-ip>:9000/TCP
# sonarqube-postgres  ClusterIP      10.x.x.x   5432/TCP
```

### 3. Wait for Ready State

```bash
# Monitor pod startup (takes 2-3 minutes)
kubectl -n sonarqube logs -f deployment/sonarqube

# Watch readiness status
kubectl -n sonarqube get pods -w
```

---

## 🔐 Access SonarQube

### Local Machine (Minikube)

```bash
# Get the service IP/port
kubectl -n sonarqube get svc sonarqube

# For Minikube:
minikube service sonarqube -n sonarqube

# Automatically opens: http://sonarqube-service-ip:9000
```

### Cloud Kubernetes (EKS/AKS/GKE)

```bash
# Get external IP
kubectl -n sonarqube get svc sonarqube

# Wait for EXTERNAL-IP to be assigned (may take 1-2 minutes):
kubectl -n sonarqube get svc sonarqube --watch
```

### Port Forward (Alternative)

```bash
kubectl -n sonarqube port-forward svc/sonarqube 9000:9000

# Access: http://localhost:9000
```

---

## 🔐 Initial Setup

1. **Login to SonarQube**
   - URL: `http://<sonarqube-ip>:9000`
   - Default credentials:
     - Username: `admin`
     - Password: `admin` (you'll be forced to change on first login)

2. **Create Admin Token**
   - Login → **My Account** → **Security** → **Generate Tokens**
   - Token Name: `jenkins-token`
   - Copy the token

3. **Store Token in Jenkins**
   - Jenkins → **Manage Jenkins** → **Credentials**
   - **New Credentials** → **Secret text**
   - **ID**: `sonar-token`
   - **Secret**: Paste the token

4. **Update Jenkinsfile** (if not on Kubernetes)
   - `SONAR_HOST_URL=http://sonarqube.sonarqube.svc.cluster.local:9000`
   - `SONAR_TOKEN_CREDENTIALS_ID=sonar-token`

---

## 📊 Using with Jenkins on Kubernetes

If Jenkins is also on Kubernetes in the same cluster, use service DNS:

```groovy
// In Jenkinsfile
string(name: 'SONAR_HOST_URL', 
  defaultValue: 'http://sonarqube.sonarqube.svc.cluster.local:9000',
  description: 'SonarQube URL')
```

If Jenkins is outside Kubernetes:

```groovy
// Use LoadBalancer external IP
string(name: 'SONAR_HOST_URL', 
  defaultValue: 'http://<external-ip>:9000',
  description: 'SonarQube URL')
```

---

## 🧹 Cleanup

```bash
# Delete entire SonarQube stack
kubectl delete -k k8s/sonarqube/

# Or delete namespace (removes everything in it)
kubectl delete namespace sonarqube

# Verify deletion
kubectl get namespace sonarqube  # Should return error
```

---

## 🔧 Configuration

### Change Database Password

1. Edit `k8s/sonarqube/postgres-deployment.yaml`
2. Update the base64-encoded password in the secret
3. Redeploy

### Adjust Resource Limits

Edit `k8s/sonarqube/sonarqube-deployment.yaml`:

```yaml
resources:
  requests:
    memory: "2Gi"    # Change here
    cpu: "1000m"     # Change here
  limits:
    memory: "4Gi"
    cpu: "2000m"
```

### Change Storage Size

Edit `k8s/sonarqube/*-pvc.yaml`:

```yaml
resources:
  requests:
    storage: 50Gi  # Change from 20Gi to 50Gi
```

---

## 🆘 Troubleshooting

### Pod Stuck in Pending

```bash
kubectl -n sonarqube describe pod sonarqube-xxx

# Common issues:
# - Not enough CPU/memory: Check node resources
# - Storage not available: Check storage class
# - Image pull failed: Check Docker credentials
```

### PostgreSQL Connection Failed

```bash
# Test connection
kubectl -n sonarqube exec -it sonarqube-xxx -- \
  psql -h sonarqube-postgres -U sonarqube -d sonarqube

# Check logs
kubectl -n sonarqube logs deployment/sonarqube-postgres
```

### SonarQube Not Starting

```bash
# View logs
kubectl -n sonarqube logs -f deployment/sonarqube --tail=100

# Check readiness probe
kubectl -n sonarqube describe pod sonarqube-xxx | grep -A 5 "Readiness"

# Common: Takes 2-3 minutes to start
```

---

## 📚 Resources

- [SonarQube on Kubernetes](https://docs.sonarqube.org/latest/setup-and-upgrade/install-the-server/)
- [PostgreSQL Kubernetes](https://kubernetes.io/docs/tasks/run-application/run-single-instance-stateful-application/)
- [Persistent Volumes in Kubernetes](https://kubernetes.io/docs/concepts/storage/persistent-volumes/)
