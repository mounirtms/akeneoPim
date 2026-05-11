#!/usr/bin/env node
/**
 * Daily Smoke Test Suite for Akeneo PIM
 * 
 * Purpose: Verify critical system functionality daily
 * Runtime: ~3-5 minutes
 * Exit Codes: 0 = all pass, 1 = some failures
 * 
 * Usage:
 *   node tests/smoke/daily_smoke_test.js
 *   node tests/smoke/daily_smoke_test.js --verbose
 *   node tests/smoke/daily_smoke_test.js --screenshot-on-pass
 */

const playwright = require('playwright');
const fs = require('fs');
const path = require('path');

// Configuration
const CONFIG = {
    baseUrl: 'https://pim.technostationery.com',
    username: 'mounir',
    password: '2026',
    timeout: 30000,
    screenshotDir: path.join(__dirname, '../screenshots'),
    reportDir: path.join(__dirname, '../reports'),
    verbose: process.argv.includes('--verbose'),
    screenshotOnPass: process.argv.includes('--screenshot-on-pass')
};

// Ensure directories exist
[CONFIG.screenshotDir, CONFIG.reportDir].forEach(dir => {
    if (!fs.existsSync(dir)) {
        fs.mkdirSync(dir, { recursive: true });
    }
});

// Test results container
const testResults = {
    timestamp: new Date().toISOString(),
    duration: 0,
    passed: 0,
    failed: 0,
    tests: []
};

// Logging helper
function log(message, level = 'info') {
    const prefix = {
        info: 'ℹ',
        success: '✅',
        error: '❌',
        warn: '⚠️'
    }[level] || 'ℹ';
    
    console.log(`${prefix} ${message}`);
}

// Screenshot helper
async function takeScreenshot(page, name, force = false) {
    if (CONFIG.screenshotOnPass || force) {
        const filename = `${Date.now()}_${name.replace(/\s+/g, '_')}.png`;
        const filepath = path.join(CONFIG.screenshotDir, filename);
        await page.screenshot({ path: filepath, fullPage: true });
        return filename;
    }
    return null;
}

// Test wrapper
async function runTest(name, testFn) {
    const startTime = Date.now();
    log(`Running: ${name}`, 'info');
    
    try {
        const result = await testFn();
        const duration = Date.now() - startTime;
        
        const testResult = {
            name,
            passed: result.passed,
            duration,
            details: result.details || {},
            error: result.error || null,
            screenshot: result.screenshot || null
        };
        
        testResults.tests.push(testResult);
        
        if (result.passed) {
            testResults.passed++;
            log(`✓ ${name} (${duration}ms)`, 'success');
        } else {
            testResults.failed++;
            log(`✗ ${name} (${duration}ms)`, 'error');
            if (result.error && CONFIG.verbose) {
                console.log(`  Error: ${result.error}`);
            }
        }
        
        return testResult;
    } catch (error) {
        const duration = Date.now() - startTime;
        testResults.failed++;
        
        const testResult = {
            name,
            passed: false,
            duration,
            error: error.message,
            screenshot: null
        };
        
        testResults.tests.push(testResult);
        log(`✗ ${name} - Exception: ${error.message}`, 'error');
        
        return testResult;
    }
}

// TEST 1: Login Page Loads
async function testLoginPageLoads() {
    const browser = await playwright.chromium.launch({ 
        headless: true,
        args: ['--no-sandbox', '--disable-setuid-sandbox']
    });
    const page = await browser.newPage({ ignoreHTTPSErrors: true });
    
    try {
        const response = await page.goto(`${CONFIG.baseUrl}/user/login`, {
            waitUntil: 'networkidle',
            timeout: CONFIG.timeout
        });
        
        const status = response.status();
        const url = page.url();
        const title = await page.title();
        
        const screenshot = await takeScreenshot(page, 'login_page');
        
        await browser.close();
        
        return {
            passed: status === 200 && url.includes('/user/login'),
            details: { status, url, title },
            screenshot
        };
    } catch (error) {
        await browser.close();
        return { passed: false, error: error.message };
    }
}

