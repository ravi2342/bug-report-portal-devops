# Jenkins Build Parameters

## Core Parameters

| Parameter | Default | Purpose |
|-----------|---------|---------|
| `BRANCH` | `master` | Git branch |
| `GITHUB_REPO_URL` | `https://github.com/ravi2342/bugreportportal.git` | App repo |
| `DOCKER_IMAGE_PATH` | `demu147/bugreportportal` | Docker image (default works for demo) |
| `DO_PUSH` | `false` | Push to Docker Hub |
| `DO_DEPLOY` | `false` | Deploy to Kubernetes |
| `RUN_SONAR` | `false` | Run SonarQube analysis |

## SonarQube (if RUN_SONAR=true)

| Parameter | Default | Purpose |
|-----------|---------|---------|
| `SONAR_HOST_URL` | `http://sonarqube:9000` | SonarQube URL |
| `SONAR_PROJECT_KEY` | `bug-report-portal` | Project key |
| `SONAR_TOKEN_CREDENTIALS_ID` | `sonar-token` | Jenkins credential |

## Credentials Required in Jenkins

- **dockerhub-creds-pat** - Docker Hub username/password
- **github-pat** - GitHub PAT (for shared library)
- **sonar-token** - SonarQube token (if RUN_SONAR=true)

## Quick Examples

**Build only (no push, no deploy) — Demo default:**
```
BRANCH = master
DOCKER_IMAGE_PATH = demu147/bugreportportal (default - works for demo)
DO_PUSH = false
DO_DEPLOY = false
RUN_SONAR = false
```

**Full pipeline (build → push → deploy):**
```
BRANCH = master
DOCKER_IMAGE_PATH = demu147/bugreportportal (or your-username/your-app)
DO_PUSH = true
DO_DEPLOY = true
RUN_SONAR = true
```

**💡 Note:** Use default `DOCKER_IMAGE_PATH = demu147/bugreportportal` for demo. Change to your Docker Hub username/image for production.

## 12-Stage Pipeline

1. Clean Workspace
2. Checkout Application
3. Checkout DevOps
4. Preflight Checks
5. Setup (install deps, Prisma)
6. Quality Gates (lint, tests)
7. SonarQube (optional)
8. Build Docker Image
9. Security Scan (Trivy)
10. Push to Registry (optional)
11. Deploy to Kubernetes (optional)
12. Notify Status

---

**See ERROR_FIXES_SIMPLIFIED.md for troubleshooting**
