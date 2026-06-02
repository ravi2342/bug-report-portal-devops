# Jenkins Pipeline Troubleshooting Guide

Common errors and solutions when running the Bug Report Portal CI/CD pipeline.

---

## ❌ AccessDeniedException: Workspace Write Permission Error

### Error Message
```
java.nio.file.AccessDeniedException: /var/jenkins_home/workspace/bug-report-portal@script/...
at hudson.FilePath.write(FilePath.java:2524)
```

### Root Cause
Jenkins container cannot write to workspace directory. Usually happens when:
- Jenkins runs as non-root user but workspace is owned by `root`
- Permission issues after Docker container restart
- File ownership mismatch between Jenkins user and workspace

### Solution

#### For Docker-based Jenkins:

1. **Identify Jenkins container ID:**
   ```bash
   docker ps --filter "name=jenkins" --format "table {{.ID}}\t{{.Names}}\t{{.Status}}"
   ```

2. **Fix workspace ownership:**
   ```bash
   docker exec -u 0 <container-id> chown -R jenkins:jenkins /var/jenkins_home/workspace
   ```

3. **Verify permissions (optional):**
   ```bash
   docker exec <container-id> ls -la /var/jenkins_home/workspace/
   ```
   
   Expected output:
   ```
   drwxr-xr-x  5 jenkins jenkins ...  .
   ```

4. **Rebuild the Jenkins job** in Jenkins UI

---

## 🔑 Git Credentials Not Found

### Error Message
```
ERROR: Couldn't find any credentials with ID 'xxx'
Failed to authenticate
```

### Solution

1. Go to **Jenkins Dashboard** → **Manage Jenkins** → **Credentials**
2. Add new credentials:
   - **Type:** GitHub (or your git provider)
   - **ID:** Match the ID in Jenkinsfile
   - **Username:** GitHub username
   - **Password/Token:** GitHub personal access token
3. Rebuild the job

---

## 🐳 Docker Build Failure

### Error Message
```
Cannot connect to Docker daemon
docker: command not found
```

### Solution

1. **Verify Docker is accessible in Jenkins container:**
   ```bash
   docker exec <jenkins-container-id> docker ps
   ```

2. **If using Docker-in-Docker, ensure:**
   - Jenkins container mounts `/var/run/docker.sock`
   - Docker group permissions are correct

3. **For containerized Jenkins, use proper Docker volume:**
   ```yaml
   volumes:
     - /var/run/docker.sock:/var/run/docker.sock
   ```

---

## 🔍 SonarQube Connection Failure

### Error Message
```
Error getting settings from server: connection refused
Connection timed out
```

### Causes & Solutions

#### 1. SonarQube Server Not Running
```bash
# Check if SonarQube is running
docker ps | grep sonar

# Start SonarQube (if stopped)
docker start <sonarqube-container-id>
```

#### 2. Wrong Host URL
- **Default URL:** `http://host.docker.internal:9000`
- **From Docker container:** `http://sonarqube:9000` (service name)
- **From local machine:** `http://localhost:9000`

Verify in Jenkins job parameters: `SONAR_HOST_URL`

#### 3. Missing or Expired Token
1. Go to SonarQube UI
2. Generate new token: **My Account** → **Security** → **Tokens**
3. Update Jenkins credential: **Manage Jenkins** → **Credentials** → Edit `sonar-token`

---

## ⌛ Build Timeout During Deployment

### Error Message
```
Timed out waiting for deployment/xxx to be rolled out
```

### Solution

1. **Check pod status:**
   ```bash
   kubectl -n bug-report-portal get pods
   kubectl -n bug-report-portal describe pod <pod-name>
   ```

2. **View logs:**
   ```bash
   kubectl -n bug-report-portal logs <pod-name>
   ```

3. **Common causes:**
   - Image pull failures → Check image registry credentials
   - Insufficient resources → Check node capacity
   - Readiness probe failing → Check app health endpoint

4. **Increase timeout** (in Jenkinsfile):
   ```groovy
   kubectl rollout status deployment/bug-report-portal-app \
     -n bug-report-portal --timeout=300s  // Increase from 120s
   ```

---

## 🚨 Build Failure: "npm ci" or Dependencies

### Error Message
```
npm ERR! 404 Not Found
npm ERR! Could not find a package
```

### Solution

1. **Clear npm cache:**
   ```bash
   npm cache clean --force
   ```

2. **Verify .npmrc or package.json** for private registry configuration

3. **For private packages, add npm credentials:**
   - Jenkins: **Manage Jenkins** → **Credentials** → Add NPM token
   - Jenkinsfile can use `withCredentials()` to inject credentials

---

## 🔐 Registry Login Failure

### Error Message
```
denied: Your authorization token has expired
Error response from daemon: Get token server error
```

### Solution

1. **Verify registry credentials are valid:**
   ```bash
   docker login <registry-url>
   ```

2. **Update Jenkins credentials:**
   - **Manage Jenkins** → **Credentials** → Edit `docker-registry-credentials`
   - Re-enter username and password/token

3. **For Docker Hub:**
   ```bash
   docker logout
   docker login  # Re-authenticate
   ```

4. **For private registries:**
   - Ensure Jenkins agent has network access
   - Check firewall rules

---

## 📋 Pod Events & Logs

### Useful Commands for Debugging

```bash
# View all events in namespace
kubectl -n bug-report-portal get events --sort-by='.lastTimestamp'

# View pod logs
kubectl -n bug-report-portal logs <pod-name>

# Follow logs in real-time
kubectl -n bug-report-portal logs -f <pod-name>

# Get detailed pod information
kubectl -n bug-report-portal describe pod <pod-name>

# Check deployment rollout status
kubectl -n bug-report-portal rollout status deployment/bug-report-portal-app

# Rollback to previous deployment
kubectl -n bug-report-portal rollout undo deployment/bug-report-portal-app
```

---

## 🆘 Still Not Working?

1. **Check Jenkins logs:**
   ```bash
   docker logs <jenkins-container-id> | tail -100
   ```

2. **Enable debug mode in Jenkinsfile:**
   ```groovy
   sh 'set -x'  // Enable command echo
   ```

3. **Capture full build output:**
   - Jenkins UI → Job → Build #N → Console Output

4. **Check environment variables:**
   ```groovy
   sh 'env | sort'  // Print all available environment variables
   ```

---

## 📞 Support Resources

- **Jenkins Docs:** https://www.jenkins.io/doc/
- **Groovy Pipeline Syntax:** https://www.jenkins.io/doc/book/pipeline/syntax/
- **Docker Docs:** https://docs.docker.com/
- **Kubernetes Docs:** https://kubernetes.io/docs/
- **SonarQube Docs:** https://docs.sonarqube.org/
