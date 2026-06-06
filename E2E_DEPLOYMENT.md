# End-to-End (E2E) Deployment Guide

Complete walkthrough of deploying the Bug Report Portal application from code commit to browser access with automated e2e testing.

---

## Overview

The deployment process consists of:

1. **Code Commit** → GitHub repository
2. **Jenkins CI/CD Pipeline** → Automated build, test, scan, deploy
3. **Kubernetes Deployment** → Application running in Kind cluster
4. **Port-Forward** → Tunnel from localhost to pod
5. **E2E Testing** → Automated browser testing
6. **Browser Access** → User accesses application

---

## Prerequisites

### Local Environment Setup
- **macOS with Docker Desktop installed** (running Docker engine)
- **Kind cluster created:** `kind create cluster --config /path/to/kind-config.yaml`
- **kubectl installed:** `kubectl version --client`
- **Git configured** with SSH or HTTPS credentials
- **~10GB free disk space** for Docker images and databases

### Jenkins Environment
- **Docker Compose running:** `docker compose up -d`
- **Jenkins accessible:** http://localhost:8080/jenkins
- **Jenkins initially configured** with admin credentials
- **GitHub repository cloned:** Contains Jenkinsfile and k8s manifests

### Kubernetes Cluster
- **Kind cluster running:** `kind get clusters` shows `bug-report-portal`
- **kubectl context configured:** `kubectl config use-context kind-bug-report-portal`
- **kubeconfig valid:** `kubectl cluster-info` shows cluster endpoint

### Application Repository
- **Latest code pushed to GitHub:** https://github.com/ravi2342/bugreportportal
- **Docker Hub credentials configured in Jenkins:**
  - Username: `demu147` (or your Docker Hub username)
  - Personal Access Token configured as `dockerhub-creds-pat` in Jenkins

---

## E2E Deployment Step-by-Step

### Step 1: Commit Code Changes to GitHub

Make changes to your application code and commit:

```bash
cd ~/path/to/bugreportportal
git add .
git commit -m "Feature: Add new bug report fields"
git push origin master
```

**Verification:**
- Changes appear on GitHub repository
- Jenkins webhook receives notification (if configured)

---

### Step 2: Trigger Jenkins Build

#### Option A: Manual Trigger (Recommended for Testing)

1. **Open Jenkins:** http://localhost:8080/jenkins
2. **Navigate to:** bug-report-portal job
3. **Click:** "Build with Parameters"
4. **Configure parameters:**

   | Parameter | Value | Purpose |
   |-----------|-------|---------|
   | **BRANCH** | master | Git branch to build |
   | **GITHUB_REPO_URL** | https://github.com/ravi2342/bugreportportal.git | Application repository |
   | **DO_PUSH** | ✓ (checked) | Push Docker image to registry |
   | **DO_DEPLOY** | ✓ (checked) | Deploy to Kubernetes |
   | **RUN_SONAR** | ✓ (checked) | Run SonarQube code scan |
   | **RUN_POST_DEPLOY_TESTS** | ✓ (checked) | Run smoke tests |
   | **RUN_UI_E2E** | ✓ (checked) | Run UI e2e tests |
   | **REGISTRY_CREDENTIALS_ID** | dockerhub-creds-pat | Docker Hub credentials |
   | **SONAR_HOST_URL** | http://sonarqube:9000 | SonarQube endpoint |

5. **Click:** "Build"

#### Option B: Automatic Trigger (via Webhook)

1. **Configure GitHub webhook:**
   - GitHub repository → Settings → Webhooks
   - Payload URL: `http://your-jenkins-url/github-webhook/`
   - Events: Push events
   - Active: ✓

2. **Jenkins job configuration:**
   - Jenkins job → Configure → Build Triggers
   - GitHub hook trigger: ✓

3. **Push code to GitHub:**
   ```bash
   git push origin master
   ```
   - GitHub automatically triggers Jenkins build
   - Jenkins Build #XX starts automatically

**Verification:**
- Jenkins console shows build starting
- Build progress visible at: http://localhost:8080/jenkins/job/bug-report-portal/XX/

---

### Step 3: Monitor CI/CD Pipeline Execution

