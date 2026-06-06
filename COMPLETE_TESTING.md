# Complete Testing Guide - Unit, Integration, E2E, & Smoke Tests

Comprehensive overview of all testing in the CI/CD pipeline and how to run them locally.

---

## Testing Overview

The application uses a **multi-layer testing strategy** integrated into the Jenkins pipeline:

```
Code Commit
    ↓
[Stage 4] Unit Tests (Jest)
    ↓
[Stage 5] Code Coverage Analysis
    ↓
[Stage 6] SonarQube Code Quality Scan
    ↓
[Stage 7] Quality Gate Check
    ↓
[Stage 8-9] Build & Push Docker Image
    ↓
[Stage 10-12] Deploy to Kubernetes
    ↓
[Stage 13] Post-Deploy Smoke Tests
    ↓
[Stage 14] E2E UI Tests (Playwright)
    ↓
[Stage 15] Collect Test Reports
    ↓
Build Success/Failure Report
```

---

## Unit Tests (Stage 4)

### What Are Unit Tests?
Unit tests verify individual functions and components in isolation:
- Test a single function with various inputs
- Verify outputs are correct
- Mock external dependencies (database, HTTP calls)
- Fast execution (< 1 second per test)
- Run before any deployment

### Technology
- **Framework:** Jest (JavaScript testing framework)
- **Location:** Application repository `src/__tests__/` folder
- **Command:** `npm test`

### Example Test Case
```javascript
// src/__tests__/utils/validation.test.js
describe('validateEmail', () => {
  it('should accept valid email addresses', () => {
    expect(validateEmail('admin@example.com')).toBe(true);
  });
  
  it('should reject invalid email addresses', () => {
    expect(validateEmail('invalid-email')).toBe(false);
  });
  
  it('should reject empty string', () => {
    expect(validateEmail('')).toBe(false);
  });
});
```

### Running Locally
```bash
cd ~/path/to/bugreportportal

# Run all unit tests
npm test

# Run specific test file
npm test -- src/__tests__/utils/validation.test.js

# Run with coverage report
npm test -- --coverage

# Watch mode (re-run on file changes)
npm test -- --watch
```

### Output Example
```
PASS  src/__tests__/utils/validation.test.js (1.234s)
  validateEmail
    ✓ should accept valid email addresses (5ms)
    ✓ should reject invalid email addresses (3ms)
    ✓ should reject empty string (2ms)

PASS  src/__tests__/controllers/reportController.test.js
  createReport
    ✓ should create new report with valid data (8ms)
    ✓ should reject report missing title (4ms)
    ✓ should validate priority enum (3ms)

Test Suites: 2 passed, 2 total
Tests:       6 passed, 6 total
Snapshots:   0 total
Time:        2.450 s
```

### Pipeline Integration (Stage 4)
```groovy
stage('Run Tests') {
  echo "=== Running Unit Tests ==="
  sh '''
    npm test -- --coverage \
      --testResultsProcessor=./test-results-processor.js
  '''
}
```

### Failure Handling
If any unit test fails:
1. Jenkins build stops at Stage 4
2. Build marked as FAILED
3. No Docker image built
4. No deployment to Kubernetes
5. Test failure details in console output

```bash
# Example failure output:
FAIL  src/__tests__/controllers/reportController.test.js
  createReport
    ✗ should create new report with valid data (15ms)
      
      Expected: {"id": 1, "title": "Bug title"}
      Received: {"id": null, "title": "Bug title"}

Tests: 1 failed, 5 passed
```

---

## Code Coverage Analysis (Stage 5)

### What Is Code Coverage?
Measures what percentage of code is executed by tests:
- **Line coverage:** % of code lines tested
- **Branch coverage:** % of if/else branches tested
- **Function coverage:** % of functions called by tests
- **Statement coverage:** % of statements executed

### Configuration
**jest.config.js:**
```javascript
module.exports = {
  collectCoverage: true,
  collectCoverageFrom: [
    'src/**/*.js',
    '!src/index.js',
    '!src/**/*.test.js',
  ],
  coverageThreshold: {
    global: {
      branches: 70,
      functions: 75,
      lines: 80,
      statements: 80,
    },
  },
};
```

### Running Locally
```bash
npm test -- --coverage
```

