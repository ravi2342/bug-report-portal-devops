# Error Fixes - Quick Reference

## Issue #1: Jenkins Container Cannot Reach Kubernetes Cluster

**Error:** `error: unable to connect to the server: dial tcp 127.0.0.1:65148: connect refused`

**Root Cause:** Jenkins runs in a Docker container; `127.0.0.1` refers to container's own localhost, not the host machine where Kind cluster runs.

**Solution:** Replace `127.0.0.1` with `host.docker.internal` in kubeconfig
```bash
KUBE_SERVER=$(kubectl config view -o jsonpath='{.clusters[?(@.name=="kind-bug-report-portal")].cluster.server}')
KUBE_SERVER=$(echo "$KUBE_SERVER" | sed 's|127.0.0.1|host.docker.internal|g')
kubectl config set-cluster kind-bug-report-portal --server="$KUBE_SERVER"
```

**Status:** ✅ Fixed (Jenkinsfile handles this automatically)

---

## Issue #2: Shell Syntax Error - Bash vs POSIX sh

**Error:** `[[ -z ]]: not found`

**Root Cause:** Jenkinsfile used bash-specific syntax `[[ ]]`, but Jenkins default shell is POSIX `sh`.

**Solution:** Use POSIX-compatible syntax
```bash
# Before (bash-only):
if [[ -z "$KUBE_SERVER" ]]; then

# After (POSIX):
if [ -z "$KUBE_SERVER" ]; then
```

**Status:** ✅ Fixed

---

## Issue #3: Environment Variable Syntax Error

**Error:** `Environment variable values must either be single quoted, double quoted, or function calls`

**Root Cause:** Declarative pipeline's `environment` block cannot use `params` references or complex expressions.

**Solution:** Move IMAGE_TAG computation to script block
```groovy
stage('Checkout DevOps') {
  steps {
    script {
      // Compute at runtime, not compile-time
      def dockerImagePath = params.DOCKER_IMAGE_PATH ?: 'demu147/bugreportportal'
      def appVersion = sh(script: "...", returnStdout: true).trim()
      env.IMAGE_TAG = "docker.io/${dockerImagePath}:${appVersion}-${BUILD_NUMBER}"
    }
  }
}
```

**Status:** ✅ Fixed (Build #60+)

---

## Issue #4: Kubernetes Deployment Image Mismatch

**Error:** `Kustomize unable to find image to patch`

**Root Cause:** Jenkinsfile passed `deploymentName: 'bug-report-portal-app'` (K8s resource name), but kustomize needs the Docker image name `'bugreportportal'`.

**Solution:** Use correct image name
```groovy
k8sDeploy(
  imageTag: "${env.IMAGE_TAG}",
  deploymentName: 'bugreportportal',  # ← Docker image name, not K8s resource name
  ...
)
```

**Mapping:**
- kustomization.yaml: `images.name = 'bugreportportal'` ✓
- app-deployment.yaml: `container.image = 'bugreportportal'` ✓
- Jenkinsfile parameter: `deploymentName = 'bugreportportal'` ✓

**Status:** ✅ Fixed (Commit 97665f8)

---

## Issue #5: SonarCloud Scanning 0 Files

**Error:** `SonarQube analysis shows 0 files indexed`

**Root Cause:** Misconfigured paths in sonar-project.properties and missing `-Dsonar.projectBaseDir` parameter.

**Solution:** Fix configuration
```properties
# sonar-project.properties
sonar.sources=app
sonar.organization=ravi2342
sonar.projectBaseDir=..
```

```groovy
# Jenkinsfile
sonarScan(
  hostUrl: params.SONAR_HOST_URL,
  projectKey: params.SONAR_PROJECT_KEY,
  tokenCredId: params.SONAR_TOKEN_CREDENTIALS_ID,
  waitForQualityGate: true
)
```

**Status:** ✅ Fixed (69 files indexed)

---

## Verification Checklist

- [x] Build completes without syntax errors
- [x] kubectl connectivity from Jenkins container
- [x] IMAGE_TAG computed correctly at runtime
- [x] Kustomize image patching succeeds
- [x] SonarQube analysis scans app code
- [x] Docker image builds with correct tag
- [x] Kubernetes deployment receives correct image
- [x] No hardcoded Docker Hub usernames
- [x] All parameters come from Jenkins job configuration
