# Bug Report Portal - DevOps Code Review

## 📋 Architecture Overview

This DevOps repository provides a **complete CI/CD pipeline** for the Bug Report Portal application with local development infrastructure via Docker Compose.

```
┌─────────────────────────────────────────────────────────────┐
│                    JENKINS PIPELINE                          │
│  (Scripted Pipeline with 21 stages, enterprise-ready)        │
└────┬────────────────────────────────────────────────────────┘
     │
     ├─→ Checkout Code
     ├─→ Build Metadata
     ├─→ Dependencies & Build
     ├─→ Testing (Lint, Jest)
     ├─→ SonarQube Analysis
     ├─→ Docker Build
     ├─→ Security Scan (Trivy)
     ├─→ Docker Push (Optional)
     ├─→ Kubernetes Deploy (Optional)
     ├─→ Smoke Tests (Optional)
     ├─→ E2E Tests (Optional)
     ├─→ Health Checks
     ├─→ Rollback Strategy
     ├─→ Artifact Collection
     ├─→ Report Publishing
     ├─→ Notifications
     └─→ Cleanup & Summary

┌──────────────────────────────────────────────────────────────┐
│           LOCAL DEVELOPMENT (Docker Compose)                 │
├──────────────────────────────────────────────────────────────┤
│ Service         │ Image              │ Port   │ Purpose       │
├─────────────────┼────────────────────┼────────┼───────────────┤
│ Jenkins         │ jenkins/jenkins:lts│ 8080   │ CI/CD Engine  │
│ SonarQube       │ sonarqube:10       │ 9000   │ Code Quality  │
│ PostgreSQL      │ postgres:15-alpine │ 5432   │ SonarQube DB  │
└──────────────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────────────────┐
│           APP DEPLOYMENT (Kubernetes)                          │
├────────────────────────────────────────────────────────────────┤
│ Resource              │ File                 │ Purpose          │
├───────────────────────┼──────────────────────┼──────────────────┤
│ Namespace             │ namespace.yaml       │ bug-report-portal│
│ Deployment            │ app-deployment.yaml  │ App containers   │
│ Service               │ app-service.yaml     │ Service exposure │
│ ConfigMap             │ app-configmap.yaml   │ App config       │
│ Secret                │ app-secret.template  │ Credentials      │
│ Ingress               │ ingress.yaml         │ External access  │
│ Database Deployment   │ postgres-deployment  │ App DB           │
│ Database Service      │ postgres-service.yaml│ DB networking    │
│ Database PVC          │ postgres-pvc.yaml    │ Data persistence │
└────────────────────────────────────────────────────────────────┘
```

---

## 📂 File Structure & Purpose

### Core CI/CD

| File | Purpose | Key Points |
|------|---------|-----------|
| **Jenkinsfile** | 21-stage scripted pipeline | Groovy-based, enterprise error handling, 16 parameters, comprehensive logging |
| **Dockerfile.jenkins** | Custom Jenkins agent image | Docker CLI, Node.js 20, SonarScanner, Trivy, ca-certificates |
| **sonar-project.properties** | SonarQube analysis config | Project exclusions (node_modules, migrations), UTF-8 encoding |
| **docker-compose.yml** | Local dev infrastructure | Jenkins + SonarQube + PostgreSQL, bridge network, healthchecks |

### Kubernetes Manifests

| File | Purpose | Details |
|------|---------|---------|
| **app-deployment.yaml** | Application deployment | Node.js app on port 3000, init container for DB wait, readiness/liveness probes |
| **postgres-deployment.yaml** | App database deployment | PostgreSQL 16, init container for migration, mount for persistence |
| **app-service.yaml** | App service exposure | ClusterIP internal, web port 3000 |
| **postgres-service.yaml** | Database service | ClusterIP, port 5432 for app connectivity |
| **app-configmap.yaml** | Application configuration | Environment variables (NODE_ENV, DB connection, API keys) |
| **app-secret.template.yaml** | Secrets template | Database credentials, JWT tokens (base64 encoded) |
| **ingress.yaml** | External access route | Hostname-based routing, TLS ready |
| **namespace.yaml** | Kubernetes namespace | Isolates app resources |
| **kustomization.yaml** | Kustomize orchestration | Resource ordering, common labels |

