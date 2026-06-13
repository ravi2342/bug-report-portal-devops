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
| **README.md** | Project overview (this file) |
| **KIND_SETUP.md** | Local Kubernetes cluster setup |
| **TESTING.md** | Trigger Jenkins builds & verify deployment |
| **E2E_DEPLOYMENT.md** | Complete pipeline walkthrough |
| **DEPLOY_TO_K8S.md** | Manual deployment (without Jenkins) |
| **JENKINS_BUILD_PARAMETERS.md** | Pipeline parameters reference |
| **ERROR_FIXES.md** | All 5 critical errors with solutions |
| **BUILD_FAILURES.md** | Troubleshoot DevOps infrastructure failures |
| **JENKINS_SETUP.md** | Configure Jenkins shared library (quick start) |
| **QUICK_REFERENCE.md** | Fast command reference & troubleshooting |
| **COMPLETE_TESTING.md** | All testing layers (unit, integration, E2E) |
| **LOCAL_TESTING_COMPLETE_GUIDE.md** | Complete local testing for Windows/macOS/Linux |
| **DOCUMENTATION_INDEX.md** | Master documentation index |

---

## 🎯 Prerequisites

**For Kubernetes deployment (Kind cluster):**

#### Step 1: Install kubectl & Kind
```bash
# Install kubectl (client tool - MUST be first)
brew install kubectl
kubectl version --client

# Install Kind (cluster creator)
brew install kind
kind version
```

#### Step 2: Understand Kubeconfig
**Kubeconfig** is a configuration file (`~/.kube/config`) that tells kubectl:
- Where your Kubernetes cluster is located (IP address)
- How to authenticate (certificates, tokens)
- Which cluster to use by default

**Why it matters:**
- Kind creates kubeconfig automatically when cluster is created
- We modify it to use `host.docker.internal` instead of `127.0.0.1`
- This allows Jenkins container to access the cluster
- Jenkins container mounts kubeconfig via docker-compose volume

**Example kubeconfig:**
```yaml
clusters:
  - name: kind-bug-report-portal
    cluster:
      server: https://host.docker.internal:65148  # Modified for Jenkins
users:
  - name: kind-bug-report-portal
    user:
      client-certificate: /Users/demu/.kube/...
contexts:
  - name: kind-bug-report-portal
    context:
      cluster: kind-bug-report-portal
      user: kind-bug-report-portal
current-context: kind-bug-report-portal
```

