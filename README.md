# Bug Report Portal - DevOps Repository

CI/CD pipeline automation and local development infrastructure.

**App Repo:** [bugreportportal](https://github.com/ravi2342/bugreportportal)

---

## 📋 Contents

| File | Purpose |
|------|---------|
| **docker-compose.yml** | Local CI/CD infrastructure (Jenkins, SonarQube, PostgreSQL) |
| **Dockerfile.jenkins** | Jenkins agent with pre-installed toolchain |
| **init-db.sh** | PostgreSQL database initialization |
| **Jenkinsfile** | 21-stage CI/CD pipeline (scripted pipeline) |
| **JENKINS_BUILD_PARAMETERS.md** | Pipeline parameters reference |
| **CODE_REVIEW.md** | Complete architecture documentation |
| **TROUBLESHOOTING.md** | Setup guide and troubleshooting |
| **sonar-project.properties** | SonarQube code quality config |
| **k8s/** | Kubernetes app deployment manifests |

---

## 🚀 Quick Start

### Start Local CI/CD Stack
```bash
docker compose up -d
sleep 60
docker compose ps
```

### Access Services
- **Jenkins:** http://localhost:8080/jenkins
- **SonarQube:** http://localhost:9000
- **PostgreSQL:** localhost:5432

### Get Jenkins Admin Password
```bash
docker compose exec -T jenkins cat /var/jenkins_home/secrets/initialAdminPassword
```

See [TROUBLESHOOTING.md](TROUBLESHOOTING.md) for detailed setup and troubleshooting.

---

## 📚 Documentation

- **[TROUBLESHOOTING.md](TROUBLESHOOTING.md)** - Complete setup guide, common issues, verification steps
- **[CODE_REVIEW.md](CODE_REVIEW.md)** - Architecture overview, parameter explanations
- **[JENKINS_BUILD_PARAMETERS.md](JENKINS_BUILD_PARAMETERS.md)** - Pipeline parameters reference

---

## 🔄 Jenkins Pipeline

**Type:** Scripted Pipeline (Groovy)  
**Stages:** 21 stages from checkout to rollback  
**Parameters:** 16 configurable parameters

Control pipeline behavior with parameters:
- `BRANCH` - Git branch to build
- `DO_PUSH` - Push image to registry
- `DO_DEPLOY` - Deploy to Kubernetes
- `RUN_SONAR` - Run SonarQube analysis

See [JENKINS_BUILD_PARAMETERS.md](JENKINS_BUILD_PARAMETERS.md) for complete list.

---

## 🛠️ Services

### Jenkins
- **Image:** Custom build from Dockerfile.jenkins
- **Tools:** Docker CLI, Node.js 20, npm, SonarScanner, Trivy
- **Port:** 8080 (UI), 50000 (agent)

### SonarQube
- **Image:** sonarqube:lts-community
- **Port:** 9000
- **Database:** PostgreSQL (sonarqube db)

### PostgreSQL
- **Image:** postgres:16-alpine
- **Port:** 5432
- **Databases:** sonarqube, bugreportportal
- **Credentials:** postgres/postgres

---

## 📝 Troubleshooting

If services fail to start:
```bash
docker compose down -v
docker compose build --no-cache
docker compose up -d
sleep 60
docker compose ps
```

See [TROUBLESHOOTING.md](TROUBLESHOOTING.md) for common issues and solutions.

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
