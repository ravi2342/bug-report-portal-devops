# Bug Report Portal - DevOps

12-stage CI/CD pipeline with Jenkins Shared Library and Kubernetes.

**Repos:** [App](https://github.com/ravi2342/bugreportportal) | [Shared Library](https://github.com/ravi2342/bugreportportal-sharedlib) | [DevOps](https://github.com/ravi2342/bug-report-portal-devops)

---

## 🚀 Quick Start (5 minutes)

### 1. Prerequisites
```bash
brew install kubectl kind docker
```

### 2. Start Services
```bash
docker compose up -d
sleep 60
docker compose ps
```

### 3. Get Jenkins Admin Password
```bash
docker compose exec -T jenkins cat /var/jenkins_home/secrets/initialAdminPassword
```

### 4. Access Services
- **Jenkins:** http://localhost:8080/jenkins (admin / password above)
- **SonarQube:** http://localhost:9000 (admin / admin)

---

## 📖 Next Steps

1. **[JENKINS_SETUP.md](JENKINS_SETUP.md)** - Configure Jenkins with shared library (5 min)
2. **[KIND_SETUP.md](KIND_SETUP.md)** - Setup Kubernetes cluster
3. **[NAMESPACE_AND_DEPLOYMENT.md](NAMESPACE_AND_DEPLOYMENT.md)** - Understanding namespace and environment configuration ⭐ **START HERE FOR E2E**
4. **[JENKINS_BUILD_PARAMETERS.md](JENKINS_BUILD_PARAMETERS.md)** - Build parameters explained
5. **[E2E_DEPLOYMENT.md](E2E_DEPLOYMENT.md)** - Complete end-to-end deployment walkthrough
6. **[ERROR_FIXES.md](ERROR_FIXES.md)** - Troubleshooting common issues

---

## 📁 Project Structure

```
bug-report-portal-devops/
├── Jenkinsfile                 # 12-stage pipeline (shared library)
├── docker-compose.yml          # Jenkins + SonarQube + PostgreSQL
├── sonar-project.properties    # SonarQube config
└── k8s/                        # Kubernetes manifests
    ├── app-deployment.yaml
    ├── app-configmap.yaml
    ├── app-secret.template.yaml
    ├── kustomization.yaml
    └── ...
```

---

## ⚙️ 12-Stage Pipeline

1. Clean Workspace
2. Checkout Application
3. Checkout DevOps
4. Preflight Checks
5. Setup (deps, Prisma)
6. Quality Gates (lint, tests)
7. SonarQube (optional)
8. Build Docker Image
9. Security Scan
10. Push to Registry (optional)
11. Deploy to Kubernetes (optional)
12. Notify Status

**Parameters:** BRANCH, DOCKER_IMAGE_PATH, DO_PUSH, DO_DEPLOY, RUN_SONAR

---

## 🔧 Services

| Service | Port | Credentials |
|---------|------|-------------|
| Jenkins | 8080 | admin / (see above) |
| SonarQube | 9000 | admin / admin |
| PostgreSQL | 5432 | postgres / postgres |

---

## ✅ Verification

After build completes:
```bash
# Check pods
kubectl get pods -n bug-report-portal

# Port-forward to app
kubectl port-forward -n bug-report-portal svc/bug-report-portal-service 8888:3000

# Access app
curl http://localhost:8888
```

---

See [QUICK_REFERENCE.md](QUICK_REFERENCE.md) for more commands.
