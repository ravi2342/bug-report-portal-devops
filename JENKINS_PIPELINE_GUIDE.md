# Jenkins Pipeline - Comprehensive Stage Guide

This document provides an in-depth explanation of each stage in the Bug Report Portal CI/CD pipeline, including what happens, why it matters, and how it contributes to the overall deployment process.

## Table of Contents

1. [Pipeline Architecture Overview](#pipeline-architecture-overview)
2. [Pipeline Configuration & Parameters](#pipeline-configuration--parameters)
3. [Environment & Options](#environment--options)
4. [Stage-by-Stage Breakdown](#stage-by-stage-breakdown)
5. [Shared Library Functions](#shared-library-functions)
6. [Post-Action Handling](#post-action-handling)
7. [Build Flow Diagram](#build-flow-diagram)
8. [Error Handling Strategy](#error-handling-strategy)

---

## Pipeline Architecture Overview

The Jenkins pipeline is a **Declarative Pipeline** using a **Shared Library** for reusable components:

```
Jenkinsfile (Main orchestration)
    ↓
@Library('bug-report-portal-lib') (Shared Library from GitHub)
    ↓
vars/ (Shared functions)
    ├── gitCheckout.groovy
    ├── preflightChecks.groovy
    ├── installDeps.groovy
    ├── prismaGenerate.groovy
    ├── lintAndTest.groovy
    ├── sonarScan.groovy
    ├── dockerBuild.groovy
    ├── trivyScan.groovy
    ├── dockerPush.groovy
    ├── k8sDeploy.groovy
    └── notifyStatus.groovy
```

**Why Shared Library?**
- ✅ Reusable code across multiple pipelines
- ✅ Centralized maintenance (one change fixes all pipelines)
- ✅ Versioning and backward compatibility
- ✅ Cleaner Jenkinsfile (orchestration vs. implementation)
- ✅ Team collaboration (library maintainers separate from pipeline users)

---

## Pipeline Configuration & Parameters

### Build Parameters

```groovy
properties([
  parameters([
    string(name: 'BRANCH', defaultValue: 'master', ...)
    string(name: 'GITHUB_REPO_URL', defaultValue: 'https://github.com/ravi2342/bugreportportal.git', ...)
    string(name: 'DOCKER_IMAGE_PATH', defaultValue: 'demu147/bugreportportal', ...)
    booleanParam(name: 'DO_PUSH', defaultValue: false, ...)
    booleanParam(name: 'DO_DEPLOY', defaultValue: false, ...)
    booleanParam(name: 'RUN_SONAR', defaultValue: false, ...)
    string(name: 'REGISTRY_CREDENTIALS_ID', defaultValue: 'dockerhub-creds-pat', ...)
    string(name: 'SONAR_HOST_URL', defaultValue: 'http://sonarqube:9000', ...)
    string(name: 'SONAR_PROJECT_KEY', defaultValue: 'bug-report-portal', ...)
    string(name: 'SONAR_TOKEN_CREDENTIALS_ID', defaultValue: 'sonar-token', ...)
    choice(name: 'TARGET_ENV', choices: ['dev'], ...)
  ])
])
```

| Parameter | Type | Default | Purpose | Use Case |
|-----------|------|---------|---------|----------|
| `BRANCH` | String | master | Git branch to checkout | Build from feature/dev branches |
| `GITHUB_REPO_URL` | String | bugreportportal repo | App repository | Use internal mirror if needed |
| `DOCKER_IMAGE_PATH` | String | demu147/bugreportportal | Docker Hub path | Change for private registry |
| `DO_PUSH` | Boolean | false | Push image to registry | Only when image is stable |
| `DO_DEPLOY` | Boolean | false | Deploy to Kubernetes | Only on ready builds |
| `RUN_SONAR` | Boolean | false | Run code quality scan | Enable for feature branches |
| `REGISTRY_CREDENTIALS_ID` | String | dockerhub-creds-pat | Jenkins credentials for Docker | Reference existing credentials |
| `SONAR_HOST_URL` | String | http://sonarqube:9000 | SonarQube server URL | Cloud: https://sonarcloud.io |
| `SONAR_PROJECT_KEY` | String | bug-report-portal | SonarQube project key | Must exist in SonarQube |
| `SONAR_TOKEN_CREDENTIALS_ID` | String | sonar-token | Jenkins credentials for Sonar | Reference existing credentials |
| `TARGET_ENV` | Choice | dev | Deployment environment | Matches key in deploy-config.yaml |

### How to Run Pipeline

**Example 1: Build Only (No Push, No Deploy)**
```
Branch: master
DO_PUSH: false
DO_DEPLOY: false
RUN_SONAR: false
→ Builds image locally, runs quality gates, skips registry push and deployment
```

**Example 2: Build & Push (Stable Release)**
```
Branch: master
DO_PUSH: true
DO_DEPLOY: false
RUN_SONAR: false
→ Builds image, runs quality gates, pushes to Docker Hub (credentials needed)
```

**Example 3: Full Pipeline (Deploy to Dev)**
```
Branch: master
DO_PUSH: true
DO_DEPLOY: true
RUN_SONAR: true
TARGET_ENV: dev
→ Complete CI/CD: build → quality gates → sonar → docker push → kubernetes deploy
```

**Example 4: Feature Branch Testing**
```
Branch: feature/new-comments
DO_PUSH: false
DO_DEPLOY: false
RUN_SONAR: true
→ Tests new feature: build → quality gates → sonar (fail fast)
```

---

## Environment & Options

### Environment Variables

```groovy
environment {
    IMAGE_REGISTRY = 'docker.io'
    APP_VERSION = sh(script: "node -e \"const p=require('./app/package.json'); console.log(p.version)\" 2>/dev/null || echo '1.0.0'", returnStdout: true).trim()
}
```

| Variable | Value | Purpose |
|----------|-------|---------|
| `IMAGE_REGISTRY` | docker.io | Docker Hub registry URL |
| `APP_VERSION` | package.json version | Semantic versioning from app |
| `IMAGE_TAG` | `docker.io/demu147/bugreportportal:1.0.0-42` | Full image reference with build number |

**IMAGE_TAG Format:**
```
docker.io/{DOCKER_IMAGE_PATH}:{APP_VERSION}-{BUILD_NUMBER}
                              ↓
                    1.0.0-42 = semantic version + Jenkins build #
```

### Pipeline Options

```groovy
options {
    timestamps()           # Add timestamps to console log
    timeout(time: 1, unit: 'HOURS')  # Abort if pipeline exceeds 1 hour
    buildDiscarder(logRotator(numToKeepStr: '10'))  # Keep last 10 builds
}
```

| Option | Behavior |
|--------|----------|
| `timestamps()` | All console output has `HH:MM:SS` prefix |
| `timeout(1 HOUR)` | Pipeline auto-fails if running > 1 hour (prevents stuck builds) |
| `buildDiscarder` | Deletes old builds to save disk (keeps 10 builds) |

---

## Stage-by-Stage Breakdown

### STAGE 1: Clean Workspace

**Purpose:** Fresh start for each build

```groovy
stage('Clean Workspace') {
  steps {
    script {
      deleteDir()
      echo "✓ Workspace cleaned"
    }
  }
}
```

**What Happens:**
1. `deleteDir()` - Deletes entire Jenkins workspace directory
2. Removes all files from previous build
3. No residual code, artifacts, or temp files

**Why It Matters:**
- ✅ Prevents contamination from previous builds
- ✅ Ensures reproducible builds (no stale files)
- ✅ Avoids permission issues with old files
- ✅ Clears Docker build cache pollution

**Execution Time:** ~1-2 seconds

**When It Fails:** Rarely - only if Jenkins lacks write permissions to workspace

---

### STAGE 2: Checkout Application

**Purpose:** Get the latest application source code

```groovy
stage('Checkout Application') {
  steps {
    script {
      gitCheckout(
        branch: params.BRANCH,
        repoUrl: params.GITHUB_REPO_URL,
        targetDir: 'app'
      )
    }
  }
}
```

**What Happens:**
1. Calls `gitCheckout()` shared library function
2. Clones `GITHUB_REPO_URL` repository
3. Checks out specified `BRANCH`
4. Places code in `app/` subdirectory
5. Jenkins tracks commit SHA for reproducibility

**Example:**
```
Branch: master
Repository: https://github.com/ravi2342/bugreportportal.git
           ↓ Clone
Workspace/app/
  ├── src/
  ├── public/
  ├── package.json
  ├── Dockerfile
  ├── prisma/
  └── .env.example
```

**Why It Matters:**
- ✅ Gets source code needed for build
- ✅ Allows building from any branch (master, feature, release)
- ✅ Jenkins records exact commit SHA in build metadata

**Execution Time:** ~5-10 seconds (depends on network + repo size)

**Common Failures:**
- ❌ Network timeout → Retry connection
- ❌ Invalid branch → Check BRANCH parameter
- ❌ SSH key not configured → Use HTTPS or add credentials

---

### STAGE 3: Checkout DevOps

**Purpose:** Get Kubernetes manifests and deployment configuration

```groovy
stage('Checkout DevOps') {
  steps {
    script {
      gitCheckout(
        branch: 'master',
        repoUrl: 'https://github.com/ravi2342/bug-report-portal-devops.git',
        targetDir: 'devops'
      )
      
      // Compute IMAGE_TAG and set build display name
      def dockerImagePath = params.DOCKER_IMAGE_PATH ?: 'demu147/bugreportportal'
      def appVersion = sh(script: "node -e \"const p=require('./app/package.json'); console.log(p.version)\" 2>/dev/null || echo '1.0.0'", returnStdout: true).trim()
      env.IMAGE_TAG = "docker.io/${dockerImagePath}:${appVersion}-${BUILD_NUMBER}"
      
      currentBuild.displayName = "#${BUILD_NUMBER} - ${env.IMAGE_TAG}"
      currentBuild.description = """
        Branch: ${params.BRANCH}
        Push: ${params.DO_PUSH}
        Deploy: ${params.DO_DEPLOY}
        SonarQube: ${params.RUN_SONAR}
      """.stripIndent()
    }
  }
}
```

**What Happens:**
1. Clones DevOps repository (always from master)
2. Places Kubernetes manifests in `devops/` directory
3. Reads `app/package.json` version
4. Computes `IMAGE_TAG` with version + build number
5. Sets Jenkins build display name for easy identification

**Example Output:**
```
Workspace/
  ├── app/           (Application source)
  ├── devops/        (K8s manifests)
  │   ├── k8s/
  │   ├── deploy-config.yaml
  │   ├── Jenkinsfile
  │   └── JENKINS_PIPELINE_GUIDE.md

IMAGE_TAG = "docker.io/demu147/bugreportportal:1.0.0-42"
                                               ↑      ↑
                                        Version    Build #

Build Display: "#42 - docker.io/demu147/bugreportportal:1.0.0-42"
```

**Why It Matters:**
- ✅ Gets Kubernetes manifests needed for deployment
- ✅ IMAGE_TAG critical for connecting app to K8s
- ✅ Build display name helps identify builds in Jenkins UI
- ✅ VERSION ensures image versioning matches semantic versioning

**Execution Time:** ~3-5 seconds

**Key Point:** IMAGE_TAG is computed AFTER both checkouts (needs app version from app/, needs devops for manifest structure)

---

### STAGE 4: Preflight Checks

**Purpose:** Verify Jenkins environment and dependencies are ready

```groovy
stage('Preflight Checks') {
  steps {
    script {
      preflightChecks()
    }
  }
}
```

**Shared Function Pseudo-Code:**
```groovy
def call() {
    echo "🔍 Running preflight checks..."
    
    // Check required tools
    sh("docker --version")           // Docker daemon available?
    sh("kubectl --version")          // kubectl CLI installed?
    sh("node --version")             // Node.js available?
    sh("git --version")              // Git available?
    sh("prisma --version")           // Prisma CLI available?
    
    // Check Docker daemon
    sh("docker ps")                  // Can connect to Docker daemon?
    
    // Check Kubernetes connectivity
    sh("kubectl config current-context")  // K8s cluster configured?
    sh("kubectl get nodes")          // K8s cluster accessible?
    
    echo "✓ All preflight checks passed"
}
```

**What Happens:**
1. Verifies Docker is installed and running
2. Verifies kubectl is installed
3. Verifies Node.js is available
4. Verifies git is available
5. Checks kubectl can connect to Kubernetes cluster
6. Lists Kubernetes nodes (proves cluster is accessible)

**Example Success Output:**
```
🔍 Running preflight checks...
Docker version 25.0.1
Client Version: v1.31.0
v20.17.0
git version 2.42.0
5.2.8
Docker containers running fine...
Current context: kind-bug-report-portal
node1   Ready    control-plane,master
node2   Ready    worker
✓ All preflight checks passed
```

**Example Failure Output:**
```
❌ Cannot connect to Docker daemon
Reason: Jenkins user lacks permission to /var/run/docker.sock
Fix: usermod -aG docker jenkins
```

**Why It Matters:**
- ✅ Fail early if environment is misconfigured
- ✅ Prevents wasting time on build if tools missing
- ✅ Ensures reproducible build environment
- ✅ Catches permission issues upfront

**Execution Time:** ~5-10 seconds

**Common Failures:**
- ❌ Docker daemon not running → `systemctl start docker`
- ❌ Jenkins user not in docker group → `sudo usermod -aG docker jenkins`
- ❌ kubectl config missing → `kubectl config use-context kind-bug-report-portal`
- ❌ Kubernetes cluster unreachable → Network issue or cluster down

---

### STAGE 5: Setup (Dependencies & Build)

**Purpose:** Install Node.js dependencies and generate Prisma client

```groovy
stage('Setup') {
  steps {
    script {
      try {
        installDeps()
        prismaGenerate()
      } catch (Exception e) {
        error("Setup failed: ${e.message}")
      }
    }
  }
}
```

**installDeps() - Pseudo-Code:**
```groovy
def call() {
    echo "📦 Installing dependencies..."
    dir('app') {
        sh("npm ci --prefer-offline --no-audit")  // Same versions as package-lock.json
    }
    echo "✓ Dependencies installed"
}
```

**prismaGenerate() - Pseudo-Code:**
```groovy
def call() {
    echo "🔧 Generating Prisma client..."
    dir('app') {
        sh("npx prisma generate")  // Generate @prisma/client from schema.prisma
    }
    echo "✓ Prisma client generated"
}
```

**What Happens:**

**Part 1: installDeps()**
1. Changes to `app/` directory
2. Runs `npm ci` (clean install)
   - Uses exact versions from `package-lock.json`
   - Deterministic (reproducible)
   - Faster than `npm install`
   - Designed for CI/CD
3. Installs all dependencies:
   - express, prisma, dotenv, bcrypt, etc.
   - DevDependencies: jest, eslint, prettier, etc.

**Part 2: prismaGenerate()**
1. Reads `app/prisma/schema.prisma`
2. Generates TypeScript types for database models
3. Creates `node_modules/.prisma/client/`
4. Enables type-safe database queries

**Example:**
```
app/prisma/schema.prisma
├── model BugReport { ... }
├── model Comment { ... }
└── model ActivityLog { ... }
           ↓ prisma generate
node_modules/.prisma/client/
├── index.d.ts       (TypeScript types)
├── runtime/index.js  (Runtime code)
└── query-engine    (Database query engine)
```

**Why It Matters:**
- ✅ `npm ci` ensures reproducible builds (same deps every time)
- ✅ Prisma client is required for app to function
- ✅ Type checking depends on generated types
- ✅ Linting and tests need this setup

**Execution Time:** ~20-30 seconds (depends on npm cache)

**Common Failures:**
- ❌ `npm ERR! 404` → Package not found (corrupt package.json or network)
- ❌ `prisma ERR! Cannot find schema.prisma` → Prisma config missing
- ❌ `ERR! ERESOLVE unable to resolve dependency tree` → Version conflict
- ❌ Disk full → Not enough space for node_modules (typically 500MB+)

**Error Handling:**
```groovy
try {
  installDeps()
  prismaGenerate()
} catch (Exception e) {
  error("Setup failed: ${e.message}")  // Fails entire pipeline
}
```

---

### STAGE 6: Quality Gates (Lint & Tests)

**Purpose:** Code quality checks and automated tests

```groovy
stage('Quality Gates') {
  steps {
    script {
      lintAndTest()
    }
  }
}
```

**lintAndTest() - Pseudo-Code:**
```groovy
def call() {
    echo "🔍 Running quality gates..."
    dir('app') {
        // LINTING
        echo "📋 Running ESLint..."
        sh("npm run lint")           // Check code style, detect issues
        
        // UNIT TESTS
        echo "✅ Running unit tests..."
        sh("npm test")               // Jest tests
        
        // TEST COVERAGE
        echo "📊 Checking coverage..."
        sh("npm run test:coverage")  // Coverage reports (if configured)
    }
    echo "✓ Quality gates passed"
}
```

**What Happens:**

**Part 1: Linting (ESLint)**
1. Reads `.eslintrc.js` or `.eslintrc.json`
2. Scans all JavaScript/TypeScript files
3. Checks code style (formatting, naming conventions)
4. Detects common errors (unused variables, missing semicolons)
5. Reports issues and fails if errors found

**Example Issues Caught:**
```javascript
// ❌ Unused variable
const unused = 42;

// ❌ Missing error handling
const data = fs.readFileSync('file.txt');

// ❌ Incorrect async/await
async function broken() {
  fetch(url)  // Missing await
}

// ❌ Type errors (TypeScript)
function add(a: number, b: number) {
  return a + b;
}
add("1", "2")  // ❌ Strings passed instead of numbers
```

**Part 2: Unit Tests (Jest)**
1. Discovers test files (`*.test.js`, `*.spec.js`)
2. Runs all test suites
3. Reports pass/fail for each test
4. Generates coverage reports
5. Fails if any test fails

**Example Test Suite:**
```javascript
describe('Comment Management', () => {
  test('should create new comment', async () => {
    const comment = await createComment({
      reportId: 1,
      text: "Found issue with...",
      author: "john@example.com"
    });
    expect(comment).toHaveProperty('id');
  });
  
  test('should fail if missing required fields', async () => {
    expect(() => createComment({ text: "..." })).toThrow();
  });
});
```

**Why It Matters:**
- ✅ Catches bugs before deployment
- ✅ Enforces code style for team consistency
- ✅ Ensures tests exist for features
- ✅ Prevents regression (old bugs don't resurface)
- ✅ Fail fast (catch issues before Docker build)

**Execution Time:** ~30-60 seconds (depends on test count)

**Common Failures:**
- ❌ ESLint errors → Fix code style issues
- ❌ Test failures → Fix logic bugs
- ❌ Coverage too low → Add more tests (if threshold enforced)

**Example Test Failure:**
```
FAIL  src/services/reportService.test.js
  ● BugReport › should assign bug to user

  Expected: {"status": "assigned", "assignee": "john"}
  Received: {"status": "open", "assignee": null}

  at Object.<anonymous> (src/services/reportService.test.js:45:12)
```

---

### STAGE 7: SonarQube Scan (OPTIONAL)

**Purpose:** Code quality and security analysis from SonarQube

```groovy
stage('SonarQube Scan') {
  when {
    expression { params.RUN_SONAR && params.SONAR_HOST_URL?.trim() }
  }
  steps {
    script {
      sonarScan(
        hostUrl: params.SONAR_HOST_URL,
        projectKey: params.SONAR_PROJECT_KEY,
        tokenCredId: params.SONAR_TOKEN_CREDENTIALS_ID,
        waitForQualityGate: true
      )
    }
  }
}
```

**Condition:** Only runs if:
- `RUN_SONAR` parameter = true
- `SONAR_HOST_URL` is not empty

**sonarScan() - Pseudo-Code:**
```groovy
def call(Map config) {
    echo "🔐 Running SonarQube analysis..."
    dir('app') {
        withCredentials([string(credentialsId: config.tokenCredId, variable: 'SONAR_TOKEN')]) {
            sh("""
                npx sonar-scanner \
                  -Dsonar.projectKey=${config.projectKey} \
                  -Dsonar.host.url=${config.hostUrl} \
                  -Dsonar.login=${SONAR_TOKEN} \
                  -Dsonar.sources=src \
                  -Dsonar.tests=src \
                  -Dsonar.test.inclusions=**/*.test.js
            """)
        }
        
        if (config.waitForQualityGate) {
            waitForQualityGate(abortPipeline: true)  // Wait for gate verdict
        }
    }
    echo "✓ SonarQube analysis complete"
}
```

**What Happens:**

1. **Authenticate** to SonarQube using token credentials
2. **Scan** codebase for:
   - Code duplicates
   - Security vulnerabilities (SQL injection, XSS, auth issues)
   - Code smells (complexity, anti-patterns)
   - Test coverage gaps
   - Technical debt

3. **Report** in SonarQube dashboard:
   - Overall quality grade (A-F)
   - Issues count by severity
   - Code coverage percentage
   - Lines of code

4. **Quality Gate** - Checks pass/fail criteria:
   ```
   ✅ Coverage ≥ 80%
   ❌ New bugs = 0 FAILED (6 new issues)
   ✅ Duplicated code ≤ 3%
   ```

**Example SonarQube Issues Found:**
```
CRITICAL - SQL Injection vulnerability in reportService.js:45
  SELECT * FROM reports WHERE id = ${id}
  FIX: Use parameterized queries

HIGH - Cross-site scripting in views/reportDetail.html:12
  <div>{report.description}</div>
  FIX: Sanitize user input

MEDIUM - Hard-coded password in .env.example
  ADMIN_PASSWORD=admin123
  FIX: Use environment variables

LOW - Code duplication in commentService.js
  Lines 12-18 duplicate reportService.js:45-51
  FIX: Extract to shared utility
```

**Why It Matters:**
- ✅ Catches security vulnerabilities (OWASP Top 10)
- ✅ Tracks code quality over time
- ✅ Enforces security gates (gate = pass/fail criteria)
- ✅ Identifies technical debt
- ✅ Blocks deployment if quality below threshold
- ✅ Reports trends (improving or declining)

**Execution Time:** ~30-60 seconds (depends on codebase size)

**When to Enable:**
- ✅ Production branches (master, release)
- ✅ Large features (security critical)
- ✅ Team requires quality assurance
- ❌ Skip for: quick feature branches, local testing

**Quality Gate Failure:**
```
❌ Quality Gate failed
   Coverage < 80% (73%)
   New bugs introduced: 3
   
Action: Fix tests, resolve issues, push new commit
```

---

### STAGE 8: Docker Build

**Purpose:** Create Docker image from application source

```groovy
stage('Build Docker Image') {
  steps {
    script {
      dockerBuild(
        imageTag: "${env.IMAGE_TAG}",
        dockerfile: 'app'
      )
    }
  }
}
```

**dockerBuild() - Pseudo-Code:**
```groovy
def call(Map config) {
    echo "🐳 Building Docker image: ${config.imageTag}..."
    
    dir(config.dockerfile) {  // cd app/
        sh("""
            docker build \
              -t ${config.imageTag} \
              -f Dockerfile \
              --no-cache \
              .
        """)
    }
    
    sh("docker images | grep -E '${config.imageTag}|REPOSITORY'")  // Show image
    echo "✓ Docker image built: ${config.imageTag}"
}
```

**What Happens:**

1. **Reads** `app/Dockerfile`
2. **Executes** Dockerfile instructions:
   - Base image: `FROM node:20-alpine`
   - Working directory: `WORKDIR /app`
   - Copy source: `COPY . .`
   - Install deps: `npm ci`
   - Generate Prisma: `npx prisma generate`
   - Expose port: `EXPOSE 3000`
   - Start app: `CMD ["node", "src/server.js"]`

3. **Layers** created and cached:
   ```
   Layer 1: Base image (node:20-alpine) - ~150MB
   Layer 2: System deps (apk add...) - +50MB
   Layer 3: App code (COPY . .) - +10MB
   Layer 4: npm packages (npm ci) - +200MB
   Layer 5: Prisma client (prisma generate) - +5MB
   Total: ~415MB
   ```

4. **Tags** image with IMAGE_TAG:
   ```
   docker.io/demu147/bugreportportal:1.0.0-42
   ```

5. **Verifies** image created:
   ```
   REPOSITORY                      TAG         IMAGE ID      SIZE
   demu147/bugreportportal         1.0.0-42    abc123def456  415MB
   ```

**Example Dockerfile:**
```dockerfile
FROM node:20-alpine
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production
COPY . .
RUN npx prisma generate
EXPOSE 3000
HEALTHCHECK --interval=30s --timeout=3s \
  CMD node -e "require('http').get('http://localhost:3000/login', (r) => {if (r.statusCode !== 200) throw new Error(r.statusCode)})"
CMD ["node", "src/server.js"]
```

**Why It Matters:**
- ✅ Creates deployable artifact (image)
- ✅ Encapsulates application + dependencies
- ✅ Enables consistent environment (dev == prod)
- ✅ Docker image is input for security scan
- ✅ Image is deployed to Kubernetes

**Execution Time:** ~60-120 seconds (first build slower due to cache)

**Build Output Example:**
```
Sending build context to Docker daemon  250MB
Step 1/12 : FROM node:20-alpine
Step 2/12 : WORKDIR /app
Step 3/12 : COPY package*.json ./
Step 4/12 : RUN npm ci --only=production
Step 5/12 : COPY . .
Step 6/12 : RUN npx prisma generate
Step 7/12 : EXPOSE 3000
Step 8/12 : HEALTHCHECK --interval=30s
Step 9/12 : CMD ["node", "src/server.js"]
Successfully built abc123def456
Successfully tagged demu147/bugreportportal:1.0.0-42
```

**Common Failures:**
- ❌ `COPY package*.json ./` → package.json not found (wrong working dir)
- ❌ `npm ERR! 404` → Package not found during npm ci
- ❌ `Docker daemon not running` → Start Docker: `systemctl start docker`
- ❌ `Disk full` → Clean Docker images: `docker image prune -a`

---

### STAGE 9: Security Scan (Trivy)

**Purpose:** Scan Docker image for vulnerabilities

```groovy
stage('Security Scan') {
  steps {
    script {
      trivyScan(
        imageTag: "${env.IMAGE_TAG}",
        failOnSeverity: true
      )
    }
  }
}
```

**trivyScan() - Pseudo-Code:**
```groovy
def call(Map config) {
    echo "🔒 Running Trivy security scan..."
    
    sh("""
        trivy image \
          --scanners vuln,config,secret \
          --severity HIGH,CRITICAL \
          --exit-code 1 \
          ${config.imageTag}
    """)
    
    echo "✓ Security scan passed (no high/critical vulnerabilities)"
}
```

**What Happens:**

1. **Scans** Docker image layers for vulnerabilities
2. **Detects**:
   - Known CVEs (Common Vulnerabilities & Exposures)
   - Unpatched packages
   - Misconfigurations
   - Hardcoded secrets

3. **Reports** by severity:
   ```
   CRITICAL - node_modules/crypto-js: CVE-2023-46805
   HIGH - nginx: CVE-2024-123456
   MEDIUM - openssh: CVE-2024-567890
   LOW - git: version info leak
   ```

4. **Fails** if `failOnSeverity: true` and finds HIGH/CRITICAL issues

**Example Trivy Output:**
```
Scanning image for vulnerabilities...
Total: 15 vulnerabilities detected

CRITICAL (3):
  ├─ node_modules/express: CVE-2023-123456 (RCE via HTTP request)
  ├─ node_modules/lodash: CVE-2023-789101 (Prototype pollution)
  └─ system: openssl: CVE-2024-456789 (Buffer overflow)

HIGH (5):
  ├─ node_modules/axios: CVE-2024-111111 (SSRF)
  ├─ node_modules/uuid: CVE-2023-999999 (Denial of Service)
  └─ ...

MEDIUM (7):
  └─ ...

Severity breakdown:
 ┌───────────┬──────────┐
 │ Severity  │ Count    │
 ├───────────┼──────────┤
 │ CRITICAL  │ 3        │
 │ HIGH      │ 5        │
 │ MEDIUM    │ 7        │
 │ LOW       │ 0        │
 └───────────┴──────────┘

Recommended action: Update vulnerable packages
```

**Why It Matters:**
- ✅ Prevents deploying images with known vulnerabilities
- ✅ Compliance (security regulations require vulnerability scanning)
- ✅ Fail fast (before pushing to registry or deploying)
- ✅ Protects users (prevents exploits)

**Execution Time:** ~10-20 seconds

**Common Failures:**
- ❌ `CRITICAL vulnerability found` → Update base image or packages
  ```bash
  # Example fix: Update Node.js base image
  FROM node:20-alpine      # Current
  FROM node:21-alpine      # Update
  ```
  
- ❌ `Trivy database outdated` → Refresh vulnerability DB
  ```bash
  trivy image --download-db-only
  ```

**Failure Example:**
```
❌ Security scan failed
   Found 3 CRITICAL vulnerabilities in dependencies

Blockers:
  1. node_modules/express: CVE-2023-123456 (Remote Code Execution)
     Affected: express < 4.18.2
     Fix: npm install express@latest
     
  2. system: openssl: CVE-2024-456789 (Buffer overflow)
     Affected: openssl < 3.0.10
     Fix: Use base image node:21-alpine or later

Action: Fix vulnerabilities and retry build
```

---

### STAGE 10: Push to Registry (OPTIONAL)

**Purpose:** Push Docker image to Docker Hub registry

```groovy
stage('Push to Registry') {
  when {
    expression { params.DO_PUSH }
  }
  steps {
    script {
      dockerPush(
        imageTag: "${env.IMAGE_TAG}",
        registryCredId: params.REGISTRY_CREDENTIALS_ID
      )
    }
  }
}
```

**Condition:** Only runs if `DO_PUSH` = true

**dockerPush() - Pseudo-Code:**
```groovy
def call(Map config) {
    echo "📤 Pushing image to registry: ${config.imageTag}..."
    
    withCredentials([usernamePassword(
        credentialsId: config.registryCredId,
        usernameVariable: 'DOCKER_USER',
        passwordVariable: 'DOCKER_PASS'
    )]) {
        sh("""
            echo ${DOCKER_PASS} | docker login -u ${DOCKER_USER} --password-stdin
            docker push ${config.imageTag}
            docker logout
        """)
    }
    
    echo "✓ Image pushed successfully"
}
```

**What Happens:**

1. **Authenticates** to Docker Hub:
   - Retrieves credentials from Jenkins (jenkinsfile-creds)
   - Logs in with username/token
   - Credentials never exposed in logs (masked)

2. **Pushes** image layers to Docker Hub:
   ```
   Pushing demu147/bugreportportal:1.0.0-42
   └── Layer 1: node:20-alpine [cached]
   └── Layer 2: System deps [30MB] Uploading...
   └── Layer 3: App code [10MB] Uploading...
   └── Layer 4: npm packages [200MB] Uploading...
   └── Layer 5: Prisma client [5MB] Uploading...
   
   Digest: sha256:abc123def456...
   Status: Pushed
   ```

3. **Logout** from registry (cleanup credentials)

4. **Verifies** on Docker Hub:
   - Image visible at: https://hub.docker.com/r/demu147/bugreportportal
   - Tag: 1.0.0-42
   - Size: 415MB
   - Scan status: Security scan results

**Why It Matters:**
- ✅ Stores image in central registry (accessible from anywhere)
- ✅ Enables Kubernetes to pull image
- ✅ Enables team members to run image locally
- ✅ Preserves image history (version control for containers)

**Execution Time:** ~30-60 seconds (depends on network + image size)

**When to Push:**
- ✅ `DO_PUSH: true` → Master branch stable builds
- ✅ Release versions (v1.0.0)
- ❌ `DO_PUSH: false` → Feature branches, testing, quick builds

**Failure Example:**
```
❌ Failed to push image
Error: unauthorized: authentication required

Likely causes:
  1. Credentials incorrect
  2. Token expired
  3. Repository doesn't exist
  4. User lacks push permissions

Fix:
  1. Verify REGISTRY_CREDENTIALS_ID in Jenkins → Manage Credentials
  2. Check token hasn't expired
  3. Create repository on Docker Hub if needed
  4. Grant repository push permissions
```

**Registry Credentials Setup:**

In Jenkins:
```
Manage Jenkins → Manage Credentials → System → Global credentials

ID: dockerhub-creds-pat
Type: Username with password
Username: demu147
Password: docker-hub-personal-access-token
Description: Docker Hub credentials for pushing images
```

---

### STAGE 11: Deploy to Kubernetes (OPTIONAL)

**Purpose:** Deploy application to Kubernetes cluster

```groovy
stage('Deploy to Kubernetes') {
  when {
    expression { params.DO_DEPLOY }
  }
  steps {
    script {
      def allEnvs = readYaml(file: 'devops/deploy-config.yaml').environments
      def cfg = allEnvs[params.TARGET_ENV]
      if (!cfg) {
        error("TARGET_ENV '${params.TARGET_ENV}' not found in devops/deploy-config.yaml (available: ${allEnvs.keySet()})")
      }

      k8sDeploy(
        imageTag: "${env.IMAGE_TAG}",
        clusterContext: cfg.clusterContext,
        namespace: cfg.namespace,
        deploymentName: cfg.deploymentName,
        imageName: cfg.imageName,
        skipTlsVerify: cfg.skipTlsVerify != null ? cfg.skipTlsVerify : true,
        manifestDir: cfg.manifestDir
      )
    }
  }
}
```

**Condition:** Only runs if `DO_DEPLOY` = true

**What Happens:**

1. **Reads** deploy-config.yaml to get environment config:
   ```yaml
   environments:
     dev:
       clusterContext: kind-bug-report-portal
       namespace: bug-report-portal-dev
       deploymentName: bug-report-portal-app
       imageName: bugreportportal
       skipTlsVerify: true
       manifestDir: k8s/
   ```

2. **Validates** TARGET_ENV exists (prevents typos)

3. **Calls** k8sDeploy() shared function

**k8sDeploy() - Pseudo-Code:**
```groovy
def call(Map config) {
    echo "🚀 Deploying to Kubernetes..."
    dir('devops') {
        // 1. Switch to target cluster context
        sh("kubectl config use-context ${config.clusterContext}")
        
        // 2. Verify namespace exists
        sh("kubectl create namespace ${config.namespace} --dry-run=client -o yaml | kubectl apply -f -")
        
        // 3. Patch Kustomization for image tag
        sh("""
            cd ${config.manifestDir}
            kustomize edit set image ${config.imageName}=${config.imageTag}
        """)
        
        // 4. Apply manifests
        sh("""
            kubectl apply -k ${config.manifestDir} \
              --namespace=${config.namespace}
        """)
        
        // 5. Wait for deployment to be ready
        sh("""
            kubectl rollout status deployment/${config.deploymentName} \
              --namespace=${config.namespace} \
              --timeout=5m
        """)
        
        // 6. Show deployment status
        sh("""
            kubectl get pods -n ${config.namespace} \
              -l app=bug-report-portal-app
        """)
    }
    
    echo "✓ Deployment successful"
}
```

**Deployment Flow:**

```
1. Switch Context
   kubectl config use-context kind-bug-report-portal
   ↓
2. Create Namespace (if not exists)
   kubectl create namespace bug-report-portal-dev
   ↓
3. Patch Image Tag in Kustomization
   kustomization.yaml:
     - name: bugreportportal
       newTag: docker.io/demu147/bugreportportal:1.0.0-42
   ↓
4. Apply Kubernetes Manifests
   k8s/
   ├── namespace.yaml              → Create namespace
   ├── app-configmap.yaml          → Config data
   ├── app-secret.template.yaml    → Secrets
   ├── postgres-pvc.yaml           → Database storage
   ├── postgres-deployment.yaml    → Database pod
   ├── postgres-service.yaml       → Database service
   ├── app-deployment.yaml         → App pod
   ├── app-service.yaml            → App service
   ├── ingress.yaml                → External access
   └── kustomization.yaml          → Image patching
   ↓
5. Wait for Deployment Ready
   kubectl rollout status deployment/bug-report-portal-app -n bug-report-portal-dev
   ↓
6. Show Pod Status
   kubectl get pods -n bug-report-portal-dev -l app=bug-report-portal-app
   ↓
✅ Deployment Complete
```

**What Gets Deployed:**

```
Kubernetes Cluster (kind-bug-report-portal)
└── Namespace: bug-report-portal-dev
    ├── ConfigMap: bug-report-portal-config
    │   ├── NODE_ENV: production
    │   ├── PORT: 3000
    │   ├── LOG_LEVEL: info
    │   └── DATABASE_URL: postgresql://...
    │
    ├── Secret: bug-report-portal-secrets
    │   ├── DB_USERNAME: postgres
    │   ├── DB_PASSWORD: ****
    │   └── JWT_SECRET: ****
    │
    ├── PVC: postgres-pvc (10GB storage)
    │
    ├── Pod: postgres-65788c85f4-w429v
    │   ├── Image: postgres:16-alpine
    │   ├── Port: 5432
    │   ├── Env: POSTGRES_DB=bugreportportal
    │   └── Volume: database storage
    │
    ├── Pod: bug-report-portal-app-7c585f6f85-xxfkg
    │   ├── Image: docker.io/demu147/bugreportportal:1.0.0-42
    │   ├── Init: wait-for-postgres (checks DB ready)
    │   ├── Init: db-migrate (runs prisma migrate deploy)
    │   ├── Port: 3000
    │   ├── Env: NODE_ENV=production, DATABASE_URL=...
    │   └── Health: readinessProbe, livenessProbe
    │
    ├── Service: bug-report-portal-service (NodePort 3xxxx)
    │   └── Routes traffic to app pod
    │
    ├── Service: postgres (ClusterIP 10.x.x.x)
    │   └── Internal database access
    │
    └── Ingress: bug-report-portal-ingress (optional)
        └── External HTTP routing
```

**Example Deployment Output:**
```
🚀 Deploying to Kubernetes...

Switched to context 'kind-bug-report-portal'
Created namespace bug-report-portal-dev

Patching image:
  bugreportportal → docker.io/demu147/bugreportportal:1.0.0-42

Applying manifests:
  configmap/bug-report-portal-config created
  secret/bug-report-portal-secrets configured
  persistentvolumeclaim/postgres-pvc created
  deployment.apps/postgres created
  service/postgres created
  deployment.apps/bug-report-portal-app created
  service/bug-report-portal-service created

Waiting for rollout:
  Waiting for deployment "bug-report-portal-app" rollout to finish
  deployment "bug-report-portal-app" successfully rolled out
  Waiting for deployment "postgres" rollout to finish
  deployment "postgres" successfully rolled out

Pod Status:
NAME                                     READY   STATUS    RESTARTS
bug-report-portal-app-7c585f6f85-xxfkg  1/1     Running   0
postgres-65788c85f4-w429v               1/1     Running   0

✓ Deployment successful
```

**Why It Matters:**
- ✅ Runs application in production
- ✅ Kubernetes manages pod lifecycle (restart if fails)
- ✅ Load balancing if multiple replicas
- ✅ Self-healing (replaces dead pods)
- ✅ Scalable (easy to increase replicas)
- ✅ Database initialized via init containers
- ✅ Health checks ensure pod is ready

**Execution Time:** ~60-90 seconds (depends on image pull + pod startup)

**Deployment Stages Timeline:**
```
T+0:  kubectl apply -k k8s/ → Manifests submitted
T+5:  Kubernetes creates pods
T+10: Init container: wait-for-postgres (15-30s)
T+25: Init container: db-migrate (npx prisma migrate deploy)
T+35: App container starts
T+40: Health checks pass
T+45: rollout status succeeds
```

**Common Failures:**

❌ **Image Pull Error**
```
ImagePullBackOff: Failed to pull image

Cause: DO_PUSH=false but image not in registry
Fix: Set DO_PUSH=true or change image to local/already-pushed image
```

❌ **Namespace Config Issues**
```
Error: clusterContext 'kind-bug-report-portal' not found

Cause: Cluster not configured
Fix: kubectl config get-contexts to verify cluster name
```

❌ **Database Connectivity Timeout**
```
Init container: wait-for-postgres timed out

Cause: PostgreSQL pod not ready yet
Fix: Increase wait timeout in app-deployment.yaml init container
```

❌ **Pod CrashLoopBackOff**
```
pod is crash looping

Cause: App can't connect to database or missing env vars
Fix: Check logs: kubectl logs bug-report-portal-app-xxx -n bug-report-portal-dev
```

---

### STAGE 12: Notify

**Purpose:** Notify team about build status

```groovy
stage('Notify') {
  steps {
    script {
      notifyStatus(
        buildStatus: currentBuild.result ?: 'SUCCESS',
        buildNumber: env.BUILD_NUMBER,
        jobName: env.JOB_NAME,
        imageTag: "${env.IMAGE_TAG}",
        deployed: params.DO_DEPLOY
      )
    }
  }
}
```

**notifyStatus() - Pseudo-Code:**
```groovy
def call(Map config) {
    echo "📢 Notifying status..."
    
    // Currently just prints summary (no email/Slack configured)
    echo """
    ╔═════════════════════════════════════════╗
    ║     Build #${config.buildNumber} - ${config.jobName}
    ║     Status: ${config.buildStatus}
    ║     Image: ${config.imageTag}
    ║     Deployed: ${config.deployed ? 'YES' : 'NO'}
    ╚═════════════════════════════════════════╝
    """
    
    // Future: Send Slack notification
    // sh("curl -X POST -H 'Content-type: application/json' --data '{...}' \
    //   ${SLACK_WEBHOOK_URL}")
    
    // Future: Send email notification
    // emailext(to: 'team@example.com', ...)
}
```

**What Happens:**

1. Prints build summary with status
2. Shows image tag and deployment status
3. Currently basic (no external notifications)

**Why It Matters:**
- ✅ Team aware of build status
- ✅ Quick feedback (success/failure)
- ✅ Deployment confirmation
- ✅ Foundation for Slack/email integration

**Example Output:**
```
📢 Notifying status...
╔═════════════════════════════════════════╗
║     Build #42 - bug-report-portal
║     Status: SUCCESS
║     Image: docker.io/demu147/bugreportportal:1.0.0-42
║     Deployed: YES
╚═════════════════════════════════════════╝
```

**Future Enhancements:**
```groovy
// Slack notification
withCredentials([string(credentialsId: 'slack-webhook', variable: 'SLACK_WEBHOOK')]) {
    sh("""
        curl -X POST -H 'Content-type: application/json' \
          --data '{
            "text": "✅ Build #${buildNumber} successful",
            "blocks": [{
              "type": "section",
              "text": {"type": "mrkdwn", "text": "Image: ${imageTag}"}
            }]
          }' \
          ${SLACK_WEBHOOK}
    """)
}

// Email notification
emailext(
    to: 'team@example.com',
    subject: "Build #${buildNumber} - ${buildStatus}",
    body: "Build #${buildNumber} completed with status: ${buildStatus}\nImage: ${imageTag}"
)
```

---

## Post-Action Handling

### Post: Always (Runs regardless of success/failure)

```groovy
post {
  always {
    script {
      echo """
      ╔═══════════════════════════════════════════════════════════════╗
      ║                   PIPELINE COMPLETE                          ║
      ╠═══════════════════════════════════════════════════════════════╣
      ║ Status:          ${currentBuild.result ?: 'SUCCESS'}
      ║ Build:           #${BUILD_NUMBER}
      ║ Duration:        ${currentBuild.durationString}
      ║ Image:           ${env.IMAGE_TAG}
      ╚═══════════════════════════════════════════════════════════════╝
      """
    }
  }
```

**Runs after pipeline completes (success or failure)**
- Always displays summary
- Shows final status
- Useful for cleanup tasks

### Post: Failure (Only if pipeline failed)

```groovy
failure {
  script {
    echo "❌ Pipeline failed - check logs above for details"
  }
}
```

**What Happens:**
- Prints failure message
- Directs user to check logs
- Could trigger alerts/notifications

### Post: Success (Only if pipeline succeeded)

```groovy
success {
  script {
    echo "✓ Pipeline completed successfully"
    if (params.DO_DEPLOY) {
      echo """
    ╔═══════════════════════════════════════════════════════════════╗
    ║               ✅ DEPLOYMENT SUCCESSFUL                        ║
    ╠═══════════════════════════════════════════════════════════════╣
    ║ Next: Access your application                               ║
    ║                                                               ║
    ║ 1. Port-forward to the service:                              ║
    ║    kubectl port-forward -n bug-report-portal-dev \\         ║
    ║      svc/bug-report-portal-service 8888:3000                 ║
    ║                                                               ║
    ║ 2. Open in browser:                                          ║
    ║    http://localhost:8888                                     ║
    ║                                                               ║
    ║ 3. Login credentials:                                        ║
    ║    Username: admin                                           ║
    ║    Password: admin123                                           ║
    ║                                                               ║
    ║ 4. Check pod status:                                         ║
    ║    kubectl get pods -n bug-report-portal-dev                 ║
    ║                                                               ║
    ║ 5. View logs:                                                ║
    ║    kubectl logs -n bug-report-portal-dev \\                 ║
    ║      -l app=bug-report-portal-app --tail=100 -f              ║
    ╚═══════════════════════════════════════════════════════════════╝
      """
    }
  }
}
```

**What Happens:**
- Shows success message
- If deployed: provides access instructions
- Port-forward command
- Login credentials
- Helpful kubectl commands

---

## Shared Library Functions

### Function: gitCheckout()

**Location:** `vars/gitCheckout.groovy` in shared library

**Purpose:** Clone and checkout git repositories

**Signature:**
```groovy
def call(Map config) {
  // config.branch
  // config.repoUrl
  // config.targetDir
}
```

**Implementation Example:**
```groovy
def call(Map config) {
    echo "📥 Cloning ${config.repoUrl} (${config.branch})..."
    checkout([
        $class: 'GitSCM',
        branches: [[name: config.branch]],
        userRemoteConfigs: [[url: config.repoUrl]]
    ])
    sh("mkdir -p ${config.targetDir} && mv * ${config.targetDir}/ 2>/dev/null || true")
    echo "✓ Checked out ${config.repoUrl}"
}
```

### Function: preflightChecks()

**Location:** `vars/preflightChecks.groovy`

**Purpose:** Verify tools are installed and working

**Checks:**
- Docker CLI and daemon
- kubectl CLI
- Kubernetes cluster connectivity
- Node.js version
- Git version

### Function: installDeps()

**Location:** `vars/installDeps.groovy`

**Purpose:** Install Node.js dependencies using npm ci

**Command:**
```bash
cd app && npm ci --prefer-offline --no-audit
```

### Function: prismaGenerate()

**Location:** `vars/prismaGenerate.groovy`

**Purpose:** Generate Prisma client from schema

**Command:**
```bash
cd app && npx prisma generate
```

### Function: lintAndTest()

**Location:** `vars/lintAndTest.groovy`

**Purpose:** Run ESLint and Jest tests

**Commands:**
```bash
cd app && npm run lint
cd app && npm test
```

### Function: sonarScan()

**Location:** `vars/sonarScan.groovy`

**Purpose:** Run SonarQube code analysis

**Commands:**
```bash
npx sonar-scanner \
  -Dsonar.projectKey=bug-report-portal \
  -Dsonar.host.url=http://sonarqube:9000 \
  -Dsonar.login=${SONAR_TOKEN}
waitForQualityGate(abortPipeline: true)
```

### Function: dockerBuild()

**Location:** `vars/dockerBuild.groovy`

**Purpose:** Build Docker image

**Command:**
```bash
docker build -t ${imageTag} -f Dockerfile app/
```

### Function: trivyScan()

**Location:** `vars/trivyScan.groovy`

**Purpose:** Scan image for vulnerabilities

**Command:**
```bash
trivy image \
  --scanners vuln,config,secret \
  --severity HIGH,CRITICAL \
  --exit-code 1 \
  ${imageTag}
```

### Function: dockerPush()

**Location:** `vars/dockerPush.groovy`

**Purpose:** Push image to Docker registry

**Commands:**
```bash
docker login (with credentials)
docker push ${imageTag}
docker logout
```

### Function: k8sDeploy()

**Location:** `vars/k8sDeploy.groovy`

**Purpose:** Deploy to Kubernetes

**Steps:**
1. Switch cluster context
2. Create namespace
3. Patch image in kustomization
4. Apply manifests
5. Wait for rollout
6. Show pod status

### Function: notifyStatus()

**Location:** `vars/notifyStatus.groovy`

**Purpose:** Notify build status

**Current:** Prints summary
**Future:** Slack/email integration

---

## Build Flow Diagram

```
START
  ↓
┌─────────────────────────────────┐
│ 1. Clean Workspace              │
│    └─ deleteDir()               │
└──────────────┬──────────────────┘
               ↓
┌─────────────────────────────────┐
│ 2. Checkout Application         │
│    └─ Clone bugreportportal     │
└──────────────┬──────────────────┘
               ↓
┌─────────────────────────────────┐
│ 3. Checkout DevOps              │
│    ├─ Clone devops repo         │
│    └─ Compute IMAGE_TAG         │
└──────────────┬──────────────────┘
               ↓
┌─────────────────────────────────┐
│ 4. Preflight Checks             │
│    ├─ Docker version            │
│    ├─ kubectl config            │
│    └─ K8s cluster ready?        │
└──────────────┬──────────────────┘
               ↓
┌─────────────────────────────────┐
│ 5. Setup                        │
│    ├─ npm ci (install deps)     │
│    └─ prisma generate           │
└──────────────┬──────────────────┘
               ↓
┌─────────────────────────────────┐
│ 6. Quality Gates                │
│    ├─ ESLint (code style)       │
│    └─ Jest (tests)              │
└──────────────┬──────────────────┘
               ↓
         RUN_SONAR?
          /         \
        YES          NO
        ↓            ↓
    ┌───────┐    └─────┐
    │ Sonar │          │
    └───┬───┘          │
        └──────┬───────┘
               ↓
┌─────────────────────────────────┐
│ 8. Docker Build                 │
│    └─ docker build -t IMAGE_TAG │
└──────────────┬──────────────────┘
               ↓
┌─────────────────────────────────┐
│ 9. Security Scan (Trivy)        │
│    └─ Check for CVEs            │
└──────────────┬──────────────────┘
               ↓
         DO_PUSH?
         /       \
       YES        NO
       ↓          ↓
    ┌──────┐   └─────┐
    │ Push │         │
    └───┬──┘         │
        └──────┬─────┘
               ↓
         DO_DEPLOY?
         /        \
       YES         NO
       ↓           ↓
    ┌──────────┐   └─────┐
    │ Deploy K8s│        │
    └───┬──────┘         │
        └──────┬─────────┘
               ↓
┌─────────────────────────────────┐
│ 12. Notify                      │
│    └─ Print summary             │
└──────────────┬──────────────────┘
               ↓
        POST Actions
    (always/success/failure)
               ↓
             END
```

---

## Error Handling Strategy

### Stage Failure Behavior

**Current:** On any stage failure → entire pipeline stops

```groovy
// Example: If lintAndTest() fails
stage('Quality Gates') {
  steps {
    script {
      lintAndTest()  // ← Fails here
                     // ↓ Pipeline stops immediately
                     // Post actions still run
    }
  }
}
```

### Try-Catch Error Handling

```groovy
stage('Setup') {
  steps {
    script {
      try {
        installDeps()
        prismaGenerate()
      } catch (Exception e) {
        error("Setup failed: ${e.message}")  // Rethrow to fail pipeline
      }
    }
  }
}
```

### Conditional Stages (Skip on Condition)

```groovy
stage('SonarQube Scan') {
  when {
    expression { params.RUN_SONAR && params.SONAR_HOST_URL?.trim() }
  }
  steps {
    // Only runs if conditions met
  }
}
```

### Failure Recovery Strategies

| Failure | Recovery |
|---------|----------|
| Network timeout | Retry stage (handled by Jenkins retry plugin) |
| Out of disk | Clean Docker images: `docker image prune -a` |
| Permission denied | Check Jenkins user group: `usermod -aG docker jenkins` |
| Pod won't start | Check logs: `kubectl logs pod-name -n namespace` |
| Database connection timeout | Increase wait timeout in init container |

---

## Summary Table

| Stage | Purpose | Duration | Mandatory | Conditional |
|-------|---------|----------|-----------|-------------|
| Clean Workspace | Fresh start | ~1s | ✅ | - |
| Checkout App | Get source | ~5-10s | ✅ | - |
| Checkout DevOps | Get K8s manifests | ~3-5s | ✅ | - |
| Preflight | Verify tools | ~5-10s | ✅ | - |
| Setup | Install deps | ~20-30s | ✅ | - |
| Quality Gates | Lint & tests | ~30-60s | ✅ | - |
| SonarQube | Code analysis | ~30-60s | ❌ | RUN_SONAR |
| Docker Build | Create image | ~60-120s | ✅ | - |
| Security Scan | CVE check | ~10-20s | ✅ | - |
| Push to Registry | Docker Hub | ~30-60s | ❌ | DO_PUSH |
| Deploy to K8s | Run in cluster | ~60-90s | ❌ | DO_DEPLOY |
| Notify | Send status | ~1s | ✅ | - |

---

## Quick Reference

### Run Just Build (No Push/Deploy)
```
Branch: master
DO_PUSH: false
DO_DEPLOY: false
RUN_SONAR: false
→ Duration: ~3-5 minutes
```

### Run Full Pipeline (Build + Push + Deploy)
```
Branch: master
DO_PUSH: true
DO_DEPLOY: true
RUN_SONAR: true
TARGET_ENV: dev
→ Duration: ~8-12 minutes
```

### Test Feature Branch
```
Branch: feature/new-feature
DO_PUSH: false
DO_DEPLOY: false
RUN_SONAR: true
→ Duration: ~4-6 minutes
```

### Production Release
```
Branch: master
DO_PUSH: true
DO_DEPLOY: true
RUN_SONAR: true
TARGET_ENV: dev (or prod if available)
→ Duration: ~10-15 minutes
→ Action: Push to registry for release tag
```

---

**End of Document**

For actual shared library source code, see: https://github.com/ravi2342/bugreportportal-sharedlib
