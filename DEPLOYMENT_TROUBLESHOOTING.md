# Bug Report Portal - Complete Troubleshooting Guide

## TABLE OF CONTENTS
1. [Kubernetes Issues](#kubernetes-issues)
2. [Docker & Security Issues](#docker--security-issues)
3. [CI/CD Pipeline Issues](#cicd-pipeline-issues)
4. [Configuration Issues](#configuration-issues)

---

# KUBERNETES ISSUES

## Issue: Service Cannot Be Modified

### Symptom
```
The Service "postgres" is invalid: spec.clusterIPs[0]: Invalid value: ["None"]: may not change once set
```

### Root Cause
Kubernetes **Services have immutable fields**. Once a Service is created with a specific `clusterIP`, you cannot change it to a different value (including making it headless with `clusterIP: None`).

**Timeline:**
1. Build #80: Created Service with `clusterIP: <some-ip>` (old postgres Deployment setup)
2. Build #82: Tried to apply Service with `clusterIP: None` (new StatefulSet setup)
3. **Conflict**: Kubernetes rejects the change → deployment fails

### Manual Fix (One-time)
```bash
# Delete the old Service
kubectl delete service postgres -n bug-report-portal-dev

# Next Jenkins run will create the new Service
```

## Immutable Kubernetes Fields

### Services
- `spec.clusterIP` - Cannot change once set
- `spec.clusterIPs` - Cannot change once set
- `spec.ipFamilies` - Cannot change once set
- `spec.type` - Cannot change from ClusterIP → Headless

### StatefulSets
- `spec.serviceName` - Cannot change once set
- `spec.selector` - Cannot change once set

### Deployments
- `spec.selector` - Cannot change once set

## Prevention Strategy

**When migrating K8s resources:**
1. Use `kubectl delete <resource-type> <name> --ignore-not-found` to clean conflicting resources
2. Add a 2-3 second sleep between delete and apply
3. Automate cleanup in CI/CD pipeline instead of manual intervention

## Related Issues
- **PostgreSQL Deployment → StatefulSet**: Required cleanup of old Deployment + Service
- **Service type changes**: Requires delete + recreate

### Architecture Reference
For detailed information on pod communication, init containers, and StatefulSet architecture, see:
- [POSTGRES_STATEFULSET_LOCAL_TEST.md](POSTGRES_STATEFULSET_LOCAL_TEST.md) - Architecture & testing procedures
- [DEPLOY_TO_K8S.md](DEPLOY_TO_K8S.md) - Kubernetes deployment procedures

---

# DOCKER & SECURITY ISSUES

## Issue: Trivy Security Scan Failures (5 HIGH Vulnerabilities)

### Symptom
```
[Pipeline] Security Scan (Trivy)
Trivy found 5 HIGH severity vulnerabilities:
- CVE-2026-12143 (form-data 4.0.5)
- CVE-2026-5079 (multer 2.1.1)
- CVE-2026-12151 (undici 6.25.0)
- CVE-2026-48779 (ws 8.20.1)
- CVE-2026-48779 (undici in npm CLI)
Pipeline: FAILURE
```

### Root Causes
1. **Outdated npm dependencies**: Direct dependency versions had known CVEs
2. **npm CLI bundled vulnerabilities**: Node base image contains npm with bundled undici that has CVE
3. **Dev dependencies in production image**: Development packages scanned despite `--omit=dev`

### Solution

**Step 1: Update package.json (app repository)**
```bash
npm install form-data@4.0.6 multer@2.2.0 undici@6.27.0 ws@8.21.0 --save
git add package.json package-lock.json
git commit -m "security: fix 5 HIGH Trivy vulnerabilities"
git push origin master
```

**Step 2: Update Dockerfile (app repository) - BOTH stages**

In the **dependencies stage:**
```dockerfile
FROM node:22-alpine3.24 AS dependencies
RUN npm install -g npm@latest && apk update && apk upgrade
# ... rest of build
```

In the **runner stage:**
```dockerfile
FROM node:22-alpine3.24 AS runner
RUN npm install -g npm@latest && apk update && apk upgrade
# ... rest of build
```

**Step 3: Use `--omit=dev` in production build**
```dockerfile
RUN npm ci --omit=dev  # Exclude dev-only dependencies from production image
```

**Step 4: Verify npm audit shows no HIGH vulns**
```bash
npm audit --omit=dev
# Should show only MODERATE (dev-only) vulnerabilities
```

**Step 5: Commit and trigger new build**
```bash
git add Dockerfile
git commit -m "security: patch npm CLI and OS packages in Dockerfile"
git push origin master
```

### Why This Works
- **Step 1**: Fixes direct dependencies
- **Step 2**: Patches npm CLI's bundled packages (fixes undici CVE in npm)
- **Step 3**: Excludes dev-only packages from production image
- **Step 4**: Verification that only safe versions remain

### Prevention
- **Weekly audits**: Run `npm audit --omit=dev` on production code
- **Automated scanning**: CI/CD pipeline includes Trivy scan before each push
- **Base image updates**: Monitor Alpine Linux and Node.js security bulletins
- **Immediate action**: Upgrade vulnerabilities within 24-48 hours

### Related Issues
- Build #75-76: Failed Trivy scan (5 HIGH vulnerabilities)
- Build #77: Passed Trivy scan (0 HIGH/CRITICAL vulnerabilities)
- Build #92: Confirmed passing Trivy scan in production

---

# CI/CD PIPELINE ISSUES

## Issue: Kubernetes Rollout Timeout

### Symptom
```
[Pipeline] Deploy to Kubernetes
+ kubectl rollout status deployment/bug-report-portal-app -n bug-report-portal-dev --timeout=120s
Waiting for deployment to finish: 1 replicas updated, 1 of 1 ready
deadline exceeded
ERROR: Deployment rolled out, but exceeded 120s timeout
Pipeline: FAILURE (stage: Deploy)
```

### Root Cause
Pod startup sequence exceeds timeout threshold:
- **Image pull**: ~30 seconds (pulling Node.js image from Docker Hub)
- **npm install**: ~15 seconds (dependencies already in image via npm ci)
- **PostgreSQL init**: ~10 seconds (pg_isready polling via init container)
- **Prisma migrations**: ~30-60 seconds (database schema creation/updates)
- **App startup**: ~10 seconds (Express server initialization)
- **Total**: ~85-125 seconds (exceeds 120s default timeout)

### Solution

**Update k8sDeploy.groovy in shared library (v1.1)**

```groovy
// Before (too short)
kubectl rollout status deployment/${deploymentName} \
  -n ${namespace} \
  --timeout=120s

// After (sufficient for database init)
kubectl rollout status deployment/${deploymentName} \
  -n ${namespace} \
  --timeout=300s   # 5 minutes instead of 2 minutes
```

**Implementation:**
```bash
# In shared library repo
git -C /path/to/bugreportportal-sharedlib edit vars/k8sDeploy.groovy
# Change: --timeout=120s → --timeout=300s

git tag -a v1.1 -m "feat: increase rollout timeout to 300s for database init"
git push origin v1.1

# Update Jenkinsfile to use v1.1
@Library('bug-report-portal-lib@v1.1') _
```

### Why 300s?
```
Worst-case startup timeline:
├─ Image pull: 30s (if not cached)
├─ OS upgrade: 5s
├─ Prisma generation: 30s
├─ Init container: wait-for-postgres polling: 10s
├─ Prisma migrate deploy: 60s (large migrations)
├─ App startup: 10s
├─ K8s scheduling: 10s
├─ Rolling update: 5s
└─ Safety margin: 30s
   = ~190s typical, ~240s with variance
   Use 300s (5 min) for production reliability
```

### Optimization Tips
- **Docker layer caching**: Use buildkit to cache npm install layers
- **Parallel init containers**: Non-dependent init containers can run simultaneously
- **Pre-run migrations**: Consider running Prisma migrations in CI stage (before deployment)
- **Monitor trend**: Track actual startup time across builds to detect regressions

### Prevention
- **Measure baseline**: Time first deployment startup end-to-end
- **Add buffer**: Use formula: `baseline + 60s overhead + 30s safety`
- **Alert on regression**: Set up monitoring for deployment latency
- **Test locally**: Use Kind cluster to measure startup times before production

### Related Issues
- Build #78: Timeout exceeded at 126 seconds
- Build #79-80: Passed with extended timeout
- Build #92: Confirmed passing with 300s timeout

---

## Issue: SonarQube Configuration Not Found

### Symptom
```
[Pipeline] SonarQube Scan
+ cd devops
+ cat sonar-project.properties
cat: sonar-project.properties: No such file or directory
ERROR: Unable to read sonar-project.properties
Pipeline: FAILURE (stage: Quality Gates)
```

### Root Cause
- **Config location moved**: `sonar-project.properties` belongs in app repo (where source code is)
- **Shared library mismatch**: v1.0 looked for config in `devops/` directory
- **Incorrect assumption**: DevOps repo shouldn't contain app-specific configurations

### Solution

**Step 1: Move config to app repository**
```bash
# From devops repo
rm /Users/demu/bug-report-portal-devops/sonar-project.properties
git add -A
git commit -m "chore: remove sonar-project.properties (moved to app repo)"

# In app repo
cat > /Users/demu/bugreportportal/sonar-project.properties << 'EOF'
sonar.projectKey=bug-report-portal
sonar.projectName=Bug Report Portal
sonar.sources=.
sonar.tests=tests
sonar.test.inclusions=tests/**/*.test.js
sonar.javascript.lcov.reportPaths=coverage/lcov.info
sonar.coverage.exclusions=tests/**,printReports.js,prisma/**,views/**,public/**,seed-demo.js
EOF

git add sonar-project.properties
git commit -m "chore: add SonarQube configuration to app repo"
git push origin master
```

**Step 2: Update shared library v1.1**

In `vars/sonarScan.groovy`:
```groovy
// Before (v1.0)
cd(config.workDir || 'devops')
sh 'cat sonar-project.properties'

// After (v1.1)
String workDir = config.workDir ?: 'app'
sh(script: "cd ${workDir} && cat sonar-project.properties", returnStdout: true)
```

**Step 3: Create library tag**
```bash
cd /Users/demu/bugreportportal-sharedlib
git tag -a v1.1 -m "feat: update sonarScan to work with app-repo sonar-project.properties"
git push origin v1.1
```

**Step 4: Update Jenkinsfile**
```groovy
// Before
@Library('bug-report-portal-lib@v1.0') _

// After
@Library('bug-report-portal-lib@v1.1') _
```

### Separation of Concerns
```
CORRECT STRUCTURE:

App Repository (bugreportportal/)
├── src/
├── tests/
├── Dockerfile
├── package.json
├── sonar-project.properties      ← App config (moved here)
└── .eslintrc                      ← App config

DevOps Repository (bug-report-portal-devops/)
├── k8s/
├── Jenkinsfile
├── README.md
└── deployment configs only        ← NO app configs
```

### Related Issues
- Build #91: Failed with "No such file or directory"
- Build #92: Passed after moving config and updating to v1.1

---

## Issue: Jenkins Approval Gate Timeout Not Enforced

### Symptom
```
[Pipeline] Deployment Approval
Waiting for approval...
(stays waiting indefinitely, no auto-abort after 30 minutes)
```

### Root Cause
- **Missing timeout wrapper**: `input()` step doesn't have timeout by default
- **Manual approval required**: Without timeout, Jenkins waits forever for human decision
- **No failure safety**: Stuck build consumes executor indefinitely

### Solution

**Jenkinsfile Stage (Deployment Approval)**
```groovy
stage('Deployment Approval') {
  steps {
    script {
      def env_name = params.TARGET_ENV.toUpperCase()
      currentBuild.displayName = "#${BUILD_NUMBER} - Approving ${env_name}"
      
      try {
        // 30-minute timeout: Pipeline auto-aborts if not approved in time
        timeout(time: 30, unit: 'MINUTES') {
          input(
            message: "Approve deployment to ${env_name} environment?",
            ok: "✓ Proceed with ${env_name}",
            submitter: null  // Allow any Jenkins user to approve
          )
        }
        
        echo "✓ Deployment approved - proceeding with rollout..."
        currentBuild.displayName = "#${BUILD_NUMBER} - ${env_name} ✓ Approved"
        
      } catch (err) {
        // Timeout or user rejection
        currentBuild.result = 'ABORTED'
        currentBuild.displayName = "#${BUILD_NUMBER} - ${env_name} ✗ Rejected"
        error("❌ Deployment rejected or approval timed out (30 min deadline)")
      }
    }
  }
}
```

### Key Features
- **30-minute timeout**: Adequate response time for on-call engineers
- **Auto-abort**: Pipeline automatically stops if no approval within deadline
- **Clear messaging**: Console shows exact reason for abort
- **Status tracking**: Build display shows approval result for audit trail
- **Safe default**: Prevents runaway deployments from forgotten approvals

### Why This Matters (Production Safety)
```
WITHOUT timeout:
├─ Build waits forever
├─ Executor held indefinitely
├─ Jenkins resources consumed
├─ Pipeline appears "stuck" to team
└─ Risk: Approval forgotten, stale code deployed hours/days later

WITH 30-min timeout:
├─ On-call engineer notified immediately
├─ Has 30 minutes to respond (reasonable timeframe)
├─ If not approved, build automatically stops
├─ Executor released for other work
├─ Clear audit trail: Who approved? When?
└─ Safe: Never deploys forgotten approvals
```

### Prevention
- **Document timeout**: Make 30 minutes a team standard
- **Alert integration**: Send Slack/email when approval gate triggered
- **Submitter tracking**: Consider requiring specific approvers (e.g., on-call engineer)
- **Audit logging**: Keep build history for compliance/incident review

### Related Issues
- Build #92: Approval gate tested and working with timeout

---

## Issue: Jenkins GString Interpolation in Stage Names

### Symptom
```
org.codehaus.groovy.control.MultipleCompilationErrorsException: 
  startup failed:
WorkflowScript: 209: Expected string literal @ line 209, column 11.
  stage("Deployment Approval (${params.TARGET_ENV.toUpperCase()})") {
        ^
1 error
```

### Root Cause
- **Jenkins Declarative Pipeline limitation**: Stage names must be static strings
- **Groovy vs. Jenkins DSL**: Groovy supports GString (`${}` interpolation), but Jenkins pipeline parser doesn't
- **Compile-time vs. runtime**: Stage names evaluated at parse time, parameters available only at runtime

### Solution (Use `currentBuild.displayName` instead)

**What DOESN'T work (causes error):**
```groovy
// ❌ ERROR: GString in stage name not allowed
stage("Deployment Approval (${params.TARGET_ENV})") {  // Causes parse error!
  steps { ... }
}
```

**What WORKS (correct approach):**
```groovy
// ✅ CORRECT: Static stage name
stage('Deployment Approval') {  // Keep stage name static
  steps {
    script {
      def env_name = params.TARGET_ENV.toUpperCase()
      
      // Set dynamic display name (shown in Jenkins UI)
      currentBuild.displayName = "#${BUILD_NUMBER} - Approving ${env_name}"
      
      try {
        timeout(time: 30, unit: 'MINUTES') {
          input(
            message: "Approve deployment to ${env_name} environment?",
            ok: "✓ Proceed with ${env_name}"
          )
        }
        
        // Update display after approval
        currentBuild.displayName = "#${BUILD_NUMBER} - ${env_name} ✓ Approved"
        
      } catch (err) {
        currentBuild.displayName = "#${BUILD_NUMBER} - ${env_name} ✗ Rejected"
        error('Deployment rejected or timed out')
      }
    }
  }
}
```

### How It Works
```
Jenkins UI Display:

Build List View:
  #92 - DEV ✓ Approved          ← currentBuild.displayName (dynamic)
  #91 - STAGING ✗ Rejected      ← Updated at runtime
  #90 - DEV ✓ Approved
  
Stage View:
  Stage: Deployment Approval    ← stage name (static, required)
  Status: ABORTED (after 30 min timeout)
```

### Declarative Pipeline Limitations
```
STATIC (Allowed):
├─ stage('Deploy App')  ← No interpolation
├─ parameters { ... }
├─ environment { PATH = '/usr/bin:$PATH' }  ← Simple vars only
└─ triggers { ... }

DYNAMIC (Not allowed in declarative):
├─ stage("Deploy ${target}")  ← ❌ GString not allowed
├─ environment { IMG = "${params.REPO}/${params.TAG}" }  ← ❌ Complex expressions
└─ triggers { ... }

DYNAMIC (Must use script block):
├─ script {
│   def stageName = "Deploy ${target}"  ← ✅ Works in script
│   currentBuild.displayName = stageName  ← ✅ Updates UI display
│   ...
└─ }
```

### Where GString IS Allowed
```groovy
pipeline {
  agent any
  parameters {
    string(name: 'TARGET_ENV', defaultValue: 'DEV')
  }
  
  stages {
    stage('Static Stage Name') {  // ✅ No interpolation
      steps {
        script {
          // ✅ GString OK here (inside script block)
          def env_name = "${params.TARGET_ENV.toUpperCase()}"
          echo "Deploying to: ${env_name}"
          
          // ✅ GString OK here
          currentBuild.displayName = "#${BUILD_NUMBER} - ${env_name}"
          
          // ✅ GString OK here
          sh "echo Deploy to ${env_name}"
        }
      }
    }
  }
}
```

### Prevention
- **Learn Jenkins DSL limits**: Stage names and properties must be static
- **Use `script` blocks**: Move interpolation into `script {}` sections
- **currentBuild object**: Use for dynamic display, description, results
- **Test in Jenkins**: Always validate Groovy syntax in actual Jenkins (IDE may be permissive)

### Related Issues
- Initial implementation attempt failed with GString in stage name
- Corrected by moving dynamic content to `currentBuild.displayName`

---

# SUMMARY OF SESSION ISSUES & FIXES

| Build | Issue | Cause | Solution | Status |
|-------|-------|-------|----------|--------|
| #75-76 | Trivy vulnerabilities (5 HIGH) | Outdated npm packages + npm CLI | Updated deps, patched npm, npm ci --omit=dev | ✅ Fixed |
| #78 | Rollout timeout (120s < 126s) | Pod startup includes Prisma migrations | Increased timeout to 300s | ✅ Fixed |
| #80 | SonarQube config not found | Config in devops repo, v1.0 looked there | Moved to app repo, updated v1.1 | ✅ Fixed |
| #82 | Service immutable conflict | Tried to change clusterIP to None | Manual delete, rebuilt for StatefulSet | ✅ Fixed |
| #85-90 | Data loss risk | Deployment (ephemeral), no PVC | Migrated to StatefulSet with volumeClaimTemplates | ✅ Fixed |
| #92 | All checks passed | Integration successful | Full E2E pipeline validated | ✅ Verified |

---

# ADDITIONAL RESOURCES

- [ERROR_FIXES.md](ERROR_FIXES.md) - Jenkins container, shell syntax, environment variable errors
- [BUILD_FAILURES.md](BUILD_FAILURES.md) - Docker build, K8s deployment, Jenkins container issues
- [QUICK_REFERENCE.md](QUICK_REFERENCE.md) - Common commands and troubleshooting quick fixes
- [POSTGRES_STATEFULSET_LOCAL_TEST.md](POSTGRES_STATEFULSET_LOCAL_TEST.md) - Local testing procedures
- [JENKINS_PIPELINE_GUIDE.md](JENKINS_PIPELINE_GUIDE.md) - Complete pipeline architecture and each stage
