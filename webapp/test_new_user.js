const { chromium } = require('playwright');

(async () => {
    const browser = await chromium.launch({ headless: true });
    const page = await (await browser.newContext({ ignoreHTTPSErrors: true, viewport: { width: 1920, height: 1080 } })).newPage();
    
    console.log('🔐 Testing with newly created user...\n');
    
    await page.goto('https://pim.technostationery.com/user/login');
    await page.waitForTimeout(2000);
    
    await page.fill('input[name="_username"]', 'testadmin');
    await page.fill('input[name="_password"]', 'testpass');
    await page.click('button[type="submit"]');
    await page.waitForTimeout(5000);
    
    const url = page.url();
    const error = await page.evaluate(() => {
        const el = document.querySelector('.Helper .Text, .alert');
        return el ? el.textContent.trim() : null;
    });
    
    console.log('Current URL:', url);
    console.log('Error:', error || 'None');
    console.log('Login Success:', !url.includes('/user/login') ? '✅ YES!' : '❌ NO');
    
    if (!url.includes('/user/login')) {
        const pageInfo = await page.evaluate(() => ({
            title: document.title,
            hasLoading: !!document.querySelector('[class*="loading"]'),
            hasApp: !!document.querySelector('.app'),
            hasMenu: !!document.querySelector('.AknDefault-mainMenu, nav')
        }));
        console.log('\nPage after login:', JSON.stringify(pageInfo, null, 2));
        await page.screenshot({ path: '/tmp/login_success.png', fullPage: true });
        console.log('Screenshot: /tmp/login_success.png');
    }
    
    await browser.close();
})();
