# Namespace and Deployment Configuration Guide

**Comprehensive guide explaining how Kubernetes namespace is created and how deployments are managed across environments (dev, prod, uat)**

---

## 🎯 Key Concepts

### What is a Namespace?
A **Kubernetes namespace** is a logical partition of a cluster. Think of it as a separate "environment" or "workspace":

| Aspect | Single Namespace | Multi-Namespace |
|--------|------------------|-----------------|
| **Isolation** | Everything mixed | Dev separate from Prod |
| **Naming** | Objects can have same name | Same object names allowed in different namespaces |
| **RBAC** | Single policy | Different policies per environment |
| **Cleanup** | Delete one resource | Delete entire namespace at once |

**In your setup:**
- Namespace: `bug-report-portal-dev` (Development environment)
- Future: `bug-report-portal-prod` (Production environment)
- Future: `bug-report-portal-uat` (UAT environment)

---

## 📊 How Namespace is Created

### The Creation Flow

```
Jenkins Pipeline Triggered (with DO_DEPLOY=true)
    ↓
Stage: Deploy to Kubernetes
    ↓
Read: deploy-config.yaml
    ↓
Load: environments['dev']  (TARGET_ENV parameter)
    ↓
Extract: cfg.namespace = 'bug-report-portal-dev'
    ↓
Call: k8sDeploy(namespace: cfg.namespace, ...)
    ↓
Shared Library (k8sDeploy.groovy)
    ↓
Execute: kubectl apply -k k8s/
    ↓
Kustomize Processes Resources (in order):
    1️⃣  k8s/namespace.yaml (FIRST - creates namespace)
    2️⃣  k8s/app-secret.template.yaml
    3️⃣  k8s/postgres-pvc.yaml
    4️⃣  k8s/app-configmap.yaml
    5️⃣  k8s/postgres-deployment.yaml
    6️⃣  k8s/postgres-service.yaml
    7️⃣  k8s/app-deployment.yaml
    8️⃣  k8s/app-service.yaml
    9️⃣  k8s/ingress.yaml
    ↓
✅ Namespace 'bug-report-portal-dev' created
✅ All resources deployed in that namespace
```

### Why Namespace First?

Kustomize applies resources in the order they appear in `kustomization.yaml`:

```yaml
resources:
  - namespace.yaml           # ← FIRST (creates namespace)
  - app-secret.template.yaml # ← Then secrets
  - postgres-pvc.yaml        # ← Then storage
  - app-configmap.yaml       # ← Then config
  - postgres-deployment.yaml # ← Then database
  - postgres-service.yaml
  - app-deployment.yaml      # ← Then app
  - app-service.yaml
  - ingress.yaml             # ← Finally ingress
```

**Result:** Namespace must exist before other resources can be created inside it (K8s requirement).

---

## 🔄 How TARGET_ENV Picks the Namespace

### Configuration Files

**1. Jenkinsfile (Parameter Definition)**
```groovy
choice(name: 'TARGET_ENV', choices: ['dev'], description: 'Deployment environment')
```
- User selects: `TARGET_ENV = 'dev'`

**2. deploy-config.yaml (Environment Configuration)**
```yaml
environments:
  dev:                              # ← Matches TARGET_ENV = 'dev'
    clusterContext: kind-bug-report-portal
    namespace: bug-report-portal-dev   # ← THIS IS PICKED
    deploymentName: bug-report-portal-app
    imageName: bugreportportal
    manifestDir: devops/k8s
    skipTlsVerify: true
```

**3. Jenkinsfile (Environment Lookup)**
```groovy
stage('Deploy to Kubernetes') {
  when { expression { params.DO_DEPLOY } }
  steps {
    script {
      def allEnvs = readYaml(file: 'devops/deploy-config.yaml').environments
      def cfg = allEnvs[params.TARGET_ENV]  // ← Looks up 'dev'
      
      if (!cfg) {
        error("TARGET_ENV '${params.TARGET_ENV}' not found...")
      }
      
      k8sDeploy(
        namespace: cfg.namespace,  // ← 'bug-report-portal-dev' comes here
        deploymentName: cfg.deploymentName,
        imageName: cfg.imageName,
        manifestDir: cfg.manifestDir,
        ...
      )
    }
  }
}
```

### The Complete Lookup Process

