# Complete CI/CD Pipeline Setup - End-to-End Guide

Complete step-by-step guide to deploy Jenkins + SonarQube on Kubernetes and run the pipeline.

---

## 📊 Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    Your Kubernetes Cluster                   │
├─────────────────┬──────────────────────┬────────────────────┤
│                 │                      │                    │
│  jenkins NS     │   sonarqube NS       │  bug-report-portal │
│  ┌──────────┐   │   ┌──────────────┐   │  (Your App)        │
│  │ Jenkins  │   │   │ SonarQube    │   │                    │
│  │ (8080)   │───┼──→│ (9000)       │   │                    │
│  └──────────┘   │   ├──────────────┤   │                    │
│                 │   │ PostgreSQL   │   │                    │
│                 │   │ (5432)       │   │                    │
│                 │   └──────────────┘   │                    │
└─────────────────┴──────────────────────┴────────────────────┘
```

---

## 🚀 Step-by-Step Setup

### **Phase 1: Prerequisites** (5 minutes)

#### Check 1: Kubernetes Cluster Ready

```bash
# Verify kubectl is configured
kubectl cluster-info

# Expected output:
# Kubernetes control plane is running at https://...
# CoreDNS is running at https://...
```

#### Check 2: Storage Class Available

```bash
# Check available storage classes
kubectl get storageclass

# Expected output:
# NAME                 PROVISIONER            ...
# standard (default)   k8s.io/minikube-hostpath
```

#### Check 3: Enough Resources

```bash
# Check cluster resources
kubectl top nodes

# For this setup, you need:
# - At least 4GB RAM available
# - At least 2 CPU cores
# - 50GB disk space (for PVCs)
```

---

### **Phase 2: Deploy Infrastructure** (10-15 minutes)

#### Step 1: Deploy SonarQube (+ PostgreSQL)

```bash
# Navigate to devops repo
cd /path/to/bug-report-portal-devops

# Deploy SonarQube stack
kubectl apply -k k8s/sonarqube/

# Wait for pods to be ready
kubectl -n sonarqube get pods -w

# Expected:
# sonarqube-postgres-xxx   1/1     Running   0          2m
# sonarqube-xxx            1/1     Running   0          5m (takes longer)
```

**⏱️ SonarQube takes 2-3 minutes to start up. WAIT until it's Running.**

#### Step 2: Deploy Jenkins

```bash
# Deploy Jenkins stack
kubectl apply -k k8s/jenkins/

# Wait for pod to be ready
kubectl -n jenkins get pods -w

# Expected:
# jenkins-xxx   1/1     Running   0          2m
```

#### Step 3: Verify Both Are Running

```bash
# Check all namespaces
kubectl get pods -n jenkins
kubectl get pods -n sonarqube

# Both should show 1/1 Running status
```

---

### **Phase 3: Access Jenkins** (5 minutes)

#### Option A: Port Forward (Easiest for Local Development)

```bash
# Forward Jenkins port
kubectl -n jenkins port-forward svc/jenkins 8080:8080

# Open browser
open http://localhost:8080/jenkins

# Keep terminal open while using Jenkins
```

#### Option B: LoadBalancer (Cloud Kubernetes)

```bash
# Get external IP
kubectl -n jenkins get svc jenkins

# Wait for EXTERNAL-IP to be assigned:
kubectl -n jenkins get svc jenkins --watch

# Open browser
open http://<EXTERNAL-IP>:8080/jenkins
```

#### Step 1: Get Initial Admin Password

```bash
# Method 1: From pod logs
kubectl -n jenkins logs deployment/jenkins | grep "password"

# Method 2: From pod
kubectl -n jenkins exec -it deployment/jenkins -- \
  cat /var/jenkins_home/secrets/initialAdminPassword

# Copy the password (you'll need it)
```

#### Step 2: First Login

1. Open Jenkins UI: `http://localhost:8080/jenkins`
2. Paste the admin password
3. Click **Continue**
4. Click **Install Suggested Plugins** (takes 2-3 minutes)
5. Create admin user:
   - Username: `admin`
   - Password: Your choice
   - Email: Your email
6. Click **Save and Continue** → **Start using Jenkins**

---

### **Phase 4: Configure Jenkins** (10 minutes)

#### Step 1: Configure Git Credentials

1. **Jenkins Dashboard** → **Manage Jenkins** → **Credentials**
2. Click **System** → **Global credentials**
3. **New credentials** → Select **GitHub (or Git)**
4. Fill in:
   - Username: Your GitHub username
   - Password: GitHub Personal Access Token
   - ID: `github-pat`
5. Click **Create**

#### Step 2: Create SonarQube Token in SonarQube

```bash
# Port forward to SonarQube
kubectl -n sonarqube port-forward svc/sonarqube 9000:9000

# Open browser
open http://localhost:9000
```

1. Login to SonarQube:
   - Username: `admin`
   - Password: `admin`
2. Change password (forced on first login)
3. Go to **My Account** → **Security** → **Generate Tokens**
4. Create token:
   - Token name: `jenkins-token`
   - Click **Generate**
