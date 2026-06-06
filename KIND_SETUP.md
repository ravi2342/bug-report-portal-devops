# Kind (Kubernetes in Docker) Setup Guide

## Why Kind Instead of Minikube?

Kind is the better choice for Jenkins + Docker Compose environments.

### The Problem with Minikube

Minikube is a great tool, but it has **network isolation issues** when running Jenkins in Docker Compose:

| Aspect | Minikube | Kind |
|--------|----------|------|
| **Runs in** | Host machine VM/Docker | Docker (like Jenkins) |
| **Network** | Isolated from Docker Compose | Shared Docker network |
| **Jenkins Access** | ❌ Cannot reach from container | ✅ Can reach via `host.docker.internal` |
| **Setup Complexity** | Simple for single user | Simple + container-friendly |
| **Use Case** | Local single-user development | CI/CD, containerized workflows |

### What We Tried with Minikube
1. ❌ Direct kubectl from Jenkins container → Connection refused (different networks)
2. ❌ Copied kubeconfig to Jenkins → Certificate path issues (host-relative paths)
3. ❌ Modified kubeconfig to use host machine IP → TLS verification failed
4. ❌ Used `extra_hosts` in docker-compose → Still couldn't route properly

**Root Cause:** Docker Compose runs Jenkins on a bridge network (ci-cd), Minikube runs on host machine. These networks don't have direct routing.

