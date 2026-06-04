# Bug Report Portal - DevOps Architecture

## 🏗️ System Overview

This DevOps repository provides a **complete CI/CD pipeline** with local development infrastructure via Docker Compose.

```
GITHUB REPO
    ↓
JENKINS PIPELINE (21 stages)
├─ Checkout → Build → Test → Lint → SonarQube Analysis
├─ Docker Build → Security Scan (Trivy)
├─ Docker Push → Kubernetes Deploy (optional)
├─ Health Checks → Rollback
└─ Reports & Notifications

LOCAL DEVELOPMENT (Docker Compose)
├─ Jenkins (port 8080)     - CI/CD orchestration
├─ SonarQube (port 9000)   - Code quality analysis
└─ PostgreSQL (port 5432)  - SonarQube database

PRODUCTION (Kubernetes)
├─ Bug Report Portal App
├─ PostgreSQL (app database)
├─ Ingress Controller
└─ ConfigMap/Secrets
```

---

## 📁 Repository Structure

### Docker Compose (Local Infrastructure)
| File | Purpose |
|------|---------|
| `docker-compose.yml` | Jenkins, SonarQube, PostgreSQL services |
| `Dockerfile.jenkins` | Custom Jenkins agent with toolchain |
| `init-db.sh` | PostgreSQL initialization script |

### CI/CD Pipeline
| File | Purpose |
|------|---------|
| `Jenkinsfile` | 21-stage scripted pipeline (Groovy) |
| `sonar-project.properties` | SonarQube analysis configuration |
| `JENKINS_BUILD_PARAMETERS.md` | Pipeline parameters reference |

### Kubernetes (App Deployment)
| File | Purpose |
|------|---------|
| `k8s/app-deployment.yaml` | Bug Report Portal app deployment |
| `k8s/postgres-deployment.yaml` | App database deployment |
| `k8s/app-service.yaml` | App service exposure |
| `k8s/postgres-service.yaml` | Database networking |
| `k8s/app-configmap.yaml` | App environment configuration |
| `k8s/app-secret.template.yaml` | Secrets template |
| `k8s/ingress.yaml` | External access routing |
| `k8s/namespace.yaml` | Kubernetes namespace |
| `k8s/kustomization.yaml` | Kustomize orchestration |

### Documentation
| File | Purpose |
|------|---------|
| `README.md` | Quick start guide |
| `TROUBLESHOOTING.md` | Setup guide & troubleshooting |
| `JENKINS_BUILD_PARAMETERS.md` | Pipeline parameters |

---

## 🔧 Services

### Jenkins (Custom Build)
- **Image:** `jenkins/jenkins:lts-jdk17`
- **Pre-installed Tools:** Docker CLI, Node.js 20, npm, SonarScanner, Trivy
- **Port:** 8080 (UI), 50000 (agents)
- **Memory:** ~512-1024MB
- **Docker Socket:** Mounted for container operations

### SonarQube (LTS Community)
- **Image:** `sonarqube:lts-community`
- **Database:** PostgreSQL (sonarqube db)
- **Port:** 9000
- **Memory:** ~512MB
- **Startup:** 2-3 minutes (Elasticsearch initialization)

### PostgreSQL (16 Alpine)
- **Image:** `postgres:16-alpine`
- **Purpose:** SonarQube database only
- **Credentials:** postgres/postgres
- **Database:** sonarqube
- **Port:** 5432
- **Note:** Bug Report Portal uses separate PostgreSQL in Kubernetes

---

## 🔄 Jenkins Pipeline (21 Stages)

| Stage | Purpose |
|-------|---------|
| 1-3 | Initialization (Clean, Checkout, Metadata) |
| 4-7 | Build & Quality (Dependencies, Lint, Tests, SonarQube) |
| 8-11 | Containerization (Docker Build, Trivy, Push, Deploy) |
| 12-14 | Validation (Smoke Tests, E2E, Health Checks) |
| 15-16 | Rollback & Artifacts |
| 17-21 | Reports, Notifications, Cleanup, Summary |