```
User Build Parameters
    ↓
TARGET_ENV: 'dev'
    ↓
Jenkinsfile reads: deploy-config.yaml
    ↓
Looks up: allEnvs['dev']
    ↓
Retrieves config object:
{
  clusterContext: 'kind-bug-report-portal',
  namespace: 'bug-report-portal-dev',        ← Namespace comes here
  deploymentName: 'bug-report-portal-app',
  imageName: 'bugreportportal',
  manifestDir: 'devops/k8s',
  skipTlsVerify: true
}
    ↓
Passes to: k8sDeploy(namespace: cfg.namespace, ...)
    ↓
Shared library uses: kubectl apply -k . -n bug-report-portal-dev
```

---

## 📦 Files Involved in Namespace Creation

| File | Purpose | Contains |
|------|---------|----------|
| **k8s/namespace.yaml** | Defines namespace resource | `kind: Namespace`, `name: bug-report-portal-dev` |
| **k8s/app-configmap.yaml** | Config with namespace reference | `namespace: bug-report-portal-dev` |
| **k8s/app-secret.template.yaml** | Secrets with namespace reference | `namespace: bug-report-portal-dev` |
| **k8s/app-deployment.yaml** | App deployment with namespace | `namespace: bug-report-portal-dev` |
| **k8s/postgres-deployment.yaml** | Database with namespace reference | `namespace: bug-report-portal-dev` |
| **k8s/postgres-service.yaml** | Database service | `namespace: bug-report-portal-dev` |
| **k8s/app-service.yaml** | App service with namespace | `namespace: bug-report-portal-dev` |
| **k8s/ingress.yaml** | Ingress controller | `namespace: bug-report-portal-dev` |
| **deploy-config.yaml** | Environment configs | `dev.namespace: bug-report-portal-dev` |
| **kustomization.yaml** | Kustomize orchestration | Lists all resources in order |

**Key insight:** ALL files reference the same namespace (`bug-report-portal-dev`). If you change it in one place, change it everywhere!

---

## 🚀 End-to-End Deployment Flow

### Complete Pipeline Journey

```
1. SETUP PHASE
   Jenkins Parameter:    TARGET_ENV = 'dev'
   
2. CONFIGURATION PHASE
   Jenkinsfile reads:    deploy-config.yaml
   Looks up:             environments['dev']
   Retrieves:            namespace: 'bug-report-portal-dev'
   
3. KUBERNETES PHASE
   kubectl config:       use-context kind-bug-report-portal
   Apply resources:      kubectl apply -k k8s/ (with Kustomize)
   
   Execution order:
   ├── 1️⃣  Create namespace: bug-report-portal-dev
   ├── 2️⃣  Create secrets in namespace
   ├── 3️⃣  Create storage in namespace
   ├── 4️⃣  Create ConfigMap in namespace
   ├── 5️⃣  Start PostgreSQL in namespace
   ├── 6️⃣  Start PostgreSQL service in namespace
   ├── 7️⃣  Start Application in namespace
   ├── 8️⃣  Create App service in namespace
   └── 9️⃣  Create Ingress in namespace
   
4. VERIFICATION PHASE
   Check pods:           kubectl get pods -n bug-report-portal-dev
   Check deployment:     kubectl get deployment -n bug-report-portal-dev
   Check services:       kubectl get svc -n bug-report-portal-dev
   
5. ACCESS PHASE
   Port-forward:         kubectl port-forward -n bug-report-portal-dev svc/bug-report-portal-service 8888:3000
   Browser:              http://localhost:8888
   Credentials:          admin / admin123
```

---

## 🔧 Multi-Environment Setup (Future)

### Adding a PROD Environment

**Step 1: Update deploy-config.yaml**
```yaml
environments:
  dev:
    clusterContext: kind-bug-report-portal
    namespace: bug-report-portal-dev
    deploymentName: bug-report-portal-app
    imageName: bugreportportal
    manifestDir: devops/k8s
    skipTlsVerify: true
  
  prod:                                    # ← New environment
    clusterContext: prod-cluster-context   # ← Different cluster
    namespace: bug-report-portal-prod      # ← Different namespace
    deploymentName: bug-report-portal-app
    imageName: bugreportportal
    manifestDir: devops/k8s
    skipTlsVerify: false                   # ← TLS verification enabled for prod
```