---

## 🔄 Pipeline Stages (21 Total)

### **Stage 1-3: Setup**
```
1. Clean Workspace → 2. Checkout → 3. Build Metadata
   ↓                     ↓              ↓
   Delete old build  Clone app repo  Extract version from package.json
   Delete /workspace from params     Extract registry URL
```

### **Stage 4-7: Build & Test**
```
4. Dependencies   → 5. Lint        → 6. Unit Tests → 7. SonarQube
   ↓                 ↓               ↓               ↓
   npm install      npm run lint   npm test      sonar-scanner
   Prisma setup     ESLint config  Jest reporter SonarQube scan
```

### **Stage 8-11: Container**
```
8. Docker Build → 9. Trivy Scan  → 10. Push (opt) → 11. Deploy (opt)
   ↓              ↓                ↓                ↓
   docker build  High/CRIT check  docker push    kubectl apply
   Tag image     Fail if severe   Registry auth   set image
```

### **Stage 12-16: Post-Deploy**
```
12. Smoke Tests → 13. E2E (opt)  → 14. Health Check
    ↓             ↓               ↓
    curl /login   npm run e2e    kubectl status
    curl /api     Optional       Port checks
```

### **Stage 17-21: Reports & Cleanup**
```
17. Artifacts     → 18. Reports   → 19. Notify    → 20. Cleanup
    ↓              ↓               ↓               ↓
    tar logs      junit publish  Slack message  Docker prune
    Screenshots   Coverage HTML  Build summary  Final report
```

---

## 🔌 Component Interactions

### **Jenkinsfile ↔ Dockerfile.jenkins**
```groovy
// Jenkinsfile uses tools installed in Dockerfile.jenkins
sh 'npm install'           // Node.js 20 from Dockerfile
sh 'sonar-scanner'        // SonarScanner installed in Dockerfile
sh 'trivy image ...'      // Trivy installed in Dockerfile
sh 'docker build ...'     // Docker CLI from Dockerfile
```

### **Jenkinsfile ↔ SonarQube (via Docker Compose)**
```groovy
// Stage 7: SonarQube Scan
sonarQubeName 'SonarQube'
sonarScannerHome = tool 'sonar-scanner'

withSonarQubeEnv {
  sh """
    ${sonarQubeName}/bin/sonar-scanner \
    -Dsonar.host.url=http://sonarqube:9000 \
    -Dsonar.projectKey=bug-report-portal
  """
}
// SonarQube accessible via Docker network: http://sonarqube:9000
```

### **Jenkinsfile ↔ Kubernetes**
```groovy
// Stage 14: Kubernetes Deployment
sh """
  kubectl apply -k devops/k8s
  kubectl set image deployment/bug-report-portal-app app=${IMAGE_TAG}
  kubectl rollout status deployment/bug-report-portal-app
"""
// Uses kustomization.yaml to orchestrate manifests
```

### **docker-compose.yml ↔ Services**
```yaml
# Jenkins can access SonarQube via service name
environment:
  SONAR_HOST_URL: http://sonarqube:9000

# SonarQube depends on PostgreSQL (service_healthy)
depends_on:
  postgres:
    condition: service_healthy

# Jenkins mounts Docker socket for building images
volumes:
  - /var/run/docker.sock:/var/run/docker.sock
```

---

## 📊 Data Flow

### **Build Flow**
```
GitHub Repo
    ↓
Jenkinsfile (Clone)
    ↓
npm install + Prisma setup
    ↓
npm run lint (ESLint)
    ↓
npm test (Jest)
    ↓
sonar-scanner (SonarQube analysis)
    ↓
docker build (App image)
    ↓
trivy scan (Security check)
    ↓
docker push (Optional, to registry)
    ↓
kubectl apply (Optional, to K8s)
    ↓
Smoke tests & E2E tests
    ↓
Health checks & Deployment URL
    ↓
Artifacts archived + Reports published
```