### Output Example
```
File                      | % Stmts | % Branch | % Funcs | % Lines |
--------------------------|---------|----------|---------|---------|
All files                 |   82.5  |   78.2   |   85.1  |   82.3  |
 src/controllers/         |   85.0  |   80.0   |   88.0  |   85.0  |
  reportController.js     |   85.0  |   80.0   |   88.0  |   85.0  |
 src/models/              |   80.0  |   75.0   |   82.0  |   80.0  |
  report.js               |   80.0  |   75.0   |   82.0  |   80.0  |
 src/utils/               |   82.0  |   78.0   |   85.0  |   82.0  |
  validation.js           |   82.0  |   78.0   |   85.0  |   82.0  |
```

### Pipeline Integration (Stage 5)
```groovy
stage('Code Coverage') {
  echo "=== Analyzing Code Coverage ==="
  sh '''
    npm test -- --coverage
    # Coverage report saved to: coverage/lcov.html
  '''
}
```

### Viewing Coverage Report Locally
```bash
# Generate coverage
npm test -- --coverage

# Open HTML report in browser
open coverage/lcov-report/index.html
```

---

## SonarQube Code Quality Scan (Stage 6)

### What Is SonarQube?
Performs static code analysis to detect:
- Security vulnerabilities
- Code smells (anti-patterns)
- Bugs and potential bugs
- Code complexity
- Duplication
- Technical debt

### Technology
- **Tool:** SonarQube (open source code quality platform)
- **Location:** http://localhost:9000
- **Configuration:** `sonar-project.properties`

### Configuration
**sonar-project.properties:**
```properties
sonar.projectKey=bug-report-portal
sonar.projectName=Bug Report Portal
sonar.sources=src
sonar.tests=src/__tests__
sonar.exclusions=**/node_modules/**
sonar.javascript.lcov.reportPaths=coverage/lcov.info
```

### Running Locally
```bash
# 1. Start SonarQube
docker compose up -d sonarqube

# 2. Get authentication token
# Go to: http://localhost:9000
# Login: admin / admin
# Generate token in: User > My Account > Security

# 3. Run analysis
cd ~/path/to/bugreportportal

npm run sonar -- \
  -Dsonar.host.url=http://localhost:9000 \
  -Dsonar.login=YOUR_SONAR_TOKEN

# 4. View results
# Open: http://localhost:9000/dashboard
```

### Example SonarQube Issues
```
BLOCKER: SQL Injection vulnerability in query builder
CRITICAL: Missing null check before array access
MAJOR: Hardcoded credentials in config file
MINOR: Unused variable declared on line 45
INFO: Duplicate code detected in utils/validation.js
```

### Pipeline Integration (Stage 6)
```groovy
stage('SonarQube Scan') {
  if (params.RUN_SONAR) {
    echo "=== Running SonarQube Analysis ==="
    sh '''
      npm run sonar -- \
        -Dsonar.host.url=http://sonarqube:9000 \
        -Dsonar.login=${SONAR_TOKEN}
    '''
  }
}
```

### Quality Gate Check (Stage 7)
After SonarQube analysis completes, Quality Gate automatically checks:
- No BLOCKER issues
- No CRITICAL security vulnerabilities
- Code coverage > 80%
- No increased technical debt

If Quality Gate fails, build stops.

---

## Smoke Tests - Post-Deploy Health Check (Stage 13)

### What Are Smoke Tests?
Quick tests verifying basic application functionality after deployment:
- Application is running
- API endpoints respond
- Database is connected
- Basic operations work
- No immediate crashes

### Smoke Test Cases

#### Test 1: API Health Check
```bash
curl -k https://localhost:8888/health
# Response: {"status":"ok","timestamp":"2024-01-15T10:30:00Z"}
```

#### Test 2: Database Connection
```bash
curl -k https://localhost:8888/api/reports/count
# Response: {"count":0}
```

#### Test 3: Authentication
```bash
curl -k -X POST https://localhost:8888/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"admin","password":"admin"}'
# Response: {"token":"jwt_token_here","user":{"id":1,"email":"admin"}}
```

#### Test 4: Create Report
```bash
curl -k -X POST https://localhost:8888/api/reports \
  -H "Authorization: Bearer jwt_token_here" \
  -H "Content-Type: application/json" \
  -d '{
    "title":"Test Bug",
    "description":"Test Description",
    "priority":"high"
  }'
# Response: {"id":1,"title":"Test Bug","status":"open"}
```

### Running Locally
```bash
# Prerequisites:
# - Application running at localhost:8888
# - Port-forward active in separate terminal
# - Database initialized with test data

# Run smoke tests
npm run test:smoke

# Or manually with curl:
bash scripts/smoke-tests.sh
```

