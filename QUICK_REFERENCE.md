# Quick Reference Guide - Complete Workflow

Fast reference for common tasks, commands, and troubleshooting.

---

## 🎯 What's in This Guide?

✅ **Quick Start** - 5-step deployment workflow  
✅ **Common Commands** - Copy-paste kubectl/docker/jenkins commands  
✅ **Troubleshooting** - Quick fixes for common issues  
✅ **Key Concepts** - Understanding Docker/Kubernetes/Port-forward architecture  
✅ **Emergency Procedures** - Force restart/reset commands  
✅ **Pipeline Stages** - All 21+ Jenkins stages explained  

**For detailed error analysis, root causes & solutions:**  
👉 **[ERROR_FIXES.md](ERROR_FIXES.md)** - Complete troubleshooting with error logs

---

## 🆕 First Time Setup?

**New to this project?** Start with the complete guide first:
👉 **[LOCAL_TESTING_COMPLETE_GUIDE.md](LOCAL_TESTING_COMPLETE_GUIDE.md)** - Step-by-step for Windows/macOS/Linux
- Part 1: Pre-flight checklist
- Part 2: Software installation (all OS)
- Parts 3-12: Complete workflow from setup to testing

Then come back here for quick commands and concepts.

---

## �🚀 Quick Start: Deploy & Access Application

### 1️⃣ Trigger Build in Jenkins
```bash
# Option A: Manual
Open http://localhost:8080/jenkins → Build with Parameters:
- DO_PUSH: ✓
- DO_DEPLOY: ✓
- RUN_UI_E2E: ✓

# Option B: Automatic
git push origin master  # (If webhook configured)
```

### 2️⃣ Monitor Build Progress
```bash
# Watch Jenkins build
http://localhost:8080/jenkins/job/bug-report-portal/XX/console

# Expected: All 21+ stages pass ✓
```

### 3️⃣ Verify Deployment
```bash
kubectl get all -n bug-report-portal
# Expected: All pods Running, service has CLUSTER-IP
```

### 4️⃣ Start Port-Forward on macOS

**Option A: Foreground (terminal stays open)**
```bash
kubectl port-forward -n bug-report-portal \
  svc/bug-report-portal-service 8888:3000 \
  --insecure-skip-tls-verify
```

**Option B: Background with output file (Recommended)**
```bash
kubectl port-forward -n bug-report-portal \
  svc/bug-report-portal-service 8888:3000 \
  --insecure-skip-tls-verify > ~/.kube/portforward.log 2>&1 &
```

**Option C: Background with nohup (survives terminal close)**
```bash
nohup kubectl port-forward -n bug-report-portal \
  svc/bug-report-portal-service 8888:3000 \
  --insecure-skip-tls-verify > ~/.kube/portforward.log 2>&1 &
```

**Check if running:**
```bash
ps aux | grep "kubectl port-forward" | grep -v grep
```

**View logs:**
```bash
tail -f ~/.kube/portforward.log
```

**Stop port-forward:**
```bash
pkill -f "kubectl port-forward"
```

### 5️⃣ Access Application
```
Browser: http://localhost:8888
Login: admin / admin
```

---

## 📋 Common Commands

### Monitor Deployment
```bash
# Real-time pod status
watch kubectl get pods -n bug-report-portal

# Pod logs
kubectl logs -n bug-report-portal deployment/bug-report-portal-app -f

# Resource usage
kubectl top pods -n bug-report-portal

# Describe pod (for troubleshooting)
kubectl describe pod POD_NAME -n bug-report-portal
```

### Manage Application
```bash
# Rollback to previous version
kubectl rollout undo deployment/bug-report-portal-app -n bug-report-portal

# Scale replicas
kubectl scale deployment bug-report-portal-app --replicas=5 -n bug-report-portal

# Restart pods
kubectl rollout restart deployment/bug-report-portal-app -n bug-report-portal

# Access pod shell
kubectl exec -it deployment/bug-report-portal-app -n bug-report-portal -- /bin/sh
```

### Database Access
```bash
# Port-forward PostgreSQL
kubectl port-forward -n bug-report-portal svc/postgres 5432:5432 &

# Connect to database
psql -h localhost -U postgres -d bug_report_db

# Useful psql commands:
\dt              # List tables
SELECT * FROM reports;  # View reports
\q              # Exit
```

### Jenkins
```bash
# View Jenkins logs
docker compose logs -f jenkins

# Jenkins UI
http://localhost:8080/jenkins

# Build parameters reference
cat JENKINS_BUILD_PARAMETERS.md
```

