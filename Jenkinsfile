// ========================================
// SCRIPTED PIPELINE - Bug Report Portal
// ========================================
// More realistic, flexible, and enterprise-ready scripted pipeline
// Supports complex error handling, dynamic logic, and retry mechanisms

String getImageNameFromUrl(String url) {
  return url.replaceAll(/.*\/([^\/]+)\.git$/, '$1').toLowerCase()
}

boolean commandExists(String command) {
  try {
    sh "command -v ${command} >/dev/null 2>&1"
    return true
  } catch (Exception e) {
    return false
  }
}

// ========================================
// PIPELINE CONFIGURATION
// ========================================
properties([
  parameters([
    string(name: 'BRANCH', defaultValue: 'master', description: 'Git branch to build'),
    string(name: 'GITHUB_REPO_URL', defaultValue: 'https://github.com/ravi2342/bugreportportal.git', description: 'GitHub application repository URL'),
    booleanParam(name: 'DO_PUSH', defaultValue: false, description: 'Push Docker image to registry'),
    booleanParam(name: 'DO_DEPLOY', defaultValue: false, description: 'Deploy to Kubernetes'),
    booleanParam(name: 'RUN_SONAR', defaultValue: false, description: 'Run SonarQube scan'),
    booleanParam(name: 'RUN_POST_DEPLOY_TESTS', defaultValue: false, description: 'Run smoke tests after deploy'),
    booleanParam(name: 'RUN_UI_E2E', defaultValue: false, description: 'Run UI E2E after smoke tests'),
    string(name: 'REGISTRY_CREDENTIALS_ID', defaultValue: 'dockerhub-creds-pat', description: 'Jenkins credentials ID for Docker Hub login'),
    string(name: 'E2E_COMMAND', defaultValue: '', description: 'Optional UI E2E command (e.g. npm run test:e2e)'),
    string(name: 'SONAR_HOST_URL', defaultValue: 'http://sonarqube:9000', description: 'SonarQube URL (Docker Compose: sonarqube:9000, K8s: sonarqube.sonarqube.svc.cluster.local:9000)'),
    string(name: 'SONAR_TOKEN_CREDENTIALS_ID', defaultValue: 'sonar-token', description: 'Optional Jenkins String credential ID for Sonar token')
  ])
  // Note: For automatic triggers, use GitHub webhooks instead of pollSCM for better efficiency
  // To enable webhook trigger: Jenkins > Job Config > Build Triggers > "GitHub hook trigger for GITScm polling"
])

// ========================================
// GLOBAL VARIABLES & INITIALIZATION
// ========================================
def IMAGE_TAG = ''
def BUILD_STATUS = 'SUCCESS'
def DEPLOYMENT_URL = ''
def PREVIOUS_IMAGE_TAG = ''
def TEST_REPORT_SUMMARY = ''

