# SonarQube Setup & Configuration

Complete guide for setting up and using SonarQube for code quality analysis.

---

## 📊 What is SonarQube?

SonarQube is a static code analysis tool that:
- ✅ Detects bugs and vulnerabilities
- ✅ Measures code coverage
- ✅ Tracks code quality metrics
- ✅ Enforces quality gates

---

## 🔧 Setup

### 1. SonarQube Server (Docker Compose)

SonarQube is already configured in `docker-compose.yml`:

```yaml
sonarqube:
  image: sonarqube:lts-community
  ports:
    - "9000:9000"
  environment:
    SONAR_JDBC_URL: jdbc:postgresql://postgres-db:5432/sonarqube
    SONAR_JDBC_USERNAME: postgres
    SONAR_JDBC_PASSWORD: ...
  depends_on:
    - postgres-db
```

**Start it:**
```bash
docker compose up -d sonarqube
```

**Access:** http://localhost:9000

---

### 2. Initial Login

Default credentials:
```
Username: admin
Password: admin
```

⚠️ **CHANGE PASSWORD** on first login (Security best practice)

---

### 3. Create Project Token

Required for Jenkins pipeline to authenticate:

1. Click **Administration** → **Security** → **Users** → **Tokens**
2. Click **Generate Tokens**
3. Enter name: `jenkins-token`
4. Copy the token
5. Create Jenkins credential:
   - Jenkins → **Manage Jenkins** → **Credentials**
   - Add credential → **Secret text**
   - Paste token, ID: `sonar-token`

---

## 📋 Configuration Files

### `sonar-project.properties`
Defines project metadata and source locations:

```properties
sonar.projectKey=bug-report-portal
sonar.projectName=Bug Report Portal
sonar.projectVersion=1.0

# Source code location (relative to where sonar-scanner runs from devops/)
sonar.sources=../app

# Files to exclude from analysis
sonar.exclusions=**/node_modules/**,**/uploads/**,**/data/**,**/prisma/migrations/**,.git/**,**/dist/**,**/build/**

sonar.sourceEncoding=UTF-8
```

**How it works:**
- `sonar-scanner` **automatically reads** this file when run from `devops/` directory
- No need to pass `-Dsonar.projectKey`, `-Dsonar.sources`, etc. manually
- Jenkins only passes **dynamic values**: host URL, token, branch name

---

## 🌿 Understanding Branches in SonarQube

### What is a Branch?

SonarQube tracks **different versions** of your code analysis:
- **Project**: `bug-report-portal` (container)
  - **Branch 1**: `master` (main branch)
  - **Branch 2**: `develop` (development branch)
  - **Branch 3**: `feature/xyz` (feature branch)

### Without Branch Specification

```groovy
sonar-scanner -Dsonar.projectKey=bug-report-portal
```
Result:
- Goes to **default branch** (SonarQube default is "main")
- All builds update the SAME branch
- UI shows latest analysis only

### With Branch Specification

```groovy
sonar-scanner \
  -Dsonar.projectKey=bug-report-portal \
  -Dsonar.branch.name=master
```
Result:
- Explicitly targets `master` branch
- Separate from other branches (develop, feature/xyz)
- UI shows branch-specific metrics

### In Jenkins (Current Implementation)

```groovy
sonar-scanner \
  -Dsonar.host.url="${params.SONAR_HOST_URL}" \
  -Dsonar.token="${SONAR_TOKEN}" \
  -Dsonar.branch.name=${params.BRANCH} \  # ← Uses Jenkins parameter
  -Dsonar.qualitygate.wait=true
```

**Behavior:**
- Build on `master` branch → analysis goes to `master` in SonarQube
- Build on `develop` branch → analysis goes to `develop` in SonarQube
- Separate metrics per branch

---

## 🚀 Running SonarQube Analysis

### Via Jenkins Pipeline

**Option 1: Trigger with RUN_SONAR=true**

