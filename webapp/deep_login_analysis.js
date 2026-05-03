const { chromium } = require('playwright');
const fs = require('fs');

(async () => {
    const browser = await chromium.launch({ 
        headless: true,
        args: ['--no-sandbox', '--disable-setuid-sandbox']
    });
    const context = await browser.newContext({
        ignoreHTTPSErrors: true
    });
    const page = await context.newPage();
    
    const report = [];
    const log = (msg) => {
        console.log(msg);
        report.push(msg);
    };
    
    log('=== DEEP CSS AND LOGIN ANALYSIS ===\n');
    
    // Capture all network requests
    const failedResources = [];
    const loadedResources = [];
    
    page.on('response', response => {
        const url = response.url();
        const status = response.status();
        
        if (status >= 400) {
            failedResources.push(`${status} - ${url}`);
        } else if (status === 200 && (url.includes('.css') || url.includes('.js') || url.includes('.svg'))) {
            loadedResources.push(`${status} - ${url}`);
        }
    });
    
    // Capture console messages
    const consoleMessages = [];
    page.on('console', msg => {
        consoleMessages.push(`[${msg.type()}] ${msg.text()}`);
    });
    
    const testUrl = 'http://205.134.249.177:8000/index.php';
    
    try {
        log(`Testing: ${testUrl}\n`);
        
        await page.goto(testUrl, { 
            waitUntil: 'networkidle', 
            timeout: 30000 
        });
        
        await page.waitForTimeout(3000);
        
        log('=== LOADED RESOURCES ===');
        loadedResources.forEach(r => log(r));
        
        log('\n=== FAILED RESOURCES ===');
        if (failedResources.length > 0) {
            failedResources.forEach(r => log(r));
        } else {
            log('None - all resources loaded successfully!');
        }
        
        log('\n=== CSS ANALYSIS ===');
        
        // Check if CSS file is actually loaded
        const cssLoaded = await page.evaluate(() => {
            const links = Array.from(document.querySelectorAll('link[rel="stylesheet"]'));
            return links.map(link => ({
                href: link.href,
                loaded: link.sheet !== null,
                rules: link.sheet ? link.sheet.cssRules.length : 0
            }));
        });
        
        log('CSS Files:');
        cssLoaded.forEach(css => {
            log(`  ${css.href}`);
            log(`    Loaded: ${css.loaded ? 'YES' : 'NO'}`);
            log(`    Rules: ${css.rules}`);
        });
        
        log('\n=== COMPUTED STYLES CHECK ===');
        
        // Check actual computed styles on key elements
        const styleCheck = await page.evaluate(() => {
            const body = document.querySelector('body');
            const loginWrapper = document.querySelector('.AuthenticationWrapper');
            const form = document.querySelector('.Form');
            const button = document.querySelector('button[type="submit"]');
            
            const getStyles = (el, props) => {
                if (!el) return 'ELEMENT NOT FOUND';
                const computed = window.getComputedStyle(el);
                const result = {};
                props.forEach(prop => {
                    result[prop] = computed.getPropertyValue(prop);
                });
                return result;
            };
            
            return {
                body: getStyles(body, ['background-color', 'font-family', 'margin']),
                loginWrapper: getStyles(loginWrapper, ['display', 'background', 'padding']),
                form: getStyles(form, ['width', 'margin', 'padding']),
                button: getStyles(button, ['background-color', 'color', 'padding', 'border'])
            };
        });
        
        log('Body styles:', JSON.stringify(styleCheck.body, null, 2));
        log('Login wrapper styles:', JSON.stringify(styleCheck.loginWrapper, null, 2));
        log('Form styles:', JSON.stringify(styleCheck.form, null, 2));
        log('Button styles:', JSON.stringify(styleCheck.button, null, 2));
        
        log('\n=== ATTEMPTING FULL LOGIN FLOW ===\n');
        
        // Fill and submit login
        await page.fill('input[name="_username"]', 'admin');
        await page.fill('input[name="_password"]', 'admin');
        
        log('✓ Credentials entered');
        
        await page.screenshot({ 
            path: '/home/pim/public_html/webapp/login_before_submit.png', 
            fullPage: true 
        });
        log('✓ Screenshot taken: login_before_submit.png');
        
        // Click submit
        await page.click('button[type="submit"]');
        log('✓ Submit button clicked');
        
        // Wait for navigation
        try {
            await page.waitForNavigation({ timeout: 15000 });
            log('✓ Navigation occurred');
        } catch (e) {
            log('⚠ Navigation timeout (might still be successful)');
        }
        
        await page.waitForTimeout(5000);
        
        const finalUrl = page.url();
        const finalTitle = await page.title();
        
        log(`\nFinal URL: ${finalUrl}`);
        log(`Final Title: ${finalTitle}`);
        
        // Take screenshot of final page
        await page.screenshot({ 
            path: '/home/pim/public_html/webapp/after_login_dashboard.png', 
            fullPage: true 
        });
        log('✓ Dashboard screenshot: after_login_dashboard.png');
        
        // Check for dashboard elements
        const dashboardCheck = await page.evaluate(() => {
            const selectors = [
                '.AknHeader',
                '.oro-navigation',
                'nav',
                '#container',
                '.navigation',
                '[data-toggle="dropdown"]'
            ];
            
            const found = {};
            selectors.forEach(sel => {
                const el = document.querySelector(sel);
                found[sel] = el ? 'FOUND' : 'NOT FOUND';
            });
            
            return found;
        });
        
        log('\n=== DASHBOARD ELEMENTS CHECK ===');
        Object.keys(dashboardCheck).forEach(sel => {
            log(`${sel}: ${dashboardCheck[sel]}`);
        });
        
        // Check for error messages
        const errorCheck = await page.evaluate(() => {
            const errorSelectors = [
                '.alert-error',
                '.alert-danger',
                '.flash-error',
                '.error-message'
            ];
            
            const errors = [];
            errorSelectors.forEach(sel => {
                const el = document.querySelector(sel);
                if (el) {
                    errors.push({
                        selector: sel,
                        text: el.textContent.trim()
                    });
                }
            });
            
            return errors;
        });
        
        if (errorCheck.length > 0) {
            log('\n=== ERROR MESSAGES FOUND ===');
            errorCheck.forEach(err => {
                log(`${err.selector}: ${err.text}`);
            });
        }
        
        // Get full page HTML of current page
        const currentHTML = await page.content();
        fs.writeFileSync('/home/pim/public_html/webapp/current_page.html', currentHTML);
        log('\n✓ Saved full HTML to: current_page.html');
        
        log('\n=== CONSOLE MESSAGES ===');
        consoleMessages.forEach(msg => log(msg));
        
        // Determine success
        const isLoggedIn = !finalUrl.includes('login') || 
                          finalTitle.toLowerCase().includes('dashboard') ||
                          dashboardCheck['.AknHeader'] === 'FOUND' ||
                          dashboardCheck['.oro-navigation'] === 'FOUND';
        
        log('\n=== FINAL VERDICT ===');
        log(`Login Successful: ${isLoggedIn ? 'YES ✓✓✓' : 'NO ✗'}`);
        log(`Still on login page: ${finalUrl.includes('login') ? 'YES (PROBLEM)' : 'NO (GOOD)'}`);
        
        fs.writeFileSync('/home/pim/public_html/webapp/DEEP_ANALYSIS_REPORT.txt', report.join('\n'));
        
        await browser.close();
        process.exit(isLoggedIn ? 0 : 1);
        
    } catch (error) {
        log(`\n❌ ERROR: ${error.message}`);
        log(error.stack);
        
        await page.screenshot({ 
            path: '/home/pim/public_html/webapp/error_screenshot.png',
            fullPage: true 
        });
        
        fs.writeFileSync('/home/pim/public_html/webapp/DEEP_ANALYSIS_REPORT.txt', report.join('\n'));
        await browser.close();
        process.exit(1);
    }
})();
