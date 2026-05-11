/**
 * Phase 7: Integration Testing
 * Comprehensive test to verify all fixes are working
 * 
 * Tests:
 * 1. Login functionality
 * 2. Dashboard loading
 * 3. PIM UI/Menu visibility
 * 4. JavaScript errors check
 * 5. CSS styling verification
 * 6. Module loading (404 checks)
 */

const playwright = require('playwright');
const fs = require('fs');

const CONFIG = {
    url: 'https://pim.technostationery.com',
    username: 'mounir',
    password: '2026',
    timeout: 30000,
    screenshotDir: './webapp'
};

async function runIntegrationTest() {
    console.log('='.repeat(80));
    console.log('PHASE 7: INTEGRATION TESTING');
    console.log('='.repeat(80));
    console.log(`\nTimestamp: ${new Date().toISOString()}`);
    console.log(`Target: ${CONFIG.url}\n`);

    const browser = await playwright.chromium.launch({ 
        headless: true,
        args: ['--no-sandbox', '--disable-setuid-sandbox']
    });
    
    const context = await browser.newContext({
        ignoreHTTPSErrors: true,
        viewport: { width: 1920, height: 1080 }
    });
    
    const page = await context.newPage();
    
    // Collect console messages and errors
    const consoleMessages = [];
    const jsErrors = [];
    const networkErrors = [];
    
    page.on('console', msg => {
        const type = msg.type();
        const text = msg.text();
        consoleMessages.push({ type, text, timestamp: new Date().toISOString() });
        
        if (type === 'error') {
            console.log(`[CONSOLE ERROR] ${text}`);
        }
    });
    
    page.on('pageerror', error => {
        const errorMsg = error.toString();
        jsErrors.push({ error: errorMsg, timestamp: new Date().toISOString() });
        console.log(`[JS ERROR] ${errorMsg}`);
    });
    
    page.on('requestfailed', request => {
        const url = request.url();
        const failure = request.failure();
        if (url.includes(CONFIG.url)) {
            networkErrors.push({ 
                url, 
                failure: failure ? failure.errorText : 'unknown',
                timestamp: new Date().toISOString() 
            });
            console.log(`[NETWORK ERROR] ${url} - ${failure ? failure.errorText : 'unknown'}`);
        }
    });
    
    let testResults = {
        timestamp: new Date().toISOString(),
        tests: {},
        consoleErrors: [],
        jsErrors: [],
        networkErrors: [],
        screenshots: {}
    };
    
    try {
        // TEST 1: Load login page
        console.log('\n[TEST 1] Loading login page...');
        const loginResponse = await page.goto(`${CONFIG.url}/user/login`, { 
            waitUntil: 'networkidle',
            timeout: CONFIG.timeout 
        });
        
        testResults.tests.loginPageLoad = {
            passed: loginResponse.status() === 200,
            status: loginResponse.status(),
            url: page.url()
        };
        
        console.log(`  ✓ Status: ${loginResponse.status()}`);
        console.log(`  ✓ URL: ${page.url()}`);
        
        await page.screenshot({ 
            path: `${CONFIG.screenshotDir}/test_1_login_page.png`,
            fullPage: true 
        });
        testResults.screenshots.loginPage = 'test_1_login_page.png';
        
        // TEST 2: Login form submission
        console.log('\n[TEST 2] Submitting login form...');
        
        await page.waitForSelector('input[name="_username"]', { timeout: 5000 });
        await page.fill('input[name="_username"]', CONFIG.username);
        await page.fill('input[name="_password"]', CONFIG.password);
        
        console.log('  ✓ Credentials filled');
        
        // Wait a bit for any dynamic content to load
        await page.waitForTimeout(1000);
        
        // Click submit and wait for navigation
        await Promise.all([
            page.waitForNavigation({ waitUntil: 'networkidle', timeout: CONFIG.timeout }),
            page.click('button[type="submit"]')
        ]);
        
        const afterLoginUrl = page.url();
        testResults.tests.loginSubmit = {
            passed: !afterLoginUrl.includes('/user/login'),
            url: afterLoginUrl,
            redirected: afterLoginUrl !== `${CONFIG.url}/user/login`
        };
        
        console.log(`  ✓ After login URL: ${afterLoginUrl}`);
        
        await page.screenshot({ 
            path: `${CONFIG.screenshotDir}/test_2_after_login.png`,
            fullPage: true 
        });
        testResults.screenshots.afterLogin = 'test_2_after_login.png';
        
        // Wait for dashboard to load
        await page.waitForTimeout(3000);
        
        // TEST 3: Dashboard elements presence
        console.log('\n[TEST 3] Checking dashboard elements...');
        
        const containerExists = await page.$('#container') !== null;
        const headerExists = await page.$('.AknHeader') !== null;
        const menuExists = await page.$('[data-testid="pim-menu"]') !== null;
        const mainContentExists = await page.$('.AknDefault-mainContent') !== null;
        
        testResults.tests.dashboardElements = {
            passed: containerExists && headerExists,
            container: containerExists,
            header: headerExists,
            menu: menuExists,
            mainContent: mainContentExists
        };
        
        console.log(`  ${containerExists ? '✓' : '✗'} #container: ${containerExists}`);
        console.log(`  ${headerExists ? '✓' : '✗'} .AknHeader: ${headerExists}`);
        console.log(`  ${menuExists ? '✓' : '✗'} PIM Menu: ${menuExists}`);
        console.log(`  ${mainContentExists ? '✓' : '✗'} Main Content: ${mainContentExists}`);
        
        await page.screenshot({ 
            path: `${CONFIG.screenshotDir}/test_3_dashboard.png`,
            fullPage: true 
        });
        testResults.screenshots.dashboard = 'test_3_dashboard.png';
        
        // TEST 4: Check for specific 404 errors we fixed
        console.log('\n[TEST 4] Checking for 404 errors (fixed modules)...');
        
        const check404s = networkErrors.filter(err => 
            err.url.includes('loading-mask.js') || 
            err.url.includes('legacy-bridge.js')
        );
        
        testResults.tests.fixed404Errors = {
            passed: check404s.length === 0,
            errors: check404s
        };
        
        if (check404s.length === 0) {
            console.log('  ✓ No 404 errors for fixed modules');
        } else {
            console.log(`  ✗ Found ${check404s.length} 404 errors:`);
            check404s.forEach(err => console.log(`    - ${err.url}`));
        }
        
        // TEST 5: Check for form builder errors
        console.log('\n[TEST 5] Checking for form builder errors...');
        
        const formBuilderErrors = jsErrors.filter(err => 
            err.error.includes('replace is not a function')
        );
        
        testResults.tests.formBuilderErrors = {
            passed: formBuilderErrors.length === 0,
            errors: formBuilderErrors
        };
        
        if (formBuilderErrors.length === 0) {
            console.log('  ✓ No form builder errors');
        } else {
            console.log(`  ✗ Found ${formBuilderErrors.length} form builder errors`);
        }
        
        // TEST 6: CSS styling verification
        console.log('\n[TEST 6] Checking CSS styling...');
        
        const bodyStyles = await page.evaluate(() => {
            const body = document.body;
            const styles = window.getComputedStyle(body);
            return {
                fontFamily: styles.fontFamily,
                backgroundColor: styles.backgroundColor,
                hasStyles: styles.fontFamily !== '' && styles.backgroundColor !== ''
            };
        });
        
        testResults.tests.cssStyles = {
            passed: bodyStyles.hasStyles,
            fontFamily: bodyStyles.fontFamily,
            backgroundColor: bodyStyles.backgroundColor
        };
        
        console.log(`  ${bodyStyles.hasStyles ? '✓' : '✗'} Styles applied: ${bodyStyles.hasStyles}`);
        console.log(`    Font: ${bodyStyles.fontFamily}`);
        console.log(`    BG Color: ${bodyStyles.backgroundColor}`);
        
        // TEST 7: Check webpack bundles loaded
        console.log('\n[TEST 7] Checking webpack bundles...');
        
        const webpackLoaded = await page.evaluate(() => {
            const scripts = Array.from(document.querySelectorAll('script[src]'));
            const mainJs = scripts.some(s => s.src.includes('main.min.js'));
            const vendorJs = scripts.some(s => s.src.includes('vendor.min.js'));
            return { mainJs, vendorJs, scripts: scripts.map(s => s.src) };
        });
        
        testResults.tests.webpackBundles = {
            passed: webpackLoaded.mainJs && webpackLoaded.vendorJs,
            mainJs: webpackLoaded.mainJs,
            vendorJs: webpackLoaded.vendorJs
        };
        
        console.log(`  ${webpackLoaded.mainJs ? '✓' : '✗'} main.min.js loaded: ${webpackLoaded.mainJs}`);
        console.log(`  ${webpackLoaded.vendorJs ? '✓' : '✗'} vendor.min.js loaded: ${webpackLoaded.vendorJs}`);
        
        // Wait a bit more to catch any late errors
        await page.waitForTimeout(5000);
        
    } catch (error) {
        console.error(`\n[FATAL ERROR] ${error.message}`);
        testResults.fatalError = error.message;
        
        await page.screenshot({ 
            path: `${CONFIG.screenshotDir}/test_error.png`,
            fullPage: true 
        });
        testResults.screenshots.error = 'test_error.png';
    }
    
    // Collect final error counts
    testResults.consoleErrors = consoleMessages.filter(m => m.type === 'error');
    testResults.jsErrors = jsErrors;
    testResults.networkErrors = networkErrors;
    
    await browser.close();
    
    // Generate summary
    console.log('\n' + '='.repeat(80));
    console.log('TEST SUMMARY');
    console.log('='.repeat(80));
    
    const testNames = Object.keys(testResults.tests);
    const passedTests = testNames.filter(name => testResults.tests[name].passed);
    const failedTests = testNames.filter(name => !testResults.tests[name].passed);
    
    console.log(`\nTotal Tests: ${testNames.length}`);
    console.log(`Passed: ${passedTests.length}`);
    console.log(`Failed: ${failedTests.length}`);
    
    if (failedTests.length > 0) {
        console.log('\nFailed Tests:');
        failedTests.forEach(name => {
            console.log(`  ✗ ${name}`);
        });
    }
    
    console.log(`\nConsole Errors: ${testResults.consoleErrors.length}`);
    console.log(`JavaScript Errors: ${testResults.jsErrors.length}`);
    console.log(`Network Errors: ${testResults.networkErrors.length}`);
    
    if (testResults.networkErrors.length > 0) {
        console.log('\nNetwork Errors:');
        testResults.networkErrors.forEach(err => {
            console.log(`  - ${err.url}`);
        });
    }
    
    // Save detailed report
    const reportPath = `${CONFIG.screenshotDir}/integration_test_report_${Date.now()}.json`;
    fs.writeFileSync(reportPath, JSON.stringify(testResults, null, 2));
    console.log(`\nDetailed report saved: ${reportPath}`);
    
    console.log('\n' + '='.repeat(80));
    
    const overallSuccess = failedTests.length === 0 && 
                          testResults.jsErrors.length === 0 &&
                          !testResults.fatalError;
    
    if (overallSuccess) {
        console.log('OVERALL RESULT: ✓ ALL TESTS PASSED');
    } else {
        console.log('OVERALL RESULT: ✗ SOME TESTS FAILED');
    }
    console.log('='.repeat(80) + '\n');
    
    return overallSuccess;
}

// Run the test
runIntegrationTest()
    .then(success => {
        process.exit(success ? 0 : 1);
    })
    .catch(error => {
        console.error('Test execution failed:', error);
        process.exit(1);
    });