### Why Kind Works
- Kind runs **inside Docker** like Jenkins
- Both Jenkins and Kind use the **same Docker daemon**
- Jenkins can reach Kind via `host.docker.internal` (Docker's built-in hostname)
- Simple one-line setup: `kind create cluster --name bug-report-portal`

---

## Prerequisites: Kind Requires kubectl

**Important:** Kind and kubectl are **two different tools**:

| Tool | Purpose | Role |
|------|---------|------|
| **Kind** | Creates Kubernetes cluster | Server |
| **kubectl** | Interacts with cluster | Client |

**Without kubectl, you CANNOT:**
- Deploy applications
- Check pod status  
- View logs
- Access the cluster at all

Think of it like: Kind starts a database server, but kubectl is the client tool to query it.

---

## Installation Steps (9 steps, in order)

### Step 1: Install kubectl (CLI tool to interact with Kubernetes)
```bash
brew install kubectl
```

**Verify installation:**
```bash
kubectl version --client
# Output: Client Version: v1.33.1, Git commit: abc1234, Built: 2026-06-06...
```

### Step 2: Install Kind (Kubernetes cluster creator)
```bash
brew install kind
```

**Verify installation:**
```bash
kind version
# Output: kind v0.32.0 go1.23.2 darwin/arm64
```

**Why install kubectl FIRST?**
- Kind uses kubectl under the hood
- kubectl needs to be in PATH before Kind creates clusters
- Ensures smooth cluster creation and immediate access

### Step 3: Create Kind Cluster
```bash
kind create cluster --name bug-report-portal --wait 2m
```

**What happens:**
- Creates single-node Kubernetes cluster
- Runs cluster in Docker containers
- Sets kubectl context to `kind-bug-report-portal`
- Waits for control plane to be ready

### Step 4: Verify Both Tools Work Together
```bash
# Verify cluster was created
kind get clusters
# Output: bug-report-portal

# Verify kubectl can access it
kubectl cluster-info --context kind-bug-report-portal
# Output: Kubernetes control plane is running at https://127.0.0.1:xxxxx
```

### Step 5: Create Kubernetes Resources
```bash
cd /Users/demu/bug-report-portal-devops

# Apply all manifests - Kustomize automatically creates the namespace first
kubectl apply -k k8s/
```

**What gets created automatically:**
- Namespace: `bug-report-portal`
- ConfigMap, Secret, PVC
- PostgreSQL deployment + service
- App deployment + service + ingress

**No manual namespace creation needed** ✅ (unlike Minikube)

### Step 6: Modify Kubeconfig for Jenkins Container

Kind uses `127.0.0.1` (localhost) which works on host, but Jenkins runs in a Docker container on a different network.

**Solution:** Modify kubeconfig to use `host.docker.internal`:

```bash
# Replace 127.0.0.1 with host.docker.internal in kubeconfig
kubectl config view --raw | sed 's/127\.0\.0\.1/host.docker.internal/g' > ~/.kube/config

# Verify the change
grep "server:" ~/.kube/config
# Output: server: https://host.docker.internal:65148
```

### Step 7: Update Docker-Compose

Jenkins service needs access to the modified kubeconfig:

```yaml
# docker-compose.yml - jenkins section
jenkins:
  volumes:
    - ~/.kube:/root/.kube:ro        # Mount entire .kube directory
  environment:
    KUBECONFIG: /root/.kube/config  # Tell Jenkins where to find it
```

### Step 8: Restart Docker-Compose Services
```bash
docker compose down
docker compose up -d
sleep 30  # Wait for services to start
```

### Step 9: Verify Jenkins Can Access Kind Cluster
```bash
docker exec jenkins kubectl --insecure-skip-tls-verify cluster-info
# Output: Kubernetes control plane is running at https://host.docker.internal:65148
```

✅ **Setup complete!** Jenkins can now deploy to Kind cluster.

---

## What is Kubeconfig? (Important!)

### Overview
**Kubeconfig** is a configuration file that tells `kubectl` how to connect to Kubernetes clusters.

**File Location:**
```bash
~/.kube/config
```

**Why it's needed:**
Without kubeconfig, kubectl has no idea:
- Where your cluster is located (IP address)
- How to authenticate (certificates, tokens)
- Which cluster to use by default
- What user/context to apply

**Analogy:** Kubeconfig is like a connection string for a database - it tells the client where the server is and how to authenticate.

### Kubeconfig Structure

```yaml
apiVersion: v1
kind: Config

# 1. CLUSTERS: Where are your Kubernetes servers?
clusters:
- cluster:
    certificate-authority: /Users/demu/.kube/ca.crt
    server: https://host.docker.internal:65148  # Server address
  name: kind-bug-report-portal                  # Cluster identifier

# 2. CONTEXTS: Which cluster + user + namespace combo?
contexts:
- context:
    cluster: kind-bug-report-portal             # Use this cluster
    user: kind-bug-report-portal                # Use this user
    namespace: default                          # Default namespace
  name: kind-bug-report-portal                  # Context name

# 3. USERS: How to authenticate?
users:
- name: kind-bug-report-portal
  user:
    client-certificate: /Users/demu/.kube/kind-certs/client-cert.crt
    client-key: /Users/demu/.kube/kind-certs/client-key.key

# 4. CURRENT CONTEXT: Which one to use by default?
current-context: kind-bug-report-portal
```

### Three Key Components

| Component | Purpose | Example |
|-----------|---------|---------|
| **Clusters** | Where is the Kubernetes server? | `https://host.docker.internal:65148` |
| **Contexts** | Which cluster + user + namespace? | `kind-bug-report-portal` |
| **Users** | How to authenticate? | Certificate path, token, etc. |

### How kubectl Uses Kubeconfig

```bash
# When you run this:
kubectl cluster-info

# kubectl does this:
# 1. Reads current-context from kubeconfig (kind-bug-report-portal)
# 2. Looks up cluster details (server: https://host.docker.internal:65148)
# 3. Finds user auth (client-certificate, client-key)
# 4. Connects to server using that config
```

### Kubeconfig Common Commands

```bash
# View entire kubeconfig
kubectl config view

# View raw kubeconfig (unresolved paths)
kubectl config view --raw

# List all clusters in kubeconfig
kubectl config get-clusters

# List all contexts
kubectl config get-contexts

# Get current context
kubectl config current-context

# Switch to different context
kubectl config use-context kind-bug-report-portal

# Set default namespace for context
kubectl config set-context kind-bug-report-portal --namespace=bug-report-portal

# Get kubeconfig file location
echo $KUBECONFIG  # If set, else ~/.kube/config is default
```

---

## Understanding Kind + kubectl Relationship

```
┌──────────────────────────────────────────────────────────────┐
│ Your Machine (macOS)                                         │
├─────────────────────┬────────────────────────────────────────┤
│ kubectl             │ Kind                                   │
│ (client tool)       │ (cluster creator)                      │
│                     │                                        │
│ ▲ Sends commands    │ ▼ Creates/manages cluster             │
│ │ via kubeconfig    │ Uses kubectl internally               │
│ └─────────┬─────────┘──┬───────────────────────┐            │
│           │            │                       │            │
│           └────────────┴───────────────────────┘            │
│                        │                                     │
│                        ▼ (via kubeconfig)                    │
│               ┌────────────────────┐                         │
│               │ Kind Cluster       │                         │
│               │ (running in Docker)│                         │
│               │                    │                         │
│               │ - Control Plane    │                         │
│               │ - Nodes            │                         │
│               │ - Network          │                         │
│               └────────────────────┘                         │
└──────────────────────────────────────────────────────────────┘
```

### Typical Workflow

```bash
# 1. Install both tools FIRST
brew install kubectl    # Install client
brew install kind       # Install cluster creator

# 2. Create a cluster
kind create cluster --name bug-report-portal

# 3. Verify cluster was created
kind get clusters       # Shows: bug-report-portal

# 4. Now use kubectl to interact with it
kubectl cluster-info           # Check if accessible
kubectl get nodes              # List cluster nodes
kubectl apply -k k8s/          # Deploy apps
kubectl get pods -n bug-report-portal  # Check deployment

# 5. When done, delete cluster
kind delete cluster --name bug-report-portal
```

---

## Comparing Kind vs Minikube

### Installation Difference

**Minikube** (includes kubectl):
```bash
brew install minikube
minikube start --driver=docker
```

**Kind** (requires kubectl separately):
```bash
brew install kubectl    # First!
brew install kind       # Second
kind create cluster --name bug-report-portal
```

### Network Access from Jenkins Container

**Kind** ✅ Works:
```bash
docker exec jenkins kubectl cluster-info
# ✓ Successfully connects via host.docker.internal
```

**Minikube** ❌ Fails:
```bash
docker exec jenkins kubectl cluster-info
# ✗ Error: couldn't get current server API group list
```

### Resource Usage

- **Kind:** ~1 container, ~400MB RAM
- **Minikube:** ~1 VM, ~1-2GB RAM (VM overhead)

### Best For

- **Kind:** CI/CD pipelines, containerized workflows, Jenkins, GitHub Actions
- **Minikube:** Local single-user development, desktop use, familiar interface

---

## Common Commands

### Cluster Management
```bash
# List all Kind clusters
kind get clusters

# Delete Kind cluster
kind delete cluster --name bug-report-portal

# Get cluster kubeconfig
kind get kubeconfig --name bug-report-portal

# Export kubeconfig to file
kind get kubeconfig --name bug-report-portal > /tmp/kind-config.yaml
```

### Kubernetes Verification
```bash
# Get cluster info
kubectl cluster-info --context kind-bug-report-portal

# List all resources in namespace
kubectl get all -n bug-report-portal

# View pod details
kubectl describe pod -n bug-report-portal <POD_NAME>

# View logs
kubectl logs -n bug-report-portal -l app=bug-report-portal-app

# Stream logs
kubectl logs -n bug-report-portal -l app=bug-report-portal-app -f

# Execute command in pod
kubectl exec -it -n bug-report-portal <POD_NAME> -- /bin/sh
```

---

## Known Issues & Workarounds

### Issue #1: TLS Certificate Validation Error

**Error:**
```
tls: failed to verify certificate: x509: certificate is valid for 
bug-report-portal-control-plane, kubernetes, kubernetes.default, ..., 
not host.docker.internal
```

**Cause:** Kind certificates don't include `host.docker.internal` in SAN.

**Workaround:** Use `--insecure-skip-tls-verify` flag
```bash
kubectl --insecure-skip-tls-verify cluster-info
kubectl --insecure-skip-tls-verify apply -k k8s/
```

**Why this is safe:**
- Development/testing only
- Docker internal networking is trusted
- Jenkins container is local, not exposed to internet

### Issue #2: ImagePullBackOff

**Error:**
```
pod/bug-report-portal-app has image pull errors
```

**Cause:** New Kind cluster doesn't have Docker Hub credentials

**Solution:** Image is public (`demu147/bugreportportal`), just ensure:
1. Image exists on Docker Hub
2. Image was pushed from Jenkins build

### Issue #3: Pod Stuck in Init State

**Error:**
```
pod/bug-report-portal-app is waiting for postgres to be ready
```

**Solution:**
```bash
# Wait for postgres to be fully ready
kubectl wait --for=condition=Ready pod -l app=postgres \
  -n bug-report-portal --timeout=300s

# Then application pod will become ready
kubectl get pods -n bug-report-portal
```

---

## Troubleshooting Checklist

**Before troubleshooting, verify:**
- [ ] kubectl installed: `kubectl version --client`
- [ ] Kind installed: `kind version`
- [ ] Kind cluster running: `kind get clusters`
- [ ] Cluster accessible: `kubectl cluster-info`
- [ ] Namespace exists: `kubectl get ns bug-report-portal`
- [ ] Jenkins container running: `docker ps | grep jenkins`
- [ ] Kubeconfig uses `host.docker.internal`: `grep "host.docker.internal" ~/.kube/config`

**If Jenkins cannot access Kind:**
```bash
# 1. Verify kubeconfig is correct
cat ~/.kube/config | grep "server:"

# 2. Test from Jenkins container
docker exec jenkins kubectl --insecure-skip-tls-verify cluster-info

# 3. Check Jenkins logs
docker logs jenkins | grep -i kube
```

---

## References

- [Kind Official Docs](https://kind.sigs.k8s.io/)
- [Kind Quick Start](https://kind.sigs.k8s.io/docs/user/quick-start/)
- [Docker host.docker.internal](https://docs.docker.com/desktop/features/networking/#i-want-to-connect-from-a-container-to-a-service-on-the-host)
