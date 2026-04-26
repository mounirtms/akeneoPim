const { chromium } = require('playwright');

(async () => {
    const browser = await chromium.launch({ headless: true });
    const context = await browser.newContext({ 
        ignoreHTTPSErrors: true,
        viewport: { width: 1920, height: 1080 }
    });
    const page = await context.newPage();
    
    try {
        console.log('🔐 Testing Akeneo PIM Login (with CSRF fix)...\n');
        
        // Go to login page
        console.log('1️⃣  Loading login page...');
        await page.goto('https://pim.technostationery.com/user/login', { 
            waitUntil: 'domcontentloaded',
            timeout: 30000 
        });
        await page.waitForTimeout(2000);
        console.log('✅ Login page loaded\n');
        
        // Get CSRF token
        const csrfToken = await page.evaluate(() => {
            const input = document.querySelector('input[name="_csrf_token"]');
            return input ? input.value : null;
        });
        console.log('2️⃣  CSRF Token:', csrfToken ? `${csrfToken.substring(0, 20)}...` : 'NOT FOUND');
        
        // Fill form
        console.log('\n3️⃣  Filling login form...');
        await page.fill('input[name="_username"]', 'admin');
        await page.fill('input[name="_password"]', 'admin');
        console.log('✅ Credentials entered\n');
        
        console.log('4️⃣  Submitting form (form will handle CSRF automatically)...');
        await page.click('button[type="submit"]');
        
        // Wait for navigation or error
        try {
            await page.waitForURL(url => !url.includes('/user/login'), { timeout: 10000 });
            console.log('✅ Navigated away from login page!\n');
        } catch {
            console.log('⚠️  Still on login page after 10s\n');
        }
        
        await page.waitForTimeout(5000);
        
        const url = page.url();
        console.log(`5️⃣  Current URL: ${url}\n`);
        
        // Check for error messages
        const errorMsg = await page.evaluate(() => {
            const helper = document.querySelector('.Helper .Text');
            const alert = document.querySelector('.alert, [class*="error"]');
            return (helper || alert) ? (helper?.textContent || alert?.textContent).trim() : null;
        });
        
        if (errorMsg) {
            console.log(`❌ Error on page: "${errorMsg}"\n`);
        }
        
        // Check what's on the page
        console.log('6️⃣  Analyzing page content...');
        const pageInfo = await page.evaluate(() => {
            return {
                title: document.title,
                bodyClasses: document.body.className,
                hasLoadingScreen: !!document.querySelector('[class*="loading"], [class*="Loading"], .AknDefault-progressContainer'),
                loadingText: document.querySelector('[class*="loading"], [class*="Loading"], .AknDefault-progressContainer')?.textContent?.trim() || 'N/A',
                appElement: {
                    exists: !!document.querySelector('.app'),
                    children: document.querySelector('.app')?.children.length || 0
                },
                menuVisible: !!document.querySelector('.AknDefault-mainMenu, nav[class*="menu"]'),
                dashboardVisible: !!document.querySelector('[class*="dashboard"], [class*="Dashboard"]')
            };
        });
        
        console.log('📄 Page Info:');
        console.log(`   Title: ${pageInfo.title}`);
        console.log(`   Body Classes: ${pageInfo.bodyClasses}`);
        console.log(`   Loading Screen: ${pageInfo.hasLoadingScreen ? 'YES ⚠️' : 'NO ✅'}`);
        if (pageInfo.hasLoadingScreen) {
            console.log(`   Loading Text: "${pageInfo.loadingText}"`);
        }
        console.log(`   App Element: ${pageInfo.appElement.exists ? 'YES ✅' : 'NO ❌'}`);
        console.log(`   App Children: ${pageInfo.appElement.children}`);
        console.log(`   Menu Visible: ${pageInfo.menuVisible ? 'YES ✅' : 'NO ❌'}`);
        console.log(`   Dashboard: ${pageInfo.dashboardVisible ? 'YES ✅' : 'NO ❌'}`);
        console.log('');
        
        // Final verdict
        if (url.includes('/user/login')) {
            console.log('❌ RESULT: Authentication failed - still on login page');
        } else if (pageInfo.hasLoadingScreen) {
            console.log('⚠️  RESULT: Logged in but page stuck on loading screen');
            console.log('   This is the known AMD/ES6 module issue from earlier documentation.');
        } else if (pageInfo.menuVisible || pageInfo.dashboardVisible) {
            console.log('✅✅✅ SUCCESS! Dashboard loaded properly! ✅✅✅');
        } else {
            console.log('⚠️  RESULT: Logged in but UI not fully rendered');
        }
        
        // Take screenshots
        await page.screenshot({ path: '/tmp/akeneo_login_test.png', fullPage: true });
        console.log('\n📸 Screenshot saved: /tmp/akeneo_login_test.png\n');
        
    } catch (error) {
        console.error('❌ Error:', error.message);
        await page.screenshot({ path: '/tmp/akeneo_error.png' });
    } finally {
        await browser.close();
    }
})();
