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
    
    log('=== AKENEO PIM COMPREHENSIVE LOGIN TEST ===\n');
    log('Test Date: ' + new Date().toISOString());
    log('');
    
    // Capture console messages
    const consoleMessages = [];
    page.on('console', msg => {
        consoleMessages.push(`[${msg.type()}] ${msg.text()}`);
    });
    
    // Capture network errors
    const networkErrors = [];
    page.on('response', response => {
        if (response.status() >= 400) {
            networkErrors.push(`${response.status()} - ${response.url()}`);
        }
    });
    
    // Test the development server URL
    const testUrl = 'http://205.134.249.177:8000/index.php';
    
    try {
        log(`Testing Akeneo PIM at: ${testUrl}\n`);
        
        const response = await page.goto(testUrl, { 
            waitUntil: 'domcontentloaded', 
            timeout: 30000 
        });
        
        const statusCode = response.status();
        const title = await page.title();
        
        log(`✓ Page loaded successfully`);
        log(`  Status Code: ${statusCode}`);
        log(`  Page Title: ${title}`);
        
        // Wait a bit for dynamic content
        await page.waitForTimeout(2000);
        
        // Check if this is the Akeneo login page
        const hasLoginForm = await page.locator('input[name="_username"], input[type="text"]').count() > 0;
        const hasPasswordField = await page.locator('input[name="_password"], input[type="password"]').count() > 0;
        
        log(`  Login Form Present: ${hasLoginForm ? 'YES' : 'NO'}`);
        log(`  Password Field Present: ${hasPasswordField ? 'YES' : 'NO'}`);
        
        // Take screenshot of login page
        await page.screenshot({ path: '/home/pim/public_html/webapp/akeneo_login_page.png', fullPage: true });
        log(`  Screenshot saved: akeneo_login_page.png`);
        
        if (!hasLoginForm || !hasPasswordField) {
            log('\n⚠ WARNING: Login form not detected!');
            log('Page content preview:');
            const bodyText = await page.textContent('body').catch(() => 'Unable to read body');
            log(bodyText.substring(0, 500));
            
            fs.writeFileSync('/home/pim/public_html/webapp/AKENEO_TEST_REPORT.txt', report.join('\n'));
            await browser.close();
            process.exit(1);
        }
        
        log('\n=== ATTEMPTING LOGIN ===\n');
        
        // Define credentials to try
        const credentials = [
            { username: 'admin', password: 'admin', name: 'Default Admin' },
            { username: 'finaladmin', password: 'Admin@2024!', name: 'Final Admin' }
        ];
        
        let loginSuccess = false;
        let successfulCred = null;
        
        for (const cred of credentials) {
            try {
                log(`--- Attempt: ${cred.name} (${cred.username}) ---`);
                
                // Find and fill username
                const usernameField = page.locator('input[name="_username"], input[type="text"]').first();
                await usernameField.clear();
                await usernameField.fill(cred.username);
                log(`✓ Username entered: ${cred.username}`);
                
                // Find and fill password
                const passwordField = page.locator('input[name="_password"], input[type="password"]').first();
                await passwordField.clear();
                await passwordField.fill(cred.password);
                log(`✓ Password entered`);
                
                // Take screenshot before login
                await page.screenshot({ 
                    path: `/home/pim/public_html/webapp/before_login_${cred.username}.png`,
                    fullPage: true 
                });
                
                // Find and click submit button
                const submitButton = page.locator('button[type="submit"], input[type="submit"], .btn-primary').first();
                await submitButton.click();
                log(`✓ Login button clicked`);
                
                // Wait for navigation or error message
                try {
                    await Promise.race([
                        page.waitForURL(url => !url.includes('login') && url !== testUrl, { timeout: 10000 }),
                        page.waitForSelector('.alert-danger, .alert-error, .error', { timeout: 10000 })
                    ]);
                } catch (e) {
                    // Timeout is okay, we'll check the URL below
                }
                
                await page.waitForTimeout(3000);
                
                const currentUrl = page.url();
                const currentTitle = await page.title();
                
                log(`  Current URL: ${currentUrl}`);
                log(`  Current Title: ${currentTitle}`);
                
                // Take screenshot after login
                await page.screenshot({ 
                    path: `/home/pim/public_html/webapp/after_login_${cred.username}.png`,
                    fullPage: true 
                });
                log(`  Screenshot saved: after_login_${cred.username}.png`);
                
                // Check for error messages
                const errorElement = await page.locator('.alert-danger, .alert-error, .error, .flash-error').first();
                const errorVisible = await errorElement.isVisible().catch(() => false);
                
                if (errorVisible) {
                    const errorText = await errorElement.textContent();
                    log(`✗ Login Error: ${errorText.trim()}`);
                    
                    // Reload page for next attempt
                    await page.goto(testUrl, { waitUntil: 'domcontentloaded' });
                    continue;
                }
                
                // Check if login was successful
                const isDashboard = currentTitle.toLowerCase().includes('dashboard') || 
                                   currentTitle.toLowerCase().includes('home') ||
                                   currentUrl.includes('dashboard') ||
                                   currentUrl !== testUrl;
                
                const hasNavigation = await page.locator('.AknHeader, .oro-navigation, nav.navbar').count() > 0;
                
                if (isDashboard || hasNavigation || currentUrl !== testUrl) {
                    log(`\n✓✓✓ LOGIN SUCCESSFUL! ✓✓✓`);
                    log(`Credentials: ${cred.username}`);
                    log(`Dashboard Title: ${currentTitle}`);
                    log(`Dashboard URL: ${currentUrl}`);
                    
                    loginSuccess = true;
                    successfulCred = cred;
                    
                    // Take final dashboard screenshot
                    await page.waitForTimeout(2000);
                    await page.screenshot({ 
                        path: '/home/pim/public_html/webapp/akeneo_dashboard.png',
                        fullPage: true 
                    });
                    log(`✓ Dashboard screenshot saved: akeneo_dashboard.png`);
                    
                    // Check for any console errors
                    const errors = consoleMessages.filter(msg => msg.startsWith('[error]'));
                    if (errors.length > 0) {
                        log(`\n⚠ Console Errors Detected (${errors.length}):`);
                        errors.slice(0, 5).forEach(err => log(`  - ${err}`));
                    }
                    
                    break;
                } else {
                    log(`✗ Login failed - still on login page`);
                    await page.goto(testUrl, { waitUntil: 'domcontentloaded' });
                }
                
            } catch (error) {
                log(`✗ Error during login: ${error.message}`);
                await page.screenshot({ 
                    path: `/home/pim/public_html/webapp/error_${cred.username}.png` 
                });
            }
            
            log('');
        }
        
        // Final Report
        log('\n========================================');
        log('===        TEST SUMMARY             ===');
        log('========================================');
        log(`Server URL: ${testUrl}`);
        log(`Server Status: ONLINE`);
        log(`Login Form: FOUND`);
        log(`Login Success: ${loginSuccess ? 'YES ✓✓✓' : 'NO ✗'}`);
        if (successfulCred) {
            log(`Successful Credentials: ${successfulCred.username}`);
        }
        log('');
        
        if (networkErrors.length > 0) {
            log(`Network Errors (HTTP 4xx/5xx): ${networkErrors.length}`);
            networkErrors.slice(0, 5).forEach(err => log(`  - ${err}`));
            log('');
        }
        
        if (consoleMessages.length > 0) {
            const errorCount = consoleMessages.filter(m => m.startsWith('[error]')).length;
            const warnCount = consoleMessages.filter(m => m.startsWith('[warning]')).length;
            log(`Browser Console Messages: ${consoleMessages.length} (Errors: ${errorCount}, Warnings: ${warnCount})`);
        }
        
        log('========================================\n');
        log(`Access Akeneo PIM at: http://205.134.249.177:8000/`);
        log(`Credentials: admin / admin  OR  finaladmin / Admin@2024!`);
        log('');
        
        // Save report
        fs.writeFileSync('/home/pim/public_html/webapp/AKENEO_TEST_REPORT.txt', report.join('\n'));
        log('Full report saved to: AKENEO_TEST_REPORT.txt');
        
        await browser.close();
        process.exit(loginSuccess ? 0 : 1);
        
    } catch (error) {
        log(`\n❌ FATAL ERROR: ${error.message}`);
        log(`Stack: ${error.stack}`);
        
        await page.screenshot({ 
            path: '/home/pim/public_html/webapp/fatal_error.png',
            fullPage: true 
        });
        log('Error screenshot saved: fatal_error.png');
        
        fs.writeFileSync('/home/pim/public_html/webapp/AKENEO_TEST_REPORT.txt', report.join('\n'));
        await browser.close();
        process.exit(1);
    }
})();