// TEST 2: Login Form Elements Present
async function testLoginFormPresent() {
    const browser = await playwright.chromium.launch({ 
        headless: true,
        args: ['--no-sandbox', '--disable-setuid-sandbox']
    });
    const page = await browser.newPage({ ignoreHTTPSErrors: true });
    
    try {
        await page.goto(`${CONFIG.baseUrl}/user/login`, {
            waitUntil: 'networkidle',
            timeout: CONFIG.timeout
        });
        
        const usernameExists = await page.$('input[name="_username"]') !== null;
        const passwordExists = await page.$('input[name="_password"]') !== null;
        const submitExists = await page.$('button[type="submit"]') !== null;
        
        const screenshot = await takeScreenshot(page, 'login_form');
        
        await browser.close();
        
        return {
            passed: usernameExists && passwordExists && submitExists,
            details: { usernameExists, passwordExists, submitExists },
            screenshot
        };
    } catch (error) {
        await browser.close();
        return { passed: false, error: error.message };
    }
}

// TEST 3: CSS Loads Without Errors
async function testCSSLoads() {
    const browser = await playwright.chromium.launch({ 
        headless: true,
        args: ['--no-sandbox', '--disable-setuid-sandbox']
    });
    const page = await browser.newPage({ ignoreHTTPSErrors: true });
    
    const cssErrors = [];
    page.on('response', response => {
        const url = response.url();
        if (url.includes('.css') && response.status() !== 200) {
            cssErrors.push({ url, status: response.status() });
        }
    });
    
    try {
        await page.goto(`${CONFIG.baseUrl}/user/login`, {
            waitUntil: 'networkidle',
            timeout: CONFIG.timeout
        });
        
        await page.waitForTimeout(2000);
        
        const screenshot = await takeScreenshot(page, 'css_load_test');
        
        await browser.close();
        
        return {
            passed: cssErrors.length === 0,
            details: { cssErrors: cssErrors.length, errors: cssErrors },
            screenshot
        };
    } catch (error) {
        await browser.close();
        return { passed: false, error: error.message };
    }
}

// TEST 4: No Critical JavaScript Errors
async function testNoJSErrors() {
    const browser = await playwright.chromium.launch({ 
        headless: true,
        args: ['--no-sandbox', '--disable-setuid-sandbox']
    });
    const page = await browser.newPage({ ignoreHTTPSErrors: true });
    
    const jsErrors = [];
    page.on('pageerror', error => {
        jsErrors.push(error.toString());
    });
    
    const consoleErrors = [];
    page.on('console', msg => {
        if (msg.type() === 'error') {
            consoleErrors.push(msg.text());
        }
    });
    
    try {
        await page.goto(`${CONFIG.baseUrl}/user/login`, {
            waitUntil: 'networkidle',
            timeout: CONFIG.timeout
        });
        
        await page.waitForTimeout(3000);
        
        const screenshot = await takeScreenshot(page, 'js_error_test');
        
        await browser.close();
        
        // Filter out non-critical errors (analytics, CDN, etc.)
        const criticalErrors = jsErrors.filter(err => 
            !err.includes('analytics') && 
            !err.includes('cdn-cgi') &&
            !err.includes('465q/ag/g')
        );
        
        return {
            passed: criticalErrors.length === 0,
            details: { 
                criticalErrors: criticalErrors.length,
                totalJSErrors: jsErrors.length,
                totalConsoleErrors: consoleErrors.length,
                errors: criticalErrors.slice(0, 5)
            },
            screenshot
        };
    } catch (error) {
        await browser.close();
        return { passed: false, error: error.message };
    }
}

// TEST 5: Webpack Bundles Accessible
async function testWebpackBundles() {
    const browser = await playwright.chromium.launch({ 
        headless: true,
        args: ['--no-sandbox', '--disable-setuid-sandbox']
    });
    const page = await browser.newPage({ ignoreHTTPSErrors: true });
    
    const bundleErrors = [];
    page.on('response', response => {
        const url = response.url();
        if ((url.includes('main.min.js') || url.includes('vendor.min.js')) && 
            response.status() !== 200) {
            bundleErrors.push({ url, status: response.status() });
        }
    });
    
    try {
        await page.goto(`${CONFIG.baseUrl}/user/login`, {
            waitUntil: 'networkidle',
            timeout: CONFIG.timeout
        });
        
        await page.waitForTimeout(2000);
        
        const screenshot = await takeScreenshot(page, 'webpack_bundles');
        
        await browser.close();
        
        return {
            passed: bundleErrors.length === 0,
            details: { bundleErrors },
            screenshot
        };
    } catch (error) {
        await browser.close();
        return { passed: false, error: error.message };
    }
}

