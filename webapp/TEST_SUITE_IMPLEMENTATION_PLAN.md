# Akeneo PIM - Comprehensive Test Suite Implementation Plan

**Date:** 2026-05-10  
**Version:** 1.0  
**Status:** READY FOR IMPLEMENTATION (pending manual verification)

---

## Table of Contents

1. [Overview](#overview)
2. [Test Categories](#test-categories)
3. [Automated Tests](#automated-tests)
4. [Manual Test Checklists](#manual-test-checklists)
5. [Test Rotation Schedule](#test-rotation-schedule)
6. [Test Data Requirements](#test-data-requirements)
7. [Implementation Steps](#implementation-steps)

---

## Overview

### Purpose
Establish comprehensive testing framework to ensure Akeneo PIM remains operational and catches regressions early.

### Test Philosophy
- **Fast Feedback:** Quick smoke tests run frequently
- **Comprehensive Coverage:** Full test suite runs weekly
- **Realistic Scenarios:** Tests mirror actual user workflows
- **Automated Where Possible:** Reduce manual testing burden
- **Clear Documentation:** All tests have clear pass/fail criteria

### Test Environment
- **URL:** https://pim.technostationery.com
- **Test User:** mounir / 2026
- **Test Browser:** Chromium (Playwright)
- **Test Framework:** Playwright + Node.js
- **Manual Testing:** Chrome/Firefox

---

## Test Categories

### 1. Smoke Tests (Daily - 5 minutes)
**Purpose:** Verify system is operational  
**Frequency:** Daily or after deployments  
**Duration:** ~5 minutes

**Tests:**
- Login page loads (HTTP 200)
- Login succeeds with valid credentials
- Dashboard loads after login
- Navigation menu visible
- No critical JavaScript errors

### 2. Functional Tests (Weekly - 30 minutes)
**Purpose:** Verify core functionality works  
**Frequency:** Weekly  
**Duration:** ~30 minutes

**Tests:**
- Product CRUD operations
- Family management
- Attribute creation
- Category navigation
- User management
- Import/export basics

### 3. Integration Tests (Weekly - 45 minutes)
**Purpose:** Verify components work together  
**Frequency:** Weekly  
**Duration:** ~45 minutes

**Tests:**
- Product with multiple attributes
- Product association workflows
- Media handling (images, documents)
- Locale switching
- Channel management
- Asset management

### 4. Performance Tests (Monthly - 60 minutes)
**Purpose:** Ensure system performs adequately  
**Frequency:** Monthly  
**Duration:** ~60 minutes

**Tests:**
- Page load times < 3 seconds
- Dashboard renders < 2 seconds
- Product list loads < 3 seconds
- Search responds < 1 second
- API endpoints < 500ms

### 5. Regression Tests (Before Major Changes)
**Purpose:** Ensure no existing functionality broken  
**Frequency:** Before major updates  
**Duration:** ~2 hours

**Tests:**
- Full smoke test suite
- Full functional test suite
- Edge case scenarios
- Error handling verification

---

## Automated Tests

### Test 1: Daily Smoke Test Suite

**File:** `webapp/tests/smoke_test_daily.js`

```javascript
/**
 * Daily Smoke Test Suite
 * Verifies basic system functionality
 * Runtime: ~5 minutes
 */

const playwright = require('playwright');

async function runSmokeTests() {
    const tests = [
        testLoginPageLoads,
        testLoginSuccess,
        testDashboardVisible,
        testNavigationMenu,
        testNoJSErrors
    ];
    
    const results = [];
    
    for (const test of tests) {
        const result = await test();
        results.push(result);
        console.log(`${result.passed ? '✅' : '❌'} ${result.name}`);
    }
    
    const allPassed = results.every(r => r.passed);
    return { allPassed, results };
}

async function testLoginPageLoads() {
    const browser = await playwright.chromium.launch({ headless: true });
    const page = await browser.newPage({ ignoreHTTPSErrors: true });
    
    try {
        const response = await page.goto('https://pim.technostationery.com/user/login');
        const passed = response.status() === 200;
        await browser.close();
        return { name: 'Login Page Loads', passed };
    } catch (error) {
        await browser.close();
        return { name: 'Login Page Loads', passed: false, error: error.message };
    }
}

// Additional test functions...
```

### Test 2: Functional Test Suite

**File:** `webapp/tests/functional_test_suite.js`

**Test Scenarios:**

1. **Product Creation Test**
   - Navigate to Products
   - Click "Create Product"
   - Fill required fields
   - Save product
   - Verify success message
   - Verify product appears in list

2. **Product Edit Test**
   - Search for product
   - Open product detail
   - Modify fields
   - Save changes
   - Verify changes persisted

3. **Family Management Test**
   - Navigate to Settings > Families
   - Create new family
   - Add attributes to family
   - Save family
   - Verify family in list

4. **Attribute Creation Test**
   - Navigate to Settings > Attributes
   - Create new attribute
   - Configure attribute properties
   - Save attribute
   - Verify attribute available

### Test 3: API Endpoint Tests

**File:** `webapp/tests/api_endpoint_tests.js`

**Endpoints to Test:**

```javascript
const API_TESTS = [
    {
        name: 'Get Products',
        method: 'GET',
        endpoint: '/api/rest/v1/products',
        expectedStatus: 200,
        requiresAuth: true
    },
    {
        name: 'Get Families',
        method: 'GET',
        endpoint: '/api/rest/v1/families',
        expectedStatus: 200,
        requiresAuth: true
    },
    {
        name: 'Get Attributes',
        method: 'GET',
        endpoint: '/api/rest/v1/attributes',
        expectedStatus: 200,
        requiresAuth: true
    },
    {
        name: 'Get Categories',
        method: 'GET',
        endpoint: '/api/rest/v1/categories',
        expectedStatus: 200,
        requiresAuth: true
    }
];
```

### Test 4: Performance Test Suite

**File:** `webapp/tests/performance_tests.js`

**Metrics to Measure:**

```javascript
const PERFORMANCE_THRESHOLDS = {
    loginPage: { max: 3000, unit: 'ms' },
    dashboard: { max: 2000, unit: 'ms' },
    productList: { max: 3000, unit: 'ms' },
    productDetail: { max: 2000, unit: 'ms' },
    search: { max: 1000, unit: 'ms' },
    apiEndpoint: { max: 500, unit: 'ms' }
};

async function measurePageLoad(url) {
    const start = Date.now();
    await page.goto(url, { waitUntil: 'networkidle' });
    const duration = Date.now() - start;
    return duration;
}
```

---

## Manual Test Checklists

### Manual Test 1: Login & Authentication

**Frequency:** Weekly  
**Duration:** 5 minutes

**Checklist:**

- [ ] Navigate to login page
- [ ] Verify login form displays correctly
- [ ] Enter valid credentials
- [ ] Click "Log in" button
- [ ] Verify redirect to dashboard
- [ ] Verify user menu shows correct username
- [ ] Test logout functionality
- [ ] Verify redirect back to login page
- [ ] Test invalid credentials (should show error)
- [ ] Test empty form submission (should show validation)

**Pass Criteria:** All items checked without errors

---

### Manual Test 2: Dashboard Verification

**Frequency:** Weekly  
**Duration:** 5 minutes

**Checklist:**

- [ ] Dashboard loads within 3 seconds
- [ ] Akeneo logo visible in header
- [ ] Navigation menu visible on left
- [ ] Dashboard widgets display correctly
- [ ] No JavaScript errors in console (F12)
- [ ] No CSS styling issues
- [ ] Activity feed shows recent actions
- [ ] Quick links are clickable
- [ ] User menu accessible
- [ ] System menu accessible

**Pass Criteria:** All items checked, zero console errors

---

### Manual Test 3: Product Management

**Frequency:** Weekly  
**Duration:** 15 minutes

**Checklist:**

**Create Product:**
- [ ] Navigate to Products menu
- [ ] Click "Create Product" button
- [ ] Product creation form appears
- [ ] Select family dropdown works
- [ ] Fill SKU field
- [ ] Fill other required fields
- [ ] Click "Save" button
- [ ] Success message appears
- [ ] Product appears in product list

**Edit Product:**
- [ ] Search for created product
- [ ] Click product to open detail
- [ ] Product detail page loads
- [ ] Edit product name
- [ ] Add product description
- [ ] Upload product image (if applicable)
- [ ] Click "Save" button
- [ ] Success message appears
- [ ] Changes reflected in UI

**Delete Product:**
- [ ] Open product detail
- [ ] Click delete button
- [ ] Confirm deletion dialog appears
- [ ] Confirm deletion
- [ ] Success message appears
- [ ] Product removed from list

**Pass Criteria:** All operations complete without errors

---

### Manual Test 4: Navigation & UI

**Frequency:** Weekly  
**Duration:** 10 minutes

**Checklist:**

**Menu Navigation:**
- [ ] Products menu expands/collapses
- [ ] Settings menu accessible
- [ ] System menu accessible
- [ ] Activity menu accessible
- [ ] Imports menu works
- [ ] Exports menu works

**Page Loading:**
- [ ] All pages load without errors
- [ ] Breadcrumb navigation works
- [ ] Back button works correctly
- [ ] Search functionality works
- [ ] Filters apply correctly

**UI Elements:**
- [ ] Buttons are clickable
- [ ] Dropdowns function properly
- [ ] Modals open and close
- [ ] Forms validate correctly
- [ ] Error messages display properly
- [ ] Success messages display properly

**Pass Criteria:** All navigation smooth, no broken links

---

### Manual Test 5: Import/Export

**Frequency:** Bi-weekly  
**Duration:** 20 minutes

**Checklist:**

**Export Test:**
- [ ] Navigate to Exports
- [ ] Create new export profile
- [ ] Configure export settings
- [ ] Run export
- [ ] Export completes successfully
- [ ] Download exported file
- [ ] Verify file contents correct

**Import Test:**
- [ ] Navigate to Imports
- [ ] Create new import profile
- [ ] Configure import settings
- [ ] Upload test CSV file
- [ ] Run import
- [ ] Import completes successfully
- [ ] Verify imported data in system

**Pass Criteria:** Both import and export work without errors

---

## Test Rotation Schedule

### Daily (Automated)
```
09:00 AM - Smoke Test Suite
- Login test
- Dashboard load test
- Basic navigation test
- JS error check
```

### Weekly (Mixed)
```
Monday 10:00 AM:
- Automated: Full smoke test suite
- Automated: API endpoint tests
- Manual: Dashboard verification checklist

Wednesday 10:00 AM:
- Manual: Product management checklist
- Manual: Navigation & UI checklist

Friday 10:00 AM:
- Automated: Functional test suite
- Manual: Login & authentication checklist
```

### Bi-Weekly
```
Every Other Monday 2:00 PM:
- Manual: Import/Export checklist
- Manual: User management checklist
```

### Monthly
```
First Monday of Month 2:00 PM:
- Automated: Performance test suite
- Manual: Full regression checklist
- Review test failures from past month
- Update test suite as needed
```

---

## Test Data Requirements

### Test Users
```
Username: mounir
Password: 2026
Role: Administrator
Purpose: Primary test account
```

### Test Products
```
SKU Prefix: TEST_
Naming Convention: TEST_PRODUCT_001, TEST_PRODUCT_002, etc.
Purpose: Safe to delete/modify
```

### Test Families
```
Name Prefix: TEST_FAMILY_
Purpose: Test family creation/management
```

### Test Attributes
```
Code Prefix: test_attr_
Purpose: Test attribute operations
```

### Test Categories
```
Code Prefix: test_cat_
Purpose: Test category management
```

---

## Implementation Steps

### Phase 1: Setup (Day 1)

**Step 1.1: Install Test Dependencies**
```bash
cd /home/pim/public_html/webapp
npm install playwright --save-dev
npm install @playwright/test --save-dev
npm install chai --save-dev
```

**Step 1.2: Create Test Directory Structure**
```bash
mkdir -p tests/{smoke,functional,integration,performance,manual}
mkdir -p tests/reports
mkdir -p tests/screenshots
```

**Step 1.3: Create Base Test Configuration**
```javascript
// tests/config.js
module.exports = {
    baseUrl: 'https://pim.technostationery.com',
    credentials: {
        username: 'mounir',
        password: '2026'
    },
    timeout: 30000,
    headless: true,
    screenshotOnFailure: true
};
```

### Phase 2: Implement Smoke Tests (Day 1-2)

**Step 2.1: Create Smoke Test Suite**
- Write `tests/smoke/daily_smoke.js`
- Implement 5 core smoke tests
- Add screenshot capture on failure
- Add JSON report generation

**Step 2.2: Test Smoke Suite**
```bash
node tests/smoke/daily_smoke.js
```

**Step 2.3: Setup Daily Automation**
```bash
# Add to crontab
0 9 * * * cd /home/pim/public_html/webapp && node tests/smoke/daily_smoke.js >> tests/reports/smoke_$(date +\%Y\%m\%d).log 2>&1
```

### Phase 3: Implement Functional Tests (Day 2-3)

**Step 3.1: Create Functional Test Suite**
- Write product CRUD tests
- Write family management tests
- Write attribute tests
- Write navigation tests

**Step 3.2: Test Functional Suite**
```bash
node tests/functional/functional_suite.js
```

### Phase 4: Create Manual Checklists (Day 3)

**Step 4.1: Document Manual Procedures**
- Create checklist templates
- Add screenshots for clarity
- Define pass/fail criteria
- Assign responsibilities

**Step 4.2: Train Users**
- Walkthrough manual test procedures
- Demonstrate how to report issues
- Establish communication channels

### Phase 5: Setup Test Reporting (Day 4)

**Step 5.1: Create Report Dashboard**
```bash
# Create simple HTML dashboard
webapp/tests/reports/index.html
```

**Step 5.2: Implement Email Notifications**
- Send daily smoke test results
- Alert on test failures
- Weekly summary reports

### Phase 6: Monitor & Iterate (Ongoing)

**Step 6.1: Review Test Results**
- Weekly review of all test failures
- Identify patterns
- Update tests for new features

**Step 6.2: Maintain Test Suite**
- Add tests for new features
- Remove obsolete tests
- Keep test data clean

---

## Test Execution Commands

### Run All Automated Tests
```bash
cd /home/pim/public_html/webapp
npm run test:all
```

### Run Smoke Tests Only
```bash
npm run test:smoke
```

### Run Functional Tests Only
```bash
npm run test:functional
```

### Run Performance Tests
```bash
npm run test:performance
```

### Generate Test Report
```bash
npm run test:report
```

---

## Success Metrics

### Target Test Coverage
- **Smoke Tests:** 100% of critical paths
- **Functional Tests:** 80% of core features
- **Integration Tests:** 70% of workflows
- **Performance Tests:** All key pages/endpoints

### Target Pass Rates
- **Daily Smoke:** 100% pass rate
- **Weekly Functional:** 95%+ pass rate
- **Monthly Performance:** 90%+ within thresholds

### Response Times
- **Test Failure Detection:** < 24 hours
- **Issue Resolution:** < 7 days for critical, < 30 days for non-critical

---

## Appendix A: Test Script Templates

### Template 1: Basic Page Test
```javascript
async function testPageLoads(url, expectedTitle) {
    const browser = await playwright.chromium.launch();
    const page = await browser.newPage({ ignoreHTTPSErrors: true });
    
    try {
        const response = await page.goto(url);
        const title = await page.title();
        const passed = response.status() === 200 && title.includes(expectedTitle);
        
        await browser.close();
        return { passed, status: response.status(), title };
    } catch (error) {
        await browser.close();
        return { passed: false, error: error.message };
    }
}
```

### Template 2: Authenticated Test
```javascript
async function testWithAuth(testFunction) {
    const browser = await playwright.chromium.launch();
    const context = await browser.newContext({ ignoreHTTPSErrors: true });
    const page = await context.newPage();
    
    // Login first
    await page.goto('https://pim.technostationery.com/user/login');
    await page.fill('input[name="_username"]', 'mounir');
    await page.fill('input[name="_password"]', '2026');
    await page.click('button[type="submit"]');
    await page.waitForNavigation();
    
    // Run test
    const result = await testFunction(page);
    
    await browser.close();
    return result;
}
```

---

## Document Control

**Version History:**
- v1.0 (2026-05-10): Initial test suite plan created

**Next Review:** After manual testing confirms fixes work

**Owner:** Development Team

**Status:** READY FOR IMPLEMENTATION