5. **Copy the token** (you'll need it)

#### Step 3: Store SonarQube Token in Jenkins

1. **Jenkins Dashboard** → **Manage Jenkins** → **Credentials**
2. Click **System** → **Global credentials**
3. **New credentials**:
   - Kind: **Secret text**
   - Secret: Paste the SonarQube token
   - ID: `sonar-token`
4. Click **Create**

---

### **Phase 5: Create Jenkins Job** (5 minutes)

#### Step 1: Create New Pipeline Job

1. **Jenkins Dashboard** → **New Item**
2. Name: `bug-report-portal`
3. Type: **Pipeline**
4. Click **OK**

#### Step 2: Configure Pipeline

**General Tab:**
- Check: **GitHub project**
- URL: `https://github.com/ravi2342/bug-report-portal-devops`

**Build Triggers Tab:**
- Check: **GitHub hook trigger for GITScm polling**

**Pipeline Tab:**
- Definition: **Pipeline script from SCM**
- SCM: **Git**
- Repository URL: `https://github.com/ravi2342/bug-report-portal-devops`
- Branch: `master`
- Script Path: `Jenkinsfile`

**Save the job**

---

### **Phase 6: Run the Pipeline** (15-30 minutes)

#### Option 1: Manual Trigger

1. Go to job: **bug-report-portal**
2. Click **Build with Parameters**
3. Fill in parameters:
   - `BRANCH`: `master`
   - `DO_PUSH`: `false` (skip for testing)
   - `DO_DEPLOY`: `false` (skip for testing)
   - `RUN_SONAR`: `true` ← This will test SonarQube
   - `SONAR_TOKEN_CREDENTIALS_ID`: `sonar-token`
4. Click **Build**

#### Option 2: Automated via Webhook

1. GitHub repo settings
2. **Settings** → **Webhooks** → **Add webhook**
3. Payload URL: `http://jenkins-service-url:8080/jenkins/github-webhook/`
4. Click **Add webhook**
5. Every push to master will trigger Jenkins automatically

---

### **Phase 7: Monitor Pipeline** (Real-time)

#### Watch Build Progress

```bash
# In Jenkins UI:
# - Job name → Build #N → Console Output
# Shows real-time logs as pipeline runs

# In terminal (optional):
kubectl -n jenkins logs -f deployment/jenkins
```

#### Pipeline Stages

1. **Clean Workspace** ✅ (10 sec)
2. **Checkout** ✅ (5 sec)
3. **Build Metadata** ✅ (5 sec)
4. **Preflight Checks** ✅ (5 sec)
5. **Install Dependencies** ✅ (1 min)
6. **Prisma Generate** ✅ (30 sec)
7. **Lint** ✅ (30 sec)
8. **Run Tests** ✅ (1 min)
9. **SonarQube Scan** ✅ (2 min) - This tests SonarQube connection
10. **Build Docker Image** (3-5 min)
11. **Cleanup & Report** ✅ (1 min)

**Total: ~12-15 minutes for first build**

---

### **Phase 8: Verify Success** ✅

#### Jenkins Build Completed

```
╔═══════════════════════════════════════════╗
║      PIPELINE EXECUTION SUMMARY           ║
╠═══════════════════════════════════════════╣
║ Status:        SUCCESS                    ║
║ Build #:       1                          ║
║ Duration:      15 min                     ║
║ Image Tag:     demu147/bugreportportal:.. ║
╚═══════════════════════════════════════════╝
```

#### View SonarQube Results

```bash
# Go to SonarQube UI
open http://localhost:9000

# Or find results:
# SonarQube → Projects → bug-report-portal
# See code quality metrics, coverage, etc.
```

---

## 🆘 Troubleshooting

### Jenkins Not Starting

```bash
# Check logs
kubectl -n jenkins logs deployment/jenkins

# Common issues:
# - PVC not bound: Check storage class
# - Image pull failed: Check Docker credentials
# - Port already in use: Use different port
```

### SonarQube Not Reachable from Jenkins

```bash
# Test connectivity from Jenkins pod
kubectl -n jenkins exec -it deployment/jenkins -- \
  curl -v http://sonarqube.sonarqube.svc.cluster.local:9000/api/system/status

# If fails:
# 1. Verify SonarQube is running: kubectl -n sonarqube get pods
# 2. Verify service exists: kubectl -n sonarqube get svc
# 3. Check firewall rules
```

### Tests Failing

```bash
# Check app repo for issues
git clone https://github.com/ravi2342/bugreportportal.git
cd bugreportportal

# Verify locally
npm ci
npm test
npm run lint
```

---

## 🧹 Cleanup

### Remove Everything

```bash
# Delete Jenkins
kubectl delete -k k8s/jenkins/

# Delete SonarQube
kubectl delete -k k8s/sonarqube/

# Or delete entire namespaces
kubectl delete namespace jenkins sonarqube
```

### Keep Data (Remove Only Pods)

```bash
# This keeps PVCs and secrets
kubectl -n jenkins scale deployment jenkins --replicas=0
kubectl -n sonarqube scale deployment sonarqube --replicas=0
```

---

## 📚 Next Steps

Once this works, you can:

1. **Add More Stages**
   - Deploy to Kubernetes
   - Run smoke tests
   - Publish artifacts

2. **Integrate with GitHub**
   - Webhooks for automatic builds
   - Pull request checks

3. **Add More Tools**
   - Checkmarx for security scanning
   - Prometheus for monitoring
   - Slack notifications

---

## ⏱️ Timeline Summary

| Phase | Duration | Task |
|-------|----------|------|
| Prerequisites | 5 min | Check cluster resources |
| Infrastructure | 15 min | Deploy SonarQube + Jenkins |
| Access Setup | 5 min | Get Jenkins password, login |
| Configuration | 10 min | Add credentials, create job |
| First Run | 15 min | Execute pipeline |
| **Total** | **50 min** | **Complete end-to-end setup** |

---

## 📖 Documentation Links

- [Jenkinsfile](../Jenkinsfile) - Pipeline definition
- [Jenkins K8s Deployment](k8s/jenkins/) - Kubernetes manifests
- [SonarQube K8s Deployment](k8s/sonarqube/) - SonarQube setup
- [Troubleshooting Guide](JENKINS_TROUBLESHOOTING.md) - Common issues
