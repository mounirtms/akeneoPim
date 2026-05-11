const { chromium } = require('playwright');

(async () => {
    const browser = await chromium.launch({ headless: true });
    const page = await (await browser.newContext({ ignoreHTTPSErrors: true })).newPage();
    
    await page.goto('https://pim.technostationery.com/user/login');
    await page.fill('input[name="_username"]', 'admin');
    await page.fill('input[name="_password"]', 'admin');
    await page.click('button[type="submit"]');
    await page.waitForTimeout(3000);
    
    const errorMsg = await page.evaluate(() => {
        const alert = document.querySelector('.alert, .error, .flash-message, [class*="error"]');
        return alert ? alert.textContent.trim() : null;
    });
    
    const pageText = await page.evaluate(() => document.body.innerText);
    
    console.log('Error message:', errorMsg || 'None');
    console.log('\nPage text:', pageText.substring(0, 500));
    
    await browser.close();
})();