// TEST 6: Fixed Modules Load (oro, legacy-bridge)
async function testFixedModules() {
    const browser = await playwright.chromium.launch({ 
        headless: true,
        args: ['--no-sandbox', '--disable-setuid-sandbox']
    });
    const page = await browser.newPage({ ignoreHTTPSErrors: true });
    
    const moduleErrors = [];
    page.on('response', response => {
        const url = response.url();
        if ((url.includes('loading-mask.js') || url.includes('legacy-bridge.js')) && 
            response.status() === 404) {
            moduleErrors.push({ url, status: response.status() });
        }
    });
    
    try {
        await page.goto(`${CONFIG.baseUrl}/user/login`, {
            waitUntil: 'networkidle',
            timeout: CONFIG.timeout
        });
        
        await page.waitForTimeout(3000);
        
        const screenshot = await takeScreenshot(page, 'fixed_modules');
        
        await browser.close();
        
        return {
            passed: moduleErrors.length === 0,
            details: { moduleErrors },
            screenshot
        };
    } catch (error) {
        await browser.close();
        return { passed: false, error: error.message };
    }
}

// TEST 7: Page Load Performance
async function testPageLoadPerformance() {
    const browser = await playwright.chromium.launch({ 
        headless: true,
        args: ['--no-sandbox', '--disable-setuid-sandbox']
    });
    const page = await browser.newPage({ ignoreHTTPSErrors: true });
    
    try {
        const startTime = Date.now();
        await page.goto(`${CONFIG.baseUrl}/user/login`, {
            waitUntil: 'networkidle',
            timeout: CONFIG.timeout
        });
        const loadTime = Date.now() - startTime;
        
        const screenshot = await takeScreenshot(page, 'performance_test');
        
        await browser.close();
        
        const threshold = 5000; // 5 seconds max
        
        return {
            passed: loadTime < threshold,
            details: { loadTime, threshold, unit: 'ms' },
            screenshot
        };
    } catch (error) {
        await browser.close();
        return { passed: false, error: error.message };
    }
}

// Main test execution
async function runAllTests() {
    const startTime = Date.now();
    
    console.log('\n' + '='.repeat(80));
    console.log('AKENEO PIM - DAILY SMOKE TEST SUITE');
    console.log('='.repeat(80));
    console.log(`Date: ${new Date().toLocaleString()}`);
    console.log(`Target: ${CONFIG.baseUrl}`);
    console.log('='.repeat(80) + '\n');
    
    // Run all tests
    await runTest('Test 1: Login Page Loads', testLoginPageLoads);
    await runTest('Test 2: Login Form Elements Present', testLoginFormPresent);
    await runTest('Test 3: CSS Loads Without Errors', testCSSLoads);
    await runTest('Test 4: No Critical JavaScript Errors', testNoJSErrors);
    await runTest('Test 5: Webpack Bundles Accessible', testWebpackBundles);
    await runTest('Test 6: Fixed Modules Load', testFixedModules);
    await runTest('Test 7: Page Load Performance', testPageLoadPerformance);
    
    testResults.duration = Date.now() - startTime;
    
    // Summary
    console.log('\n' + '='.repeat(80));
    console.log('TEST SUMMARY');
    console.log('='.repeat(80));
    console.log(`Total Tests: ${testResults.tests.length}`);
    console.log(`Passed: ${testResults.passed} ✅`);
    console.log(`Failed: ${testResults.failed} ❌`);
    console.log(`Duration: ${testResults.duration}ms`);
    console.log('='.repeat(80));
    
    if (testResults.failed > 0) {
        console.log('\nFailed Tests:');
        testResults.tests.filter(t => !t.passed).forEach(test => {
            console.log(`  ❌ ${test.name}`);
            if (test.error && CONFIG.verbose) {
                console.log(`     Error: ${test.error}`);
            }
        });
    }
    
    // Save report
    const reportPath = path.join(
        CONFIG.reportDir, 
        `smoke_test_${Date.now()}.json`
    );
    fs.writeFileSync(reportPath, JSON.stringify(testResults, null, 2));
    console.log(`\nDetailed report: ${reportPath}`);
    
    // Exit with appropriate code
    const allPassed = testResults.failed === 0;
    console.log(`\n${allPassed ? '✅ ALL TESTS PASSED' : '❌ SOME TESTS FAILED'}\n`);
    
    process.exit(allPassed ? 0 : 1);
}

// Run tests
runAllTests().catch(error => {
    console.error('Fatal error running tests:', error);
    process.exit(1);
});