### Pipeline Integration (Stage 13)
```groovy
stage('Post-Deploy Health Check') {
  if (params.RUN_POST_DEPLOY_TESTS) {
    echo "=== Running Smoke Tests ==="
    sh '''
      # Wait for application to be ready
      for i in {1..30}; do
        if curl -k http://localhost:8888/health 2>/dev/null; then
          echo "✓ Application is ready"
          break
        fi
        echo "  Waiting for app... ($i/30)"
        sleep 2
      done
      
      # Run smoke tests
      npm run test:smoke
    '''
  }
}
```

### Expected Output
```
✓ Health check: OK
✓ Database connection: OK
✓ Authentication: OK
✓ Create report: OK
✓ Read report: OK
✓ Update report: OK
✓ Delete report: OK

All smoke tests passed! (7/7)
Execution time: 2.345s
```

### Failure Handling
If any smoke test fails:
1. Jenkins build fails at Stage 13
2. Build marked as FAILED
3. E2E tests skipped
4. Deployment considered unsuccessful
5. Debug the pod logs: `kubectl logs deployment/bug-report-portal-app -n bug-report-portal`

---

## E2E (End-to-End) UI Tests - Playwright (Stage 14)

### What Are E2E Tests?
Automated tests simulating real user interactions:
- Launch browser
- Navigate pages
- Fill forms
- Click buttons
- Verify results on page
- End-to-end workflow testing

### Technology
- **Framework:** Playwright (browser automation)
- **Browsers tested:** Chromium, Firefox, WebKit (optional)
- **Location:** Application repository `e2e/` folder

### Example E2E Test
```javascript
// e2e/tests/login.spec.js
import { test, expect } from '@playwright/test';

test.describe('Login Flow', () => {
  test('should login with valid credentials', async ({ page }) => {
    // Navigate to login page
    await page.goto('http://localhost:8888/login');
    
    // Verify page loaded
    await expect(page).toHaveTitle('Bug Report Portal - Login');
    
    // Fill credentials
    await page.fill('input[name="email"]', 'admin');
    await page.fill('input[name="password"]', 'admin');
    
    // Submit form
    await page.click('button[type="submit"]');
    
    // Verify redirect to dashboard
    await expect(page).toHaveURL('http://localhost:8888/dashboard');
    
    // Verify welcome message
    await expect(page.locator('h1')).toContainText('Dashboard');
  });

  test('should reject invalid credentials', async ({ page }) => {
    await page.goto('http://localhost:8888/login');
    
    await page.fill('input[name="email"]', 'admin');
    await page.fill('input[name="password"]', 'wrong-password');
    await page.click('button[type="submit"]');
    
    // Verify error message appears
    await expect(page.locator('.error-message')).toContainText('Invalid credentials');
    
    // Verify still on login page
    await expect(page).toHaveURL('http://localhost:8888/login');
  });
});
```

### Running Locally

#### Setup
```bash
cd ~/path/to/bugreportportal

# Install dependencies
npm install

# Install Playwright browsers
npx playwright install
```

#### Run All E2E Tests
```bash
npm run test:e2e
```

#### Run Specific Test File
```bash
npm run test:e2e -- e2e/tests/login.spec.js
```

#### Run with Browser Visible (headed mode)
```bash
npm run test:e2e -- --headed
# Browser opens and you see automation happen
```

#### Run with Debug Mode
```bash
npm run test:e2e -- --debug
# Opens Playwright Inspector for step-by-step execution
```

#### Run with Slow Motion
```bash
npm run test:e2e -- --headed --slow-mo=1000
# Slows down each action by 1 second (easier to watch)
```

### E2E Test Scenarios

#### Scenario 1: Complete Bug Report Workflow
```javascript
test('create, read, update, delete bug report', async ({ page }) => {
  // Login
  await page.goto('http://localhost:8888/login');
  await page.fill('input[name="email"]', 'admin');
  await page.fill('input[name="password"]', 'admin');
  await page.click('button[type="submit"]');
  
  // Create report
  await page.click('button:has-text("New Report")');
  await page.fill('input[name="title"]', 'Login button unresponsive');
  await page.fill('textarea[name="description"]', 'Clicking login button does nothing');
  await page.selectOption('select[name="priority"]', 'high');
  await page.click('button:has-text("Submit")');
  
  // Verify created
  await expect(page.locator('text=Report created successfully')).toBeVisible();
  
  // Read report
  await page.click('text=Login button unresponsive');
  await expect(page.locator('h1')).toContainText('Login button unresponsive');
  
  // Update report
  await page.click('button:has-text("Edit")');
  await page.selectOption('select[name="priority"]', 'medium');
  await page.click('button:has-text("Save")');
  
  // Verify updated
  await expect(page.locator('text=Priority: Medium')).toBeVisible();
  
  // Delete report
  await page.click('button:has-text("Delete")');
  await page.click('button:has-text("Confirm Delete")');
  
  // Verify deleted
  await expect(page.locator('text=Login button unresponsive')).not.toBeVisible();
});
```

