const { chromium } = require('playwright');

(async () => {
    const browser = await chromium.launch({ headless: true });
    const context = await browser.newContext({
        ignoreHTTPSErrors: true,
        viewport: { width: 1920, height: 1080 }
    });
    const page = await context.newPage();
    
    const consoleMessages = [];
    
    page.on('console', msg => {
        const type = msg.type();
        const text = msg.text();
        consoleMessages.push({ type, text });
        console.log(`[${type.toUpperCase()}] ${text}`);
    });
    
    page.on('pageerror', error => {
        console.log(`[PAGE ERROR] ${error.message}`);
    });
    
    page.on('requestfailed', request => {
        console.log(`[REQUEST FAILED] ${request.url()} - ${request.failure().errorText}`);
    });
    
    try {
        console.log('=== LOADING LOGIN PAGE ===');
        await page.goto('https://pim.technostationery.com/', { timeout: 30000, waitUntil: 'networkidle' });
        
        console.log('\n=== LOGGING IN ===');
        await page.fill('input[name="_username"]', 'admin');
        await page.fill('input[name="_password"]', 'admin');
        await page.click('button[type="submit"]');
        
        // Wait for navigation without strict URL match
        await page.waitForLoadState('networkidle', { timeout: 20000 });
        await page.waitForTimeout(5000);
        
        const currentUrl = page.url();
        console.log(`\n=== CURRENT URL: ${currentUrl} ===`);
        
        console.log('\n=== PAGE TITLE ===');
        const title = await page.title();
        console.log(title);
        
        console.log('\n=== CHECKING MENU VISIBILITY ===');
        const menuCheck = await page.evaluate(() => {
            const selectors = [
                '.AknDefault-mainMenu',
                '.mainMenu', 
                'nav',
                '[class*="Menu"]',
                '[class*="menu"]'
            ];
            
            const results = {};
            selectors.forEach(sel => {
                const el = document.querySelector(sel);
                if (el) {
                    const styles = window.getComputedStyle(el);
                    results[sel] = {
                        exists: true,
                        display: styles.display,
                        visibility: styles.visibility,
                        opacity: styles.opacity,
                        className: el.className
                    };
                }
            });
            return results;
        });
        
        console.log(JSON.stringify(menuCheck, null, 2));
        
        await page.screenshot({ path: '/tmp/pim_after_login.png', fullPage: true });
        console.log('\n=== Screenshot saved to /tmp/pim_after_login.png ===');
        
        console.log(`\n=== TOTAL CONSOLE MESSAGES: ${consoleMessages.length} ===`);
        
    } catch (error) {
        console.error('Script error:', error.message);
        await page.screenshot({ path: '/tmp/pim_error.png', fullPage: true });
    } finally {
        await browser.close();
    }
})();