Jenkins executes 21+ automated stages:

#### Stage Group 1: Code Preparation (5 stages)
1. **Checkout SCM** → Clone code from GitHub
2. **Setup & Verification** → Verify Node.js, npm, kubectl versions
3. **Install Dependencies** → npm install
4. **Run Tests** → Jest unit tests, coverage reports
5. **Code Coverage** → Generate coverage metrics

**Expected Output:**
```
✓ npm packages installed
✓ All tests passed
✓ Coverage: X%
```

#### Stage Group 2: Code Quality (2 stages)
6. **SonarQube Scan** (optional if RUN_SONAR=true)
   - Static code analysis
   - Security scan
   - Technical debt assessment
   
7. **Quality Gate Check**
   - Passes if code meets quality threshold
   - Fails if quality issues found

**Expected Output:**
```
✓ SonarQube analysis complete
✓ Quality gate: PASSED
```

#### Stage Group 3: Docker Build & Push (2 stages)
8. **Build Docker Image**
   - Image name: `demu147/bugreportportal:1.0.0-XX`
   - Dockerfile location: Application repository root
   - Builds Node.js application container

9. **Push to Docker Registry** (if DO_PUSH=true)
   - Pushes image to Docker Hub
   - Makes image available for deployment

**Expected Output:**
```
✓ Image built: demu147/bugreportportal:1.0.0-32
✓ Image pushed to Docker Hub
```

#### Stage Group 4: Kubernetes Deployment (3 stages)
10. **Deploy to Kubernetes** (if DO_DEPLOY=true)
    - Creates temporary kubeconfig for Jenkins container
    - Replaces 127.0.0.1 with host.docker.internal
    - Applies all Kubernetes manifests:
      - Namespace: `bug-report-portal`
      - ConfigMap: Application configuration
      - Secret: Database credentials
      - PostgreSQL deployment & PVC
      - Application deployment (3 replicas)
      - Service: bug-report-portal-service
      - Ingress: HTTP routing rules

11. **Wait for Rollout**
    - Waits up to 120 seconds
    - All pods transition to Running state
    - All containers ready

12. **Setup Port-Forward** (in Jenkins container)
    - Attempts to set up port-forward (for reference only)
    - User must run manual port-forward on macOS

**Expected Output:**
```
✓ Temporary kubeconfig created
✓ All 9 Kubernetes manifests applied
✓ Deployment rollout successful
✓ All pods running
```

#### Stage Group 5: Testing (3 stages)
13. **Post-Deploy Health Check** (if RUN_POST_DEPLOY_TESTS=true)
    - Smoke tests verify:
      - Deployment exists
      - Service is accessible
      - Pod is ready
      - Database connection works

14. **E2E UI Tests** (if RUN_UI_E2E=true)
    - Automated browser testing
    - Test scenarios:
      - Navigate to login page
      - Enter credentials (admin/admin)
      - Click login button
      - Verify dashboard loads
      - Submit bug report form
      - Verify data saved to database
      - Logout successfully

15. **Collect Test Reports**
    - JUnit XML reports
    - Coverage reports
    - E2E test videos/screenshots
    - Logs from all tests

**Expected Output:**
```
✓ Health check: PASSED
✓ E2E tests: 10/10 passed
✓ No failed test cases
```

#### Stage Group 6: Cleanup & Report (3 stages)
16. **Cleanup Build Artifacts**
    - Remove Docker build cache
    - Clean temporary files

17. **Send Notifications**
    - Slack notification (optional)
    - Email notification (optional)

18. **Final Report & Summary**
    - Build status: SUCCESS or FAILED
    - Build duration
    - Image tag deployed
    - Application URL for manual testing
    - Instructions for browser access via port-forward

---

### Step 4: Verify Deployment in Kubernetes

Monitor deployment from macOS terminal:

```bash
# Check namespace exists
kubectl get namespace bug-report-portal

# Check all resources
kubectl get all -n bug-report-portal

# Expected output:
NAME                                    READY   STATUS    RESTARTS   AGE
pod/bug-report-portal-app-XXXXX-XXXXX   1/1     Running   0          2m

NAME                                  TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)     AGE
service/bug-report-portal-service     ClusterIP   10.96.XX.XX      <none>        3000/TCP    2m
service/postgres                      ClusterIP   10.96.XX.XX      <none>        5432/TCP    2m

NAME                                      READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/bug-report-portal-app     3/3     3            3           2m
deployment.apps/postgres                  1/1     1            1           2m

# View deployment status
kubectl rollout status deployment/bug-report-portal-app -n bug-report-portal

# Check application pod logs
kubectl logs -n bug-report-portal pod/bug-report-portal-app-XXXXX-XXXXX

# Expected in logs:
# Server running on http://localhost:3000
# Connected to PostgreSQL at postgres:5432
```

---

### Step 5: Set Up Port-Forward on macOS

**IMPORTANT:** Port-forward runs on your macOS terminal, NOT in Jenkinsfile.

```bash
# Open a new terminal on macOS (keep open while using application)
kubectl port-forward -n bug-report-portal \
  svc/bug-report-portal-service 8888:3000 \
  --insecure-skip-tls-verify
```

**Output when successful:**
```
Forwarding from 127.0.0.1:8888 -> 3000
Forwarding from [::1]:8888 -> 3000
```

**Terminal stays running:** Keep this terminal open. Port-forward must continue running while you use the application.

---

#### Option A: Run Port-Forward in Foreground (Default)

Keep terminal open:
```bash
kubectl port-forward -n bug-report-portal \
  svc/bug-report-portal-service 8888:3000 \
  --insecure-skip-tls-verify
```

**Pros:** See real-time output, easy to stop (Ctrl+C)
**Cons:** Terminal is occupied, can't use that terminal for other commands

---

#### Option B: Run Port-Forward in Background (Recommended)

**Simplest - Using `&`:**
```bash
kubectl port-forward -n bug-report-portal \
  svc/bug-report-portal-service 8888:3000 \
  --insecure-skip-tls-verify &
```

**Better - Redirect output to file:**
```bash
kubectl port-forward -n bug-report-portal \
  svc/bug-report-portal-service 8888:3000 \
  --insecure-skip-tls-verify > ~/.kube/portforward.log 2>&1 &
echo "Port-forward running in background!"
```

**Best - Using `nohup` (survives terminal close):**
```bash
nohup kubectl port-forward -n bug-report-portal \
  svc/bug-report-portal-service 8888:3000 \
  --insecure-skip-tls-verify > ~/.kube/portforward.log 2>&1 &
echo "Port-forward started in background (PID: $!)"
```

**After starting in background:**
```bash
# Check if running
ps aux | grep "kubectl port-forward" | grep -v grep

# View logs
tail -f ~/.kube/portforward.log

# Stop port-forward
pkill -f "kubectl port-forward"
```

---

#### Option C: Quick Background Setup Script

Add this to `~/.zshrc` or `~/.bash_profile`:

```bash
# Start port-forward in background
pf-start() {
  echo "Starting port-forward in background..."
  nohup kubectl port-forward -n bug-report-portal \
    svc/bug-report-portal-service 8888:3000 \
    --insecure-skip-tls-verify > ~/.kube/portforward.log 2>&1 &
  echo "✓ Port-forward started! (PID: $!)"
  echo "View logs: tail -f ~/.kube/portforward.log"
}

# Stop port-forward
pf-stop() {
  echo "Stopping port-forward..."
  pkill -f "kubectl port-forward"
  echo "✓ Port-forward stopped!"
}

# Check status
pf-status() {
  if ps aux | grep -q "[k]ubectl port-forward"; then
    echo "✓ Port-forward is RUNNING"
    ps aux | grep "kubectl port-forward" | grep -v grep
  else
    echo "✗ Port-forward is NOT running"
  fi
}
```

**Then use:**
```bash
pf-start    # Start in background
pf-status   # Check if running
pf-stop     # Stop when done
```

---

**Verification:**
```bash
# In another terminal, verify connection
curl -k http://localhost:8888/login

# Should return: HTML login page (or similar response, not Connection refused)
```

---

### Step 6: Access Application in Browser

