const { chromium } = require('playwright');
const fs = require('fs');

// Configuration
const BASE_URL = 'https://pim.technostationery.com';
const TEST_USERS = [
    { username: 'mounir', password: '2026', name: 'Mounir' },
    { username: 'admin', password: 'Admin123!', name: 'Admin' }
];

// Comprehensive test results
const testResults = {
    timestamp: new Date().toISOString(),
    baseUrl: BASE_URL,
    testSuites: [],
    consoleLogs: [],
    networkLogs: [],
    errors: [],
    screenshots: [],
    performance: {}
};

// Helper to add log
function addLog(type, message, data = {}) {
    const log = {
        timestamp: new Date().toISOString(),
        type,
        message,
        ...data
    };
    
    if (type === 'console') {
        testResults.consoleLogs.push(log);
    } else if (type === 'network') {
        testResults.networkLogs.push(log);
    } else if (type === 'error') {
        testResults.errors.push(log);
    }
    
    console.log(`[${type.toUpperCase()}] ${message}`);
}

async function captureScreenshot(page, name, description) {
    const filename = `/home/pim/public_html/webapp/screenshot_${name}.png`;
    await page.screenshot({ path: filename, fullPage: true });
    testResults.screenshots.push({ name, filename, description, timestamp: new Date().toISOString() });
    console.log(`📸 Screenshot saved: ${name}`);
}

