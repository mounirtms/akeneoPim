const { chromium } = require('playwright');

(async () => {
    const browser = await chromium.launch({ headless: true });
    const context = await browser.newContext({
        ignoreHTTPSErrors: true,
        viewport: { width: 1920, height: 1080 }
    });
    const page = await context.newPage();
    
    const consoleMessages = [];
    const errors = [];
    
    page.on('console', msg => {
        const type = msg.type();
        const text = msg.text();
        consoleMessages.push({ type, text });
        if (type === 'error' || type === 'warning') {
            console.log(`[${type.toUpperCase()}] ${text}`);
        }
    });
    
    page.on('pageerror', error => {
        errors.push(error.message);
        console.log(`[PAGE ERROR] ${error.message}`);
    });
    
    try {
        console.log('=== LOADING LOGIN PAGE ===');
        await page.goto('https://pim.technostationery.com/', { timeout: 30000 });
        await page.waitForTimeout(2000);
        
        console.log('\n=== LOGGING IN ===');
        await page.fill('input[name="_username"]', 'admin');
        await page.fill('input[name="_password"]', 'admin');
        await page.click('button[type="submit"]');
        
        console.log('\n=== WAITING FOR DASHBOARD ===');
        await page.waitForURL('**/dashboard', { timeout: 15000 });
        await page.waitForTimeout(5000); // Wait for everything to load
        
        console.log('\n=== CHECKING MENU STYLES ===');
        const menuInfo = await page.evaluate(() => {
            const menu = document.querySelector('.AknDefault-mainMenu, .mainMenu, nav, [class*="menu"]');
            if (!menu) return { found: false };
            
            const styles = window.getComputedStyle(menu);
            const rect = menu.getBoundingClientRect();
            
            return {
                found: true,
                className: menu.className,
                display: styles.display,
                position: styles.position,
                width: styles.width,
                height: styles.height,
                zIndex: styles.zIndex,
                visibility: styles.visibility,
                rect: { top: rect.top, left: rect.left, width: rect.width, height: rect.height },
                hasChildren: menu.children.length
            };
        });
        
        console.log('\n=== MENU ELEMENT INFO ===');
        console.log(JSON.stringify(menuInfo, null, 2));
        
        console.log('\n=== CHECKING FOR STYLE ERRORS ===');
        const missingStyles = await page.evaluate(() => {
            const issues = [];
            const allElements = document.querySelectorAll('*');
            allElements.forEach(el => {
                const styles = window.getComputedStyle(el);
                if (styles.display === 'none' && el.className && el.className.includes('AknDefault')) {
                    issues.push({
                        tag: el.tagName,
                        class: el.className,
                        display: styles.display
                    });
                }
            });
            return issues.slice(0, 10); // First 10 issues
        });
        
        console.log('\n=== HIDDEN ELEMENTS WITH ISSUES ===');
        console.log(JSON.stringify(missingStyles, null, 2));
        
        console.log('\n=== TAKING SCREENSHOT ===');
        await page.screenshot({ path: '/tmp/pim_ui_detailed.png', fullPage: true });
        
        console.log('\n=== CONSOLE MESSAGES SUMMARY ===');
        const errorCount = consoleMessages.filter(m => m.type === 'error').length;
        const warningCount = consoleMessages.filter(m => m.type === 'warning').length;
        console.log(`Errors: ${errorCount}, Warnings: ${warningCount}`);
        
    } catch (error) {
        console.error('Script error:', error.message);
    } finally {
        await browser.close();
    }
})();