1. **Open browser** on your macOS
2. **Navigate to:** http://localhost:8888
3. **Login page appears** with username/password fields
4. **Login credentials:**
   - Username: `admin`
   - Password: `admin`

5. **Dashboard appears** showing:
   - List of existing bug reports
   - Create new bug report button
   - User profile menu

---

### Step 7: Test Application Functionality

#### Test 1: Create Bug Report
1. Click "Create New Report" button
2. Fill in form fields:
   - Title: "Login button styling issue"
   - Description: "Login button text color hard to read"
   - Priority: "Medium"
   - Category: "UI"
3. Click "Submit"
4. Verify success message appears
5. New report appears in list

#### Test 2: View Bug Report Details
1. Click on a bug report in the list
2. Verify all fields display correctly
3. Verify report status, creation date, assignee

#### Test 3: Update Bug Report
1. Click edit button on a report
2. Change priority from "Medium" to "High"
3. Click "Save Changes"
4. Verify change persists after refresh

#### Test 4: Database Persistence
1. Create a bug report
2. Refresh browser page (Cmd+R)
3. Verify bug report still appears (not lost)
4. Prove data saved to PostgreSQL

#### Test 5: Logout & Login Again
1. Click "Logout" button
2. Verify redirected to login page
3. Login again with admin/admin
4. Verify session restored

---

### Step 8: Run E2E Tests Manually (Optional)

If you want to run e2e tests outside of pipeline:

```bash
# Prerequisites:
# - Application running at http://localhost:8888
# - Port-forward active in another terminal
# - Database populated with test data

# In application repository:
cd ~/path/to/bugreportportal

# Run E2E tests
npm run test:e2e

# Expected output:
# ✓ Login page loads
# ✓ Login with credentials succeeds
# ✓ Dashboard displays
# ✓ Create bug report works
# ✓ Update bug report works
# ✓ Delete bug report works
# ✓ Logout works
# 
# Test Results: 7 passed, 0 failed
```

---

### Step 9: Monitor Application Logs

View real-time application logs:

```bash
# View current logs
kubectl logs -n bug-report-portal \
  deployment/bug-report-portal-app \
  --tail=50

# Follow logs (watch for new entries)
kubectl logs -n bug-report-portal \
  deployment/bug-report-portal-app \
  -f

# View logs from previous crash (if pod restarted)
kubectl logs -n bug-report-portal \
  pod/PODNAME \
  --previous
```

**Normal application startup logs:**
```
Server running on http://localhost:3000
Connected to PostgreSQL at postgres:5432
Database migrations completed successfully
API server ready to accept requests
```

---

### Step 10: Monitor Database

Verify PostgreSQL connection and data:

```bash
# Port-forward to PostgreSQL
kubectl port-forward -n bug-report-portal \
  svc/postgres 5432:5432 &

# Connect to PostgreSQL
psql -h localhost -U postgres -d bug_report_db

# At psql prompt:
\dt                    # List all tables
SELECT * FROM reports; # View bug reports
\q                     # Exit

# Verify data:
# - Tables: reports, users, comments, etc.
# - Data rows: Bug reports created via web interface
# - Timestamps: Reflect when reports were created
```

---

## Troubleshooting E2E Deployment

### Issue: Pod stuck in Pending state

```bash
kubectl describe pod POD_NAME -n bug-report-portal
```

**Common causes:**
- Insufficient cluster resources
- Image pull failure (check image tag)
- PVC not bound (check postgres-pvc status)

**Solution:**
```bash
# Check cluster capacity
kubectl top node

# Check events
kubectl get events -n bug-report-portal

# Describe PVC
kubectl describe pvc postgres-pvc -n bug-report-portal
```

### Issue: Application not responding at localhost:8888

**Checklist:**
1. Port-forward running in terminal?
   ```bash
   ps aux | grep "kubectl port-forward"
   ```
   Should show active port-forward process

2. Pod is Running?
   ```bash
   kubectl get pods -n bug-report-portal
   ```
   Should show all pods in Running state

3. Service exists?
   ```bash
   kubectl get svc -n bug-report-portal
   ```
   Should show bug-report-portal-service with CLUSTER-IP