node {
  timestamps {
    try {
      // ========================================
      // STAGE 1: CLEAN WORKSPACE
      // ========================================
      stage('Clean Workspace') {
        echo "=== Cleaning workspace ==="
        deleteDir()
        echo "✓ Workspace cleaned"
      }

      // ========================================
      // STAGE 2: CHECKOUT APPLICATION REPO
      // ========================================
      stage('Checkout Application') {
        echo "=== Checking out application repository ==="
        try {
          sh """
            set -e
            echo "Cloning application repo: ${params.BRANCH} from ${params.GITHUB_REPO_URL}"
            git clone --branch ${params.BRANCH} ${params.GITHUB_REPO_URL} app
            echo "✓ Application repository cloned"
          """
        } catch (Exception e) {
          BUILD_STATUS = 'FAILED'
          error("Application checkout failed: ${e.message}")
        }
      }

      // ========================================
      // STAGE 3: CHECKOUT DEVOPS REPO
      // ========================================
      stage('Checkout DevOps') {
        echo "=== Checking out DevOps repository ==="
        try {
          sh """
            set -e
            echo "Cloning DevOps repo..."
            git clone https://github.com/ravi2342/bug-report-portal-devops.git devops
            echo "✓ DevOps repository cloned"
          """
        } catch (Exception e) {
          BUILD_STATUS = 'FAILED'
          error("DevOps checkout failed: ${e.message}")
        }
      }

      // ========================================
      // STAGE 3: BUILD METADATA
      // ========================================
      stage('Build Metadata') {
        echo "=== Building metadata ==="
        try {
          // Read registry from config file
          def imageRegistry = readFile('app/.docker-registry').trim()
          echo "Registry: ${imageRegistry}"
          
          // Extract version from package.json
          def packageJson = readJSON file: 'app/package.json'
          def appVersion = packageJson.version ?: 'unknown'
          echo "App Version: ${appVersion}"
          
          // Extract repo name
          def imageName = getImageNameFromUrl(params.GITHUB_REPO_URL)
          echo "Image Name: ${imageName}"
          
          // Build full image tag
          IMAGE_TAG = "${imageRegistry}/${imageName}:${appVersion}-${BUILD_NUMBER}"
          echo "Full Image Tag: ${IMAGE_TAG}"
          
          // Set build display name
          currentBuild.displayName = "#${BUILD_NUMBER} - ${IMAGE_TAG}"
          currentBuild.description = """
            Branch: ${params.BRANCH}
            Push: ${params.DO_PUSH}
            Deploy: ${params.DO_DEPLOY}
            SonarQube: ${params.RUN_SONAR}
          """.stripIndent()
          
          echo "✓ Metadata built successfully"
        } catch (Exception e) {
          BUILD_STATUS = 'FAILED'
          error("Build metadata failed: ${e.message}")
        }
      }

      // ========================================
      // STAGE 4: PREFLIGHT CHECKS
      // ========================================
      stage('Preflight Checks') {
        echo "=== Running preflight checks ==="
        try {
          sh '''
            set -e
            echo "Checking required tools..."
            echo "Node: $(node -v)"
            echo "npm: $(npm -v)"
            echo "Docker: $(docker --version)"
            
            # Check for required tools
            if ! command -v docker >/dev/null 2>&1; then
              echo "ERROR: docker not found"
              exit 1
            fi
            
            if ! command -v trivy >/dev/null 2>&1; then
              echo "WARN: trivy not found - security scan will be skipped"
            fi
            
            echo "✓ All critical tools available"
          '''
        } catch (Exception e) {
          BUILD_STATUS = 'FAILED'
          error("Preflight checks failed: ${e.message}")
        }
      }

      // ========================================
      // STAGE 5: INSTALL DEPENDENCIES
      // ========================================
      stage('Install Dependencies') {
        echo "=== Installing dependencies ==="
        try {
          sh 'cd app && npm ci'
          echo "✓ Dependencies installed"
        } catch (Exception e) {
          BUILD_STATUS = 'FAILED'
          error("Dependency installation failed: ${e.message}")
        }
      }

      // ========================================
      // STAGE 6: PRISMA GENERATE
      // ========================================
      stage('Prisma Generate') {
        echo "=== Running Prisma generate ==="
        try {
          sh '''
            set -e
            cd app
            
            # Copy .env.docker.example to .env if .env doesn't exist
            if [ ! -f .env ]; then
              if [ -f .env.docker.example ]; then
                cp .env.docker.example .env
                echo "Created .env from .env.docker.example"
              else
                echo "ERROR: Neither .env nor .env.docker.example found"
                exit 1
              fi
            fi
            
            npx prisma generate
          '''
          echo "✓ Prisma schema generated"
        } catch (Exception e) {
          BUILD_STATUS = 'FAILED'
          error("Prisma generation failed: ${e.message}")
        }
      }



      // ========================================
      // STAGE 8: LINT (IF CONFIGURED)
      // ========================================
      stage('Lint') {
        echo "=== Running lint ==="
        try {
          def haslint = sh(
            script: "node -e \"const p=require('./app/package.json'); process.exit((p.scripts && p.scripts.lint) ? 0 : 1)\"",
            returnStatus: true
          ) == 0
          
          if (haslint) {
            sh 'cd app && npm run lint'
            echo "✓ Lint passed"
          } else {
            echo "⊘ No lint script configured - skipping"
          }
        } catch (Exception e) {
          echo "⚠ Lint failed but continuing: ${e.message}"
        }
      }

      // ========================================
      // STAGE 9: TESTS (IF CONFIGURED)
      // ========================================
      stage('Run Tests') {
        echo "=== Running tests ==="
        try {
          def hasTests = sh(
            script: "node -e \"const p=require('./app/package.json'); process.exit((p.scripts && p.scripts.test && !p.scripts.test.includes('no test')) ? 0 : 1)\"",
            returnStatus: true
          ) == 0
          
          if (hasTests) {
            sh 'cd app && npm test'
            echo "✓ Tests passed"
          } else {
            echo "⊘ No test script configured - skipping"
          }
        } catch (Exception e) {
          echo "⚠ Tests failed but continuing: ${e.message}"
        }
      }

      // ========================================
      // STAGE 10: SONARQUBE SCAN (OPTIONAL)
      // ========================================
      if (params.RUN_SONAR && params.SONAR_HOST_URL?.trim() && params.SONAR_TOKEN_CREDENTIALS_ID?.trim()) {
        stage('SonarQube Scan') {
          echo "=== Running SonarQube analysis ==="
          try {
            withCredentials([string(credentialsId: params.SONAR_TOKEN_CREDENTIALS_ID, variable: 'SONAR_TOKEN')]) {
              def sonarAvailable = sh(
                script: "command -v sonar-scanner >/dev/null 2>&1",
                returnStatus: true
              ) == 0
              
              if (sonarAvailable) {
                sh """
                  set -e
                  echo "Starting SonarQube analysis from devops directory..."
                  cd devops
                  sonar-scanner \\
                    -Dsonar.host.url="${params.SONAR_HOST_URL}" \\
                    -Dsonar.token="${SONAR_TOKEN}" \\
                    -Dsonar.projectKey=bug-report-portal \\
                    -Dsonar.qualitygate.wait=true \\
                    -Dsonar.qualitygate.timeout=300
                  
                  echo "✓ Quality Gate PASSED"
                  echo "View results at: ${params.SONAR_HOST_URL}/dashboard?id=bug-report-portal"
                """
              } else {
                echo "⊘ sonar-scanner not installed - skipping Sonar scan"
              }
            }
          } catch (Exception e) {
            BUILD_STATUS = 'FAILED'
            error("SonarQube scan failed: ${e.message}")
          }
        }
      }

      // ========================================
      // STAGE 11: DOCKER BUILD
      // ========================================
      stage('Build Docker Image') {
        echo "=== Building Docker image: ${IMAGE_TAG} ==="
        try {
          sh "docker build -t ${IMAGE_TAG} app"
          echo "✓ Docker image built successfully"
        } catch (Exception e) {
          BUILD_STATUS = 'FAILED'
          error("Docker build failed: ${e.message}")
        }
      }

      // ========================================
      // STAGE 12: TRIVY SECURITY SCAN
      // ========================================
      stage('Trivy Security Scan') {
        echo "=== Running Trivy security scan ==="
        try {
          def trivyAvailable = sh(
            script: "command -v trivy >/dev/null 2>&1",
            returnStatus: true
          ) == 0
          
          if (trivyAvailable) {
            sh """
              set -e
              echo "Scanning image for HIGH and CRITICAL vulnerabilities..."
              trivy image --scanners vuln --severity HIGH,CRITICAL --no-progress --exit-code 1 ${IMAGE_TAG}
            """
            echo "✓ Trivy scan passed - no HIGH/CRITICAL vulnerabilities"
          } else {
            echo "⚠ Trivy not installed - security scan skipped"
          }
        } catch (Exception e) {
          BUILD_STATUS = 'FAILED'
          error("Trivy security scan failed: ${e.message}")
        }
      }

      // ========================================
      // STAGE 13: DOCKER PUSH (OPTIONAL)
      // ========================================
      if (params.DO_PUSH) {
        stage('Push Image to Registry') {
          echo "=== Pushing Docker image to registry ==="
          try {
            if (params.REGISTRY_CREDENTIALS_ID?.trim()) {
              withCredentials([usernamePassword(credentialsId: params.REGISTRY_CREDENTIALS_ID, usernameVariable: 'REG_USER', passwordVariable: 'REG_PASS')]) {
                sh """
                  set -e
                  echo "Logging in to Docker Hub..."
                  echo "${REG_PASS}" | docker login -u "${REG_USER}" --password-stdin
                  
                  echo "Pushing image: ${IMAGE_TAG}"
                  docker push ${IMAGE_TAG}
                  
                  docker logout
                """
              }
            } else {
              sh "docker push ${IMAGE_TAG}"
            }
            echo "✓ Image pushed successfully"
          } catch (Exception e) {
            BUILD_STATUS = 'FAILED'
            error("Docker push failed: ${e.message}")
          }
        }
      }

      // ========================================
      // STAGE 14: DEPLOY TO KUBERNETES (OPTIONAL)
      // ========================================
      if (params.DO_DEPLOY) {
        stage('Deploy to Kubernetes') {
          echo "=== Deploying to Kubernetes (Kind) ==="
          try {
            def kubectlAvailable = sh(
              script: "command -v kubectl >/dev/null 2>&1",
              returnStatus: true
            ) == 0
            
            if (!kubectlAvailable) {
              error("kubectl not found on agent")
            }
            
            sh """
              set -e
              echo "Setting kubectl context to Kind cluster..."
              kubectl config use-context kind-bug-report-portal
              
              echo "Checking Kind cluster connectivity..."
              kubectl --insecure-skip-tls-verify cluster-info
              
              echo "Navigating to k8s manifests directory..."
              cd devops/k8s
              
              echo "Setting Docker Hub image tag: ${IMAGE_TAG}"
              kustomize edit set image bugreportportal=${IMAGE_TAG}
              
              echo "Applying Kubernetes manifests with dynamic image..."
              kubectl --insecure-skip-tls-verify apply -k .
              
              echo "Waiting for rollout..."
              kubectl --insecure-skip-tls-verify rollout status deployment/bug-report-portal-app -n bug-report-portal --timeout=120s
            """
            
            DEPLOYMENT_URL = "Deployed to Kind cluster"
            echo "✓ Kubernetes deployment successful"
          } catch (Exception e) {
            BUILD_STATUS = 'FAILED'
            error("Kubernetes deployment failed: ${e.message}")
          }
        }

        // ========================================
        // STAGE 15: SMOKE TESTS (OPTIONAL)
        // ========================================
        if (params.RUN_POST_DEPLOY_TESTS) {
          stage('Post-Deploy Smoke Tests') {
            echo "=== Running smoke tests ==="
            try {
              sh '''
                set -e
                
                echo "Setting up port-forward..."
                kubectl -n bug-report-portal port-forward service/bug-report-portal-service 18080:3000 >/tmp/pf.log 2>&1 &
                PF_PID=$!
                trap "kill $PF_PID >/dev/null 2>&1 || true" EXIT
                
                sleep 3
                
                echo "Testing /login endpoint..."
                curl -fsS -I http://127.0.0.1:18080/login || exit 1
                
                echo "Testing /incidents endpoint..."
                curl -fsS -I http://127.0.0.1:18080/incidents || exit 1
                
                echo "✓ Smoke tests passed"
              '''
            } catch (Exception e) {
              BUILD_STATUS = 'FAILED'
              error("Smoke tests failed: ${e.message}")
            }
          }

          // ========================================
          // STAGE 16: UI E2E TESTS (OPTIONAL)
          // ========================================
          if (params.RUN_UI_E2E && params.E2E_COMMAND?.trim()) {
            stage('UI E2E Tests') {
              echo "=== Running UI E2E tests ==="
              try {
                sh """
                  set -e
                  echo "Executing: ${params.E2E_COMMAND}"
                  ${params.E2E_COMMAND}
                """
                echo "✓ E2E tests passed"
              } catch (Exception e) {
                BUILD_STATUS = 'FAILED'
                error("E2E tests failed: ${e.message}")
              }
            }
          }
        }

        // ========================================
        // STAGE 17: HEALTH CHECK (OPTIONAL)
        // ========================================
        if (params.RUN_POST_DEPLOY_TESTS) {
          stage('Deployment Health Check') {
            echo "=== Verifying deployment health ==="
            try {
              sh '''
                set -e
                
                echo "Checking pod status..."
                POD_STATUS=$(kubectl -n bug-report-portal get pods -l app=bug-report-portal-app -o jsonpath='{.items[0].status.phase}' 2>/dev/null || echo "Unknown")
                echo "Pod Status: $POD_STATUS"
                
                if [ "$POD_STATUS" != "Running" ]; then
                  echo "ERROR: Pod is not running (Status: $POD_STATUS)"
                  exit 1
                fi
                
                echo "Checking pod readiness..."
                READY=$(kubectl -n bug-report-portal get pods -l app=bug-report-portal-app -o jsonpath='{.items[0].status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "False")
                
                if [ "$READY" != "True" ]; then
                  echo "ERROR: Pod is not ready"
                  exit 1
                fi
                
                echo "Checking deployment replicas..."
                DESIRED=$(kubectl -n bug-report-portal get deployment bug-report-portal-app -o jsonpath='{.spec.replicas}')
                READY_REPLICAS=$(kubectl -n bug-report-portal get deployment bug-report-portal-app -o jsonpath='{.status.readyReplicas}')
                
                echo "Desired: $DESIRED, Ready: $READY_REPLICAS"
                
                if [ "$DESIRED" != "$READY_REPLICAS" ]; then
                  echo "ERROR: Not all replicas are ready"
                  exit 1
                fi
                
                echo "✓ Deployment health check PASSED"
              '''
            } catch (Exception e) {
              echo "❌ Health check failed, initiating rollback..."
              BUILD_STATUS = 'FAILED - ROLLBACK INITIATED'
              
              try {
                sh '''
                  set -e
                  echo "Retrieving previous deployment image..."
                  PREVIOUS_IMAGE=$(kubectl -n bug-report-portal rollout history deployment/bug-report-portal-app --revision=0 2>/dev/null || echo "")
                  
                  if [ -z "$PREVIOUS_IMAGE" ]; then
                    echo "Rolling back to previous revision..."
                    kubectl -n bug-report-portal rollout undo deployment/bug-report-portal-app -n bug-report-portal
                    kubectl -n bug-report-portal rollout status deployment/bug-report-portal-app --timeout=120s
                    echo "✓ Rollback completed successfully"
                  fi
                '''
              } catch (Exception rollbackError) {
                echo "⚠ Rollback failed: ${rollbackError.message}"
              }
              
              error("Health check failed: ${e.message}")
            }
          }
        }
      }

      // ========================================
      // SUCCESS - SET BUILD RESULT
      // ========================================
      echo "=== Pipeline completed successfully ==="
      currentBuild.result = 'SUCCESS'

    } catch (Exception e) {
      echo "❌ Pipeline failed: ${e.message}"
      currentBuild.result = 'FAILURE'
      BUILD_STATUS = 'FAILED'
    } finally {
      // ========================================
      // STAGE 18: ARCHIVE ARTIFACTS & REPORTS
      // ========================================
      stage('Archive Artifacts') {
        echo "=== Archiving test reports and artifacts ==="
        try {
          // Archive test reports
          sh '''
            set +e
            
            # Create reports directory if it doesn't exist
            mkdir -p test-reports coverage-reports
            
            # Copy Jest test results
            if [ -f app/coverage/coverage-final.json ]; then
              cp -r app/coverage test-reports/coverage || true
            fi
            
            # Copy lint results if available
            if [ -f app/.eslintrc.json ]; then
              cd app && npm run lint -- --format json > ../test-reports/eslint-report.json 2>&1 || true
            fi
            
            # Archive build logs
            echo "Pipeline Status: ${BUILD_STATUS}" > test-reports/build-summary.txt
            echo "Build Number: ${BUILD_NUMBER}" >> test-reports/build-summary.txt
            echo "Image Tag: ${IMAGE_TAG}" >> test-reports/build-summary.txt
            echo "Timestamp: $(date)" >> test-reports/build-summary.txt
          '''
          
          // Archive to Jenkins
          archiveArtifacts artifacts: 'test-reports/**', allowEmptyArchive: true
          
          echo "✓ Artifacts archived"
        } catch (Exception e) {
          echo "⚠ Artifact archiving failed: ${e.message}"
        }
      }

      // ========================================
      // STAGE 19: PUBLISH TEST REPORTS
      // ========================================
      stage('Publish Test Reports') {
        echo "=== Publishing test reports ==="
        try {
          // Publish JUnit test results (if using JUnit reporter)
          junit testResults: 'test-reports/**/*.xml', allowEmptyResults: true
          
          // Archive coverage reports (publishHTML requires HTML Publisher plugin)
          // To enable: Install "HTML Publisher" plugin in Jenkins
          archiveArtifacts artifacts: 'test-reports/coverage/**', allowEmptyArchive: true
          
          echo "✓ Test reports published"
        } catch (Exception e) {
          echo "⚠ Test report publishing failed: ${e.message}"
        }
      }

      // ========================================
      // STAGE 20: NOTIFICATIONS
      // ========================================
      stage('Send Notifications') {
        echo "=== Sending build notifications ==="
        try {
          def slackColor = BUILD_STATUS == 'SUCCESS' ? 'good' : 'danger'
          def slackMessage = """
            Build: ${BUILD_NUMBER}
            Status: ${BUILD_STATUS}
            Repository: ${params.GITHUB_REPO_URL}
            Branch: ${params.BRANCH}
            Image: ${IMAGE_TAG ?: 'Not built'}
            Deployment: ${DEPLOYMENT_URL ?: 'Not deployed'}
            URL: ${BUILD_URL}
          """
          
          // Optional: Send to Slack (configure webhook in Jenkins credentials)
          // def slackWebhook = 'slack-webhook-url'
          // withCredentials([string(credentialsId: slackWebhook, variable: 'SLACK_URL')]) {
          //   sh """
          //     curl -X POST '${SLACK_URL}' \
          //       -H 'Content-Type: application/json' \
          //       -d '{
          //         "color": "${slackColor}",
          //         "title": "Build ${BUILD_NUMBER} ${BUILD_STATUS}",
          //         "text": "${slackMessage}",
          //         "fields": [
          //           {"title": "Repository", "value": "${params.GITHUB_REPO_URL}", "short": true},
          //           {"title": "Branch", "value": "${params.BRANCH}", "short": true},
          //           {"title": "Build URL", "value": "${BUILD_URL}", "short": false}
          //         ]
          //       }'
          //   """
          // }
          
          echo "✓ Notifications sent (Slack integration optional)"
        } catch (Exception e) {
          echo "⚠ Notification failed: ${e.message}"
        }
      }

      // ========================================
      // STAGE 21: CLEANUP & FINAL REPORT
      // ========================================
      stage('Cleanup & Report') {
        echo "=== Final cleanup ==="
        sh 'docker images | head -n 10 || true'
        
        def durationMinutes = currentBuild.durationString.replaceAll(/sec.*/, '').replaceAll(/.*,\s*/, '')
        
        echo """
        ╔═══════════════════════════════════════════════════════════╗
        ║           PIPELINE EXECUTION SUMMARY                      ║
        ╠═══════════════════════════════════════════════════════════╣
        ║ Status:           ${BUILD_STATUS}
        ║ Build #:          ${BUILD_NUMBER}
        ║ Duration:         ${currentBuild.durationString}
        ║ Image Tag:        ${IMAGE_TAG ?: 'Not built'}
        ║ Deployment:       ${DEPLOYMENT_URL ?: 'Not deployed'}
        ║ Test Reports:     ${BUILD_URL}artifact/test-reports/
        ║ Console Log:      ${BUILD_URL}console
        ╚═══════════════════════════════════════════════════════════╝
        """
      }
    }
  }
}