### **Local Development Flow (Docker Compose)**
```
$ docker compose up -d
    ↓
PostgreSQL starts (healthcheck: pg_isready)
    ↓
SonarQube starts (depends_on: postgres healthy)
    ↓
Jenkins starts (depends_on: sonarqube ready)
    ↓
Jenkins accessible @ http://localhost:8080/jenkins
SonarQube accessible @ http://localhost:9000
```

### **Configuration Flow**
```
Jenkinsfile Parameters (16 params)
    ↓
Parsed by Jenkins UI or GitHub API
    ↓
Stage logic checks: if (params.RUN_SONAR) { ... }
    ↓
Optional stages enabled/disabled based on params
    ↓
Deployment URL and Image Tag passed through global vars
    ↓
Final notification includes status + deployment info
```

---

## 🔐 Security & Access

### **Jenkins Parameters** (control pipeline)
```groovy
string(name: 'GITHUB_REPO_URL', defaultValue: 'https://github.com/ravi2342/bugreportportal.git')
string(name: 'BRANCH', defaultValue: 'master')
booleanParam(name: 'DO_PUSH', defaultValue: false)  // Require manual approval
booleanParam(name: 'RUN_SONAR', defaultValue: false)
string(name: 'REGISTRY_CREDENTIALS_ID', defaultValue: '')  // Jenkins credential ID
string(name: 'SONAR_TOKEN_CREDENTIALS_ID', defaultValue: '')  // Jenkins credential ID
```

### **Docker Credentials** (for registry push)
```groovy
// Stage 10: Docker Push
withCredentials([usernamePassword(
  credentialsId: params.REGISTRY_CREDENTIALS_ID,
  usernameVariable: 'DOCKER_USER',
  passwordVariable: 'DOCKER_PASS'
)]) {
  sh 'docker push ${REGISTRY_URL}/${IMAGE_NAME}:${IMAGE_TAG}'
}
```

### **SonarQube Authentication**
```groovy
// Stage 7: SonarQube Analysis
withSonarQubeEnv(installationName: 'SonarQube') {
  sh '''
    sonar-scanner \
      -Dsonar.token=${SONAR_TOKEN} \
      -Dsonar.host.url=${SONAR_HOST_URL}
  '''
}
```

### **Docker Socket Mount** (for DinD)
```yaml
# docker-compose.yml
jenkins:
  volumes:
    - /var/run/docker.sock:/var/run/docker.sock  # Docker-in-Docker
```

---

## ⚙️ Configuration & Parameters

### **16 Jenkins Parameters**

| Parameter | Type | Default | Used In |
|-----------|------|---------|---------|
| `BRANCH` | string | `master` | Stage 2: Checkout |
| `GITHUB_REPO_URL` | string | app repo | Stage 2: Checkout |
| `DO_PUSH` | boolean | `false` | Stage 10: Docker Push |
| `DO_DEPLOY` | boolean | `false` | Stage 14: K8s Deploy |
| `RUN_CHECKMARX` | boolean | `false` | Stage 6b (conditional) |
| `RUN_SONAR` | boolean | `false` | Stage 7 (conditional) |
| `RUN_POST_DEPLOY_TESTS` | boolean | `false` | Stages 15-17 (conditional) |
| `RUN_UI_E2E` | boolean | `false` | Stage 16 (conditional) |
| `REGISTRY_URL` | string | `` | Stage 10: docker login |
| `REGISTRY_CREDENTIALS_ID` | string | `` | Stage 10: withCredentials |
| `E2E_COMMAND` | string | `` | Stage 16 |
| `CHECKMARX_COMMAND` | string | `` | Stage 6b |
| `SONAR_HOST_URL` | string | `http://sonarqube...` | Stage 7 (local: localhost:9000, K8s: sonarqube.sonarqube.svc.cluster.local:9000) |
| `SONAR_TOKEN_CREDENTIALS_ID` | string | `` | Stage 7: withCredentials |

