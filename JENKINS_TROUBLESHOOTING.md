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

## � Prisma Generation Error

### Error Message
```
PrismaConfigEnvError: Cannot resolve environment variable: DATABASE_URL
Failed to load config file ... as a TypeScript/JavaScript module
```

### Root Cause
Prisma needs environment variables (like `DATABASE_URL`) to generate schema client. These are usually defined in a `.env` file that's not in the repo.

### Solution

1. **Create `.env` file in app repository root:**
   ```bash
   # bug-report-portal/.env (example)
   DATABASE_URL="postgresql://user:password@localhost:5432/bug_report_db"
   NODE_ENV="development"
   ```

2. **Option A: Add to Jenkinsfile (for development):**
   ```groovy
   stage('Prisma Generate') {
     echo "=== Running Prisma generate ==="
     try {
       dir(APP_DIR) {
         sh '''
           # Set minimal env vars for Prisma if not present
           if [ ! -f .env ]; then
             echo "DATABASE_URL=postgresql://localhost/app" > .env
           fi
           npx prisma generate
         '''
       }
     }
   }
   ```

3. **Option B: Use Jenkins credentials (recommended for production):**
   ```groovy
   stage('Prisma Generate') {
     withCredentials([string(credentialsId: 'database-url', variable: 'DB_URL')]) {
       dir(APP_DIR) {
         sh '''
           export DATABASE_URL="${DB_URL}"
           npx prisma generate
         '''
       }
     }
   }
   ```

4. **Store secret in Jenkins:**
   - **Manage Jenkins** → **Credentials** → Add new **String** credential
   - **ID:** `database-url`
   - **Secret:** `postgresql://user:pass@host:5432/db`

---

## 🐳 Docker API Permission Denied

### Error Message
```
permission denied while trying to connect to the docker API at unix:///var/run/docker.sock
```

### Root Cause
Jenkins container can't access Docker socket. This happens when:
- Docker socket volume not mounted in Jenkins container
- Jenkins user doesn't have permissions to `/var/run/docker.sock`
- Docker daemon not accessible from container

### Solution

#### For Docker Compose Setup:

1. **Verify docker.sock is mounted in docker-compose.yml:**
   ```yaml
   jenkins:
     image: jenkins/jenkins:lts
     volumes:
       - /var/run/docker.sock:/var/run/docker.sock  # ← THIS LINE REQUIRED
       - jenkins_home:/var/jenkins_home
     groups:
       - docker  # Add to docker group
   ```

2. **Fix socket permissions (run on host):**
   ```bash
   sudo chmod 666 /var/run/docker.sock
   ```

3. **Add jenkins user to docker group in container:**
   ```bash
   docker exec <jenkins-container-id> usermod -aG docker jenkins
   ```

4. **Restart Jenkins:**
   ```bash
   docker restart <jenkins-container-id>
   ```

#### For Kubernetes Setup:

Use Docker-in-Docker (DinD) sidecar or privileged container:

```yaml
spec:
  containers:
  - name: jenkins
    image: jenkins/jenkins:lts
    securityContext:
      privileged: true
    volumeMounts:
    - name: docker-sock
      mountPath: /var/run/docker.sock
  volumes:
  - name: docker-sock
    hostPath:
      path: /var/run/docker.sock
```

---

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
