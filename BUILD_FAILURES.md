# Jenkins Build Failures - DevOps Troubleshooting Guide

This guide covers **infrastructure and pipeline failures** in the DevOps repository.

For **application code issues** (lint, tests, coverage), see the app repository: https://github.com/ravi2342/bugreportportal

---

## 🔍 Quick Diagnosis

When a build fails:

1. **Check the stage name** - Where did it fail?
2. **Read the error message** - What's the specific error?
3. **Is it DevOps or App code?**
   - Trivy, Docker, K8s → DevOps (this guide)
   - Lint, Tests, SonarCloud → App repo (see link above)

---

## ❌ TRIVY SECURITY SCAN FAILED

### Error Message
```
ERROR: Trivy security scan failed: script returned exit code 1
Total: 2 (HIGH: 2, CRITICAL: 0)

CVE-2026-45447 - openssl: Heap Use-After-Free in OpenSSL PKCS7_verify()
Installed Version: libcrypto3/libssl3 3.5.6-r0
Fixed Version: 3.5.7-r0
```

### Root Cause
Docker image base OS has known vulnerabilities. Application's `Dockerfile` needs security patches.

### Solution

**Fix in app repository's Dockerfile:**

The app repo should include package upgrades in the Dockerfile:
```dockerfile
FROM alpine:3.24.0

# Patch OS packages to address CVEs flagged by Trivy
RUN apk update && apk upgrade --no-cache && rm -rf /var/cache/apk/*

# Rest of Dockerfile...
```

**Steps:**
1. Go to: https://github.com/ravi2342/bugreportportal
2. Edit `Dockerfile`
3. Add the `RUN apk update && apk upgrade` command after `FROM`
4. Commit and push
5. Trigger new Jenkins build

**Result:**
- Trivy scan will pass ✓
- Image will have latest security patches ✓

---

## ❌ DOCKER BUILD FAILED

### Error Message
```
ERROR: Docker build failed
ERROR: failed to solve with frontend dockerfile.v0: ...
```

### Root Cause
Issues with Dockerfile (in app repo):
- Syntax error in Dockerfile
- Missing base image
- Build step failed
- Base image unavailable

### Solution

**Check the app repository's Dockerfile:**
https://github.com/ravi2342/bugreportportal/blob/master/Dockerfile

**Common issues:**
| Issue | Fix |
|-------|-----|
| Base image not found | Verify image exists on Docker Hub, check spelling |
| Missing files | Ensure COPY/ADD files exist in app repo |
| RUN command failed | Test command locally in container |
| Syntax error | Check Dockerfile formatting |

**Fix in app repo:**
1. Edit `Dockerfile`
2. Fix the issue
3. Test locally: `docker build -t test .`
4. Push changes
5. Trigger new Jenkins build

---

## ❌ KUBERNETES DEPLOYMENT FAILED

### Error Message
```
ERROR: Kubernetes deployment failed
error: unable to connect to the server: dial tcp 127.0.0.1:65148: connect refused
```

### Root Cause
Jenkins container cannot reach Kind cluster API server on host machine.

**Architecture issue:**
- Jenkins runs in Docker container
- Container's `127.0.0.1` ≠ host's `127.0.0.1`
- Kubeconfig has `127.0.0.1` which doesn't work from container

### Solution

**This is typically handled automatically by the pipeline.**

The Jenkinsfile (lines 374-437) automatically:
1. Creates temporary kubeconfig for Jenkins container
2. Replaces `127.0.0.1` with `host.docker.internal`
3. Cleans up after deployment

**If you still see this error:**

```bash
# Verify Kind cluster is running
kind get nodes

# Check kubeconfig
cat ~/.kube/config

# Verify cluster server address
kubectl config view | grep server

# If needed, restart Kind cluster
kind delete cluster --name bug-report-portal
kind create cluster --name bug-report-portal
```

**Manual deployment (if needed):**
See [DEPLOY_TO_K8S.md](DEPLOY_TO_K8S.md) for manual kubectl commands.

---

## ❌ JENKINS CONTAINER ISSUES

### Error: Cannot Connect to Docker Socket
```
ERROR: Cannot connect to Docker daemon at unix:///var/run/docker.sock
```

### Root Cause
Jenkins container doesn't have Docker access (docker-in-docker setup issue).

### Solution

**Verify docker-compose.yml has correct volume:**
```yaml
services:
  jenkins:
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock  # Must exist
```

**Fix:**
```bash
# Restart services
docker compose down
docker compose up -d

# Verify Jenkins has Docker access
docker compose exec jenkins docker ps
```

---

### Error: Cannot Find kubectl
```
ERROR: kubectl not found
```

### Root Cause
Kubernetes tools not installed in Jenkins container image.

### Solution

**Check Dockerfile.jenkins includes kubectl installation:**
```dockerfile
# Install kubectl
RUN curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.33/deb/Release.key | gpg --dearmor ... && \
    apt-get install -y kubectl
```

