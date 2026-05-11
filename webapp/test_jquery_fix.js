const puppeteer = require('puppeteer');

(async () => {
    const browser = await puppeteer.launch({ 
        headless: true,
        args: ['--no-sandbox', '--disable-setuid-sandbox']
    });
    const page = await browser.newPage();
    
    // Monitor console
    const logs = [];
    page.on('console', msg => {
        const text = msg.text();
        logs.push(text);
        console.log('[BROWSER]', text);
    });
    
    // Monitor errors
    const errors = [];
    page.on('pageerror', err => {
        errors.push(err.message);
        console.log('[ERROR]', err.message);
    });
    
    try {
        console.log('Loading login page...');
        await page.goto('https://pim.technostationery.com/user/login', { 
            waitUntil: 'networkidle2',
            timeout: 30000 
        });
        
        await page.waitForTimeout(2000);
        
        console.log('\n--- LOGIN PAGE ANALYSIS ---');
        
        // Check if jQuery loaded
        const jQueryVersion = await page.evaluate(() => {
            return typeof jQuery !== 'undefined' ? jQuery.fn.jquery : 'NOT LOADED';
        });
        console.log('jQuery version:', jQueryVersion);
        
        // Fill and submit form
        console.log('Filling login form...');
        await page.type('input[name="_username"]', 'mounir');
        await page.type('input[name="_password"]', '2026');
        
        console.log('Submitting login...');
        await page.click('button[type="submit"]');
        
        await page.waitForNavigation({ waitUntil: 'networkidle2', timeout: 30000 });
        await page.waitForTimeout(3000);
        
        const finalUrl = page.url();
        console.log('\n--- AFTER LOGIN ---');
        console.log('URL:', finalUrl);
        
        // Check jQuery again
        const jQueryAfterLogin = await page.evaluate(() => {
            return typeof jQuery !== 'undefined' ? jQuery.fn.jquery : 'NOT LOADED';
        });
        console.log('jQuery version:', jQueryAfterLogin);
        
        // Check for menu/navigation
        const hasMenu = await page.evaluate(() => {
            return document.querySelector('.AknDefault-mainMenu') !== null ||
                   document.querySelector('nav') !== null ||
                   document.querySelector('[role="navigation"]') !== null;
        });
        console.log('Menu visible:', hasMenu);
        
        // Summary
        console.log('\n--- SUMMARY ---');
        console.log('Console logs:', logs.length);
        console.log('JavaScript errors:', errors.length);
        if (errors.length > 0) {
            console.log('Errors:', errors);
        }
        
        await page.screenshot({ path: 'jquery_fix_test.png', fullPage: true });
        console.log('Screenshot saved: jquery_fix_test.png');
        
    } catch (err) {
        console.error('Test failed:', err.message);
    } finally {
        await browser.close();
    }
})();