### **Global Variables** (state tracking)
```groovy
def APP_DIR = 'bug-report-portal'
def IMAGE_TAG = ''                    // Set in Stage 3
def BUILD_STATUS = 'SUCCESS'          // Updated on errors
def DEPLOYMENT_URL = ''               // Set in Stage 14
def PREVIOUS_IMAGE_TAG = ''           // For rollback
def TEST_REPORT_SUMMARY = ''          // From Stage 6
```

### **Docker Compose Environment**
```yaml
jenkins:
  JENKINS_OPTS: "--prefix=/jenkins"        # URL prefix for Jenkins
  JAVA_OPTS: "-Xmx1024m -Xms512m"         # Memory limits

sonarqube:
  SONAR_JDBC_URL: jdbc:postgresql://postgres:5432/sonarqube
  SONAR_JDBC_USERNAME: sonarqube
  SONAR_JDBC_PASSWORD: sonarqube
  ES_JAVA_OPTS: "-Xms512m -Xmx512m"       # Elasticsearch memory (Docker Desktop limit)

postgres:
  POSTGRES_DB: sonarqube
  POSTGRES_USER: sonarqube
  POSTGRES_PASSWORD: sonarqube
```

---

## 🚀 Usage Examples

### **Local Development Setup**
```bash
# Start services
docker compose up -d

# Check status
docker compose ps

# View logs
docker compose logs -f jenkins
docker compose logs -f sonarqube

# Stop everything
docker compose down
```

### **Access Services**
```
Jenkins:   http://localhost:8080/jenkins
           Initial password: docker compose logs jenkins | grep initialAdminPassword
           
SonarQube: http://localhost:9000
           Default: admin / admin
           
PostgreSQL: localhost:5432
            User: sonarqube
            Pass: sonarqube
            DB:   sonarqube
```

### **Trigger Pipeline**
```bash
# Manual trigger with parameters
curl -X POST \
  http://localhost:8080/jenkins/job/bug-report-portal/buildWithParameters \
  -F "BRANCH=develop" \
  -F "RUN_SONAR=true" \
  -F "DO_PUSH=false" \
  -F "DO_DEPLOY=false"

# Or via GitHub webhook:
# Settings → Webhooks → Add webhook → http://jenkins:8080/jenkins/github-webhook/
```

### **Deploy to Kubernetes (Optional)**
```bash
# Prerequisites: kubectl configured, K8s cluster running

# Trigger with deployment flags
curl -X POST \
  http://jenkins:8080/job/bug-report-portal/buildWithParameters \
  -F "RUN_SONAR=true" \
  -F "DO_PUSH=true" \
  -F "DO_DEPLOY=true" \
  -F "REGISTRY_URL=docker.io/myorg" \
  -F "REGISTRY_CREDENTIALS_ID=docker-credentials"

# Pipeline will:
# 1. Build image with version tag
# 2. Push to registry
# 3. kubectl apply -k k8s/
# 4. Update deployment with new image
# 5. Wait for rollout
# 6. Run smoke tests
# 7. Health checks
```

---

## 🔍 Key Implementation Details

### **Error Handling** (Each stage wrapped in try-catch)
```groovy
try {
  // Stage logic
} catch (Exception e) {
  BUILD_STATUS = 'FAILED'
  error("Stage failed: ${e.message}")
}
```

### **Conditional Stages** (Based on parameters)
```groovy
if (params.RUN_SONAR) {
  stage('SonarQube Analysis') { ... }
}

if (params.RUN_POST_DEPLOY_TESTS) {
  stage('Post-Deploy Smoke Tests') { ... }
  if (params.RUN_UI_E2E && params.E2E_COMMAND?.trim()) {
    stage('UI E2E Tests') { ... }
  }
}
```