---

## ⚠️ Troubleshooting Quick Fixes

### 🔴 Port-forward not working
```bash
# Check if port-forward running
ps aux | grep "kubectl port-forward" | grep -v grep

# If not running, restart in background:
nohup kubectl port-forward -n bug-report-portal \
  svc/bug-report-portal-service 8888:3000 \
  --insecure-skip-tls-verify > ~/.kube/portforward.log 2>&1 &

# View logs
tail -f ~/.kube/portforward.log

# If still failing, check pod is ready
kubectl get pods -n bug-report-portal

# Kill stuck port-forward and restart
pkill -f "kubectl port-forward"
sleep 2
nohup kubectl port-forward -n bug-report-portal \
  svc/bug-report-portal-service 8888:3000 \
  --insecure-skip-tls-verify > ~/.kube/portforward.log 2>&1 &
```

### 🔴 Application not responding
```bash
# Check pod status
kubectl get pods -n bug-report-portal

# Check pod logs
kubectl logs -n bug-report-portal deployment/bug-report-portal-app

# Check service
kubectl get svc -n bug-report-portal

# Verify pod has IP
kubectl get pods -n bug-report-portal -o wide
```

### 🔴 Database connection error
```bash
# Check postgres pod
kubectl get pods -n bug-report-portal | grep postgres

# Check postgres logs
kubectl logs -n bug-report-portal deployment/postgres

# Verify service
kubectl get svc -n bug-report-portal | grep postgres
```

### 🔴 TLS/Certificate error
```bash
# This is expected for local Kind cluster
# Add --insecure-skip-tls-verify flag:

kubectl port-forward -n bug-report-portal \
  svc/bug-report-portal-service 8888:3000 \
  --insecure-skip-tls-verify
```

### 🔴 Image pull failure
```bash
# Check image tag in Jenkins output
# Deploy stage shows: IMAGE_TAG: demu147/bugreportportal:1.0.0-XX

# Verify image pushed to Docker Hub
docker images | grep bugreportportal

# If image not in Docker Hub, re-push:
docker push demu147/bugreportportal:1.0.0-XX
```

### 🔴 Jenkins won't deploy
```bash
# Check Jenkins logs
docker compose logs jenkins | tail -50

# Check kubeconfig exists
ls -la ~/.kube/config

# Verify Jenkins can access Kind cluster
docker compose exec -T jenkins kubectl cluster-info
```

---

## 📚 Documentation Files

| File | Purpose | When to Read |
|------|---------|-------------|
| **ERROR_FIXES.md** | All issues & solutions | Debugging problems |
| **E2E_DEPLOYMENT.md** | Complete step-by-step guide | First deployment |
| **JENKINS_BUILD_PARAMETERS.md** | Build parameters reference | Configuring builds |
| **KIND_SETUP.md** | Kubernetes cluster setup | Setting up Kind |
| **DEPLOY_TO_K8S.md** | Manual deployment steps | Deploying without pipeline |
| **TROUBLESHOOTING.md** | Common issues & fixes | Debugging |

---

## 🔑 Key Concepts

### Docker Networking
- **Host machine (macOS):** 127.0.0.1
- **Jenkins container:** 127.0.0.1 = container's own localhost (NOT host machine)
- **Jenkins container to host:** Use `host.docker.internal` instead
- **Port-forward inside container:** Invisible to macOS browser
- **Port-forward on macOS:** Visible to browser ✓

### Kubeconfig
- **Location:** ~/.kube/config
- **Contains:** Cluster endpoint, certificates, auth info
- **For host machine:** Uses 127.0.0.1
- **For Jenkins container:** Temporarily uses host.docker.internal
- **After build:** Restored to 127.0.0.1

