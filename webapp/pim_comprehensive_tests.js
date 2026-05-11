const { chromium } = require('playwright');
const fs = require('fs');

// Configuration
const BASE_URL = 'https://pim.technostationery.com';
const TEST_USER = 'admin';
const TEST_PASS = 'Admin123!';

// Test results storage
const testResults = {
    timestamp: new Date().toISOString(),
    baseUrl: BASE_URL,
    tests: [],
    consoleLogs: [],
    networkLogs: [],
    errors: []
};

async function runTests() {
    console.log('🚀 Starting PIM Comprehensive Tests');
    console.log('=' .repeat(50));
    
    const browser = await chromium.launch({
        headless: true,
        args: ['--no-sandbox', '--disable-setuid-sandbox']
    });
    
    const context = await browser.newContext({
        ignoreHTTPSErrors: true,
        viewport: { width: 1920, height: 1080 }
    });
    
    const page = await context.newPage();
    
    // Capture console logs
    page.on('console', msg => {
        const log = {
            type: msg.type(),
            text: msg.text(),
            location: msg.location()
        };
        testResults.consoleLogs.push(log);
        console.log(`📝 Console [${log.type}]: ${log.text}`);
    });
    
    // Capture network logs
    page.on('response', response => {
        const log = {
            url: response.url(),
            status: response.status(),
            statusText: response.statusText(),
            contentType: response.headers()['content-type']
        };
        testResults.networkLogs.push(log);
        if (response.status() >= 400) {
            console.log(`⚠️  Network Error: ${response.status()} ${response.url()}`);
        }
    });
    
    // Capture page errors
    page.on('pageerror', error => {
        testResults.errors.push({
            message: error.message,
            stack: error.stack
        });
        console.log(`❌ Page Error: ${error.message}`);
    });
    
    try {
        // Test 1: Homepage redirect
        console.log('\n📋 Test 1: Homepage Redirect');
        const startTime1 = Date.now();
        await page.goto(BASE_URL, { waitUntil: 'networkidle' });
        await page.screenshot({ path: '/home/pim/public_html/webapp/test_1_homepage.png' });
        
        testResults.tests.push({
            name: 'Homepage Redirect',
            status: 'PASS',
            duration: Date.now() - startTime1,
            url: page.url(),
            title: await page.title()
        });
        console.log(`✅ Homepage redirects to: ${page.url()}`);
        
        // Test 2: Login Page Elements
        console.log('\n📋 Test 2: Login Page Elements');
        const startTime2 = Date.now();
        
        await page.goto(`${BASE_URL}/user/login`, { waitUntil: 'networkidle' });
        await page.screenshot({ path: '/home/pim/public_html/webapp/test_2_login_page.png' });
        
        // Check for form elements
        const usernameField = await page.$('input[name="_username"], input#username, input[type="text"]');
        const passwordField = await page.$('input[name="_password"], input#password, input[type="password"]');
        const submitButton = await page.$('button[type="submit"], input[type="submit"]');
        
        const elementsFound = {
            usernameField: !!usernameField,
            passwordField: !!passwordField,
            submitButton: !!submitButton
        };
        
        testResults.tests.push({
            name: 'Login Page Elements',
            status: (usernameField && passwordField && submitButton) ? 'PASS' : 'FAIL',
            duration: Date.now() - startTime2,
            elements: elementsFound
        });
        
        console.log(`✅ Login Elements: Username=${elementsFound.usernameField}, Password=${elementsFound.passwordField}, Submit=${elementsFound.submitButton}`);
        
        // Test 3: CSS Loading
        console.log('\n📋 Test 3: CSS Loading');
        const startTime3 = Date.now();
        
        const cssRequests = testResults.networkLogs.filter(log => 
            log.url.endsWith('.css') || log.contentType?.includes('text/css')
        );
        
        const cssStatus = cssRequests.map(req => ({
            url: req.url,
            status: req.status,
            loaded: req.status === 200
        }));
        
        testResults.tests.push({
            name: 'CSS Loading',
            status: cssRequests.some(r => r.status === 200) ? 'PASS' : 'FAIL',
            duration: Date.now() - startTime3,
            cssFiles: cssStatus
        });
        
        console.log(`📊 CSS Files: ${cssRequests.length} total, ${cssStatus.filter(c => c.loaded).length} loaded successfully`);
        
        // Test 4: JavaScript Loading
        console.log('\n📋 Test 4: JavaScript Loading');
        const startTime4 = Date.now();
        
        const jsRequests = testResults.networkLogs.filter(log => 
            log.url.endsWith('.js') || log.contentType?.includes('javascript')
        );
        
        const jsStatus = jsRequests.map(req => ({
            url: req.url,
            status: req.status,
            loaded: req.status === 200
        }));
        
        testResults.tests.push({
            name: 'JavaScript Loading',
            status: jsRequests.some(r => r.status === 200) ? 'PASS' : 'FAIL',
            duration: Date.now() - startTime4,
            jsFiles: jsStatus
        });
        
        console.log(`📊 JS Files: ${jsRequests.length} total, ${jsStatus.filter(j => j.loaded).length} loaded successfully`);
        
        // Test 5: Login Functionality
        console.log('\n📋 Test 5: Login Functionality');
        const startTime5 = Date.now();
        
        if (usernameField && passwordField && submitButton) {
            await usernameField.fill(TEST_USER);
            await passwordField.fill(TEST_PASS);
            await page.screenshot({ path: '/home/pim/public_html/webapp/test_5_before_login.png' });
            
            await submitButton.click();
            await page.waitForTimeout(3000);
            await page.screenshot({ path: '/home/pim/public_html/webapp/test_5_after_login.png' });
            
            const currentUrl = page.url();
            const pageTitle = await page.title();
            
            // Check if login was successful (URL changed or no error message)
            const loginSuccess = !currentUrl.includes('/user/login') || pageTitle.toLowerCase().includes('dashboard');
            
            testResults.tests.push({
                name: 'Login Functionality',
                status: loginSuccess ? 'PASS' : 'FAIL',
                duration: Date.now() - startTime5,
                resultUrl: currentUrl,
                resultTitle: pageTitle
            });
            
            console.log(`${loginSuccess ? '✅' : '❌'} Login Result: ${currentUrl}`);
            
            // Test 6: Dashboard/Post-Login Navigation
            if (loginSuccess) {
                console.log('\n📋 Test 6: Dashboard Navigation');
                const startTime6 = Date.now();
                
                await page.waitForTimeout(2000);
                await page.screenshot({ path: '/home/pim/public_html/webapp/test_6_dashboard.png' });
                
                // Check for navigation menu
                const menuExists = await page.$('nav, .navigation, .menu, [role="navigation"]');
                
                testResults.tests.push({
                    name: 'Dashboard Navigation',
                    status: menuExists ? 'PASS' : 'PARTIAL',
                    duration: Date.now() - startTime6,
                    menuFound: !!menuExists
                });
                
                console.log(`${menuExists ? '✅' : '⚠️'} Dashboard Menu: ${menuExists ? 'Found' : 'Not Found'}`);
            }
        } else {
            testResults.tests.push({
                name: 'Login Functionality',
                status: 'SKIP',
                reason: 'Login form elements not found'
            });
            console.log('⚠️ Skipping login test - form elements missing');
        }
        
        // Test 7: Performance Metrics
        console.log('\n📋 Test 7: Performance Metrics');
        const performanceMetrics = await page.evaluate(() => {
            const navigation = performance.getEntriesByType('navigation')[0];
            return {
                domContentLoaded: navigation.domContentLoadedEventEnd - navigation.domContentLoadedEventStart,
                loadComplete: navigation.loadEventEnd - navigation.loadEventStart,
                totalTime: navigation.loadEventEnd - navigation.fetchStart
            };
        });
        
        testResults.tests.push({
            name: 'Performance Metrics',
            status: 'INFO',
            metrics: performanceMetrics
        });
        
        console.log(`📊 Performance: DOM=${performanceMetrics.domContentLoaded.toFixed(0)}ms, Load=${performanceMetrics.loadComplete.toFixed(0)}ms, Total=${performanceMetrics.totalTime.toFixed(0)}ms`);
        
    } catch (error) {
        console.error(`❌ Test Error: ${error.message}`);
        testResults.errors.push({
            message: error.message,
            stack: error.stack
        });
    } finally {
        await browser.close();
    }
    
    // Generate report
    console.log('\n' + '='.repeat(50));
    console.log('📊 TEST SUMMARY');
    console.log('='.repeat(50));
    
    const passed = testResults.tests.filter(t => t.status === 'PASS').length;
    const failed = testResults.tests.filter(t => t.status === 'FAIL').length;
    const skipped = testResults.tests.filter(t => t.status === 'SKIP').length;
    
    console.log(`✅ Passed: ${passed}`);
    console.log(`❌ Failed: ${failed}`);
    console.log(`⚠️  Skipped: ${skipped}`);
    console.log(`📝 Console Logs: ${testResults.consoleLogs.length}`);
    console.log(`🌐 Network Requests: ${testResults.networkLogs.length}`);
    console.log(`🚨 Errors: ${testResults.errors.length}`);
    
    // Save detailed report
    fs.writeFileSync(
        '/home/pim/public_html/webapp/pim_test_report.json',
        JSON.stringify(testResults, null, 2)
    );
    
    console.log('\n✅ Detailed report saved to: pim_test_report.json');
    console.log('📸 Screenshots saved with prefix: test_');
    
    // Exit with appropriate code
    process.exit(failed > 0 ? 1 : 0);
}

runTests().catch(error => {
    console.error('Fatal error:', error);
    process.exit(1);
});