**Step 2: Update Jenkinsfile**
```groovy
choice(name: 'TARGET_ENV', choices: ['dev', 'prod'], 
       description: 'Deployment environment')
```

**Step 3: Create Prod Namespace**
```yaml
# k8s/namespace-prod.yaml (optional, for docs)
apiVersion: v1
kind: Namespace
metadata:
  name: bug-report-portal-prod
  labels:
    environment: production
```

**Step 4: Trigger Build**
- Jenkins UI → Build with Parameters
- Select: `TARGET_ENV = 'prod'`
- Set: `DO_DEPLOY = true`
- Build! 🚀

**Result:**
- Prod cluster receives deployment
- Namespace: `bug-report-portal-prod` created
- All resources deployed separately from dev

---

## 🔍 Verification Commands

### List All Namespaces
```bash
kubectl get namespaces
```
**Output:**
```
NAME                     STATUS   AGE
default                  Active   2d
kube-system              Active   2d
bug-report-portal-dev    Active   5m        ← Your namespace
```

### Check Dev Namespace Contents
```bash
# All pods in dev namespace
kubectl get pods -n bug-report-portal-dev

# All services in dev namespace
kubectl get svc -n bug-report-portal-dev

# All deployments in dev namespace
kubectl get deployment -n bug-report-portal-dev

# All resources in dev namespace
kubectl get all -n bug-report-portal-dev
```

### Verify Namespace Configuration
```bash
# Show namespace details
kubectl describe namespace bug-report-portal-dev

# Show resources that reference this namespace
kubectl get all -n bug-report-portal-dev -o yaml | grep namespace:
```

### Check Current Deployment
```bash
# Show current image tag being used
kubectl get deployment bug-report-portal-app -n bug-report-portal-dev -o jsonpath='{.spec.template.spec.containers[0].image}'

# Show full deployment configuration
kubectl get deployment bug-report-portal-app -n bug-report-portal-dev -o yaml
```

---

## ❌ Common Issues and Fixes

### Issue 1: Resources Created in Wrong Namespace

**Symptom:** Can't find pods/services
```bash
kubectl get pods -n bug-report-portal-dev
# No resources found

kubectl get pods -n bug-report-portal
# Found old namespace!
```

**Cause:** deploy-config.yaml still references old namespace name

**Fix:** Update deploy-config.yaml with correct namespace
```yaml
environments:
  dev:
    namespace: bug-report-portal-dev  # ← Must match k8s manifests
```

### Issue 2: Namespace Not Found Error

**Symptom:** 
```
Error from server (NotFound): namespaces "bug-report-portal" not found
```

**Cause:** K8s manifests reference wrong namespace name

**Fix:** Verify all files use same namespace name:
```bash
# Check all namespace references
grep -r "namespace:" k8s/ deploy-config.yaml

# All should show: bug-report-portal-dev
```

### Issue 3: Old Pods Still Running

**Symptom:** Old image tag still deployed even after new build

**Cause:** Deployment stuck in old namespace

**Fix:** Delete old namespace and redeploy
```bash
kubectl delete namespace bug-report-portal
# This deletes old namespace and all resources in it
# Next deployment creates fresh namespace with new resources
```

---

## 📋 Checklist for E2E Deployment

Before deploying, verify:

- [ ] deploy-config.yaml uses correct namespace
- [ ] All k8s/*.yaml files reference same namespace
- [ ] TARGET_ENV parameter matches deploy-config.yaml key
- [ ] Jenkinsfile passes namespace to k8sDeploy()
- [ ] Kind cluster is running: `kind get clusters`
- [ ] kubectl can access cluster: `kubectl cluster-info`
- [ ] Shared library is available: Check Jenkins Manage/Configure

---

## 📚 Related Documentation

- **[E2E_DEPLOYMENT.md](E2E_DEPLOYMENT.md)** - Complete pipeline walkthrough
- **[DEPLOY_TO_K8S.md](DEPLOY_TO_K8S.md)** - Manual deployment without Jenkins
- **[KIND_SETUP.md](KIND_SETUP.md)** - Kubernetes cluster setup
- **[TESTING.md](TESTING.md)** - Quick deployment and testing
- **[QUICK_REFERENCE.md](QUICK_REFERENCE.md)** - Commands reference