4. Application listening on port 3000?
   ```bash
   kubectl logs -n bug-report-portal \
     deployment/bug-report-portal-app | grep 3000
   ```
   Should show "Server running on http://localhost:3000"

### Issue: Login credentials don't work

**Verify admin user exists:**
```bash
kubectl exec -it -n bug-report-portal pod/postgres-XXXXX -- \
  psql -U postgres -d bug_report_db \
  -c "SELECT * FROM users WHERE email='admin';"
```

**Reset admin password:**
```bash
# Delete admin user pod to reset database
kubectl delete pod postgres-XXXXX -n bug-report-portal

# PostgreSQL restarts with init script
# Default user: admin/admin created by init-db.sql
```

### Issue: E2E tests fail in pipeline

**Check test logs:**
```bash
# Jenkins console output shows test failures
# Navigate to Jenkins build → Console Output
# Look for test failure details

# Re-run tests manually:
npm run test:e2e -- --headed  # Show browser during test
```

**Common causes:**
- Application not ready when tests start (race condition)
- Hardcoded host/port in test config
- Database not initialized
- Credentials expired

---

## Rollback Deployment

If deployment has issues, rollback to previous version:

```bash
# List rollout history
kubectl rollout history deployment/bug-report-portal-app -n bug-report-portal

# Rollback to previous revision
kubectl rollout undo deployment/bug-report-portal-app -n bug-report-portal

# Rollback to specific revision
kubectl rollout undo deployment/bug-report-portal-app \
  -n bug-report-portal \
  --to-revision=3

# Verify rollback
kubectl rollout status deployment/bug-report-portal-app \
  -n bug-report-portal
```

---

## Continuous Monitoring

After successful deployment:

```bash
# Watch pod status
watch kubectl get pods -n bug-report-portal

# Monitor resource usage
kubectl top pods -n bug-report-portal

# Check service endpoints
kubectl get endpoints -n bug-report-portal

# View service details
kubectl describe svc bug-report-portal-service -n bug-report-portal

# Check ingress status (if enabled)
kubectl get ingress -n bug-report-portal
kubectl describe ingress bug-report-portal-ingress -n bug-report-portal
```

---

## Complete E2E Testing Checklist

After deployment, verify:

- [x] Jenkins build completes successfully (all 21 stages pass)
- [x] Docker image built and pushed to Docker Hub
- [x] All Kubernetes resources created (namespace, deployment, service, etc.)
- [x] Application pods in Running state
- [x] Database initialized with tables and seed data
- [x] Port-forward running on macOS
- [x] Browser loads http://localhost:8888/login
- [x] Login with admin/admin succeeds
- [x] Dashboard displays existing reports
- [x] Create new bug report works
- [x] Submit form saves data to database
- [x] Refresh browser shows created report persists
- [x] Update bug report functionality works
- [x] Delete bug report functionality works
- [x] Logout functionality works
- [x] Login again after logout succeeds
- [x] Application logs show no errors
- [x] Database contains created reports
- [x] Pod resource usage is normal
- [x] No pending or failed pods

---

## Next Steps

**For further deployment:**
- Scale replicas: `kubectl scale deployment bug-report-portal-app --replicas=5 -n bug-report-portal`
- Update image: Trigger new Jenkins build with DO_PUSH=true and DO_DEPLOY=true
- Monitor logs: `kubectl logs -f deployment/bug-report-portal-app -n bug-report-portal`
- Access pod shell: `kubectl exec -it deployment/bug-report-portal-app -n bug-report-portal -- /bin/sh`

---

## Reference

- **Error Fixes:** See [ERROR_FIXES.md](ERROR_FIXES.md)
- **Kubernetes Setup:** See [KIND_SETUP.md](KIND_SETUP.md)
- **Deployment Details:** See [DEPLOY_TO_K8S.md](DEPLOY_TO_K8S.md)
- **Troubleshooting:** See [TROUBLESHOOTING.md](TROUBLESHOOTING.md)
- **Jenkins Parameters:** See [JENKINS_BUILD_PARAMETERS.md](JENKINS_BUILD_PARAMETERS.md)
