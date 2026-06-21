// ========================================
// Bug Report Portal - CI/CD Pipeline
// ========================================
// Using Jenkins Shared Library for reusable pipeline functions
// Repository: https://github.com/ravi2342/bugreportportal-sharedlib
// Pinned to v1.1 - Updated to support app-repo sonar-project.properties

@Library('bug-report-portal-lib@v1.1') _

// ========================================
// PIPELINE CONFIGURATION
// ========================================
properties([
  parameters([
    string(name: 'BRANCH', defaultValue: 'master', description: 'Git branch for app code (https://github.com/ravi2342/bugreportportal)'),
    string(name: 'DEVOPS_BRANCH', defaultValue: 'master', description: 'Git branch for devops repo (https://github.com/ravi2342/bug-report-portal-devops) - set to feature/postgres-statefulset to test new K8s configs'),
    string(name: 'GITHUB_REPO_URL', defaultValue: 'https://github.com/ravi2342/bugreportportal.git', description: 'GitHub application repository URL'),
    string(name: 'DOCKER_IMAGE_PATH', defaultValue: 'demu147/bugreportportal', description: 'Docker image path (format: username/imagename). Default works for demo. Change if using different registry.'),
    booleanParam(name: 'DO_PUSH', defaultValue: false, description: 'Push Docker image to registry'),
    booleanParam(name: 'DO_DEPLOY', defaultValue: false, description: 'Deploy to Kubernetes'),
    booleanParam(name: 'RUN_SONAR', defaultValue: false, description: 'Run SonarQube scan'),
    string(name: 'REGISTRY_CREDENTIALS_ID', defaultValue: 'dockerhub-creds-pat', description: 'Jenkins credentials ID for Docker Hub login'),
    string(name: 'SONAR_HOST_URL', defaultValue: 'http://sonarqube:9000', description: 'SonarQube URL (Local: http://sonarqube:9000, Cloud: https://sonarcloud.io)'),
    string(name: 'SONAR_PROJECT_KEY', defaultValue: 'bug-report-portal', description: 'SonarQube project key'),
    string(name: 'SONAR_TOKEN_CREDENTIALS_ID', defaultValue: 'sonar-token', description: 'Jenkins credentials ID for Sonar token'),
    choice(name: 'TARGET_ENV', choices: ['dev'], description: 'Deployment environment (must match a key under environments: in devops/deploy-config.yaml)')
  ])
])

// ========================================
// PIPELINE
// ========================================
pipeline {
  agent any
  
  options {
    timestamps()
    timeout(time: 1, unit: 'HOURS')
    buildDiscarder(logRotator(numToKeepStr: '10'))
  }
  
  environment {
    IMAGE_REGISTRY = 'docker.io'
    APP_VERSION = sh(script: "node -e \"const p=require('./app/package.json'); console.log(p.version)\" 2>/dev/null || echo '1.0.0'", returnStdout: true).trim()
  }
  
  stages {
    // ========================================
    // STAGE 1: CLEAN WORKSPACE
    // ========================================
    stage('Clean Workspace') {
      steps {
        script {
          deleteDir()
          echo "✓ Workspace cleaned"
        }
      }
    }
    
    // ========================================
    // STAGE 2: CHECKOUT APPLICATION
    // ========================================
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
    
    // ========================================
    // STAGE 3: CHECKOUT DEVOPS
    // ========================================
    stage('Checkout DevOps') {
      steps {
        script {
          gitCheckout(
            branch: params.DEVOPS_BRANCH ?: 'master',
            repoUrl: 'https://github.com/ravi2342/bug-report-portal-devops.git',
            targetDir: 'devops'
          )
          
          // Compute IMAGE_TAG and set build display name after both checkouts
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
    
    // ========================================
    // STAGE 4: PREFLIGHT CHECKS
    // ========================================
    stage('Preflight Checks') {
      steps {
        script {
          preflightChecks()
        }
      }
    }
    
    // ========================================
    // STAGE 5: DEPENDENCIES & BUILD SETUP
    // ========================================
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
    
    // ========================================
    // STAGE 6: QUALITY GATES (Lint & Tests)
    // ========================================
    stage('Quality Gates') {
      steps {
        script {
          lintAndTest()
        }
      }
    }
    
    // ========================================
    // STAGE 7: SONARQUBE SCAN (OPTIONAL)
    // ========================================
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
    
    // ========================================
    // STAGE 8: DOCKER BUILD
    // ========================================
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
    
    // ========================================
    // STAGE 9: SECURITY SCAN (Trivy)
    // ========================================
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
    
    // ========================================
    // STAGE 10: DOCKER PUSH (OPTIONAL)
    // ========================================
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
    
    // ========================================
    // STAGE 11: DEPLOYMENT APPROVAL (OPTIONAL)
    // ========================================
    stage('Deployment Approval') {
      when {
        expression { params.DO_DEPLOY }
      }
      steps {
        script {
          // Update build display to show which environment is being approved
          currentBuild.displayName = "#${BUILD_NUMBER} - Approving ${params.TARGET_ENV.toUpperCase()}"
          
          try {
            timeout(time: 30, unit: 'MINUTES') {
              def env_name = params.TARGET_ENV.toUpperCase()
              input message: "Approve deployment to ${env_name} environment?",
                ok: "✓ Proceed with ${env_name}",
                submitter: null
            }
            echo "✓ Deployment approved - proceeding..."
            currentBuild.displayName = "#${BUILD_NUMBER} - ${params.TARGET_ENV.toUpperCase()} ✓ Approved"
          } catch (err) {
            currentBuild.result = 'ABORTED'
            currentBuild.displayName = "#${BUILD_NUMBER} - ${params.TARGET_ENV.toUpperCase()} ✗ Rejected"
            error('❌ Deployment rejected or approval timed out (30 min expired)')
          }
        }
      }
    }
    
    // ========================================
    // STAGE 12: DEPLOY TO KUBERNETES (OPTIONAL)
    // ========================================
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
    
    // ========================================
    // STAGE 13: NOTIFY STATUS
    // ========================================
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
  }
  
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
    failure {
      script {
        echo "❌ Pipeline failed - check logs above for details"
      }
    }
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
  }
}