#### Scenario 2: Report Search & Filter
```javascript
test('search and filter reports', async ({ page }) => {
  await page.goto('http://localhost:8888/login');
  // ... login steps ...
  
  // Navigate to reports list
  await page.click('a:has-text("Reports")');
  
  // Search for report
  await page.fill('input[placeholder="Search..."]', 'login');
  await page.click('button:has-text("Search")');
  
  // Verify only matching reports shown
  await expect(page.locator('tbody >> tr')).toHaveCount(1);
  
  // Filter by priority
  await page.selectOption('select[name="priority"]', 'high');
  
  // Verify filtered results
  const rows = page.locator('tbody >> tr');
  for (let i = 0; i < await rows.count(); i++) {
    const priority = await rows.nth(i).locator('td:nth-child(3)').textContent();
    expect(priority).toContain('High');
  }
});
```

#### Scenario 3: Multi-User Collaboration
```javascript
test('multiple users can create and view reports', async ({ context }) => {
  // User 1: Create report
  const page1 = await context.newPage();
  await page1.goto('http://localhost:8888/login');
  await page1.fill('input[name="email"]', 'admin');
  await page1.fill('input[name="password"]', 'admin');
  await page1.click('button[type="submit"]');
  
  await page1.click('button:has-text("New Report")');
  await page1.fill('input[name="title"]', 'User 1 Report');
  await page1.click('button:has-text("Submit")');
  
  // User 2: See User 1's report
  const page2 = await context.newPage();
  await page2.goto('http://localhost:8888/login');
  await page2.fill('input[name="email"]', 'user2');
  await page2.fill('input[name="password"]', 'user2-password');
  await page2.click('button[type="submit"]');
  
  // User 2 should see User 1's report in list
  await expect(page2.locator('text=User 1 Report')).toBeVisible();
});
```

### Pipeline Integration (Stage 14)
```groovy
stage('E2E UI Tests') {
  if (params.RUN_UI_E2E) {
    echo "=== Running E2E Tests ==="
    sh '''
      npm run test:e2e \
        --reporter=html \
        --reporter=junit
    '''
  }
}
```

### Expected Output
```
Running 15 E2E tests...

✓ Login with valid credentials (2.345s)
✓ Login with invalid credentials (1.234s)
✓ Create bug report (3.456s)
✓ Update bug report (2.789s)
✓ Delete bug report (2.345s)
✓ Search reports (1.999s)
✓ Filter by priority (1.567s)
✓ Filter by status (1.432s)
✓ Pagination works (0.876s)
✓ Logout functionality (0.654s)
✓ Session persistence (2.109s)
✓ Concurrent users create reports (3.234s)
✓ Data validation on form (1.543s)
✓ Error handling for failed requests (1.876s)
✓ Responsive design on mobile (2.123s)

15 passed (25.234s)
```

### Failure Handling
If any E2E test fails:
1. Jenkins build fails at Stage 14
2. Build marked as FAILED
3. Test failure screenshots/videos saved
4. Reports available in Jenkins: Artifacts > e2e-reports/
5. Debug information in console output

```bash
# Check test videos (if recorded)
ls -la e2e/tests/test-results/videos/

# Check failure screenshots
ls -la e2e/tests/test-results/screenshots/
```

---

## Integration Tests (Optional)

### What Are Integration Tests?
Tests that verify multiple components working together:
- Database interactions
- API endpoints with database
- Authentication with authorization
- Real HTTP requests (not mocked)

### Example Integration Test
```javascript
// src/__tests__/integration/reportController.integration.test.js
describe('Report Controller Integration', () => {
  let database;
  
  beforeAll(async () => {
    database = await setupTestDatabase();
  });
  
  afterAll(async () => {
    await teardownTestDatabase();
  });
  
  it('should create report and save to database', async () => {
    const report = await createReport({
      title: 'Test Bug',
      description: 'Test Description',
      priority: 'high'
    });
    
    // Verify database
    const savedReport = await database.query(
      'SELECT * FROM reports WHERE id = ?',
      [report.id]
    );
    
    expect(savedReport).toBeDefined();
    expect(savedReport.title).toBe('Test Bug');
  });
  
  it('should authenticate user and create report', async () => {
    const user = await authenticateUser('admin', 'admin');
    
    const report = await createReport({
      title: 'User Report',
      userId: user.id
    });
    
    expect(report.userId).toBe(user.id);
  });
});
```

