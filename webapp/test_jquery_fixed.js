const playwright = require('playwright');
const fs = require('fs');

(async () => {
    const browser = await playwright.chromium.launch({ headless: true });
    const context = await browser.newContext({ 
        ignoreHTTPSErrors: true,
        viewport: { width: 1920, height: 1080 }
    });
    const page = await context.newPage();
    
    const logs = [];
    const errors = [];
    
    page.on('console', msg => {
        const text = msg.text();
        logs.push(text);
        console.log('[CONSOLE]', text);
    });
    
    page.on('pageerror', err => {
        errors.push(err.message);
        console.log('[ERROR]', err.message);
    });
    
    try {
        console.log('\n=== TESTING JQUERY FIX ===\n');
        
        // Load login page
        console.log('1. Loading login page...');
        await page.goto('https://pim.technostationery.com/user/login', { 
            waitUntil: 'networkidle',
            timeout: 30000 
        });
        await page.waitForTimeout(2000);
        
        // Check jQuery on login page
        const jQueryOnLogin = await page.evaluate(() => {
            return {
                loaded: typeof jQuery !== 'undefined',
                version: typeof jQuery !== 'undefined' ? jQuery.fn.jquery : null,
                globalDollar: typeof $ !== 'undefined',
                globalJQuery: typeof window.jQuery !== 'undefined'
            };
        });
        
        console.log('\n2. jQuery Status on Login Page:');
        console.log('   - jQuery loaded:', jQueryOnLogin.loaded);
        console.log('   - jQuery version:', jQueryOnLogin.version);
        console.log('   - $ available:', jQueryOnLogin.globalDollar);
        console.log('   - window.jQuery available:', jQueryOnLogin.globalJQuery);
        
        await page.screenshot({ path: 'fix_test_1_login.png', fullPage: false });
        
        // Login
        console.log('\n3. Filling login form...');
        await page.fill('input[name="_username"]', 'mounir');
        await page.fill('input[name="_password"]', '2026');
        
        console.log('4. Submitting login...');
        await page.click('button[type="submit"]');
        
        await page.waitForNavigation({ waitUntil: 'networkidle', timeout: 30000 });
        await page.waitForTimeout(5000); // Give time for app to initialize
        
        const url = page.url();
        console.log('\n5. After Login:');
        console.log('   - URL:', url);
        
        // Check jQuery after login
        const jQueryAfterLogin = await page.evaluate(() => {
            return {
                loaded: typeof jQuery !== 'undefined',
                version: typeof jQuery !== 'undefined' ? jQuery.fn.jquery : null,
                globalDollar: typeof $ !== 'undefined',
                globalJQuery: typeof window.jQuery !== 'undefined',
                webpackLoaded: typeof __webpack_require__ !== 'undefined',
                backboneLoaded: typeof Backbone !== 'undefined',
                underscoreLoaded: typeof _ !== 'undefined'
            };
        });
        
        console.log('\n6. jQuery Status on Dashboard:');
        console.log('   - jQuery loaded:', jQueryAfterLogin.loaded);
        console.log('   - jQuery version:', jQueryAfterLogin.version);
        console.log('   - $ available:', jQueryAfterLogin.globalDollar);
        console.log('   - window.jQuery available:', jQueryAfterLogin.globalJQuery);
        console.log('   - Webpack loaded:', jQueryAfterLogin.webpackLoaded);
        console.log('   - Backbone loaded:', jQueryAfterLogin.backboneLoaded);
        console.log('   - Underscore loaded:', jQueryAfterLogin.underscoreLoaded);
        
        // Check for PIM menu elements
        const menuCheck = await page.evaluate(() => {
            const selectors = [
                '.AknDefault-mainMenu',
                '.navigation',
                '[role="navigation"]',
                'nav',
                '.menu',
                '#menu',
                '.sidebar',
                '.main-menu'
            ];
            
            const found = {};
            selectors.forEach(sel => {
                const el = document.querySelector(sel);
                found[sel] = el !== null;
            });
            
            return {
                selectors: found,
                bodyClasses: document.body.className,
                hasApp: document.querySelector('.app') !== null,
                hasRoot: document.querySelector('#root') !== null
            };
        });
        
        console.log('\n7. Menu Detection:');
        console.log('   - Menu selectors found:', JSON.stringify(menuCheck.selectors, null, 2));
        console.log('   - Body classes:', menuCheck.bodyClasses);
        console.log('   - Has .app:', menuCheck.hasApp);
        console.log('   - Has #root:', menuCheck.hasRoot);
        
        await page.screenshot({ path: 'fix_test_2_dashboard.png', fullPage: true });
        
        // Summary
        console.log('\n=== SUMMARY ===');
        console.log('Console logs:', logs.length);
        console.log('JavaScript errors:', errors.length);
        
        if (errors.length > 0) {
            console.log('\n❌ JavaScript Errors Found:');
            errors.forEach((err, i) => {
                console.log(`   ${i+1}. ${err}`);
            });
        } else {
            console.log('\n✅ No JavaScript errors!');
        }
        
        // Check for specific jQuery success message
        const hasJQuerySuccess = logs.some(log => log.includes('jQuery loaded successfully'));
        const hasJQueryError = errors.some(err => err.includes('jQuery is not defined'));
        
        console.log('\nKey Indicators:');
        console.log('   - "jQuery loaded successfully" message:', hasJQuerySuccess ? '✅' : '❌');
        console.log('   - "jQuery is not defined" error:', hasJQueryError ? '❌ PRESENT' : '✅ NOT PRESENT');
        console.log('   - Dashboard loaded:', url.includes('dashboard') ? '✅' : '❌');
        
        // Save report
        const report = {
            timestamp: new Date().toISOString(),
            url,
            jQueryOnLogin,
            jQueryAfterLogin,
            menuCheck,
            logs,
            errors,
            hasJQuerySuccess,
            hasJQueryError,
            screenshots: ['fix_test_1_login.png', 'fix_test_2_dashboard.png']
        };
        
        fs.writeFileSync('jquery_fix_report.json', JSON.stringify(report, null, 2));
        console.log('\n📄 Report saved: jquery_fix_report.json');
        console.log('📸 Screenshots: fix_test_1_login.png, fix_test_2_dashboard.png');
        
    } catch (err) {
        console.error('\n❌ Test failed:', err.message);
    } finally {
        await browser.close();
    }
})();
