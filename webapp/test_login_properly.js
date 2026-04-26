const { chromium } = require('playwright');

(async () => {
    const browser = await chromium.launch({ headless: true });
    const context = await browser.newContext({ 
        ignoreHTTPSErrors: true,
        viewport: { width: 1920, height: 1080 }
    });
    const page = await context.newPage();
    
    try {
        console.log('🔍 Testing Akeneo PIM Login and Dashboard...\n');
        
        // Go to login page
        console.log('1️⃣  Loading login page...');
        await page.goto('https://pim.technostationery.com/user/login', { 
            waitUntil: 'networkidle',
            timeout: 30000 
        });
        console.log('✅ Login page loaded\n');
        
        // Fill and submit login
        console.log('2️⃣  Filling login form...');
        await page.fill('input[name="_username"]', 'admin');
        await page.fill('input[name="_password"]', 'admin');
        console.log('✅ Credentials entered\n');
        
        console.log('3️⃣  Submitting form...');
        await Promise.all([
            page.waitForNavigation({ timeout: 15000 }).catch(() => console.log('⚠️  Navigation timeout')),
            page.click('button[type="submit"]')
        ]);
        
        await page.waitForTimeout(5000);
        
        const url = page.url();
        console.log(`✅ Current URL: ${url}\n`);
        
        // Check what's on the page
        console.log('4️⃣  Analyzing page content...');
        const pageInfo = await page.evaluate(() => {
            return {
                title: document.title,
                bodyClasses: document.body.className,
                hasLoadingScreen: !!document.querySelector('[class*="loading"], [class*="Loading"]'),
                appElement: {
                    exists: !!document.querySelector('.app'),
                    children: document.querySelector('.app')?.children.length || 0,
                    innerHTML: document.querySelector('.app')?.innerHTML.substring(0, 500) || 'N/A'
                },
                menuVisible: !!document.querySelector('.AknDefault-mainMenu, nav[class*="menu"]'),
                dashboardVisible: !!document.querySelector('[class*="dashboard"], [class*="Dashboard"]')
            };
        });
        
        console.log('📄 Page Info:');
        console.log(`   Title: ${pageInfo.title}`);
        console.log(`   Body Classes: ${pageInfo.bodyClasses}`);
        console.log(`   Loading Screen: ${pageInfo.hasLoadingScreen ? 'YES ⚠️' : 'NO ✅'}`);
        console.log(`   App Element: ${pageInfo.appElement.exists ? 'YES ✅' : 'NO ❌'}`);
        console.log(`   App Children: ${pageInfo.appElement.children}`);
        console.log(`   Menu Visible: ${pageInfo.menuVisible ? 'YES ✅' : 'NO ❌'}`);
        console.log(`   Dashboard: ${pageInfo.dashboardVisible ? 'YES ✅' : 'NO ❌'}`);
        console.log('');
        
        if (pageInfo.hasLoadingScreen) {
            console.log('⚠️  ISSUE: Page stuck on loading screen');
            console.log('   This is the AMD/ES6 module issue documented earlier.');
            console.log('   App HTML:', pageInfo.appElement.innerHTML);
        } else if (pageInfo.menuVisible && pageInfo.dashboardVisible) {
            console.log('✅✅✅ SUCCESS! Dashboard loaded properly! ✅✅✅');
        } else if (url.includes('/user/login')) {
            console.log('❌ ISSUE: Still on login page - authentication may have failed');
        } else {
            console.log('⚠️  Page loaded but interface may not be fully rendered');
        }
        
        // Take screenshots
        await page.screenshot({ path: '/tmp/akeneo_final_test.png', fullPage: true });
        console.log('\n📸 Screenshot saved: /tmp/akeneo_final_test.png');
        
    } catch (error) {
        console.error('❌ Error:', error.message);
    } finally {
        await browser.close();
    }
})();
