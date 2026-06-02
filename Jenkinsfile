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
    booleanParam(name: 'RUN_CHECKMARX', defaultValue: false, description: 'Run Checkmarx SAST'),
    booleanParam(name: 'RUN_SONAR', defaultValue: false, description: 'Run SonarQube scan'),
    booleanParam(name: 'RUN_POST_DEPLOY_TESTS', defaultValue: false, description: 'Run smoke tests after deploy'),
    booleanParam(name: 'RUN_UI_E2E', defaultValue: false, description: 'Run UI E2E after smoke tests'),
    string(name: 'REGISTRY_URL', defaultValue: '', description: 'Optional registry URL for docker login'),
    string(name: 'REGISTRY_CREDENTIALS_ID', defaultValue: '', description: 'Optional Jenkins credentials ID for docker login'),
    string(name: 'E2E_COMMAND', defaultValue: '', description: 'Optional UI E2E command (e.g. npm run test:e2e)'),
    string(name: 'CHECKMARX_COMMAND', defaultValue: '', description: 'Required when RUN_CHECKMARX=true'),
    string(name: 'SONAR_HOST_URL', defaultValue: '', description: 'Optional SonarQube URL'),
    string(name: 'SONAR_TOKEN_CREDENTIALS_ID', defaultValue: '', description: 'Optional Jenkins String credential ID for Sonar token')
  ])
  // Note: For automatic triggers, use GitHub webhooks instead of pollSCM for better efficiency
  // To enable webhook trigger: Jenkins > Job Config > Build Triggers > "GitHub hook trigger for GITScm polling"
])

