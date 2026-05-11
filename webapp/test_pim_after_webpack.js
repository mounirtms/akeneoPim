const playwright = require('playwright');

(async () => {
    console.log('🔍 Testing PIM After Webpack Rebuild\n');
    
    const browser = await playwright.chromium.launch({
        headless: true,
        args: ['--no-sandbox', '--disable-setuid-sandbox']
    });
    
    const context = await browser.newContext({
        ignoreHTTPSErrors: true,
        viewport: { width: 1920, height: 1080 }
    });
    
    const page = await context.newPage();
    
    const errors = {
        console: [],
        network: [],
        page: []
    };
    
    page.on('console', msg => {
        if (msg.type() === 'error') {
            errors.console.push(msg.text());
        }
    });
    
    page.on('response', response => {
        if (response.status() >= 400) {
            errors.network.push(`${response.status()} - ${response.url()}`);
        }
    });
    
    page.on('pageerror', error => {
        errors.page.push(error.message);
    });
    
    try {
        console.log('Step 1: Loading login page...');
        await page.goto('https://pim.technostationery.com/', { 
            waitUntil: 'networkidle',
            timeout: 30000 
        });
        
        console.log(`   Status: ${page.url()}`);
        console.log(`   Title: ${await page.title()}`);
        
        // Check for login form
        const usernameField = await page.$('input[name="_username"]');
        const passwordField = await page.$('input[name="_password"]');
        
        if (usernameField && passwordField) {
            console.log('   ✅ Login form found');
            
            console.log('\nStep 2: Logging in with mounir/2026...');
            await page.fill('input[name="_username"]', 'mounir');
            await page.fill('input[name="_password"]', '2026');
            await page.click('button[type="submit"]');
            
            await page.waitForNavigation({ waitUntil: 'networkidle', timeout: 30000 });
            
            console.log(`   Status: ${page.url()}`);
            console.log(`   Title: ${await page.title()}`);
            
            // Wait for dashboard to load
            await page.waitForTimeout(3000);
            
            console.log('\nStep 3: Checking dashboard UI...');
            
            // Check for main UI elements
            const mainContainer = await page.$('#container');
            const pageElement = await page.$('#page');
            const headerElement = await page.$('.AknHeader');
            const menuElement = await page.$('[data-testid="pim-menu"]');
            
            console.log(`   Main container: ${mainContainer ? '✅ Found' : '❌ Missing'}`);
            console.log(`   Page element: ${pageElement ? '✅ Found' : '❌ Missing'}`);
            console.log(`   Header: ${headerElement ? '✅ Found' : '❌ Missing'}`);
            console.log(`   PIM Menu: ${menuElement ? '✅ Found' : '❌ Missing'}`);
            
            // Check for loading indicators
            const loadingMask = await page.$('.loading-mask');
            console.log(`   Loading mask: ${loadingMask ? '⚠️ Still visible' : '✅ Hidden'}`);
            
            // Take screenshot
            await page.screenshot({ path: '/home/pim/public_html/webapp/test_dashboard_screenshot.png', fullPage: true });
            console.log('\n   📸 Screenshot saved to: webapp/test_dashboard_screenshot.png');
            
        } else {
            console.log('   ❌ Login form not found');
        }
        
    } catch (error) {
        console.log(`\n❌ Error: ${error.message}`);
        errors.page.push(error.message);
    }
    
    console.log('\n📋 Error Summary:');
    console.log(`   Console Errors: ${errors.console.length}`);
    console.log(`   Network Errors: ${errors.network.length}`);
    console.log(`   Page Errors: ${errors.page.length}`);
    
    if (errors.console.length > 0) {
        console.log('\n   🔴 Console Errors (first 10):');
        errors.console.slice(0, 10).forEach((err, i) => {
            console.log(`      ${i + 1}. ${err.substring(0, 200)}`);
        });
    }
    
    if (errors.network.length > 0) {
        console.log('\n   🔴 Network Errors (first 10):');
        errors.network.slice(0, 10).forEach((err, i) => {
            console.log(`      ${i + 1}. ${err}`);
        });
    }
    
    await browser.close();
    
    console.log('\n✅ Test complete!');
})();
