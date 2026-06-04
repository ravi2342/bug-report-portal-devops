# Bug Report Portal - DevOps Repository

CI/CD pipeline automation and local development infrastructure with Docker Compose.

**App Repository:** [bugreportportal](https://github.com/ravi2342/bugreportportal)

---

## 📋 Contents

| File/Folder | Purpose |
|-------------|---------|
| **docker-compose.yml** | Local infrastructure: Jenkins, SonarQube, PostgreSQL |
| **Dockerfile.jenkins** | Custom Jenkins agent with toolchain |
| **init-db.sh** | PostgreSQL initialization script |
| **Jenkinsfile** | 21-stage CI/CD pipeline (scripted) |
| **sonar-project.properties** | SonarQube analysis config |
| **k8s/** | Kubernetes manifests for app deployment |
| **TROUBLESHOOTING.md** | Setup guide & common issues |
| **CODE_REVIEW.md** | Architecture & implementation details |
| **JENKINS_BUILD_PARAMETERS.md** | Pipeline parameters reference |

---

## 🚀 Quick Start

### 1. Start Services
```bash
docker compose up -d
sleep 60  # Wait for SonarQube to initialize
docker compose ps
```

### 2. Get Jenkins Password
```bash
docker compose exec -T jenkins cat /var/jenkins_home/secrets/initialAdminPassword
```

### 3. Access Services

| Service | URL | Credentials |
|---------|-----|-------------|
| **Jenkins** | http://localhost:8080/jenkins | admin / (password above) |
| **SonarQube** | http://localhost:9000 | admin / admin |
| **PostgreSQL** | localhost:5432 | postgres / postgres |

See [TROUBLESHOOTING.md](TROUBLESHOOTING.md) for complete setup guide.

---

## 📚 Documentation

- **[TROUBLESHOOTING.md](TROUBLESHOOTING.md)** - Setup guide, verification steps, common issues
- **[CODE_REVIEW.md](CODE_REVIEW.md)** - Architecture overview, pipeline details
- **[JENKINS_BUILD_PARAMETERS.md](JENKINS_BUILD_PARAMETERS.md)** - Pipeline parameters

---

## 🔧 Services

### Jenkins (Custom Build)
- **Tools:** Docker CLI, Node.js 20, npm, SonarScanner, Trivy
- **Port:** 8080 (UI), 50000 (agents)
- **Docker Socket:** Mounted for container operations

### SonarQube (LTS Community)
- **Port:** 9000
- **Database:** PostgreSQL (sonarqube db)
- **Startup:** 2-3 minutes

### PostgreSQL (16 Alpine)
- **Port:** 5432
- **Purpose:** SonarQube database only
- **Note:** Bug Report Portal uses separate PostgreSQL in Kubernetes

---

## 🔄 CI/CD Pipeline

**Type:** Scripted Pipeline (Groovy)  
**Stages:** 21 total  
**Parameters:** 16 configurable parameters  

### Pipeline Stages
1-3. Setup (Clean, Checkout, Metadata)
4-7. Build & Quality (Dependencies, Lint, Tests, SonarQube)
8-11. Containerization (Docker Build, Trivy, Push, Deploy)
12-14. Validation (Smoke Tests, E2E, Health Checks)
15-16. Rollback & Artifacts
17-21. Reports, Notifications, Cleanup

See [JENKINS_BUILD_PARAMETERS.md](JENKINS_BUILD_PARAMETERS.md) for parameter details.

---

## 📦 Kubernetes Deployment

App deployment files in `k8s/`:
- `app-deployment.yaml` - Application deployment
- `app-service.yaml` - Service exposure
- `postgres-deployment.yaml` - App database
- `app-configmap.yaml` - Configuration
- `ingress.yaml` - External access
- `kustomization.yaml` - Manifest orchestration

Deploy to K8s:
```bash
kubectl apply -k k8s/
```

---

## ⚙️ Common Commands

```bash
# View all services
docker compose ps

# View logs
docker compose logs -f sonarqube

# Stop services (keep data)
docker compose down

# Full reset (delete all data)
docker compose down -v

# Rebuild Jenkins image
docker compose build --no-cache
```

---

## 🔒 Security

- Trivy scans all images for vulnerabilities
- Jenkins credentials for secure registry/SonarQube access
- Docker socket mounted only in Jenkins
- Services isolated in Docker bridge network
- Kubernetes RBAC and NetworkPolicies for production

---

## 📝 Notes

- Docker Compose is for **CI/CD infrastructure only** (Jenkins + SonarQube)
- PostgreSQL in Compose is for **SonarQube only**
- Bug Report Portal uses its own PostgreSQL in Kubernetes
- SonarQube takes 2-3 minutes to start
- Jenkinsfile uses scripted pipeline for advanced control
- All pipeline parameters are configurable per build

For troubleshooting, see [TROUBLESHOOTING.md](TROUBLESHOOTING.md)

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