See [KIND_SETUP.md](KIND_SETUP.md#what-is-kubeconfig-important) for detailed kubeconfig explanation.

**Other requirements:**
- Docker Desktop installed
- Git configured
- ~10GB free disk space

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

See [KIND_SETUP.md](KIND_SETUP.md) for complete setup guide, then [TESTING.md](TESTING.md) to trigger your first build.

---

## 📚 Core Documentation (11 files)

**Start here:** [DOCUMENTATION_INDEX.md](DOCUMENTATION_INDEX.md) - Master navigation guide

**Quick reference:**
- **[KIND_SETUP.md](KIND_SETUP.md)** - Local Kubernetes setup
- **[TESTING.md](TESTING.md)** - Trigger Jenkins builds
- **[E2E_DEPLOYMENT.md](E2E_DEPLOYMENT.md)** - Complete pipeline walkthrough
- **[ERROR_FIXES.md](ERROR_FIXES.md)** - Critical errors & solutions
- **[QUICK_REFERENCE.md](QUICK_REFERENCE.md)** - Fast commands & troubleshooting

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

For troubleshooting and debugging, see [ERROR_FIXES.md](ERROR_FIXES.md) for known issues or [QUICK_REFERENCE.md](QUICK_REFERENCE.md) for quick fixes.

---

## � Jenkins Shared Library

This pipeline uses a **Jenkins Shared Library** for clean, reusable pipeline code.

**Shared Library Repository:** [bugreportportal-sharedlib](https://github.com/ravi2342/bugreportportal-sharedlib)

### Quick Setup (2 minutes)
**Fastest way:** [JENKINS_FORM_GUIDE.md](JENKINS_FORM_GUIDE.md) - Copy-paste exact values into Jenkins form

**What to do:**
1. Go to: Jenkins > Manage Jenkins > System Configuration
2. Scroll to: Global Trusted Pipeline Libraries
3. Follow [JENKINS_FORM_GUIDE.md](JENKINS_FORM_GUIDE.md) - fill each field
4. Click Save
5. Create Jenkins job pointing to devops repo
6. Run build - all 12 stages will use shared library functions

**Documentation options:**
- **Just want the form filled?** → [JENKINS_FORM_GUIDE.md](JENKINS_FORM_GUIDE.md) (2 min read)
- **Want step-by-step walkthrough?** → [JENKINS_UI_GUIDE.md](JENKINS_UI_GUIDE.md) (5 min read)
- **Need technical deep-dive?** → [SHARED_LIBRARY_SETUP.md](SHARED_LIBRARY_SETUP.md) (10 min read)

**Pipeline benefits:**
- ✓ 12 stages (realistic enterprise pipeline)
- ✓ All stages calling functions from shared library
- ✓ ~66% less code (257 lines vs 757 original)
- ✓ Functions: gitCheckout, dockerBuild, k8sDeploy, trivyScan, sonarScan, etc.

**Start here:** [JENKINS_FORM_GUIDE.md](JENKINS_FORM_GUIDE.md) ← Recommended!

---

## �📝 Common Issues

**Having problems?** Check these resources:

**Jenkins Shared Library Setup:**
- **How to setup?** → [JENKINS_SETUP.md](JENKINS_SETUP.md) - 5-minute quick start guide
- **Library not found error?** → [JENKINS_SETUP.md](JENKINS_SETUP.md#troubleshooting) - Troubleshooting section

**Infrastructure & Pipeline Failures:**
- **Jenkins build failed?** → [BUILD_FAILURES.md](BUILD_FAILURES.md) - Trivy, Docker, Kubernetes, Jenkins issues
- **DevOps setup error?** → [ERROR_FIXES.md](ERROR_FIXES.md) - 5 critical DevOps issues with root cause analysis
- **Need quick command?** → [QUICK_REFERENCE.md](QUICK_REFERENCE.md) - Common commands and troubleshooting

**Application Code Issues:**
- **Lint, tests, coverage?** → [bugreportportal/CONTRIBUTING.md](https://github.com/ravi2342/bugreportportal/blob/master/CONTRIBUTING.md)
- **SonarCloud quality gate?** → [bugreportportal/TROUBLESHOOTING.md](https://github.com/ravi2342/bugreportportal/blob/master/TROUBLESHOOTING.md)

**Most common DevOps issues:**
- Shared library "not found" error → SHARED_LIBRARY_SETUP.md
- Trivy security scan failing (CVE vulnerabilities) → BUILD_FAILURES.md
- Docker build failures → BUILD_FAILURES.md
- Kubernetes deployment timeouts → BUILD_FAILURES.md
- Jenkins permission errors → ERROR_FIXES.md
- Git credentials not found → QUICK_REFERENCE.md

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

**Start here based on what you need:**

### ⭐ Quick Start (5-10 minutes)
- **[QUICK_LOCAL_TEST.md](QUICK_LOCAL_TEST.md)** - Essential steps to test locally

### 📖 Setup & Deployment
- [KIND_SETUP.md](KIND_SETUP.md) - Set up local Kubernetes cluster
- [TESTING.md](TESTING.md) - Trigger Jenkins builds & verify deployment
- [DEPLOY_TO_K8S.md](DEPLOY_TO_K8S.md) - Manual deployment without Jenkins
- [PROD_K8S_STEPS.md](PROD_K8S_STEPS.md) - Production deployment guide

### 🔧 Pipeline & Tools
- [E2E_DEPLOYMENT.md](E2E_DEPLOYMENT.md) - Complete 21-stage pipeline walkthrough
- [JENKINS_BUILD_PARAMETERS.md](JENKINS_BUILD_PARAMETERS.md) - Pipeline parameters reference
- [SONARQUBE_SETUP.md](SONARQUBE_SETUP.md) - SonarCloud/SonarQube setup & configuration
- [QUICK_REFERENCE.md](QUICK_REFERENCE.md) - Commands & troubleshooting quick lookup

### ⚙️ Issues & Solutions
- [ERROR_FIXES.md](ERROR_FIXES.md) - All 6 critical issues & complete solutions

---

**Related:** [bugreportportal](https://github.com/ravi2342/bugreportportal)