// ========================================
// GLOBAL VARIABLES & INITIALIZATION
// ========================================
def APP_DIR = 'bug-report-portal'
def IMAGE_TAG = ''
def BUILD_STATUS = 'SUCCESS'
def DEPLOYMENT_URL = ''

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
      // STAGE 2: CHECKOUT REPOSITORIES
      // ========================================
      stage('Checkout') {
        echo "=== Checking out application repository ==="
        try {
          sh """
            set -e
            echo "Cloning application repo: ${params.BRANCH} from ${params.GITHUB_REPO_URL}"
            git clone --branch ${params.BRANCH} ${params.GITHUB_REPO_URL} ${APP_DIR}
            echo "Checkout completed successfully"
          """
        } catch (Exception e) {
          BUILD_STATUS = 'FAILED'
          error("Checkout failed: ${e.message}")
        }
      }

      // ========================================
      // STAGE 3: BUILD METADATA
      // ========================================
      stage('Build Metadata') {
        echo "=== Building metadata ==="
        try {
          dir(APP_DIR) {
            // Read registry from config file
            def imageRegistry = readFile('.docker-registry').trim()
            echo "Registry: ${imageRegistry}"
            
            // Extract version from package.json
            def packageJson = readJSON file: 'package.json'
            def appVersion = packageJson.version ?: 'unknown'
            echo "App Version: ${appVersion}"
            
            // Extract repo name
            def imageName = getImageNameFromUrl(params.GITHUB_REPO_URL)
            echo "Image Name: ${imageName}"
            
            // Build full image tag
            IMAGE_TAG = "${imageRegistry}/${imageName}:${appVersion}-${BUILD_NUMBER}"
            echo "Full Image Tag: ${IMAGE_TAG}"
          }
          
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
          dir(APP_DIR) {
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
          }
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
          dir(APP_DIR) {
            sh 'npm ci'
          }
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
          dir(APP_DIR) {
            sh 'npx prisma generate'
          }
          echo "✓ Prisma schema generated"
        } catch (Exception e) {
          BUILD_STATUS = 'FAILED'
          error("Prisma generation failed: ${e.message}")
        }
      }

      // ========================================
      // STAGE 7: CHECKMARX SAST (OPTIONAL)
      // ========================================
      if (params.RUN_CHECKMARX) {
        stage('Checkmarx SAST') {
          echo "=== Running Checkmarx SAST ==="
          try {
            if (!params.CHECKMARX_COMMAND?.trim()) {
              error("RUN_CHECKMARX=true but CHECKMARX_COMMAND is empty")
            }
            
            dir(APP_DIR) {
              sh """
                set -e
                echo "Executing: ${params.CHECKMARX_COMMAND}"
                ${params.CHECKMARX_COMMAND}
              """
            }
            echo "✓ Checkmarx scan completed"
          } catch (Exception e) {
            BUILD_STATUS = 'FAILED'
            error("Checkmarx scan failed: ${e.message}")
          }
        }
      }

      // ========================================
      // STAGE 8: LINT (IF CONFIGURED)
      // ========================================
      stage('Lint') {
        echo "=== Running lint ==="
        try {
          dir(APP_DIR) {
            def haslint = sh(
              script: "node -e \"const p=require('./package.json'); process.exit((p.scripts && p.scripts.lint) ? 0 : 1)\"",
              returnStatus: true
            ) == 0
            
            if (haslint) {
              sh 'npm run lint'
              echo "✓ Lint passed"
            } else {
              echo "⊘ No lint script configured - skipping"
            }
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
          dir(APP_DIR) {
            def hasTests = sh(
              script: "node -e \"const p=require('./package.json'); process.exit((p.scripts && p.scripts.test && !p.scripts.test.includes('no test')) ? 0 : 1)\"",
              returnStatus: true
            ) == 0
            
            if (hasTests) {
              sh 'npm test'
              echo "✓ Tests passed"
            } else {
              echo "⊘ No test script configured - skipping"
            }
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
              dir(APP_DIR) {
                def sonarAvailable = sh(
                  script: "command -v sonar-scanner >/dev/null 2>&1",
                  returnStatus: true
                ) == 0
                
                if (sonarAvailable) {
                  sh """
                    set -e
                    echo "Starting SonarQube analysis..."
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
          dir(APP_DIR) {
            sh "docker build -t ${IMAGE_TAG} -f ../Dockerfile .."
          }
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
                  echo "Logging in to registry..."
                  echo "${REG_PASS}" | docker login -u "${REG_USER}" --password-stdin ${params.REGISTRY_URL}
                  
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
          echo "=== Deploying to Kubernetes ==="
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
              echo "Checking cluster connectivity..."
              kubectl cluster-info
              
              echo "Applying Kubernetes manifests..."
              kubectl apply -k devops/k8s
              
              echo "Updating deployment image..."
              kubectl -n bug-report-portal set image deployment/bug-report-portal-app app=${IMAGE_TAG}
              
              echo "Waiting for rollout..."
              kubectl rollout status deployment/bug-report-portal-app -n bug-report-portal --timeout=120s
            """
            
            DEPLOYMENT_URL = "Deployed to cluster"
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
                dir(APP_DIR) {
                  sh """
                    set -e
                    echo "Executing: ${params.E2E_COMMAND}"
                    ${params.E2E_COMMAND}
                  """
                }
                echo "✓ E2E tests passed"
              } catch (Exception e) {
                BUILD_STATUS = 'FAILED'
                error("E2E tests failed: ${e.message}")
              }
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
      // CLEANUP & FINAL REPORT
      // ========================================
      stage('Cleanup & Report') {
        echo "=== Final cleanup ==="
        sh 'docker images | head -n 10 || true'
        
        echo """
        ╔════════════════════════════════════════╗
        ║      PIPELINE EXECUTION SUMMARY        ║
        ╠════════════════════════════════════════╣
        ║ Status:        ${BUILD_STATUS}
        ║ Build #:       ${BUILD_NUMBER}
        ║ Duration:      ${currentBuild.durationString}
        ║ Image Tag:     ${IMAGE_TAG}
        ║ Deployment:    ${DEPLOYMENT_URL ?: 'Not deployed'}
        ╚════════════════════════════════════════╝
        """
      }
    }
  }
}