### 16 Pipeline Parameters
- `BRANCH` - Git branch
- `GITHUB_REPO_URL` - Repository URL
- `DO_PUSH` - Push image to registry
- `DO_DEPLOY` - Deploy to Kubernetes
- `RUN_SONAR` - Run SonarQube analysis
- `SONAR_HOST_URL` - SonarQube server URL
- `REGISTRY_URL` - Docker registry
- `IMAGE_TAG` - Docker image tag
- `K8S_CLUSTER` - Kubernetes cluster
- `K8S_NAMESPACE` - Kubernetes namespace
- `ROLLBACK_ENABLED` - Enable rollback
- `SLACK_WEBHOOK` - Slack notifications
- `EMAIL_RECIPIENTS` - Email notifications
- `SKIP_TESTS` - Skip unit tests
- `KEEP_ARTIFACTS` - Archive artifacts
- `DEBUG_MODE` - Verbose logging

See [JENKINS_BUILD_PARAMETERS.md](JENKINS_BUILD_PARAMETERS.md) for details.

---

## 🔗 Component Interactions

### Jenkins → SonarQube
```groovy
// SonarQube accessible via Docker network DNS
withSonarQubeEnv {
  sh "sonar-scanner -Dsonar.host.url=http://sonarqube:9000"
}
```

### Jenkins → Kubernetes
```groovy
// Deploy to K8s using kustomization
sh "kubectl apply -k devops/k8s"
sh "kubectl set image deployment/bug-report-portal-app app=${IMAGE_TAG}"
```

### Docker Compose Services
```yaml
# SonarQube depends on healthy PostgreSQL
depends_on:
  postgres:
    condition: service_healthy

# Jenkins can reach SonarQube via network DNS
SONAR_HOST_URL: http://sonarqube:9000

# Jenkins has Docker socket access
/var/run/docker.sock:/var/run/docker.sock
```

---

## 📊 Build Flow

```
GitHub Webhook / Manual Trigger
    ↓
Jenkins Build Starts (parameters passed)
    ↓
Checkout Code (git clone)
    ↓
npm install + Prisma setup
    ↓
ESLint → Unit Tests (Jest)
    ↓
SonarQube Analysis
    ↓
Docker Image Build
    ↓
Trivy Security Scan
    ↓
Docker Push (optional)
    ↓
Kubernetes Deploy (optional)
    ↓
Smoke Tests & E2E Tests (optional)
    ↓
Health Checks + Rollback Strategy
    ↓
Archive Reports + Send Notifications
    ↓
Cleanup & Summary
```

---

## 🚀 Usage

### Start Local Development
```bash
docker compose up -d
sleep 60  # Wait for SonarQube to initialize
docker compose ps
```

### Access Services
| Service | URL | Credentials |
|---------|-----|-------------|
| Jenkins | http://localhost:8080/jenkins | admin / (see init password) |
| SonarQube | http://localhost:9000 | admin / admin |
| PostgreSQL | localhost:5432 | postgres / postgres |

### Get Jenkins Admin Password
```bash
docker compose exec -T jenkins cat /var/jenkins_home/secrets/initialAdminPassword
```

### Deploy to Kubernetes
```bash
# Trigger pipeline with deployment parameters
# Jenkins will build, push, and deploy to K8s cluster
```

See [TROUBLESHOOTING.md](TROUBLESHOOTING.md) for detailed setup and common issues.

---

## 🔐 Security

- **Trivy Scanning:** All images scanned for vulnerabilities (fails on HIGH/CRITICAL)
- **Jenkins Credentials:** Secure credential storage for registries, SonarQube tokens
- **Docker Socket:** Mounted only in Jenkins for DinD (Docker-in-Docker)
- **Kubernetes RBAC:** Separate service accounts per workload
- **Secret Management:** Credentials stored in Kubernetes Secrets or Jenkins credential store
- **Network Security:** Services isolated in Docker bridge network, K8s NetworkPolicies

---

## 📝 Notes

- **PostgreSQL in Docker Compose** is for SonarQube only - Bug Report Portal uses separate DB in K8s
- **SonarQube startup** takes 2-3 minutes due to Elasticsearch initialization
- **Jenkinsfile** uses scripted pipeline (not declarative) for advanced control flow
- **Docker Compose** is for development/CI infrastructure, NOT app deployment
- **Kubernetes manifests** deploy only the app, not Jenkins/SonarQube
- **All parameters** are configurable per build - no hardcoding in pipeline
