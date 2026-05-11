const { chromium } = require('playwright');

(async () => {
    const browser = await chromium.launch({ headless: true });
    const context = await browser.newContext({ ignoreHTTPSErrors: true });
    const page = await context.newPage();
    
    try {
        console.log('Loading page...');
        await page.goto('https://pim.technostationery.com/', { timeout: 30000 });
        await page.waitForTimeout(3000);
        
        console.log('\n=== PAGE CONTENT ===');
        const content = await page.content();
        console.log(content.substring(0, 2000));
        
        console.log('\n=== BODY TEXT ===');
        const bodyText = await page.evaluate(() => document.body.innerText);
        console.log(bodyText.substring(0, 500));
        
        console.log('\n=== ALL FORM INPUTS ===');
        const inputs = await page.evaluate(() => {
            return Array.from(document.querySelectorAll('input')).map(i => ({
                type: i.type,
                name: i.name,
                id: i.id,
                placeholder: i.placeholder
            }));
        });
        console.log(JSON.stringify(inputs, null, 2));
        
        await page.screenshot({ path: '/tmp/debug_page.png', fullPage: true });
        console.log('\nScreenshot saved to /tmp/debug_page.png');
        
    } catch (error) {
        console.error('Error:', error.message);
    } finally {
        await browser.close();
    }
})();