### **Trivy Security Scanning**
```groovy
sh """
  trivy image \
    --severity HIGH,CRITICAL \
    --exit-code 1 \
    ${IMAGE_TAG}
"""
// Fails pipeline if HIGH or CRITICAL vulnerabilities found
```

### **Kubernetes Rollout Status**
```groovy
kubectl rollout status deployment/bug-report-portal-app \
  -n bug-report-portal \
  --timeout=120s
// Waits max 2 minutes for deployment to be ready
```

### **Health Checks**
```groovy
// Docker Compose healthchecks
healthcheck:
  test: ["CMD", "curl", "-f", "http://localhost:8080/jenkins/login"]
  interval: 30s
  timeout: 10s
  retries: 5
  start_period: 60s

// Kubernetes readiness/liveness probes
readinessProbe:
  httpGet:
    path: /login
    port: 3000
  initialDelaySeconds: 20
  periodSeconds: 10
```

---

## 📊 Metrics & Monitoring

### **Pipeline Metrics Captured**
- Build duration
- Build number
- Repository URL
- Branch name
- Image tag
- Deployment URL
- Test reports location
- Build status (SUCCESS/FAILED)

### **Reports Published**
```
JUnit Test Results:      test-reports/**/*.xml
Coverage Report:         test-reports/coverage/index.html
SonarQube Analysis:      Connected to SonarQube dashboard
Docker Images:           Registry (optional)
Deployment Status:       kubectl rollout status
```

### **Notifications**
```groovy
// Slack integration (optional, currently commented)
// Requires slack-webhook-url credential in Jenkins
// Message includes: Status, Repository, Branch, Image, Deployment URL, Build URL
```

---

## 🎯 Best Practices Implemented

✅ **Infrastructure as Code (IaC)**
- All deployments defined in YAML manifests
- Kustomization for environment-specific configs
- No manual kubectl commands needed

✅ **CI/CD Pipeline**
- Scripted pipeline for flexibility & control
- Comprehensive error handling with try-catch
- 16 parameters for customization
- Conditional stages for optional workflows

✅ **Security**
- Trivy for container image scanning
- Secrets stored in Jenkins credentials
- SonarQube for code quality & security
- Docker registry authentication via credentials

✅ **Reliability**
- Health checks at every service
- Init containers for dependency ordering
- Readiness/liveness probes
- Rollout status verification
- Rollback strategy in place

✅ **Observability**
- Comprehensive logging at each stage
- Test report publishing
- Coverage reports
- Build status tracking
- Deployment URL logging

✅ **Developer Experience**
- Local Docker Compose setup
- Simple parameter-driven pipeline
- Clear error messages
- Artifact collection
- Final execution summary

---

## 🔗 Dependencies

### **Jenkinsfile requires:**
- Git client (for checkout)
- Docker CLI (for builds/push)
- Node.js 20 + npm (for dependencies, lint, tests)
- SonarScanner CLI (for code quality)
- Trivy (for security scan)
- kubectl (for K8s deployment)

### **Docker Compose requires:**
- Docker Engine
- Docker Compose (v2+)

### **Kubernetes requires:**
- Kubernetes cluster (EKS/AKS/GKE/Minikube)
- kubectl configured
- Persistent volumes for data

---

## 📝 Next Steps

1. **Configure Jenkins**:
   - Install plugins: Git, Pipeline, SonarQube, Docker
   - Add credentials: GitHub, Docker Registry, SonarQube token

2. **Create Pipeline Job**:
   - New Pipeline job
   - Pipeline script from SCM (this repo)
   - Poll SCM or use GitHub webhook

3. **Set Parameters**:
   - Configure branch
   - Enable optional stages (SONAR, DEPLOY, TESTS)
   - Add registry credentials for push

4. **Trigger Build**:
   - Manual trigger via UI
   - GitHub webhook on push
   - Scheduled builds (optional)

5. **Monitor**:
   - Watch pipeline execution
   - Check console logs
   - View SonarQube dashboard
   - Access deployment via ingress

