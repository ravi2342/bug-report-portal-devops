# 🚀 Quick Local E2E Test (5-10 minutes)

## Prerequisites
- Kind cluster: `kind create cluster --name bug-report-portal --wait 2m`
- Docker Compose running
- kubectl configured

---

## ⚡ Quick Steps

### 1️⃣ Restart Docker Compose
```bash
docker compose down && sleep 5 && docker compose up -d && sleep 60
```

### 2️⃣ Check Services Running
```bash
docker compose ps
```
**Expected:** Jenkins ✅, PostgreSQL ✅, SonarQube 🔄

---

### 3️⃣ Trigger Jenkins Build

**Via Browser:**
1. Open: http://localhost:8080/jenkins
2. Login: `admin` / `admin`
3. Click **bug-report-portal** → **Build with Parameters**
4. Set:
   ```
   DO_PUSH=true
   DO_DEPLOY=true
   RUN_SONAR=false
   ```
5. Click **Build**

**Via CLI:**
```bash
curl -X POST http://localhost:8080/jenkins/job/bug-report-portal/buildWithParameters \
  -u admin:admin -F DO_PUSH=true -F DO_DEPLOY=true -F RUN_SONAR=false
```

---

### 4️⃣ Monitor Build
```bash
# Watch Kubernetes deployment
kubectl get pods -n bug-report-portal -w

# Expected: 3 app pods → Running status
```

---

### 5️⃣ Port-Forward (New Terminal on macOS)
```bash
kubectl port-forward -n bug-report-portal svc/bug-report-portal-service 8888:3000
```
⚠️ Keep this running | Ctrl+C to stop

---

### 6️⃣ Access Application
```
Browser: http://localhost:8888

Login: admin / admin
```

---

## ✅ Success Checklist
- [ ] Jenkins build: All stages GREEN ✅
- [ ] Pods: `kubectl get pods -n bug-report-portal` shows 3 Running
- [ ] Port-forward: Shows "Forwarding from 127.0.0.1:8888 -> 3000"
- [ ] Browser: http://localhost:8888 loads login page
- [ ] Login: Works with admin/admin

---

## 🕐 Timing
| Step | Duration |
|------|----------|
| Docker restart | ~60 sec |
| Jenkins build | ~3-5 min |
| Deployment wait | ~1-2 min |
| **Total** | **~6-10 min** |

---

## 🔗 See Also
- **Full Details:** [E2E_DEPLOYMENT.md](E2E_DEPLOYMENT.md)
- **Troubleshooting:** [QUICK_REFERENCE.md](QUICK_REFERENCE.md)
- **Setup Guide:** [KIND_SETUP.md](KIND_SETUP.md)