### Running Integration Tests
```bash
npm run test:integration

# Or with coverage
npm run test:integration -- --coverage
```

---

## Test Reports in Jenkins

### Viewing Test Results in Pipeline
1. **Jenkins job:** bug-report-portal
2. **Build #XX:** Click on build number
3. **Test Results:** Link shows all test data
4. **Coverage Report:** Shows code coverage metrics
5. **SonarQube:** Link to SonarQube analysis

### Test Report Files
```
Jenkins Artifacts:
├── test-reports/
│   ├── junit.xml           # Unit test results
│   ├── coverage.html       # Code coverage report
│   ├── sonar-report.json   # SonarQube results
│   ├── smoke-tests.log     # Smoke test output
│   ├── e2e-reports/        # E2E test results
│   │   ├── index.html
│   │   ├── screenshots/    # Failed test screenshots
│   │   └── videos/         # Test execution videos
│   └── test-summary.txt    # Human-readable summary
```

### Downloading Test Reports
```bash
# Download all test reports
curl -O http://localhost:8080/jenkins/job/bug-report-portal/XX/artifact/test-reports/*

# View coverage HTML report locally
open /path/to/downloaded/coverage.html

# View E2E report
open /path/to/downloaded/e2e-reports/index.html
```

---

## Continuous Testing Best Practices

### 1. Run Tests Locally Before Committing
```bash
npm test              # Unit tests
npm run test:smoke    # Smoke tests
npm run test:e2e      # E2E tests
```

### 2. Keep Tests Updated with Code
- When feature changes, update tests
- When feature is added, add corresponding tests
- Maintain high code coverage (80%+)

### 3. Monitor Test Failures
- Check Jenkins build failures immediately
- Fix test failures before moving on
- Don't disable/skip failing tests (unless temporary)

### 4. Use Test Results for Debugging
```bash
# If E2E test fails, check:
# 1. Screenshot of failure
# 2. Video of test execution
# 3. Browser console errors
# 4. Application logs

kubectl logs -n bug-report-portal \
  deployment/bug-report-portal-app -f
```

### 5. Optimize Test Speed
- Unit tests should run < 5 seconds
- E2E tests should run < 30 seconds
- Parallel test execution for faster feedback

---

## Testing Troubleshooting

### Issue: Unit Tests Fail Locally But Pass in Jenkins
```bash
# Check Node version
node --version
npm --version

# Clear npm cache
npm cache clean --force
npm install

# Run with verbose output
npm test -- --verbose
```

### Issue: E2E Tests Timeout
```bash
# Increase timeout
npm run test:e2e -- --timeout=60000

# Check if application is responding
curl -k http://localhost:8888/health
```

### Issue: SonarQube Analysis Fails
```bash
# Check SonarQube is running
docker compose ps | grep sonarqube

# Check SonarQube logs
docker compose logs sonarqube

# Verify token is valid
# Go to: http://localhost:9000/account/security
```

### Issue: Smoke Tests Fail After Deploy
```bash
# Check if application is ready
kubectl get pods -n bug-report-portal

# Check application logs
kubectl logs -n bug-report-portal deployment/bug-report-portal-app

# Wait longer before smoke tests
# Increase delay in Jenkinsfile Deploy stage
```

---

## Summary of All Testing Layers

| Layer | Type | Technology | Scope | Time | When |
|-------|------|-----------|-------|------|------|
| **Unit** | Functional | Jest | Individual functions | <5s | Always |
| **Coverage** | Metrics | Jest coverage | % of code tested | <5s | Stage 5 |
| **Code Quality** | Static Analysis | SonarQube | Security, complexity | ~30s | Stage 6 (optional) |
| **Quality Gate** | Policy | SonarQube Gate | Quality standards | ~5s | Stage 7 |
| **Smoke** | Functional | curl/HTTP | Basic endpoints | ~10s | Stage 13 (optional) |
| **E2E** | Behavioral | Playwright | User workflows | ~30s | Stage 14 (optional) |

---

## Reference

- **Test Configuration:** `jest.config.js`, `playwright.config.js`, `sonar-project.properties`
- **E2E Deployment:** [E2E_DEPLOYMENT.md](E2E_DEPLOYMENT.md)
- **Error Fixes:** [ERROR_FIXES.md](ERROR_FIXES.md)
- **Quick Reference:** [QUICK_REFERENCE.md](QUICK_REFERENCE.md)