async function runComprehensiveTests() {
    console.log('🚀 Starting Comprehensive PIM UI Tests');
    console.log('=' .repeat(70));
    console.log(`Base URL: ${BASE_URL}`);
    console.log(`Test Users: ${TEST_USERS.map(u => u.username).join(', ')}`);
    console.log('=' .repeat(70));
    console.log('');
    
    const browser = await chromium.launch({
        headless: true,
        args: ['--no-sandbox', '--disable-setuid-sandbox', '--disable-dev-shm-usage']
    });
    
    const context = await browser.newContext({
        ignoreHTTPSErrors: true,
        viewport: { width: 1920, height: 1080 },
        userAgent: 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36 Playwright-Test'
    });
    
    const page = await context.newPage();
    
    // Set up comprehensive logging
    page.on('console', msg => {
        addLog('console', msg.text(), {
            type: msg.type(),
            location: msg.location()
        });
    });
    
    page.on('response', response => {
        const url = response.url();
        const status = response.status();
        
        addLog('network', `${status} ${url}`, {
            url,
            status,
            statusText: response.statusText(),
            contentType: response.headers()['content-type']
        });
        
        if (status >= 400) {
            addLog('error', `HTTP ${status} Error: ${url}`, { url, status });
        }
    });
    
    page.on('pageerror', error => {
        addLog('error', `Page Error: ${error.message}`, {
            message: error.message,
            stack: error.stack
        });
    });
    
    page.on('requestfailed', request => {
        addLog('error', `Request Failed: ${request.url()}`, {
            url: request.url(),
            failure: request.failure()
        });
    });
    
    try {
        // TEST SUITE 1: Authentication & Login
        console.log('\n📦 TEST SUITE 1: Authentication & Login');
        console.log('-'.repeat(70));
        
        const authSuite = { name: 'Authentication', tests: [] };
        
        for (const user of TEST_USERS) {
            console.log(`\n🔐 Testing login for: ${user.name} (${user.username})`);
            
            const authTest = {
                user: user.username,
                startTime: Date.now(),
                steps: []
            };
            
            // Navigate to login page
            console.log('  → Navigating to login page...');
            await page.goto(`${BASE_URL}/user/login`, { waitUntil: 'networkidle', timeout: 30000 });
            await captureScreenshot(page, `${user.username}_01_login_page`, 'Initial login page');
            
            authTest.steps.push({ step: 'Navigate to login', status: 'PASS', url: page.url() });
            
            // Check form elements
            console.log('  → Checking form elements...');
            const usernameField = await page.$('input[name="_username"], input#username, input[type="text"]');
            const passwordField = await page.$('input[name="_password"], input#password, input[type="password"]');
            const submitButton = await page.$('button[type="submit"], input[type="submit"], button.btn-primary');
            
            if (!usernameField || !passwordField || !submitButton) {
                authTest.steps.push({ step: 'Form elements check', status: 'FAIL', reason: 'Missing form elements' });
                authTest.status = 'FAIL';
                authSuite.tests.push(authTest);
                console.log('  ❌ Form elements not found');
                continue;
            }
            
            authTest.steps.push({ step: 'Form elements check', status: 'PASS' });
            console.log('  ✅ Form elements found');
            
            // Fill credentials
            console.log(`  → Filling credentials: ${user.username} / ${user.password.replace(/./g, '*')}`);
            await usernameField.fill(user.username);
            await passwordField.fill(user.password);
            await page.waitForTimeout(500);
            await captureScreenshot(page, `${user.username}_02_credentials_filled`, 'Credentials filled');
            
            authTest.steps.push({ step: 'Fill credentials', status: 'PASS' });
            
            // Submit login
            console.log('  → Submitting login form...');
            await submitButton.click();
            await page.waitForTimeout(3000);
            
            const currentUrl = page.url();
            const pageTitle = await page.title();
            
            await captureScreenshot(page, `${user.username}_03_after_login`, 'After login submission');
            
            // Check if login succeeded
            const loginSuccess = !currentUrl.includes('/user/login') && !currentUrl.includes('error');
            const hasErrorMessage = await page.$('.alert-danger, .error-message, [role="alert"]');
            
            authTest.endTime = Date.now();
            authTest.duration = authTest.endTime - authTest.startTime;
            authTest.resultUrl = currentUrl;
            authTest.resultTitle = pageTitle;
            authTest.hasError = !!hasErrorMessage;
            
            if (loginSuccess && !hasErrorMessage) {
                authTest.status = 'PASS';
                authTest.steps.push({ step: 'Login submission', status: 'PASS' });
                console.log(`  ✅ Login successful! Redirected to: ${currentUrl}`);
                
                // Store authenticated context for this user
                if (user.username === 'mounir') {
                    await context.storageState({ path: '/home/pim/public_html/webapp/mounir_auth.json' });
                    console.log('  💾 Stored authenticated session for Mounir');
                }
            } else {
                authTest.status = 'FAIL';
                authTest.steps.push({ 
                    step: 'Login submission', 
                    status: 'FAIL',
                    reason: hasErrorMessage ? 'Error message displayed' : 'Still on login page'
                });
                console.log(`  ❌ Login failed! URL: ${currentUrl}`);
                
                // Capture error message if present
                if (hasErrorMessage) {
                    const errorText = await hasErrorMessage.textContent();
                    authTest.errorMessage = errorText;
                    console.log(`  📝 Error message: ${errorText}`);
                }
            }
            
            authSuite.tests.push(authTest);
            
            // Logout if successful
            if (loginSuccess) {
                console.log('  → Logging out...');
                try {
                    await page.goto(`${BASE_URL}/user/logout`, { waitUntil: 'networkidle', timeout: 10000 });
                    await page.waitForTimeout(1000);
                } catch (e) {
                    console.log('  ⚠️ Logout navigation failed (may be OK)');
                }
            }
        }
        
        testResults.testSuites.push(authSuite);
        
        // TEST SUITE 2: Dashboard & Navigation (using Mounir's credentials)
        console.log('\n📦 TEST SUITE 2: Dashboard & Navigation');
        console.log('-'.repeat(70));
        
        const navSuite = { name: 'Dashboard & Navigation', tests: [] };
        
        // Login as Mounir for navigation tests
        console.log('\n🔐 Logging in as Mounir for navigation tests...');
        await page.goto(`${BASE_URL}/user/login`, { waitUntil: 'networkidle' });
        
        const usernameField = await page.$('input[name="_username"], input#username, input[type="text"]');
        const passwordField = await page.$('input[name="_password"], input#password, input[type="password"]');
        const submitButton = await page.$('button[type="submit"], input[type="submit"], button.btn-primary');
        
        if (usernameField && passwordField && submitButton) {
            await usernameField.fill('mounir');
            await passwordField.fill('2026');
            await submitButton.click();
            await page.waitForTimeout(3000);
            
            const loginSuccess = !page.url().includes('/user/login');
            
            if (loginSuccess) {
                console.log('✅ Logged in successfully as Mounir');
                await captureScreenshot(page, 'mounir_04_dashboard', 'Mounir dashboard view');
                
                // Test 2.1: Dashboard load
                const dashTest = {
                    name: 'Dashboard Load',
                    startTime: Date.now(),
                    steps: []
                };
                
                console.log('\n📋 Test 2.1: Dashboard Load');
                console.log('  → Checking dashboard elements...');
                
                // Check for common dashboard elements
                const hasNavigation = await page.$('nav, [role="navigation"], .navigation, .nav-menu');
                const hasHeader = await page.$('header, .header, .page-header');
                const hasMainContent = await page.$('main, .main-content, #content, .content');
                
                dashTest.elements = {
                    navigation: !!hasNavigation,
                    header: !!hasHeader,
                    mainContent: !!hasMainContent
                };
                
                dashTest.status = (hasNavigation || hasHeader || hasMainContent) ? 'PASS' : 'FAIL';
                dashTest.duration = Date.now() - dashTest.startTime;
                dashTest.steps.push({ step: 'Check dashboard elements', status: dashTest.status });
                
                console.log(`  ${dashTest.status === 'PASS' ? '✅' : '❌'} Navigation: ${!!hasNavigation}, Header: ${!!hasHeader}, Content: ${!!hasMainContent}`);
                
                navSuite.tests.push(dashTest);
                
                // Test 2.2: Main menu items
                const menuTest = {
                    name: 'Main Menu Items',
                    startTime: Date.now(),
                    menuItems: []
                };
                
                console.log('\n📋 Test 2.2: Main Menu Items');
                console.log('  → Extracting menu items...');
                
                const menuItems = await page.$$eval('nav a, [role="navigation"] a, .nav-menu a', links => 
                    links.slice(0, 20).map(link => ({
                        text: link.textContent.trim(),
                        href: link.href,
                        visible: link.offsetParent !== null
                    }))
                );
                
                menuTest.menuItems = menuItems;
                menuTest.count = menuItems.length;
                menuTest.status = menuItems.length > 0 ? 'PASS' : 'FAIL';
                menuTest.duration = Date.now() - menuTest.startTime;
                
                console.log(`  ✅ Found ${menuItems.length} menu items:`);
                menuItems.slice(0, 10).forEach(item => {
                    console.log(`     • ${item.text} (${item.visible ? 'visible' : 'hidden'})`);
                });
                
                navSuite.tests.push(menuTest);
                
                // Test 2.3: Navigate to Products section
                console.log('\n📋 Test 2.3: Products Section Navigation');
                
                const productTest = {
                    name: 'Products Section',
                    startTime: Date.now(),
                    steps: []
                };
                
                // Try to find and click products link
                const productLink = await page.$('a[href*="product"], a[href*="enrich"]');
                
                if (productLink) {
                    console.log('  → Clicking Products link...');
                    await productLink.click();
                    await page.waitForTimeout(3000);
                    await captureScreenshot(page, 'mounir_05_products', 'Products section');
                    
                    productTest.steps.push({ step: 'Navigate to products', status: 'PASS' });
                    productTest.status = 'PASS';
                    console.log('  ✅ Products section loaded');
                } else {
                    console.log('  ⚠️ Products link not found');
                    productTest.steps.push({ step: 'Find products link', status: 'FAIL' });
                    productTest.status = 'SKIP';
                }
                
                productTest.duration = Date.now() - productTest.startTime;
                navSuite.tests.push(productTest);
                
            } else {
                console.log('❌ Login failed for Mounir - skipping navigation tests');
                navSuite.tests.push({
                    name: 'Navigation Tests',
                    status: 'SKIP',
                    reason: 'Login failed'
                });
            }
        }
        
        testResults.testSuites.push(navSuite);
        
        // TEST SUITE 3: Performance & Assets
        console.log('\n📦 TEST SUITE 3: Performance & Assets');
        console.log('-'.repeat(70));
        
        const perfSuite = { name: 'Performance & Assets', tests: [] };
        
        // Reload page for fresh metrics
        await page.goto(`${BASE_URL}/user/login`, { waitUntil: 'networkidle' });
        
        console.log('\n📋 Test 3.1: Performance Metrics');
        const perfMetrics = await page.evaluate(() => {
            const nav = performance.getEntriesByType('navigation')[0];
            const resources = performance.getEntriesByType('resource');
            
            return {
                navigation: {
                    domContentLoaded: nav.domContentLoadedEventEnd - nav.domContentLoadedEventStart,
                    loadComplete: nav.loadEventEnd - nav.loadEventStart,
                    totalTime: nav.loadEventEnd - nav.fetchStart,
                    dnsTime: nav.domainLookupEnd - nav.domainLookupStart,
                    tcpTime: nav.connectEnd - nav.connectStart,
                    ttfb: nav.responseStart - nav.requestStart
                },
                resources: {
                    total: resources.length,
                    css: resources.filter(r => r.name.includes('.css')).length,
                    js: resources.filter(r => r.name.includes('.js')).length,
                    images: resources.filter(r => r.name.match(/\.(jpg|jpeg|png|gif|svg|webp)/i)).length,
                    fonts: resources.filter(r => r.name.match(/\.(woff|woff2|ttf|eot)/i)).length
                }
            };
        });
        
        testResults.performance = perfMetrics;
        
        console.log('  Timing Metrics:');
        console.log(`    • DOM Content Loaded: ${perfMetrics.navigation.domContentLoaded.toFixed(2)}ms`);
        console.log(`    • Load Complete: ${perfMetrics.navigation.loadComplete.toFixed(2)}ms`);
        console.log(`    • Total Time: ${perfMetrics.navigation.totalTime.toFixed(2)}ms`);
        console.log(`    • TTFB: ${perfMetrics.navigation.ttfb.toFixed(2)}ms`);
        console.log('');
        console.log('  Resource Loading:');
        console.log(`    • Total Resources: ${perfMetrics.resources.total}`);
        console.log(`    • CSS Files: ${perfMetrics.resources.css}`);
        console.log(`    • JS Files: ${perfMetrics.resources.js}`);
        console.log(`    • Images: ${perfMetrics.resources.images}`);
        console.log(`    • Fonts: ${perfMetrics.resources.fonts}`);
        
        perfSuite.tests.push({
            name: 'Performance Metrics',
            status: 'INFO',
            metrics: perfMetrics
        });
        
        testResults.testSuites.push(perfSuite);
        
    } catch (error) {
        console.error(`\n❌ FATAL ERROR: ${error.message}`);
        addLog('error', `Fatal test error: ${error.message}`, {
            message: error.message,
            stack: error.stack
        });
    } finally {
        await browser.close();
    }
    
    // Generate comprehensive report
    console.log('\n' + '='.repeat(70));
    console.log('📊 COMPREHENSIVE TEST SUMMARY');
    console.log('='.repeat(70));
    
    let totalTests = 0;
    let passedTests = 0;
    let failedTests = 0;
    let skippedTests = 0;
    
    testResults.testSuites.forEach(suite => {
        console.log(`\n${suite.name}:`);
        suite.tests.forEach(test => {
            totalTests++;
            const status = test.status;
            if (status === 'PASS') passedTests++;
            else if (status === 'FAIL') failedTests++;
            else if (status === 'SKIP') skippedTests++;
            
            const icon = status === 'PASS' ? '✅' : status === 'FAIL' ? '❌' : status === 'SKIP' ? '⏭️' : 'ℹ️';
            const name = test.name || test.user || 'Unnamed';
            console.log(`  ${icon} ${name} - ${status}`);
        });
    });
    
    console.log('\n' + '-'.repeat(70));
    console.log(`Total Tests: ${totalTests}`);
    console.log(`✅ Passed: ${passedTests}`);
    console.log(`❌ Failed: ${failedTests}`);
    console.log(`⏭️ Skipped: ${skippedTests}`);
    console.log(`📝 Console Logs: ${testResults.consoleLogs.length}`);
    console.log(`🌐 Network Requests: ${testResults.networkLogs.length}`);
    console.log(`🚨 Errors: ${testResults.errors.length}`);
    console.log(`📸 Screenshots: ${testResults.screenshots.length}`);
    
    // Save comprehensive report
    const reportPath = '/home/pim/public_html/webapp/comprehensive_pim_test_report.json';
    fs.writeFileSync(reportPath, JSON.stringify(testResults, null, 2));
    console.log(`\n✅ Comprehensive report saved to: ${reportPath}`);
    
    // Save summary report
    const summary = {
        timestamp: testResults.timestamp,
        summary: {
            total: totalTests,
            passed: passedTests,
            failed: failedTests,
            skipped: skippedTests
        },
        testSuites: testResults.testSuites.map(suite => ({
            name: suite.name,
            tests: suite.tests.map(t => ({
                name: t.name || t.user,
                status: t.status,
                duration: t.duration
            }))
        })),
        performance: testResults.performance,
        screenshots: testResults.screenshots,
        errors: testResults.errors.slice(0, 10) // Top 10 errors
    };
    
    fs.writeFileSync(
        '/home/pim/public_html/webapp/test_summary.json',
        JSON.stringify(summary, null, 2)
    );
    
    console.log('✅ Summary report saved to: test_summary.json');
    console.log('\n📸 Screenshots location: /home/pim/public_html/webapp/screenshot_*.png');
    
    // Exit with appropriate code
    process.exit(failedTests > 0 ? 1 : 0);
}

// Run tests
runComprehensiveTests().catch(error => {
    console.error('Fatal error:', error);
    process.exit(1);
});