1. Open Jenkins: http://localhost:8080/jenkins
2. Build → **Build with Parameters**
3. Set:
   ```
   RUN_SONAR=true
   DO_DEPLOY=true (optional)
   ```
4. Click **Build**

**Expected time:** ~3-5 minutes additional

### Via CLI (Manual)

```bash
cd devops

sonar-scanner \
  -Dsonar.host.url=http://localhost:9000 \
  -Dsonar.token=YOUR_TOKEN \
  -Dsonar.projectKey=bug-report-portal \
  -Dsonar.sources=../app \
  -Dsonar.exclusions="**/node_modules/**,**/uploads/**,**/data/**" \
  -Dsonar.sourceEncoding=UTF-8
```

---

## 📊 Understanding Results

### Quality Gate
SonarQube runs **quality gate checks** after analysis:
- ✅ **PASS**: Project meets standards (good coverage, no critical bugs)
- ❌ **FAIL**: Project has issues that need fixing

### View Results

1. Open http://localhost:9000
2. Click **Projects** → **Bug Report Portal**
3. View:
   - 🐛 **Issues** tab - bugs and vulnerabilities
   - 📈 **Measures** tab - code metrics (coverage, complexity)
   - 💾 **Code** tab - source code with annotations
   - 📊 **Activity** tab - analysis history

### Key Metrics

| Metric | What It Means | Target |
|--------|---------------|--------|
| **Bugs** | Code errors | 0 |
| **Vulnerabilities** | Security issues | 0 |
| **Code Smells** | Poor code quality | Minimize |
| **Coverage** | % of code tested | >80% |
| **Duplicated Lines** | Code duplication | <5% |
| **Technical Debt** | Days to fix issues | Minimal |

---

## ⚠️ Common Issues & Fixes

### Issue #1: "No lines of code" detected

**Cause:** SonarQube can't find source files

**Solution:** Verify sonar-scanner command includes `-Dsonar.sources=../app`

Check in Jenkinsfile (line 278):
```groovy
-Dsonar.sources=../app \  // ✅ This must be present
```

### Issue #2: "Authentication failed"

**Cause:** Invalid or missing token

**Solution:** Regenerate token in SonarQube:
1. http://localhost:9000 → Administration → Security → Users
2. Regenerate token
3. Update Jenkins credential

### Issue #3: Quality Gate never completes

**Cause:** SonarQube still processing or gate configuration issue

**Solution:** 
```bash
# Check SonarQube is running
docker compose ps sonarqube

# Verify gate configuration
curl http://localhost:9000/api/qualitygates/project_status?projectKey=bug-report-portal
```

---

## 🔄 Workflow Integration

### Complete E2E with SonarQube

```bash
# 1. Start services
docker compose up -d

# 2. Wait for SonarQube ready
sleep 60

# 3. Trigger Jenkins build with analysis
curl -X POST http://localhost:8080/jenkins/job/bug-report-portal/buildWithParameters \
  -u admin:admin \
  -F RUN_SONAR=true \
  -F DO_DEPLOY=true

# 4. Monitor pipeline (21+ stages, includes SonarQube scan)
# Watch in Jenkins UI or logs

# 5. View results
open http://localhost:9000/dashboard?id=bug-report-portal
```

**Expected time:** 10-15 minutes total

---

## 📚 See Also

- [TESTING.md](TESTING.md) - Jenkins build triggers
- [E2E_DEPLOYMENT.md](E2E_DEPLOYMENT.md) - Complete pipeline walkthrough
- [QUICK_REFERENCE.md](QUICK_REFERENCE.md) - Command reference
- [ERROR_FIXES.md](ERROR_FIXES.md) - Troubleshooting

---

## 🎯 Quick Checklist

- [ ] SonarQube running: `docker compose ps sonarqube` (healthy status)
- [ ] Default password changed
- [ ] Project token created
- [ ] Jenkins credential `sonar-token` configured
- [ ] Jenkins build triggered with `RUN_SONAR=true`
- [ ] Quality gate passed in build log
- [ ] Results visible at http://localhost:9000/projects
