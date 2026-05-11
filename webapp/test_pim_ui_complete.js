const { chromium } = require('playwright');
const fs = require('fs');

const BASE_URL = 'https://pim.technostationery.com';
const TEST_USERS = [
    { username: 'mounir', password: '2026', name: 'Mounir' },
    { username: 'admin', password: 'Admin2026!', name: 'Admin' }
];

const testResults = {
    timestamp: new Date().toISOString(),
    tests: [],
    consoleLogs: [],
    networkLogs: [],
    errors: []
};

async function runTests() {
    console.log('🚀 Starting Complete PIM UI Tests');
    console.log('=' .repeat(70));
    
    const browser = await chromium.launch({
        headless: true,
        args: ['--no-sandbox', '--disable-setuid-sandbox']
    });
    
    const context = await browser.newContext({
        ignoreHTTPSErrors: true,
        viewport: { width: 1920, height: 1080 }
    });
    
    const page = await context.newPage();
    
    // Capture all logs
    page.on('console', msg => {
        const log = `[${msg.type()}] ${msg.text()}`;
        testResults.consoleLogs.push(log);
        console.log(`  📝 ${log}`);
    });
    
    page.on('response', response => {
        const log = `${response.status()} ${response.url()}`;
        testResults.networkLogs.push(log);
        if (response.status() >= 400) {
            console.log(`  ⚠️  ${log}`);
        }
    });
    
    page.on('pageerror', error => {
        testResults.errors.push(error.message);
        console.log(`  ❌ ${error.message}`);
    });
    
    try {
        // Test both users
        for (const user of TEST_USERS) {
            console.log(`\n${'='.repeat(70)}`);
            console.log(`Testing ${user.name} (${user.username}/${user.password})`);
            console.log('='.repeat(70));
            
            // Navigate to login
            console.log('\n1️⃣  Navigating to login page...');
            await page.goto(`${BASE_URL}/user/login`, { waitUntil: 'networkidle', timeout: 60000 });
            await page.screenshot({ path: `/home/pim/public_html/webapp/test_${user.username}_01_login.png` });
            
            // Fill login form
            console.log('2️⃣  Filling login credentials...');
            await page.fill('input[name="_username"]', user.username);
            await page.fill('input[name="_password"]', user.password);
            await page.screenshot({ path: `/home/pim/public_html/webapp/test_${user.username}_02_filled.png` });
            
            // Submit and wait
            console.log('3️⃣  Submitting login...');
            await page.click('button[type="submit"]');
            
            // Wait for navigation or error
            console.log('4️⃣  Waiting for dashboard or error (60s timeout)...');
            await page.waitForTimeout(5000); // Initial wait
            
            const currentUrl = page.url();
            console.log(`   Current URL: ${currentUrl}`);
            
            await page.screenshot({ path: `/home/pim/public_html/webapp/test_${user.username}_03_after_submit.png`, fullPage: true });
            
            // Check if still loading
            const loadingVisible = await page.isVisible('.loading, .loader, [class*="loading"]').catch(() => false);
            console.log(`   Loading indicator visible: ${loadingVisible}`);
            
            if (loadingVisible) {
                console.log('5️⃣  Still loading... waiting 30 more seconds...');
                await page.waitForTimeout(30000);
                await page.screenshot({ path: `/home/pim/public_html/webapp/test_${user.username}_04_still_loading.png`, fullPage: true });
                
                // Check what's in the page
                const bodyText = await page.textContent('body').catch(() => 'Unable to get body text');
                console.log(`   Body text (first 200 chars): ${bodyText.substring(0, 200)}`);
            }
            
            // Check for errors
            const errorElement = await page.$('.alert-danger, .error, [role="alert"]');
            if (errorElement) {
                const errorText = await errorElement.textContent();
                console.log(`   ❌ Error message: ${errorText}`);
            }
            
            // Check page title
            const title = await page.title();
            console.log(`   Page title: ${title}`);
            
            // Try to check if dashboard elements loaded
            console.log('6️⃣  Checking for dashboard elements...');
            
            const dashboardElements = {
                navigation: await page.$('nav, [role="navigation"]').then(e => !!e),
                header: await page.$('header, .AknHeader').then(e => !!e),
                mainMenu: await page.$('.AknMainMenu, .navigation-menu').then(e => !!e),
                content: await page.$('main, .content, .AknDefault-mainContent').then(e => !!e)
            };
            
            console.log('   Dashboard elements found:');
            Object.entries(dashboardElements).forEach(([key, found]) => {
                console.log(`     ${found ? '✅' : '❌'} ${key}`);
            });
            
            // If logged in, try to navigate
            if (!currentUrl.includes('/user/login')) {
                console.log('7️⃣  Login successful! Testing navigation...');
                
                // Wait a bit more for full load
                await page.waitForTimeout(5000);
                await page.screenshot({ path: `/home/pim/public_html/webapp/test_${user.username}_05_dashboard.png`, fullPage: true });
                
                // Try to find menu items
                console.log('8️⃣  Looking for menu items...');
                const menuLinks = await page.$$eval('a', links => 
                    links.slice(0, 20).map(l => ({ text: l.textContent.trim(), href: l.href }))
                );
                
                console.log(`   Found ${menuLinks.length} links:`);
                menuLinks.slice(0, 10).forEach(link => {
                    if (link.text) console.log(`     • ${link.text}`);
                });
                
                // Try to click Products if available
                const productsLink = await page.$('a[href*="product"], a:has-text("Products")').catch(() => null);
                if (productsLink) {
                    console.log('9️⃣  Clicking Products link...');
                    await productsLink.click();
                    await page.waitForTimeout(5000);
                    await page.screenshot({ path: `/home/pim/public_html/webapp/test_${user.username}_06_products.png`, fullPage: true });
                    console.log('   Products page loaded');
                }
                
                testResults.tests.push({
                    user: user.username,
                    status: 'PASS',
                    url: currentUrl,
                    dashboardElements
                });
            } else {
                console.log('   ❌ Login failed - still on login page');
                testResults.tests.push({
                    user: user.username,
                    status: 'FAIL',
                    reason: 'Still on login page',
                    url: currentUrl
                });
            }
            
            // Logout
            try {
                await page.goto(`${BASE_URL}/user/logout`, { timeout: 10000 });
                await page.waitForTimeout(2000);
            } catch (e) {
                console.log('   ⚠️  Logout navigation skipped');
            }
        }
        
    } catch (error) {
        console.error(`\n❌ Fatal error: ${error.message}`);
        testResults.errors.push(`Fatal: ${error.message}`);
    } finally {
        await browser.close();
    }
    
    // Save results
    fs.writeFileSync(
        '/home/pim/public_html/webapp/pim_ui_test_results.json',
        JSON.stringify(testResults, null, 2)
    );
    
    console.log('\n' + '='.repeat(70));
    console.log('📊 TEST SUMMARY');
    console.log('='.repeat(70));
    console.log(`Tests run: ${testResults.tests.length}`);
    console.log(`Passed: ${testResults.tests.filter(t => t.status === 'PASS').length}`);
    console.log(`Failed: ${testResults.tests.filter(t => t.status === 'FAIL').length}`);
    console.log(`Console logs: ${testResults.consoleLogs.length}`);
    console.log(`Network logs: ${testResults.networkLogs.length}`);
    console.log(`Errors: ${testResults.errors.length}`);
    console.log('\n✅ Results saved to: pim_ui_test_results.json');
    
    process.exit(testResults.tests.filter(t => t.status === 'FAIL').length > 0 ? 1 : 0);
}

runTests().catch(error => {
    console.error('Fatal error:', error);
    process.exit(1);
});
