const playwright = require('playwright');

(async () => {
    console.log('🔍 Quick PIM Dashboard Check\n');
    
    const browser = await playwright.chromium.launch({
        headless: true,
        args: ['--no-sandbox', '--disable-setuid-sandbox']
    });
    
    const context = await browser.newContext({
        ignoreHTTPSErrors: true,
        viewport: { width: 1920, height: 1080 }
    });
    
    const page = await context.newPage();
    
    try {
        console.log('Step 1: Loading login page...');
        await page.goto('https://pim.technostationery.com/user/login', { 
            waitUntil: 'domcontentloaded',
            timeout: 15000 
        });
        
        console.log('   ✅ Login page loaded');
        
        console.log('\nStep 2: Logging in...');
        await page.fill('input[name="_username"]', 'mounir');
        await page.fill('input[name="_password"]', '2026');
        
        // Click and wait for any navigation
        await Promise.all([
            page.click('button[type="submit"]'),
            page.waitForLoadState('domcontentloaded', { timeout: 15000 }).catch(() => {})
        ]);
        
        await page.waitForTimeout(5000);
        
        const currentUrl = page.url();
        console.log(`   Current URL: ${currentUrl}`);
        console.log(`   Title: ${await page.title()}`);
        
        // Check for dashboard elements
        console.log('\nStep 3: Checking dashboard elements...');
        
        const bodyText = await page.evaluate(() => document.body.innerText.substring(0, 200));
        console.log(`   Body text preview: ${bodyText.replace(/\n/g, ' ')}`);
        
        const hasContainer = await page.$('#container');
        const hasPage = await page.$('#page');
        const hasHeader = await page.$('.AknHeader');
        const hasMenu = await page.$('.AknHeader-menuContainer');
        const hasMainMenu = await page.$('[data-testid="pim-menu"]');
        
        console.log(`   #container: ${hasContainer ? '✅' : '❌'}`);
        console.log(`   #page: ${hasPage ? '✅' : '❌'}`);
        console.log(`   .AknHeader: ${hasHeader ? '✅' : '❌'}`);
        console.log(`   .AknHeader-menuContainer: ${hasMenu ? '✅' : '❌'}`);
        console.log(`   [data-testid="pim-menu"]: ${hasMainMenu ? '✅' : '❌'}`);
        
        // Check for loading indicators
        const loadingMask = await page.$('.loading-mask:visible');
        const loadingText = await page.$('text="Loading..."');
        
        console.log(`   Loading mask visible: ${loadingMask ? '⚠️ YES' : '✅ NO'}`);
        console.log(`   "Loading..." text: ${loadingText ? '⚠️ YES' : '✅ NO'}`);
        
        // Take screenshot
        await page.screenshot({ path: '/home/pim/public_html/webapp/dashboard_quick_test.png', fullPage: true });
        console.log('\n   📸 Screenshot saved: dashboard_quick_test.png');
        
        // Get any console errors
        const errors = [];
        page.on('console', msg => {
            if (msg.type() === 'error') errors.push(msg.text());
        });
        
        await page.waitForTimeout(2000);
        
        if (errors.length > 0) {
            console.log(`\n   ⚠️ Console errors: ${errors.length}`);
            errors.slice(0, 3).forEach((err, i) => {
                console.log(`      ${i + 1}. ${err.substring(0, 150)}`);
            });
        }
        
        console.log('\n✅ Test complete!');
        
    } catch (error) {
        console.log(`\n❌ Error: ${error.message}`);
    }
    
    await browser.close();
})();
