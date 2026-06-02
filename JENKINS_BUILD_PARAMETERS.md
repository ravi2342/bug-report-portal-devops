# Jenkins Build Parameters - Quick Reference

---

## 🔗 Git & Repository

| Parameter | Default | Purpose |
|-----------|---------|---------|
| `BRANCH` | `master` | Git branch to build |
| `GITHUB_REPO_URL` | `https://github.com/ravi2342/bugreportportal.git` | Application repo |
| `DEVOPS_REPO_URL` | `https://github.com/ravi2342/bug-report-portal-devops.git` | DevOps repo |

---

## 🐳 Docker & Registry

| Parameter | Default | Purpose |
|-----------|---------|---------|
| `DO_PUSH` | `false` | Push image to registry (true/false) |
| `REGISTRY_URL` | `` | Registry URL (e.g., `ghcr.io`, `docker.io`) |
| `REGISTRY_CREDENTIALS_ID` | `` | Jenkins credential ID for registry login |

---

## ☸️ Kubernetes Deployment

| Parameter | Default | Purpose |
|-----------|---------|---------|
| `DO_DEPLOY` | `false` | Deploy to K8s cluster (true/false) |

---

## 📊 Code Quality & Security

| Parameter | Default | Purpose |
|-----------|---------|---------|
| `RUN_SONAR` | `false` | Run SonarQube scan (true/false) |
| `SONAR_HOST_URL` | `` | SonarQube server URL |
| `SONAR_TOKEN_CREDENTIALS_ID` | `` | Jenkins credential ID for Sonar token |
| `RUN_CHECKMARX` | `false` | Run Checkmarx SAST (true/false) |
| `CHECKMARX_COMMAND` | `` | Checkmarx CLI command |

---

## 🧪 Testing

| Parameter | Default | Purpose |
|-----------|---------|---------|
| `RUN_POST_DEPLOY_TESTS` | `false` | Run smoke tests after deploy |
| `RUN_UI_E2E` | `false` | Run UI E2E tests |
| `E2E_COMMAND` | `` | E2E test command (e.g., `npm run test:e2e`) |

---

## 📋 Example Scenarios

### Local Build Only
```
BRANCH=develop
DO_PUSH=false
DO_DEPLOY=false
RUN_SONAR=false
```

### Push to Staging Registry
```
BRANCH=master
DO_PUSH=true
REGISTRY_URL=ghcr.io
REGISTRY_CREDENTIALS_ID=github-token
DO_DEPLOY=false
```

### Full Production Pipeline
```
BRANCH=release/v1.0.0
DO_PUSH=true
DO_DEPLOY=true
RUN_SONAR=true
SONAR_HOST_URL=http://host.docker.internal:9000
SONAR_TOKEN_CREDENTIALS_ID=sonar-token
RUN_CHECKMARX=true
CHECKMARX_COMMAND=cx scan create --project-name bug-report-portal --scan-types sast
```

---

## ✅ Setup Checklist

- [ ] SonarQube server running
- [ ] SonarQube token created in Jenkins credentials (as `sonar-token`)
- [ ] Registry credentials created in Jenkins
- [ ] kubectl configured and accessible
- [ ] Secrets in `k8s/app-secret.template.yaml` updated
