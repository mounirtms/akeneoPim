const playwright = require('playwright');

(async () => {
    console.log('🔍 Testing Dashboard After CSP Fix\n');
    
    const browser = await playwright.chromium.launch({
        headless: true,
        args: ['--no-sandbox', '--disable-setuid-sandbox']
    });
    
    const context = await browser.newContext({
        ignoreHTTPSErrors: true,
        viewport: { width: 1920, height: 1080 }
    });
    
    const page = await context.newPage();
    
    // Capture console messages
    const consoleMessages = [];
    page.on('console', msg => {
        const text = msg.text();
        consoleMessages.push({ type: msg.type(), text: text });
        if (msg.type() === 'error') {
            console.log(`   ❌ Console Error: ${text.substring(0, 200)}`);
        }
    });
    
    // Capture JavaScript errors
    const jsErrors = [];
    page.on('pageerror', error => {
        jsErrors.push(error.message);
        console.log(`   ⚠️ JS Error: ${error.message.substring(0, 200)}`);
    });
    
    try {
        console.log('1️⃣ Navigating to login page...');
        await page.goto('https://pim.technostationery.com/', { 
            waitUntil: 'networkidle',
            timeout: 30000 
        });
        
        console.log('2️⃣ Logging in with mounir/2026...');
        await page.fill('input[name="_username"]', 'mounir');
        await page.fill('input[name="_password"]', '2026');
        await page.click('button[type="submit"]');
        
        console.log('3️⃣ Waiting for dashboard redirect...');
        await page.waitForURL('**/dashboard', { timeout: 10000 });
        console.log('   ✅ Redirected to dashboard');
        
        console.log('4️⃣ Checking CSP headers...');
        const response = await page.goto('https://pim.technostationery.com/#/dashboard');
        const headers = response.headers();
        const cspHeader = headers['content-security-policy'] || 'NOT SET';
        console.log(`   CSP Header: ${cspHeader.substring(0, 100)}...`);
        
        console.log('5️⃣ Waiting for dashboard to load (60 seconds)...');
        const startTime = Date.now();
        
        // Wait for either PIM UI elements or timeout
        try {
            await Promise.race([
                page.waitForSelector('#page', { timeout: 60000 }),
                page.waitForSelector('#container', { timeout: 60000 }),
                page.waitForSelector('.AknHeader', { timeout: 60000 }),
                page.waitForSelector('[data-testid="pim-menu"]', { timeout: 60000 })
            ]);
            
            const loadTime = ((Date.now() - startTime) / 1000).toFixed(1);
            console.log(`   ✅ Dashboard UI loaded in ${loadTime}s!`);
            
            // Check what elements are present
            const pageDiv = await page.$('#page');
            const containerDiv = await page.$('#container');
            const header = await page.$('.AknHeader');
            const menu = await page.$('[data-testid="pim-menu"]');
            
            console.log('\n📊 Dashboard Elements Found:');
            console.log(`   #page div: ${pageDiv ? '✅ Yes' : '❌ No'}`);
            console.log(`   #container div: ${containerDiv ? '✅ Yes' : '❌ No'}`);
            console.log(`   .AknHeader: ${header ? '✅ Yes' : '❌ No'}`);
            console.log(`   PIM Menu: ${menu ? '✅ Yes' : '❌ No'}`);
            
        } catch (timeoutError) {
            const loadTime = ((Date.now() - startTime) / 1000).toFixed(1);
            console.log(`   ⏱️ Timeout after ${loadTime}s - Dashboard still loading`);
            
            // Check what's on the page
            const bodyText = await page.textContent('body');
            console.log(`   Page text: ${bodyText.substring(0, 200)}`);
        }
        
        console.log('\n6️⃣ Taking screenshot...');
        await page.screenshot({ path: '/home/pim/public_html/webapp/dashboard_after_csp_fix.png', fullPage: true });
        console.log('   ✅ Screenshot saved');
        
        console.log('\n📊 SUMMARY:');
        console.log(`   Total Console Messages: ${consoleMessages.length}`);
        console.log(`   Console Errors: ${consoleMessages.filter(m => m.type === 'error').length}`);
        console.log(`   JavaScript Errors: ${jsErrors.length}`);
        
        // Show first few errors
        if (jsErrors.length > 0) {
            console.log('\n❌ First 3 JavaScript Errors:');
            jsErrors.slice(0, 3).forEach((err, idx) => {
                console.log(`   ${idx + 1}. ${err.substring(0, 200)}`);
            });
        }
        
    } catch (error) {
        console.error('\n❌ TEST FAILED:', error.message);
    } finally {
        await browser.close();
    }
    
    console.log('\n✅ Test Complete');
})();