### Port-Forward
- **Must run on:** macOS terminal (user's machine)
- **Never in:** Jenkinsfile (Jenkins container)
- **Purpose:** Create tunnel from localhost:8888 → pod:3000
- **Duration:** Keep terminal open while using application

### TLS Certificates
- **Kind cluster:** Self-signed certificate for localhost
- **Jenkins connects via:** host.docker.internal (different name)
- **Certificate validation:** Fails because cert doesn't match domain
- **Solution:** Use --insecure-skip-tls-verify flag (safe for local dev)

---

## 📊 Pipeline Stages (21 Total)

### Always Run (Stages 1-7)
1. Checkout SCM
2. Setup & Verification
3. Install Dependencies
4. Run Tests
5. Code Coverage
6. SonarQube Scan (optional)
7. Quality Gate Check

### On DO_PUSH=true (Stages 8-9)
8. Build Docker Image
9. Push to Docker Registry

### On DO_DEPLOY=true (Stages 10-12)
10. Deploy to Kubernetes
11. Wait for Rollout
12. Setup Port-Forward

### On RUN_POST_DEPLOY_TESTS=true (Stage 13)
13. Post-Deploy Health Check

### On RUN_UI_E2E=true (Stage 14)
14. E2E UI Tests

### Always Run (Stages 15-21)
15. Collect Test Reports
16. Docker Cleanup
17. Send Notifications
18. Cleanup & Report
(+ other cleanup stages)

---

## 🎯 Typical Development Workflow

### Day 1: Initial Setup
```bash
# Create Kind cluster
kind create cluster --config kind-config.yaml

# Start Jenkins
docker compose up -d

# Configure kubeconfig for Jenkins
# (See KIND_SETUP.md)
```

### Day 2+: Deploy Updates
```bash
# Make code changes
cd ~/bugreportportal
nano src/app.js
git add .
git commit -m "Feature: Add new field"
git push origin master

# Wait for Jenkins build to complete
# (Or manually trigger in Jenkins UI)

# After build, run port-forward
kubectl port-forward -n bug-report-portal \
  svc/bug-report-portal-service 8888:3000 \
  --insecure-skip-tls-verify

# Test in browser
# http://localhost:8888
```

---

## 🆘 Emergency Procedures

### Stuck Pod - Full Restart
```bash
# Delete pod (triggers restart)
kubectl delete pod POD_NAME -n bug-report-portal

# Wait for new pod to start
kubectl get pods -n bug-report-portal -w
```

### Stuck Database - Reset
```bash
# Delete postgres pod
kubectl delete pod postgres-XXXXX -n bug-report-portal

# Pod restarts, initializes fresh with init-db.sql
```

### Port-Forward Stuck - Kill & Restart
```bash
# Kill all port-forward processes
pkill -f "kubectl port-forward"

# Wait 5 seconds
sleep 5

# Restart port-forward
kubectl port-forward -n bug-report-portal \
  svc/bug-report-portal-service 8888:3000 \
  --insecure-skip-tls-verify
```

### Jenkins Broken - Full Reset
```bash
# Stop services
docker compose down

# Clean Jenkins data
rm -rf ~/jenkins_home/*

# Restart
docker compose up -d

# Wait 2 minutes for Jenkins to start
# Then reconfigure from scratch
```

### Kind Cluster Broken - Recreate
```bash
# Delete existing cluster
kind delete cluster --name bug-report-portal

# Create new cluster
kind create cluster --config kind-config.yaml

# Redeploy application
# (See E2E_DEPLOYMENT.md, Step 2 onwards)
```

---

## 📞 Quick Links

- **Jenkins:** http://localhost:8080/jenkins
- **SonarQube:** http://localhost:9000
- **Application:** http://localhost:8888 (after port-forward)
- **GitHub (App):** https://github.com/ravi2342/bugreportportal
- **GitHub (DevOps):** https://github.com/ravi2342/bug-report-portal-devops
- **Docker Hub:** https://hub.docker.com/r/demu147/bugreportportal

---

## ✅ Health Check Checklist

Run this to verify everything is working:

```bash
# 1. Kind cluster running
kind get clusters

# 2. kubectl configured
kubectl cluster-info

# 3. Namespace exists
kubectl get namespace bug-report-portal

# 4. Pods running
kubectl get pods -n bug-report-portal

# 5. Services exist
kubectl get svc -n bug-report-portal

# 6. Port-forward working
# (Run in separate terminal)
kubectl port-forward -n bug-report-portal \
  svc/bug-report-portal-service 8888:3000 \
  --insecure-skip-tls-verify

# 7. Application responds
curl -k http://localhost:8888/login

# 8. Database connected
kubectl logs -n bug-report-portal \
  deployment/bug-report-portal-app | grep "Connected to PostgreSQL"
```

If all checks pass ✓, your deployment is healthy!

---

## Need Help?

1. **Check ERROR_FIXES.md** - Complete solutions for all known issues
2. **Check E2E_DEPLOYMENT.md** - Detailed step-by-step deployment guide
3. **Check TROUBLESHOOTING.md** - Common issues and fixes
4. **Check logs:** `kubectl logs -n bug-report-portal deployment/POD_NAME`
5. **Check pod status:** `kubectl describe pod POD_NAME -n bug-report-portal`
