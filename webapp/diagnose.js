const { chromium } = require('playwright');

(async () => {
    const browser = await chromium.launch({ headless: true, args: ['--no-sandbox'] });
    const context = await browser.newContext({ ignoreHTTPSErrors: true });
    const page = await context.newPage();
    
    const errors = [];
    const failedRequests = [];
    const consoleErrors = [];
    
    // Capture all errors
    page.on('pageerror', error => {
        errors.push({ type: 'pageerror', message: error.message.substring(0, 200) });
    });
    
    page.on('console', msg => {
        if (msg.type() === 'error') {
            consoleErrors.push(msg.text().substring(0, 200));
        }
    });
    
    // Capture failed requests
    page.on('response', response => {
        if (response.status() >= 400) {
            failedRequests.push({
                url: response.url().substring(0, 150),
                status: response.status(),
                statusText: response.statusText()
            });
        }
    });
    
    // Login with new password
    console.log('=== LOGGING IN ===');
    await page.goto('https://pim.technostationery.com/user/login', { waitUntil: 'networkidle', timeout: 30000 });
    await page.fill('#_username', 'admin');
    await page.fill('#_password', 'kVjW3GxKZCe9!!$');
    await page.click('button[type="submit"], input[type="submit"], .AknLogin-submit');
    
    try {
        await page.waitForURL('**/pim.technostationery.com/**', { timeout: 15000 });
    } catch(e) {
        console.log('URL after login attempt: ' + page.url());
    }
    
    console.log('Current URL: ' + page.url());
    await page.waitForTimeout(5000);
    
    // Check announcements endpoint
    console.log('\n=== TESTING REST ENDPOINTS ===');
    const endpoints = [
        '/rest/announcements',
        '/rest/new_announcements',
        '/enrich/product/',
        '/rest/catalogs/locales',
        '/rest/user/',
        '/rest/catalogs/categories'
    ];
    
    for (const ep of endpoints) {
        try {
            const resp = await page.evaluate(async (url) => {
                try {
                    const r = await fetch(url);
                    const text = await r.text();
                    return {
                        status: r.status,
                        contentType: r.headers.get('content-type'),
                        body: text.substring(0, 300),
                        isJson: text.trim().startsWith('{') || text.trim().startsWith('[')
                    };
                } catch(e) {
                    return { error: e.message };
                }
            }, ep);
            console.log(`${ep}: status=${resp.status}, isJson=${resp.isJson}, ct=${resp.contentType}`);
            if (!resp.isJson && resp.body) {
                console.log(`  Body preview: ${resp.body.substring(0, 100)}`);
            }
        } catch(e) {
            console.log(`${ep}: Error - ${e.message}`);
        }
    }
    
    // Check for __moduleConfig
    console.log('\n=== CHECKING __moduleConfig ===');
    const moduleConfigCheck = await page.evaluate(() => {
        return {
            hasModuleConfig: typeof __moduleConfig !== 'undefined',
            hasRequire: typeof require !== 'undefined',
            hasRequireJs: typeof requirejs !== 'undefined',
            windowKeys: Object.keys(window).filter(k => k.includes('module') || k.includes('Module') || k.includes('config') || k.includes('Config')).join(', ')
        };
    }).catch(e => ({ error: e.message }));
    console.log('moduleConfig:', JSON.stringify(moduleConfigCheck));
    
    // Check CSS/styles
    console.log('\n=== CHECKING STYLES ===');
    const styleCheck = await page.evaluate(() => {
        const stylesheets = Array.from(document.querySelectorAll('link[rel="stylesheet"]')).map(l => l.href);
        const styles = Array.from(document.querySelectorAll('style')).length;
        const body = document.body;
        const computed = window.getComputedStyle(body);
        return {
            stylesheetCount: stylesheets.length,
            stylesheets: stylesheets.slice(0, 10),
            inlineStyleCount: styles,
            bodyBg: computed.backgroundColor,
            bodyFont: computed.fontFamily
        };
    });
    console.log('Styles:', JSON.stringify(styleCheck, null, 2));
    
    // Check menu and navigation
    console.log('\n=== CHECKING NAVIGATION ===');
    const navCheck = await page.evaluate(() => {
        const menu = document.querySelector('.AknHeader');
        const links = menu ? Array.from(menu.querySelectorAll('a')).map(a => ({
            text: a.textContent.trim(),
            href: a.getAttribute('href')
        })) : [];
        return { menuExists: !!menu, menuHtml: menu?.innerHTML?.substring(0, 500), links };
    });
    console.log('Nav:', JSON.stringify(navCheck, null, 2));
    
    // Summary
    console.log('\n=== SUMMARY ===');
    console.log(`Page errors: ${errors.length}`);
    errors.slice(0, 10).forEach(e => console.log(`  - ${e.message}`));
    console.log(`\nFailed requests: ${failedRequests.length}`);
    failedRequests.slice(0, 15).forEach(r => console.log(`  - ${r.status} ${r.url}`));
    console.log(`\nConsole errors: ${consoleErrors.length}`);
    consoleErrors.slice(0, 10).forEach(e => console.log(`  - ${e}`));
    
    await browser.close();
})();
