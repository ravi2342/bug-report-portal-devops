# Complete Local Testing Guide - Step by Step for All Operating Systems

Comprehensive guide for testing the Bug Report Portal application locally from scratch. Covers software installation for **Windows**, **macOS**, and **Linux**.

---

## 📋 Table of Contents

1. [Part 1: Pre-Flight Checklist](#part-1-pre-flight-checklist)
2. [Part 2: Software Installation](#part-2-software-installation)
3. [Part 3: Project Setup](#part-3-project-setup)
4. [Part 4: Create Kind Cluster](#part-4-create-kind-cluster)
5. [Part 5: Start Docker Compose Services](#part-5-start-docker-compose-services)
6. [Part 6: Jenkins Initial Setup](#part-6-jenkins-initial-setup)
7. [Part 7: SonarQube Initial Setup](#part-7-sonarqube-initial-setup)
8. [Part 8: Trigger Jenkins Build](#part-8-trigger-jenkins-build)
9. [Part 9: Monitor Kubernetes Deployment](#part-9-monitor-kubernetes-deployment)
10. [Part 10: Port-Forward Setup](#part-10-port-forward-setup)
11. [Part 11: Test Application Features](#part-11-test-application-features)
12. [Part 12: Troubleshooting & Debugging](#part-12-troubleshooting--debugging)

---

## Part 1: Pre-Flight Checklist

### System Requirements

#### macOS
- **OS Version:** macOS 10.14+
- **RAM:** Minimum 8GB (16GB recommended)
- **Disk Space:** Minimum 30GB free
- **CPU:** Apple Silicon or Intel (Intel slower for Docker)
- **Architecture:** x86_64 or ARM64

#### Windows
- **OS Version:** Windows 10 Pro/Enterprise or Windows 11
- **RAM:** Minimum 8GB (16GB recommended)
- **Disk Space:** Minimum 30GB free
- **CPU:** 64-bit processor
- **WSL 2:** Must be installed (Windows Subsystem for Linux 2)
- **Virtualization:** Must be enabled in BIOS

#### Linux
- **Distro:** Ubuntu 20.04 LTS or later (or equivalent)
- **RAM:** Minimum 8GB (16GB recommended)
- **Disk Space:** Minimum 30GB free
- **CPU:** 64-bit processor
- **Root access:** Required for some installations

### Prerequisites Check

```bash
# Check available disk space
macOS:       df -h | grep /
Windows:     wmic logicaldisk get name,size,freespace (PowerShell)
Linux:       df -h | grep /

# Check RAM
macOS:       sysctl hw.memsize
Windows:     Get-WmiObject Win32_ComputerSystem | Select-Object TotalPhysicalMemory
Linux:       free -h

# Check CPU cores
macOS:       sysctl -n hw.ncpu
Windows:     (Get-WmiObject Win32_Processor).NumberOfCores
Linux:       nproc
```

---

## Part 2: Software Installation

### 2.1 Docker Installation

#### macOS
```bash
# Option A: Using Homebrew (Recommended)
brew install --cask docker

# Option B: Direct Download
# Download from: https://docs.docker.com/desktop/install/mac-install/
# Then open the .dmg file and drag Docker to Applications

# Verify installation
docker --version
# Expected: Docker version 20.10+

# Start Docker
open /Applications/Docker.app

# Wait for Docker to start, then verify
docker ps  # Should not error
```

#### Windows
```powershell
# Option A: Using Chocolatey
choco install docker-desktop

# Option B: Using Windows Package Manager
winget install Docker.DockerDesktop

# Option C: Direct Download
# 1. Download from: https://docs.docker.com/desktop/install/windows-install/
# 2. Run installer
# 3. Follow prompts (enable WSL 2 integration)

# Verify installation (PowerShell as Admin)
docker --version
# Expected: Docker version 20.10+

# Start Docker Desktop (GUI or command)
Start-Process "C:\Program Files\Docker\Docker\Docker Desktop.exe"

# Wait ~2 minutes for Docker to start
docker ps  # Should show containers (empty list ok)
```

#### Linux (Ubuntu/Debian)
```bash
# Update package manager
sudo apt-get update

# Install Docker
sudo apt-get install -y docker.io docker-compose

# Add your user to docker group (avoid sudo)
sudo usermod -aG docker $USER
newgrp docker

# Verify installation
docker --version
# Expected: Docker version 20.10+

docker ps  # Should show empty containers list
```

---

### 2.2 Kubectl Installation

#### macOS
```bash
# Option A: Using Homebrew (Recommended)
brew install kubectl

# Option B: Using curl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/darwin/amd64/kubectl"
chmod +x ./kubectl
sudo mv ./kubectl /usr/local/bin/kubectl

# Verify
kubectl version --client
# Expected: version.Info{Major:"1", Minor:"27"+}
```

#### Windows
```powershell
# Option A: Using Chocolatey
choco install kubernetes-cli

# Option B: Using curl (PowerShell as Admin)
$url = "https://dl.k8s.io/release/$(curl https://dl.k8s.io/release/stable.txt)/bin/windows/amd64/kubectl.exe"
curl -o kubectl.exe $url
Move-Item kubectl.exe C:\Windows\System32\

# Verify
kubectl version --client
```

#### Linux (Ubuntu/Debian)
```bash
# Option A: Using apt
sudo apt-get update
sudo apt-get install -y apt-transport-https curl
sudo curl -fsSLo /usr/share/keyrings/kubernetes-archive-keyring.gpg \
  https://packages.cloud.google.com/apt/doc/apt-key.gpg
echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" \
  | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt-get update
sudo apt-get install -y kubectl

# Verify
kubectl version --client
```

---

### 2.3 Kind Installation

#### macOS
```bash
# Option A: Using Homebrew (Recommended)
brew install kind

# Option B: Using curl
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-darwin-amd64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind

# Verify
kind version
# Expected: kind v0.20.0
```

#### Windows
```powershell
# Option A: Using Chocolatey
choco install kind

# Option B: Using curl (PowerShell as Admin)
curl.exe -Lo kind-windows-amd64.exe https://kind.sigs.k8s.io/dl/v0.20.0/kind-windows-amd64
Move-Item .\kind-windows-amd64.exe C:\Windows\System32\kind.exe

# Verify
kind version
```

#### Linux (Ubuntu/Debian)
```bash
# Option A: Using apt
sudo apt-get install -y golang-go
go install sigs.k8s.io/kind@v0.20.0
export PATH=$PATH:$(go env GOPATH)/bin

# Option B: Using curl
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind

# Verify
kind version
```

---

### 2.4 Git Installation

#### macOS
```bash
# Option A: Using Homebrew
brew install git

# Option B: Using XCode
xcode-select --install

# Verify
git --version
# Expected: git version 2.x.x
```

#### Windows
```powershell
# Option A: Using Chocolatey
choco install git

# Option B: Using Git installer
# Download from: https://git-scm.com/download/win
# Run installer

# Verify
git --version
```

#### Linux (Ubuntu/Debian)
```bash
sudo apt-get install -y git

# Verify
git --version
```

---

### 2.5 Homebrew (macOS Only)

```bash
# Install Homebrew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Add to PATH (Apple Silicon Macs)
echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
eval "$(/opt/homebrew/bin/brew shellenv)"

# Verify
brew --version
```

---

### 2.6 Chocolatey (Windows Only)

```powershell
# Run PowerShell as Administrator
# Check execution policy
Get-ExecutionPolicy

# If it's "Restricted", run:
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

# Install Chocolatey
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

# Verify
choco --version
```

---

### 2.7 WSL 2 Setup (Windows Only)

```powershell
# Run PowerShell as Administrator

# Enable WSL 2
wsl --install

# This will:
# 1. Enable WSL 2 feature
# 2. Download Ubuntu LTS
# 3. Restart your computer

# After restart, complete Ubuntu setup

# Verify
wsl --list --verbose
# Should show: Ubuntu with VERSION 2

# Update WSL kernel
wsl --update
```

---

### 2.7 Node.js & npm Installation (Required for Application)

**Why needed:** The application is built with Node.js. You need Node.js and npm to:
- Install project dependencies
- Run unit tests locally
- Build the Docker image
- Run the application in development mode

**Required versions:**
- Node.js: v18+ (v20+ recommended)
- npm: v9+ (v10+ recommended)

#### macOS

**Option A: Using Homebrew (Recommended)**
```bash
# Install Node.js and npm
brew install node

# Verify installation
node --version
# Expected: v20.x.x or higher

npm --version
# Expected: 10.x.x or higher

# Update npm to latest (optional)
npm install -g npm@latest
```

**Option B: Using NVM (Node Version Manager - Best for multiple versions)**
```bash
# Install NVM
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash

# Reload shell
source ~/.zshrc  # or ~/.bash_profile

# Install Node.js LTS
nvm install --lts
nvm use --lts

# Set as default
nvm alias default 20  # or your preferred version

# Verify
node --version
npm --version
```

#### Windows

**Option A: Using Chocolatey**
```powershell
# Run PowerShell as Administrator

choco install nodejs

# Verify
node --version
npm --version

# Close and reopen PowerShell for PATH to update
```

**Option B: Using Windows Package Manager**
```powershell
winget install OpenJS.NodeJS

# Verify
node --version
npm --version
```

**Option C: Direct Download (Manual)**
1. Go to: https://nodejs.org/en/download/
2. Download LTS version (v20+)
3. Run installer
4. Follow prompts (accept defaults)
5. Restart computer
6. Open PowerShell and verify:
```powershell
node --version
npm --version
```

**Option D: Using NVM for Windows**
```powershell
# Install nvm-windows from:
# https://github.com/coreybutler/nvm-windows/releases

# Or using Chocolatey:
choco install nvm

# Close and reopen PowerShell

# List available versions
nvm list available

# Install specific version
nvm install 20.11.0
nvm use 20.11.0

# Verify
node --version
npm --version
```

#### Linux (Ubuntu/Debian)

**Option A: Using apt (Recommended)**
```bash
# Update package manager
sudo apt-get update

# Install Node.js and npm
sudo apt-get install -y nodejs npm

# Verify
node --version
# Expected: v18+ or higher

npm --version
# Expected: v9+ or higher

# Update npm to latest (optional)
sudo npm install -g npm@latest
```

**Option B: Using NodeSource Repository (Newer Versions)**
```bash
# Add NodeSource repository
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -

# Install Node.js
sudo apt-get install -y nodejs

# Verify
node --version
npm --version
```

**Option C: Using NVM (Node Version Manager)**
```bash
# Install NVM
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash

# Reload shell config
source ~/.bashrc  # or ~/.zshrc

# Install Node.js LTS
nvm install --lts
nvm use --lts

# Set as default
nvm alias default node

# Verify
node --version
npm --version
```

**Option D: Using Snap**
```bash
sudo snap install node --classic

# Verify
node --version
npm --version
```

---

### 2.8 npm Global Tools (Optional but Useful)

```bash
# Install useful npm global tools

# nodemon - auto-restart app on file changes
npm install -g nodemon

# pm2 - process manager
npm install -g pm2

# nvm - if not already installed
npm install -g nvm

# Verify
npm list -g --depth=0
```

---

### 2.9 Verification Script

Run this to verify all installations:

#### macOS/Linux
```bash
#!/bin/bash

echo "=== Software Installation Verification ==="
echo ""

# Docker
echo "Docker:"
docker --version || echo "❌ Docker not installed"

# Kubectl
echo "Kubectl:"
kubectl version --client 2>/dev/null | grep -o "v[0-9.]*" || echo "❌ Kubectl not installed"

# Kind
echo "Kind:"
kind version || echo "❌ Kind not installed"

# Git
echo "Git:"
git --version || echo "❌ Git not installed"

# Node.js
echo "Node.js:"
node --version || echo "❌ Node.js not installed"

# npm
echo "npm:"
npm --version || echo "❌ npm not installed"

echo ""
echo "All software installed! ✓"
```

#### Windows (PowerShell)
```powershell
Write-Host "=== Software Installation Verification ===" -ForegroundColor Green
Write-Host ""

# Docker
Write-Host "Docker:"
docker --version 2>$null || Write-Host "❌ Docker not installed"

# Kubectl
Write-Host "Kubectl:"
kubectl version --client 2>$null || Write-Host "❌ Kubectl not installed"

# Kind
Write-Host "Kind:"
kind version 2>$null || Write-Host "❌ Kind not installed"

# Git
Write-Host "Git:"
git --version 2>$null || Write-Host "❌ Git not installed"

# Node.js
Write-Host "Node.js:"
node --version 2>$null || Write-Host "❌ Node.js not installed"

# npm
Write-Host "npm:"
npm --version 2>$null || Write-Host "❌ npm not installed"

Write-Host ""
Write-Host "Verification complete!" -ForegroundColor Green
```

---

## Part 3: Project Setup

### Step 1: Clone Application Repository

```bash
# Create projects directory
mkdir -p ~/projects
cd ~/projects

# Clone application repo
git clone https://github.com/ravi2342/bugreportportal.git
cd bugreportportal

# Verify
ls -la
# Should show: package.json, src/, docker-compose.yml, etc.

# Check Node.js version requirement
cat package.json | grep -A 2 "engines"
# Should show Node.js requirement (typically 18+ or 20+)
```

### Step 2: Clone DevOps Repository

```bash
# Go back to projects directory
cd ~/projects

# Clone DevOps repo
git clone https://github.com/ravi2342/bug-report-portal-devops.git
cd bug-report-portal-devops

# Verify structure
ls -la
# Should show: Jenkinsfile, k8s/, docker-compose.yml, README.md, etc.
```

### Step 3: Understand Folder Structure

```
~/projects/
├── bugreportportal/                # Application code
│   ├── src/                        # Source code
│   ├── package.json                # Dependencies
│   ├── Dockerfile                  # Docker image build
│   └── prisma/                     # Database ORM
│
└── bug-report-portal-devops/       # DevOps infrastructure
    ├── Jenkinsfile                 # CI/CD pipeline
    ├── docker-compose.yml          # Local services
    ├── k8s/                        # Kubernetes manifests
    │   ├── app-deployment.yaml
    │   ├── app-service.yaml
    │   └── postgres-deployment.yaml
    ├── sonar-project.properties    # SonarQube config
    └── init-db.sql                 # Database initialization
```

---

## Part 4: Create Kind Cluster

### Step 1: Create Kind Configuration File

Create `kind-config.yaml`:

```yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: bug-report-portal
nodes:
  - role: control-plane
    ports:
      - containerPort: 80
        hostPort: 80
        protocol: TCP
      - containerPort: 443
        hostPort: 443
        protocol: TCP
      - containerPort: 8888
        hostPort: 8888
        protocol: TCP
    extraPortMappings:
      - containerPort: 3000
        hostPort: 3000
        protocol: TCP
networking:
  dnsDomain: cluster.local
```

**Save as:** `~/projects/bug-report-portal-devops/kind-config.yaml`

### Step 2: Create Kind Cluster

```bash
cd ~/projects/bug-report-portal-devops

# Create cluster
kind create cluster --config kind-config.yaml

# This will:
# 1. Download Kind node image (may take 2-3 minutes first time)
# 2. Create Docker container with Kubernetes
# 3. Set up kubeconfig automatically

# Verify cluster created
kind get clusters
# Should show: bug-report-portal

# Verify kubeconfig
kubectl config view
# Should show cluster: kind-bug-report-portal

# Get cluster info
kubectl cluster-info --context kind-bug-report-portal
# Should show: API server endpoint
```

### Step 3: Verify Kubeconfig Setup

```bash
# Check kubeconfig location
echo $KUBECONFIG
# If empty, it's at ~/.kube/config (default)

# Display kubeconfig
cat ~/.kube/config | grep -A 5 "bug-report-portal"

# Test connectivity
kubectl get nodes
# Should show: 1 node (bug-report-portal-control-plane)

# Expected output:
NAME                                 STATUS   ROLES           AGE   VERSION
bug-report-portal-control-plane      Ready    control-plane   2m    v1.27.0
```

---

## Part 5: Start Docker Compose Services

### Step 1: Understand Service Order

**IMPORTANT:** Start services in this order:

1. **Kind cluster** (already running from Part 4)
2. **Docker Compose services** (Jenkins, SonarQube, PostgreSQL)

### Step 2: Navigate to DevOps Repository

```bash
cd ~/projects/bug-report-portal-devops

# Verify docker-compose.yml exists
ls -la docker-compose.yml
```

### Step 3: Start Services

```bash
# Start all services in background
docker compose up -d

# This will:
# 1. Pull images (first time may take 5-10 minutes)
# 2. Create containers
# 3. Start services

# Monitor startup
docker compose logs -f

# Press Ctrl+C to exit logs
```

### Step 4: Verify Services Status

```bash
# Check all containers
docker compose ps

# Expected output (after ~2 minutes):
NAME           COMMAND                  SERVICE      STATUS      PORTS
jenkins        "/sbin/entrypoint.sh"    jenkins      Up 90s      0.0.0.0:8080->8080/tcp
sonarqube      "./bin/sonar.sh console" sonarqube    Up 60s      0.0.0.0:9000->9000/tcp
postgres       "docker-entrypoint.s…"   postgres     Up 100s     0.0.0.0:5432->5432/tcp

# If any show "Unhealthy" or "Exited", wait 30 seconds and check again
# Initial startup can take 2-3 minutes

# Check logs for each service
docker compose logs jenkins    # Jenkins logs
docker compose logs sonarqube  # SonarQube logs
docker compose logs postgres   # PostgreSQL logs
```

### Step 5: Get Jenkins Initial Admin Password

```bash
# Method 1: From container logs
docker compose logs jenkins | grep -A 5 "initial admin password"

# Method 2: Direct from container
docker compose exec -T jenkins cat /var/jenkins_home/secrets/initialAdminPassword

# Copy the password - you'll need it in Part 6
```

### Step 6: Access Services

Open in browser:

| Service | URL | Status |
|---------|-----|--------|
| **Jenkins** | http://localhost:8080/jenkins | Starting... |
| **SonarQube** | http://localhost:9000 | Starting... |
| **PostgreSQL** | localhost:5432 | (backend only) |

**Wait 2-3 minutes** for services to fully start before proceeding to Part 6.

---

## Part 6: Jenkins Initial Setup

### Step 1: Access Jenkins

1. **Open browser:** http://localhost:8080/jenkins
2. **Wait for page to load** (may take 30 seconds)
3. **You should see:** Jenkins login page with "Administrator password" field

### Step 2: First Login - Enter Admin Password

1. **Paste the password** from Part 5 Step 5 into the password field
2. **Click:** "Continue"
3. **Next page:** "Customize Jenkins" - Click "Install suggested plugins"
4. **Wait:** Jenkins downloads and installs plugins (5-10 minutes)

**What you'll see:**
- Progress bar showing installation
- Plugin names being installed
- Some plugins may show "Pending" which is normal

### Step 3: Create First Admin User

After plugins finish installing:

1. **Username:** admin
2. **Password:** (create secure password - e.g., Admin@123)
3. **Full name:** Administrator
4. **Email:** admin@example.com
5. **Click:** "Save and Continue"

**Save these credentials!** You'll need them for future Jenkins logins.

### Step 4: Configure Jenkins URL

Next page asks for Jenkins URL:
- **Jenkins URL:** http://localhost:8080/jenkins
- **Click:** "Save and Finish"
- **Click:** "Start using Jenkins"

### Step 5: Create Docker Hub Credentials

These are needed for Jenkins to push Docker images.

**Navigate to:**
1. Jenkins Dashboard → Manage Jenkins → Credentials
2. Click "System" on left
3. Click "Global credentials"
4. Click "Add Credentials" (top left)

**Fill in:**
- **Kind:** Username with password
- **Scope:** Global
- **Username:** demu147 (or your Docker Hub username)
- **Password:** (your Docker Hub Personal Access Token)
  - To get token: Go to https://hub.docker.com/ → Settings → Security → New Access Token
- **ID:** dockerhub-creds-pat
- **Description:** Docker Hub Credentials
- **Click:** "Create"

### Step 6: Create SonarQube Credentials

**Navigate to:**
1. Jenkins Dashboard → Manage Jenkins → Credentials
2. Click "Global credentials" 
3. Click "Add Credentials"

**Fill in:**
- **Kind:** Secret text
- **Scope:** Global
- **Secret:** (your SonarQube token - get from Part 7)
- **ID:** sonar-token
- **Description:** SonarQube Authentication Token
- **Click:** "Create"

### Step 7: Configure Jenkins Plugins

Some plugins needed for Kubernetes:

**Navigate to:**
1. Jenkins Dashboard → Manage Jenkins → Plugins
2. Click "Available plugins"
3. Search and install (if not already installed):
   - Kubernetes
   - Docker Pipeline
   - GitHub Integration
   - Email Extension

**After installing, restart Jenkins:**
- Jenkins Dashboard → Manage Jenkins → System
- Or restart from command line: `docker compose restart jenkins`

---

## Part 7: SonarQube Initial Setup

### Step 1: Access SonarQube

1. **Open browser:** http://localhost:9000
2. **Wait for page to load** (may take 30-60 seconds)
3. **You should see:** SonarQube login page

### Step 2: First Login - Default Credentials

**Default credentials:**
- **Username:** admin
- **Password:** admin

1. **Enter credentials**
2. **Click:** "Log in"
3. **You'll be asked to change password** (do this)

**New password:**
- Create a secure password (e.g., SonarQube@123)
- **Click:** "Update"

### Step 3: Generate SonarQube Authentication Token

This token is used by Jenkins to push code analysis results.

**Navigate to:**
1. Click your avatar (top right)
2. Select "My Account"
3. Click "Security" tab
4. Under "Generate Tokens":
   - **Name:** Jenkins
   - **Click:** "Generate"

**Copy the token** - use this in Part 6 Step 6 to create Jenkins credentials.

### Step 4: Create Project in SonarQube

**Navigate to:**
1. Click "Projects" (top menu)
2. Click "Create project"
3. **Project key:** bug-report-portal
4. **Project name:** Bug Report Portal
5. **Click:** "Create"

---

## Part 8: Trigger Jenkins Build

### Step 1: Create Jenkins Job (if not exists)

**If job doesn't exist in Jenkins:**

1. **Jenkins Dashboard** → "New Item"
2. **Item name:** bug-report-portal
3. **Select:** "Pipeline"
4. **Click:** "OK"

### Step 2: Configure Job (if not exists)

1. **General:**
   - **GitHub repository:** https://github.com/ravi2342/bugreportportal.git
   - **Build Triggers:** Check "GitHub hook trigger"

2. **Pipeline:**
   - **Definition:** Pipeline script from SCM
   - **SCM:** Git
   - **Repository URL:** https://github.com/ravi2342/bug-report-portal-devops.git
   - **Branch:** */master
   - **Script Path:** Jenkinsfile

3. **Click:** "Save"

### Step 3: Trigger Build Manually

**Navigate to:**
1. Jenkins Dashboard
2. Click "bug-report-portal" job
3. Click "Build with Parameters"

**Fill parameters:**

| Parameter | Value | Purpose |
|-----------|-------|---------|
| BRANCH | master | Git branch |
| GITHUB_REPO_URL | https://github.com/ravi2342/bugreportportal.git | App repo |
| DO_PUSH | ✓ checked | Push Docker image |
| DO_DEPLOY | ✓ checked | Deploy to K8s |
| RUN_SONAR | ✓ checked | Run code scan |
| RUN_POST_DEPLOY_TESTS | ✓ checked | Run health tests |
| RUN_UI_E2E | ✓ checked | Run E2E tests |
| REGISTRY_CREDENTIALS_ID | dockerhub-creds-pat | Docker Hub creds |
| SONAR_HOST_URL | http://sonarqube:9000 | SonarQube URL |
| SONAR_TOKEN_CREDENTIALS_ID | sonar-token | Sonar token cred |

**Click:** "Build"

### Step 4: Monitor Build Progress

**Navigate to:** Jenkins Dashboard → bug-report-portal → Build #1

**Watch the console output** as each stage executes:

---

### **Jenkins Pipeline Stages Explained (Line by Line)**

#### **Stage 1: Checkout SCM**
```
What: Clone application code from GitHub
Why: Need source code to build
Expected Output: "Cloning into 'bugreportportal'... done"
Time: 10-20 seconds
```

#### **Stage 2: Setup & Verification**
```
What: Verify Node.js, npm, kubectl installed
Why: Required tools for build and deployment
Expected Output:
  node version: v20.x.x
  npm version: 10.x.x
  kubectl version: 1.27+
Time: 5 seconds
```

#### **Stage 3: Install Dependencies**
```
What: npm install (download npm packages)
Why: Install all required libraries
Expected Output: "added XXX packages"
Time: 30-60 seconds
What to look for: No permission errors
```

#### **Stage 4: Run Tests**
```
What: Jest unit tests (npm test)
Why: Verify code quality and functionality
Expected Output:
  Test Suites: X passed
  Tests: Y passed, 0 failed
Time: 10-20 seconds
What to look for: All tests pass (0 failed)
```

#### **Stage 5: Code Coverage**
```
What: Generate coverage report (how much code is tested)
Why: Ensure sufficient test coverage
Expected Output:
  Statements: XX%
  Branches: XX%
  Lines: XX%
Time: 5 seconds
What to look for: Coverage > 70%
```

#### **Stage 6: SonarQube Scan** (if RUN_SONAR=true)
```
What: Static code analysis (security, bugs, code smells)
Why: Detect code quality issues early
Expected Output:
  ANALYSIS SUCCESSFUL
Time: 30-60 seconds
What to look for: No BLOCKER or CRITICAL issues
```

#### **Stage 7: Quality Gate Check**
```
What: SonarQube quality check passes
Why: Enforce code quality standards
Expected Output:
  Quality Gate: PASSED
Time: 5 seconds
What to look for: PASSED (if FAILED, check SonarQube)
```

#### **Stage 8: Build Docker Image**
```
What: Create Docker container image
Why: Package application for deployment
Expected Output:
  Image built: demu147/bugreportportal:1.0.0-XX
Time: 30-60 seconds
What to look for: No build errors
```

#### **Stage 9: Push to Docker Registry** (if DO_PUSH=true)
```
What: Upload image to Docker Hub
Why: Make image available for Kubernetes deployment
Expected Output:
  Pushed to Docker Hub
  Image: demu147/bugreportportal:1.0.0-XX
Time: 30 seconds
What to look for: "Pushed" message (image successfully uploaded)
```

#### **Stage 10: Deploy to Kubernetes** (if DO_DEPLOY=true)
```
What: Apply Kubernetes manifests to Kind cluster
Why: Deploy application pods
Expected Output:
  ✓ Using temporary kubeconfig
  ✓ All 9 Kubernetes manifests applied
  ✓ Deployment rollout successful
Time: 30-45 seconds
What to look for: 
  - No connection errors
  - Rollout status shows "successfully rolled out"
```

#### **Stage 11: Wait for Rollout**
```
What: Wait for all pods to be Running/Ready
Why: Ensure application fully started
Expected Output:
  deployment 'bug-report-portal-app' successfully rolled out
Time: 10-30 seconds
What to look for: No timeout errors
```

#### **Stage 12: Setup Port-Forward** (in Jenkins container)
```
What: Attempt to set up port-forward in Jenkins
Why: For reference (you'll run this manually on macOS)
Expected Output:
  Port-forward started
Time: 5 seconds
Note: You must run this manually on your macOS laptop
```

#### **Stage 13: Post-Deploy Health Check** (if RUN_POST_DEPLOY_TESTS=true)
```
What: Smoke tests - verify basic functionality
Why: Ensure deployment successful
Expected Output:
  ✓ Health check: OK
  ✓ API endpoints responding
  ✓ Database connected
Time: 10-15 seconds
What to look for: All checks ✓
```

#### **Stage 14: E2E UI Tests** (if RUN_UI_E2E=true)
```
What: Automated browser testing (Playwright)
Why: Verify user workflows work
Expected Output:
  Test Results:
  ✓ Login with valid credentials (PASSED)
  ✓ Create bug report (PASSED)
  ✓ Update bug report (PASSED)
  All tests: PASSED
Time: 30-60 seconds
What to look for: All tests PASSED
```

#### **Stage 15: Collect Test Reports**
```
What: Gather all test results
Why: Document test execution
Expected Output:
  Reports saved
Time: 5 seconds
```

#### **Stage 16-18: Cleanup & Notifications**
```
What: Clean up temporary files, send notifications
Why: Housekeeping
Expected Output:
  ✓ Cleanup complete
  ✓ Build summary displayed
Time: 5-10 seconds
```

### Step 5: View Build Results

After build completes (5-10 minutes total):

**Console Output shows:**
```
✓ All 21 stages completed
✓ Image: demu147/bugreportportal:1.0.0-XX
✓ Deployment: SUCCESS
✓ Application URL: http://localhost:8888

TO ACCESS FROM BROWSER:
Run this command on your macOS terminal:

kubectl port-forward -n bug-report-portal \
  svc/bug-report-portal-service 8888:3000 \
  --insecure-skip-tls-verify

Then open: http://localhost:8888
```

---

## Part 9: Monitor Kubernetes Deployment

### Step 1: Check Namespace

```bash
kubectl get namespace bug-report-portal

# Expected output:
NAME                   STATUS   AGE
bug-report-portal      Active   2m
```

### Step 2: Check All Resources

```bash
kubectl get all -n bug-report-portal

# Expected output shows:
# - 3 pods (bug-report-portal-app instances)
# - 2 pods (postgres)
# - Services (bug-report-portal-service, postgres)
# - Deployments (bug-report-portal-app, postgres)
```

### Step 3: Check Deployment Status

```bash
kubectl get deployment -n bug-report-portal

# Expected output:
NAME                    READY   UP-TO-DATE   AVAILABLE   AGE
bug-report-portal-app   3/3     3            3           2m
postgres                1/1     1            1           2m

# READY: 3/3 means all 3 replicas running
```

### Step 4: Check Pods

```bash
kubectl get pods -n bug-report-portal

# Expected output:
NAME                                   READY   STATUS    RESTARTS   AGE
bug-report-portal-app-xxxxx-xxxxx      1/1     Running   0          2m
bug-report-portal-app-xxxxx-yyyyy      1/1     Running   0          2m
bug-report-portal-app-xxxxx-zzzzz      1/1     Running   0          2m
postgres-xxxxx-xxxxx                   1/1     Running   0          2m

# All should show: 1/1 Running
```

### Step 5: Check Services

```bash
kubectl get svc -n bug-report-portal

# Expected output:
NAME                        TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)      AGE
bug-report-portal-service   ClusterIP   10.96.x.x       <none>        3000/TCP     2m
postgres                    ClusterIP   10.96.y.y       <none>        5432/TCP     2m
```

### Step 6: View Application Logs

```bash
# View current logs
kubectl logs -n bug-report-portal deployment/bug-report-portal-app

# Expected output should include:
# "Server running on http://localhost:3000"
# "Connected to PostgreSQL at postgres:5432"

# Follow logs (real-time)
kubectl logs -n bug-report-portal deployment/bug-report-portal-app -f

# Press Ctrl+C to stop following
```

### Step 7: Describe Pod (if troubleshooting)

```bash
# Get pod name
POD_NAME=$(kubectl get pods -n bug-report-portal \
  -l app=bug-report-portal-app -o jsonpath='{.items[0].metadata.name}')

# Describe pod (shows status, events, resources)
kubectl describe pod $POD_NAME -n bug-report-portal

# Look for:
# - Status: Running
# - Containers: Ready 1/1
# - No "ImagePullBackOff" or "CrashLoopBackOff" errors
```

---

## Part 10: Port-Forward Setup

### Step 1: Verify Pod is Ready

```bash
# Ensure pod is Running
kubectl get pods -n bug-report-portal

# Wait if status is "Pending" or "ContainerCreating"
# Re-run until all pods show "Running"
```

### Step 2: Start Port-Forward in Background

**Option A: Simple Background**
```bash
kubectl port-forward -n bug-report-portal \
  svc/bug-report-portal-service 8888:3000 \
  --insecure-skip-tls-verify &
```

**Option B: Background with Log File (Recommended)**
```bash
nohup kubectl port-forward -n bug-report-portal \
  svc/bug-report-portal-service 8888:3000 \
  --insecure-skip-tls-verify > ~/.kube/portforward.log 2>&1 &

echo "Port-forward started in background!"
```

**Option C: Using Screen (Advanced)**
```bash
screen -d -m -S portforward kubectl port-forward \
  -n bug-report-portal svc/bug-report-portal-service 8888:3000 \
  --insecure-skip-tls-verify
```

### Step 3: Verify Port-Forward is Running

```bash
# Check process
ps aux | grep "kubectl port-forward" | grep -v grep

# Should show running process with port 8888:3000

# Check logs (if using file redirection)
tail -f ~/.kube/portforward.log

# Expected output:
# Forwarding from 127.0.0.1:8888 -> 3000
# Forwarding from [::1]:8888 -> 3000
```

### Step 4: Test Connection

```bash
# In another terminal, verify connection
curl -k http://localhost:8888/login

# Should return: HTML content (not "Connection refused")
```

---

## Part 11: Test Application Features

### Step 1: Open Browser

1. **Open:** http://localhost:8888
2. **Should see:** Login page with "Bug Report Portal" header
3. **Fields:** Email/Username and Password input fields

### Step 2: Login Test

**Credentials:**
- **Email/Username:** admin
- **Password:** admin

**Steps:**
1. Enter username: `admin`
2. Enter password: `admin`
3. Click "Login" button
4. **Expected:** Redirected to Dashboard

**What to verify:**
- Login button works (no loading spinner stuck)
- No error messages
- Dashboard loads within 2 seconds
- No console errors (open DevTools: F12)

### Step 3: Dashboard Verification

After login, dashboard should show:

- [x] Header with "Bug Report Portal"
- [x] User profile menu (top right showing "admin")
- [x] Navigation menu (left sidebar if exists)
- [x] Main content area
- [x] List of existing reports (if any)
- [x] "Create New Report" button

### Test 1: Create Bug Report

**Steps:**
1. Click "Create New Report" or "+" button
2. Fill form fields:

   | Field | Value | Notes |
   |-------|-------|-------|
   | Title | Login button styling issue | Required field |
   | Description | The login button text color is hard to read on white background. Consider changing to a darker shade or adding border. | Detailed description |
   | Priority | High | Dropdown: Low, Medium, High, Critical |
   | Category | UI | Dropdown: UI, Backend, Database, Performance, Security |
   | Assigned To | (optional) | Can leave empty |
   | Status | Open | Usually default |

3. Click "Submit" or "Create Report" button

**Expected Result:**
```
✓ Success message appears: "Report created successfully"
✓ Redirected to report details page
✓ Report shows all entered data
✓ Creation timestamp displayed
✓ Report appears in list (click back to list)
```

**Database Verification:**
```bash
# Check if report saved to database
kubectl port-forward -n bug-report-portal svc/postgres 5432:5432 &

# Connect to database
psql -h localhost -U postgres -d bug_report_db

# At psql prompt:
SELECT id, title, priority, status FROM reports;

# Should show your created report
\q  # Exit psql
```

### Test 2: View Report Details

**Steps:**
1. From dashboard, click on the report you created
2. Verify all fields are displayed:
   - Title
   - Description
   - Priority
   - Category
   - Status
   - Creation date/time
   - Created by (admin)

**Expected Result:**
```
✓ All fields display correctly
✓ Data matches what was entered
✓ No truncation or formatting issues
✓ Timestamps are readable
```

### Test 3: Update Report

**Steps:**
1. Click "Edit" button (on report details or list)
2. Change fields:
   - Priority: Change from "High" to "Medium"
   - Status: Change from "Open" to "In Progress"
3. Click "Save" or "Update"

**Expected Result:**
```
✓ Success message appears
✓ Changes are saved immediately
✓ Refresh page (Cmd+R): changes still show
✓ List view shows updated priority/status
```

### Test 4: Search/Filter Reports

**Steps:**
1. Go to reports list
2. Try search box (if available):
   - Enter: "login"
   - Click "Search"
3. Try filters (if available):
   - Filter by Priority: "High"
   - Filter by Status: "Open"

**Expected Result:**
```
✓ Search returns matching reports
✓ Filters narrow results correctly
✓ Correct number of results shown
✓ All results match search/filter criteria
```

### Test 5: Delete Report

**Steps:**
1. From report details, click "Delete" button
2. Confirm deletion (usually a confirmation modal)
3. Click "Confirm Delete" or "Yes"

**Expected Result:**
```
✓ Confirmation dialog appears
✓ Report deleted successfully
✓ Redirected to list or dashboard
✓ Deleted report no longer appears in list
✓ Refresh page: report still gone (persistent)
```

### Test 6: Create Multiple Reports

**Create 5 reports with different data:**

```
Report 1: Priority: Critical, Status: Open, Category: Security
Report 2: Priority: High, Status: In Progress, Category: Backend
Report 3: Priority: Medium, Status: Resolved, Category: UI
Report 4: Priority: Low, Status: Open, Category: Database
Report 5: Priority: High, Status: Open, Category: Performance
```

**Expected Result:**
```
✓ All 5 reports created
✓ List shows all 5 reports
✓ Can search/filter by any criteria
✓ Each report shows correct data
```

### Test 7: Concurrent Users (Advanced)

**Steps:**
1. Open two browser windows (different logins if available)
2. Create report in Window 1
3. Refresh in Window 2
4. New report should appear in Window 2

**Expected Result:**
```
✓ Real-time data sync
✓ No data conflicts
✓ Each user sees latest data
```

### Test 8: Logout & Login Again

**Steps:**
1. Click "Logout" (usually in user menu)
2. Verify redirected to login page
3. Login again with admin/admin

**Expected Result:**
```
✓ Logout works
✓ Session ends
✓ Login again successful
✓ Previous data still accessible
✓ Session restored
```

### Test 9: Database Verification

**Verify all created reports in database:**

```bash
# Connect to database
kubectl port-forward -n bug-report-portal svc/postgres 5432:5432 &
psql -h localhost -U postgres -d bug_report_db

# Check tables exist
\dt

# View all reports
SELECT * FROM reports;

# Count reports
SELECT COUNT(*) FROM reports;

# Should match number of reports you created

# View specific report
SELECT * FROM reports WHERE id = 1;

# Exit
\q
```

### Test 10: Application Performance

**Check performance (open DevTools: F12):**

| Action | Expected | What to Check |
|--------|----------|---------------|
| Page load | < 2 seconds | Network tab |
| Login | < 1 second | Network tab |
| Create report | < 2 seconds | Network tab |
| List load | < 1 second | Network tab |
| No console errors | 0 errors | Console tab |

---

## Part 12: Troubleshooting & Debugging

### Issue 1: Docker Services Won't Start

**Problem:** `docker compose up -d` fails or services won't start

**Debugging:**
```bash
# Check Docker is running
docker ps

# Check Docker logs
docker compose logs jenkins
docker compose logs sonarqube
docker compose logs postgres

# Check port conflicts
lsof -i :8080  # Jenkins port
lsof -i :9000  # SonarQube port
lsof -i :5432  # PostgreSQL port
```

**Solutions:**
```bash
# If ports in use, stop existing services
docker compose down

# Remove volume data and start fresh
docker compose down -v
docker compose up -d

# If images corrupted, pull fresh
docker compose pull
docker compose up -d
```

---

### Issue 2: Kind Cluster Won't Create

**Problem:** `kind create cluster` fails

**Debugging:**
```bash
# Check if Docker running
docker ps

# Check disk space
df -h

# Check if cluster already exists
kind get clusters

# Check Kind version
kind version
```

**Solutions:**
```bash
# Delete existing cluster first
kind delete cluster --name bug-report-portal

# Ensure plenty of disk space (>30GB)
df -h /

# Create with verbose output
kind create cluster --config kind-config.yaml -v 2

# If still fails, check Docker resources
# Docker Desktop → Preferences → Resources
# Increase CPU cores and memory
```

---

### Issue 3: Jenkins Build Fails

**Problem:** Jenkins build #1 fails at some stage

**Debugging by Stage:**

**If fails at Stage 4 (Tests):**
```bash
# Clone app repo and run tests locally
cd ~/projects/bugreportportal
npm install
npm test

# If tests fail, check Node version
node --version  # Should be 18+
npm --version
```

**If fails at Stage 6 (SonarQube):**
```bash
# Check SonarQube running
curl http://localhost:9000

# Check token is valid
# SonarQube UI → User → My Account → Security → Tokens

# Verify Jenkins credentials are correct
# Jenkins → Manage Jenkins → Credentials
# Check: sonar-token credential exists and has correct token
```

**If fails at Stage 8-9 (Docker):**
```bash
# Check Docker Hub credentials
docker login -u demu147

# Try building image manually
cd ~/projects/bugreportportal
docker build -t bugreportportal:test .

# If fails, check Dockerfile
cat Dockerfile
```

**If fails at Stage 10 (Kubernetes):**
```bash
# Check Kind cluster running
kubectl cluster-info

# Check kubeconfig
kubectl get nodes

# Check temporary kubeconfig was created
ls -la /tmp/kubeconfig-jenkins-*

# Check manifests are valid
cd k8s
kubectl apply -k . --dry-run=client
```

---

### Issue 4: Pods Won't Start

**Problem:** Kubernetes pods stuck in "Pending" or "CrashLoopBackOff"

**Debugging:**
```bash
# Check pod status
kubectl get pods -n bug-report-portal

# Describe pod for events
kubectl describe pod POD_NAME -n bug-report-portal

# Check logs
kubectl logs -n bug-report-portal pod/POD_NAME

# Check resource usage
kubectl top pods -n bug-report-portal

# Check events
kubectl get events -n bug-report-portal
```

**Common Issues & Solutions:**

**"Pending" status:**
```bash
# Usually image pull issue
# Check image exists in Docker Hub
docker pull demu147/bugreportportal:1.0.0-XX

# Or check cluster has capacity
kubectl top nodes

# Need more RAM/CPU, scale down replicas
kubectl scale deployment bug-report-portal-app \
  --replicas=1 -n bug-report-portal
```

**"CrashLoopBackOff" status:**
```bash
# Application crashing on startup
# Check logs
kubectl logs -n bug-report-portal pod/POD_NAME

# Common causes:
# - Database not ready
# - Missing environment variables
# - Port already in use

# Wait longer and check again
sleep 10
kubectl get pods -n bug-report-portal
```

**"ImagePullBackOff" status:**
```bash
# Cannot download image from Docker Hub
# Check image exists
docker pull demu147/bugreportportal:1.0.0-XX

# Check credentials (if private registry)
kubectl get secrets -n bug-report-portal

# Verify image tag in deployment
kubectl get deployment bug-report-portal-app -n bug-report-portal -o yaml | grep image
```

---

### Issue 5: Port-Forward Not Working

**Problem:** Port-forward won't connect or errors on connect

**Debugging:**
```bash
# Check if port-forward running
ps aux | grep "kubectl port-forward"

# Check if pod ready
kubectl get pods -n bug-report-portal

# Try basic connectivity
curl -k http://localhost:8888/health

# Check logs
tail -f ~/.kube/portforward.log

# Check if port in use
lsof -i :8888
```

**Solutions:**
```bash
# Kill stuck port-forward
pkill -f "kubectl port-forward"
sleep 2

# Restart
nohup kubectl port-forward -n bug-report-portal \
  svc/bug-report-portal-service 8888:3000 \
  --insecure-skip-tls-verify > ~/.kube/portforward.log 2>&1 &

# If still fails, check service has endpoints
kubectl get endpoints -n bug-report-portal

# If no endpoints, pods not ready
kubectl get pods -n bug-report-portal -o wide
```

---

### Issue 6: Application Login Fails

**Problem:** Can't login with admin/admin

**Debugging:**
```bash
# Check application logs
kubectl logs -n bug-report-portal deployment/bug-report-portal-app

# Check database connection
# Look for "Connected to PostgreSQL" in logs

# Check admin user in database
kubectl port-forward -n bug-report-portal svc/postgres 5432:5432 &
psql -h localhost -U postgres -d bug_report_db
SELECT * FROM users WHERE email = 'admin';
\q
```

**Solutions:**
```bash
# If no admin user, database not initialized
# Check init-db.sql was executed

# Delete postgres pod to reinitialize
kubectl delete pod postgres-XXXXX -n bug-report-portal

# Wait for new pod to start
kubectl get pods -n bug-report-portal -w

# Try login again (takes 30 seconds for DB init)
```

---

### Issue 7: Application Won't Start

**Problem:** Pod running but application not responding at localhost:8888

**Debugging:**
```bash
# Check application logs
kubectl logs -n bug-report-portal deployment/bug-report-portal-app -f

# Check if listening on port 3000
kubectl exec -it -n bug-report-portal pod/POD_NAME -- netstat -an | grep 3000

# Check environment variables
kubectl get pod POD_NAME -n bug-report-portal -o yaml | grep -A 20 env

# Try connecting directly to pod
kubectl port-forward -n bug-report-portal pod/POD_NAME 3000:3000
# Then try: curl http://localhost:3000
```

**Common Issues:**
```bash
# Missing DATABASE_URL
# DATABASE_URL should be: postgresql://postgres:postgres@postgres:5432/bug_report_db

# Missing PORT environment variable
# PORT should be: 3000

# Database not initialized
# Wait for postgres pod to fully start
```

---

### Issue 8: Database Connection Error

**Problem:** Application shows "Cannot connect to database"

**Debugging:**
```bash
# Check PostgreSQL pod running
kubectl get pods -n bug-report-portal | grep postgres

# Check PostgreSQL logs
kubectl logs -n bug-report-portal deployment/postgres

# Check if service has endpoints
kubectl get endpoints postgres -n bug-report-portal

# Try connecting manually
kubectl port-forward -n bug-report-portal svc/postgres 5432:5432 &
psql -h localhost -U postgres

# If psql fails, database not ready
# Wait 30 seconds and try again
```

**Solutions:**
```bash
# If PostgreSQL pod stuck, restart it
kubectl delete pod postgres-XXXXX -n bug-report-portal

# If PVC stuck, might need to delete volume
kubectl get pvc -n bug-report-portal
kubectl delete pvc postgres-pvc -n bug-report-portal

# Recreate pod with fresh PVC
kubectl rollout restart deployment/postgres -n bug-report-portal
```

---

### Debug Commands Cheat Sheet

```bash
# Kubernetes Debugging
kubectl get all -n bug-report-portal                    # All resources
kubectl get pods -n bug-report-portal -o wide          # Pods with details
kubectl describe pod POD_NAME -n bug-report-portal     # Pod details
kubectl logs -n bug-report-portal pod/POD_NAME         # Pod logs
kubectl logs -n bug-report-portal pod/POD_NAME -f      # Follow logs
kubectl exec -it pod/POD_NAME -n bug-report-portal /bin/bash  # Shell in pod
kubectl get events -n bug-report-portal                # Cluster events
kubectl top pods -n bug-report-portal                  # Resource usage

# Docker Debugging
docker compose ps                                       # Service status
docker compose logs jenkins                             # Jenkins logs
docker compose exec -T jenkins bash                     # Shell in container
docker exec CONTAINER_ID ps aux                        # Processes in container

# Network Debugging
netstat -an | grep 8888                                # Check port 8888
lsof -i :8080                                          # Check port 8080
curl http://localhost:8888/login                       # Test connectivity
ps aux | grep kubectl                                  # Running processes

# Database Debugging
kubectl port-forward svc/postgres 5432:5432 -n bug-report-portal &
psql -h localhost -U postgres -d bug_report_db
SELECT * FROM reports;  # View reports
\dt                     # List tables
\q                      # Quit psql
```

---

### Log File Locations

```bash
# Jenkins
docker compose logs jenkins | tail -100

# SonarQube
docker compose logs sonarqube | tail -100

# PostgreSQL
docker compose logs postgres | tail -100

# Application Pod
kubectl logs -n bug-report-portal deployment/bug-report-portal-app --tail=100

# Port-forward (if using file)
tail -f ~/.kube/portforward.log

# Kubernetes Events
kubectl describe pod POD_NAME -n bug-report-portal | grep -A 20 Events
```

---

## Complete Success Verification Checklist

- [ ] Docker installed and running
- [ ] kubectl installed and working
- [ ] Kind installed
- [ ] Git installed
- [ ] Repositories cloned (app + devops)
- [ ] Kind cluster created and running
- [ ] Docker Compose services running (Jenkins, SonarQube, PostgreSQL)
- [ ] Jenkins accessible at http://localhost:8080/jenkins
- [ ] SonarQube accessible at http://localhost:9000
- [ ] Jenkins admin password obtained
- [ ] Jenkins admin user created
- [ ] Docker Hub credentials created in Jenkins
- [ ] SonarQube credentials created in Jenkins
- [ ] SonarQube token generated
- [ ] SonarQube project created
- [ ] Jenkins job created (or existing)
- [ ] Jenkins build triggered
- [ ] All 21 stages completed successfully
- [ ] Docker image pushed to Docker Hub
- [ ] Kubernetes manifests applied
- [ ] All pods running (3 app + 1 postgres)
- [ ] Port-forward running in background
- [ ] Application accessible at http://localhost:8888
- [ ] Can login with admin/admin
- [ ] Can create incident
- [ ] Can update incident
- [ ] Can delete incident
- [ ] Can search/filter incidents
- [ ] Database shows created incidents
- [ ] All application features working

**If all checked ✓ - Congratulations! You have successfully completed local testing!** 🎉

---

## Quick Reference for This Document

| Task | Section | Time |
|------|---------|------|
| Install Software | Part 2 | 30 min |
| Setup Projects | Part 3 | 10 min |
| Create Kind Cluster | Part 4 | 5 min |
| Start Services | Part 5 | 5 min |
| Jenkins Setup | Part 6 | 10 min |
| SonarQube Setup | Part 7 | 5 min |
| Trigger Build | Part 8 | 10 min |
| Monitor Deploy | Part 9 | 5 min |
| Port-Forward | Part 10 | 2 min |
| Test Features | Part 11 | 20 min |
| Debug Issues | Part 12 | As needed |

**Total Time (first time):** ~2-3 hours

---

## Support Resources

- **Kubernetes:** https://kubernetes.io/docs/
- **Kind:** https://kind.sigs.k8s.io/
- **Docker:** https://docs.docker.com/
- **Jenkins:** https://www.jenkins.io/doc/
- **SonarQube:** https://docs.sonarqube.org/
- **Bug Report App:** https://github.com/ravi2342/bugreportportal
- **DevOps Repo:** https://github.com/ravi2342/bug-report-portal-devops

**Still stuck? Check:** [TROUBLESHOOTING.md](TROUBLESHOOTING.md) and [ERROR_FIXES.md](ERROR_FIXES.md)
