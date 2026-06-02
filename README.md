# Bug Report Portal - DevOps Repository

CI/CD pipeline configurations and Kubernetes deployment manifests.

**App Repo:** [bugreportportal](https://github.com/ravi2342/bugreportportal)

---

## 📋 Contents

| File | Purpose |
|------|---------|
| **Jenkinsfile** | CI/CD pipeline automation |
| **JENKINS_BUILD_PARAMETERS.md** | Pipeline parameters reference |
| **JENKINS_TROUBLESHOOTING.md** | Common errors and solutions |
| **k8s/** | Kubernetes manifests (namespace, configmap, secret, deployments, services, ingress) |
| **sonar-project.properties** | SonarQube code quality config |
| **Dockerfile.jenkins** | Jenkins agent image |

---

## 🚀 Quick Reference

### Local Testing (Docker)
```bash
cd bugreportportal
docker compose up
# http://localhost:3000
```

### Local Kubernetes (Minikube)
See [LOCAL_K8S_STEPS.md](LOCAL_K8S_STEPS.md)

### Production Kubernetes (EKS/AKS/GKE)
See [PROD_K8S_STEPS.md](PROD_K8S_STEPS.md)

### CI/CD Pipeline Parameters
See [JENKINS_BUILD_PARAMETERS.md](JENKINS_BUILD_PARAMETERS.md)

---

## 🔄 Jenkins Pipeline

Build parameters control pipeline behavior:
- `BRANCH` - Git branch to build
- `DO_PUSH` - Push image to registry
- `DO_DEPLOY` - Deploy to Kubernetes
- `RUN_SONAR` - Run code quality scan

See [JENKINS_BUILD_PARAMETERS.md](JENKINS_BUILD_PARAMETERS.md) for complete list.

---

## 🔧 Troubleshooting

For common Jenkins pipeline errors and solutions, see [JENKINS_TROUBLESHOOTING.md](JENKINS_TROUBLESHOOTING.md)

Common issues:
- Docker workspace permission errors
- Git credentials not found
- SonarQube connection failures
- Kubernetes deployment timeouts

---

## 🔐 Important: Secrets

Edit `k8s/app-secret.template.yaml` before deploying:
```yaml
POSTGRES_PASSWORD: <strong-password>
PORTAL_LOGIN_PASSWORD: <strong-password>
AUTH_COOKIE_SECRET: <random-string>
DATABASE_URL: postgresql://postgres:<password>@postgres:5432/bugreportportal
```

Generate strong values:
```bash
openssl rand -base64 32    # Password
openssl rand -hex 32       # Secret
```

---

## 📚 Documentation

- [LOCAL_K8S_STEPS.md](LOCAL_K8S_STEPS.md) - Minikube deployment
- [PROD_K8S_STEPS.md](PROD_K8S_STEPS.md) - Production deployment  
- [JENKINS_BUILD_PARAMETERS.md](JENKINS_BUILD_PARAMETERS.md) - Pipeline parameters

---

**Related:** [bugreportportal](https://github.com/ravi2342/bugreportportal)
