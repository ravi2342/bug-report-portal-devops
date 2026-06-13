# Jenkins Shared Library Setup - Quick Start

## Overview

This pipeline uses a Jenkins Shared Library for clean, reusable code.

**Shared Library Repo:** https://github.com/ravi2342/bugreportportal-sharedlib

**Time to setup:** 5 minutes

---

## Step 1: Add Library in Jenkins UI

Go to: **Jenkins Home → Manage Jenkins → System Configuration**

Scroll down to **"Global Trusted Pipeline Libraries"** → Click **"+ Add"**

Fill these fields:

| Field | Value |
|-------|-------|
| **Name** | `bug-report-portal-lib` |
| **Default version** | `master` |
| **Retrieval method** | Modern SCM |
| **Source Code Management** | GitHub |
| **Project Repository** | `ravi2342/bugreportportal-sharedlib` |
| **Credentials** | `ravi2342/****** (github-pat)` |

**Checkboxes:**
```
☑ Allow default version to be overridden
☑ Cache fetched versions on controller for quick retrieval
☐ Load implicitly (leave unchecked)
```

Click **Save**

---

## Step 2: Create Jenkins Job

**Jenkins Home → New Item → Pipeline**

**Name:** Bug Report Portal

**Configuration:**
```
Definition: Pipeline script from SCM
SCM: Git
Repository URL: https://github.com/ravi2342/bug-report-portal-devops.git
Branch: */master
Script Path: Jenkinsfile
```

Click **Save**

---

## Step 3: Verify Jenkinsfile

Your Jenkinsfile should start with:

```groovy
@Library('bug-report-portal-lib') _

pipeline {
  agent any
  
  parameters {
    // ... parameters
  }
  
  stages {
    // ... stages
  }
}
```

**Key:** `@Library('bug-report-portal-lib') _` must be first line before `pipeline {}`

---

## Step 4: Run Build

**Job → Build Now**

**Console output should show:**
```
Loading library bug-report-portal-lib@master
Cloning repository https://github.com/ravi2342/bugreportportal-sharedlib.git

[Pipeline] stage('Clean Workspace')
[Pipeline] stage('Checkout Application')
[Pipeline] stage('Checkout DevOps')
[Pipeline] stage('Preflight Checks')
[Pipeline] stage('Setup')
[Pipeline] stage('Quality Gates')
[Pipeline] stage('SonarQube Scan')
[Pipeline] stage('Build Docker Image')
[Pipeline] stage('Security Scan')
[Pipeline] stage('Push to Registry')
[Pipeline] stage('Deploy to Kubernetes')
[Pipeline] stage('Notify Status')
```

✅ **Success! All 12 stages executed using shared library functions**

---

## Troubleshooting

### "Library not found: bug-report-portal-lib"
- Verify library name matches: `bug-report-portal-lib`
- Go to System Configuration, verify library is saved
- Click **Reload Configuration** under Manage Jenkins
- Rebuild

### "Could not resolve repository"
- Check credentials are set: `ravi2342/****** (github-pat)`
- Verify repo path: `ravi2342/bugreportportal-sharedlib`
- Test GitHub access: `git clone https://github.com/ravi2342/bugreportportal-sharedlib.git`

### Functions not found (gitCheckout, dockerBuild, etc.)
- Verify function files in shared library: `vars/gitCheckout.groovy`, `vars/dockerBuild.groovy`, etc.
- Function name must match filename (without .groovy)
- Reload Jenkins configuration and rebuild

---

## Pipeline Structure

**12 Stages:**
1. Clean Workspace
2. Checkout Application
3. Checkout DevOps
4. Preflight Checks
5. Setup (install deps, Prisma)
6. Quality Gates (lint, tests)
7. SonarQube Scan (optional, if RUN_SONAR=true)
8. Build Docker Image
9. Security Scan (Trivy)
10. Push to Registry (optional, if DO_PUSH=true)
11. Deploy to Kubernetes (optional, if DO_DEPLOY=true)
12. Notify Status

**Build Parameters:**
```
BRANCH: master
GITHUB_REPO_URL: https://github.com/ravi2342/bugreportportal.git
RUN_SONAR: false (set to true to run SonarQube)
DO_PUSH: false (set to true to push image)
DO_DEPLOY: false (set to true to deploy)
SONAR_HOST_URL: http://sonarqube:9000
SONAR_PROJECT_KEY: bug-report-portal
SONAR_TOKEN_CREDENTIALS_ID: sonar-token
REGISTRY_CREDENTIALS_ID: dockerhub-creds-pat
```

---

## Done!

Your Jenkins pipeline now uses shared library functions for:
- ✓ Git checkout (2 repos)
- ✓ Preflight checks
- ✓ Dependencies & Prisma setup
- ✓ Lint & Tests
- ✓ SonarQube analysis
- ✓ Docker build
- ✓ Trivy security scan
- ✓ Docker push
- ✓ Kubernetes deployment
- ✓ Status notifications

All in a clean, maintainable pipeline! 🎉