**Verify installation:**
```bash
docker compose exec jenkins kubectl version --client
```

**Rebuild if needed:**
```bash
docker compose build --no-cache jenkins
docker compose up -d
```

---

## ❌ SONARCLOUD CONNECTIVITY FAILED

### Error Message
```
ERROR: Failed to connect to SonarCloud
ERROR: Unable to reach https://sonarcloud.io
```

### Root Cause
Network connectivity issue or credentials problem.

### Solution

**Check network connectivity:**
```bash
docker compose exec jenkins curl -I https://sonarcloud.io
```

**Verify SonarCloud credentials:**
1. Go to Jenkins → Manage Credentials
2. Check `sonar-token` credential exists
3. Verify token is valid at https://sonarcloud.io

**If needed, update token:**
```bash
# Jenkins UI → Manage Credentials → sonar-token → Update
# Paste new token from https://sonarcloud.io/account/security
```

**Configuration:**
- SONAR_HOST_URL: `https://sonarcloud.io`
- SONAR_PROJECT_KEY: `ravi2342_bugreportportal`
- Organization: `ravi2342`

---

## ❌ JENKINS BUILD PARAMETER ISSUES

### Error: Parameter Not Found
```
ERROR: Parameter SONAR_TOKEN_CREDENTIALS_ID not found
```

### Root Cause
Build parameters not configured in Jenkinsfile or credentials not created in Jenkins.

### Solution

**Verify credentials exist in Jenkins:**
1. Go to: http://localhost:8080/jenkins
2. Manage Jenkins → Manage Credentials
3. Check these credentials exist:
   - `dockerhub-creds-pat` - Docker Hub credentials
   - `sonar-token` - SonarCloud token
   - Any other referenced in Jenkinsfile

**Create missing credentials:**
```bash
# Example: Create sonar-token
Jenkins UI → Manage Credentials → Add Credentials
Type: Secret text
Secret: <your-sonarcloud-token>
ID: sonar-token
```

**Verify Jenkinsfile parameters:**
See [JENKINS_BUILD_PARAMETERS.md](JENKINS_BUILD_PARAMETERS.md) for all parameters.

---

## 🔧 Debug Pipeline Failures

### 1. Check Jenkins Console Log
- Jenkins UI → Job → Build #N → Console Output
- Look for first error (not just summary)

### 2. Run Docker Commands Locally
```bash
# Test Docker build
docker build -t test app/

# Test Docker image with Trivy
trivy image --severity HIGH,CRITICAL test

# Test Kubernetes connectivity
kubectl cluster-info
kubectl get pods -A
```

### 3. Check DevOps Environment
```bash
# Verify all tools installed locally
docker --version
kubectl --version
kind version
trivy --version
sonar-scanner --version

# Check Git repos
git -C devops status
```

### 4. Enable Verbose Logging
Add `-X` flag to commands:
```bash
sonar-scanner -X ...
kubectl -v=4 ...
```

---

## 📋 Pre-Build Checklist

Before pushing code that triggers Jenkins:

- [ ] Docker image builds locally: `docker build -t test app/`
- [ ] Trivy scan passes: `trivy image --severity HIGH,CRITICAL test`
- [ ] Kubernetes cluster running: `kind get nodes`
- [ ] kubectl accessible: `kubectl cluster-info`
- [ ] SonarCloud token valid: Check at https://sonarcloud.io
- [ ] Credentials in Jenkins: Check Manage Credentials

---

## 🚀 Common DevOps Fixes

| Issue | Command |
|-------|---------|
| Restart all services | `docker compose restart` |
| Rebuild Jenkins image | `docker compose build --no-cache jenkins` |
| Reset everything | `docker compose down -v && docker compose up -d` |
| View service logs | `docker compose logs -f [service]` |
| Access Jenkins UI | http://localhost:8080/jenkins |
| Access SonarQube | http://localhost:9000 |

---

## 📚 Related Documentation

- **[ERROR_FIXES.md](ERROR_FIXES.md)** - Critical DevOps setup errors
- **[QUICK_REFERENCE.md](QUICK_REFERENCE.md)** - Quick command reference
- **[KIND_SETUP.md](KIND_SETUP.md)** - Kubernetes cluster setup
- **[DEPLOY_TO_K8S.md](DEPLOY_TO_K8S.md)** - Manual deployment guide

**App Repository Issues:**
- **[bugreportportal/CONTRIBUTING.md](https://github.com/ravi2342/bugreportportal/blob/master/CONTRIBUTING.md)** - Lint, tests, coverage fixes
- **[bugreportportal/TROUBLESHOOTING.md](https://github.com/ravi2342/bugreportportal/blob/master/TROUBLESHOOTING.md)** - App-specific issues

---

Last updated: 2026-06-13
