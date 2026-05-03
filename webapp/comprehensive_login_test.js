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
    
    log('=== COMPREHENSIVE AKENEO PIM LOGIN TEST ===\n');
    
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
    
    // Test URLs in order of likelihood
    const urls = [
        'https://ded701.inmotionhosting.com/index.php',
        'https://ded701.inmotionhosting.com/',
        'http://ded701.inmotionhosting.com/index.php',
        'http://ded701.inmotionhosting.com/'
    ];
    
    let workingUrl = null;
    let loginPageFound = false;
    
    for (const url of urls) {
        try {
            log(`\nTesting URL: ${url}`);
            const response = await page.goto(url, { 
                waitUntil: 'domcontentloaded', 
                timeout: 30000 
            });
            
            const statusCode = response.status();
            const title = await page.title();
            const bodyText = await page.textContent('body').catch(() => '');
            
            log(`  Status: ${statusCode}`);
            log(`  Title: ${title}`);
            
            // Check if this is the Akeneo login page
            const hasLoginForm = await page.locator('input[name="_username"], input[type="text"][autocomplete="username"]').count() > 0;
            const hasPasswordField = await page.locator('input[name="_password"], input[type="password"]').count() > 0;
            const isAkeneo = bodyText.includes('Akeneo') || title.includes('Akeneo') || title.includes('PIM');
            
            log(`  Has login form: ${hasLoginForm}`);
            log(`  Has password field: ${hasPasswordField}`);
            log(`  Is Akeneo: ${isAkeneo}`);
            
            if (statusCode === 200 && (hasLoginForm || isAkeneo)) {
                workingUrl = url;
                loginPageFound = hasLoginForm && hasPasswordField;
                log(`  ✓✓✓ THIS IS THE AKENEO LOGIN PAGE! ✓✓✓\n`);
                await page.screenshot({ path: '/home/pim/public_html/webapp/login_page_found.png', fullPage: true });
                break;
            } else if (statusCode === 200) {
                log(`  ⚠ Page loads but no login form detected`);
            } else {
                log(`  ✗ Not working (status: ${statusCode})\n`);
            }
        } catch (error) {
            log(`  ✗ Error: ${error.message}\n`);
        }
    }
    
    if (!workingUrl) {
        log('\n❌ FATAL: Could not find a working Akeneo PIM URL');
        log('\nPlease check:');
        log('1. Web server is running');
        log('2. PHP is configured correctly');
        log('3. Akeneo is properly deployed');
        
        fs.writeFileSync('/home/pim/public_html/webapp/LOGIN_TEST_REPORT.txt', report.join('\n'));
        await browser.close();
        process.exit(1);
    }
    
    if (!loginPageFound) {
        log('\n⚠ Working URL found but login form not detected');
        log(`URL: ${workingUrl}`);
        log('Taking diagnostic screenshot...');
        await page.screenshot({ path: '/home/pim/public_html/webapp/page_content.png', fullPage: true });
    }
    
    log(`\n=== ATTEMPTING LOGIN ===`);
    log(`URL: ${workingUrl}\n`);
    
    // Define credentials to try
    const credentials = [
        { username: 'admin', password: 'admin', name: 'Default Admin' },
        { username: 'finaladmin', password: 'Admin@2024!', name: 'Final Admin' }
    ];
    
    let loginSuccess = false;
    
    for (const cred of credentials) {
        try {
            log(`\n--- Trying: ${cred.name} (${cred.username}) ---`);
            
            // Wait for and find username field
            await page.waitForSelector('input[name="_username"], input[type="text"]', { timeout: 5000 });
            
            // Clear and fill username
            const usernameField = page.locator('input[name="_username"], input[type="text"]').first();
            await usernameField.clear();
            await usernameField.fill(cred.username);
            log(`✓ Username entered: ${cred.username}`);
            
            // Clear and fill password
            const passwordField = page.locator('input[name="_password"], input[type="password"]').first();
            await passwordField.clear();
            await passwordField.fill(cred.password);
            log('✓ Password entered');
            
            // Take screenshot before submitting
            await page.screenshot({ path: `/home/pim/public_html/webapp/before_login_${cred.username}.png` });
            log(`✓ Screenshot saved: before_login_${cred.username}.png`);
            
            // Find and click submit button
            const submitButton = page.locator('button[type="submit"], input[type="submit"], .btn-primary').first();
            await submitButton.click();
            log('✓ Login button clicked');
            
            // Wait for navigation or error
            await Promise.race([
                page.waitForURL(url => url !== workingUrl, { timeout: 10000 }),
                page.waitForSelector('.alert-error, .error, .alert-danger', { timeout: 10000 }).catch(() => null)
            ]);
            
            await page.waitForTimeout(2000);
            
            const currentUrl = page.url();
            const currentTitle = await page.title();
            
            log(`Current URL: ${currentUrl}`);
            log(`Current Title: ${currentTitle}`);
            
            // Take screenshot after login attempt
            await page.screenshot({ path: `/home/pim/public_html/webapp/after_login_${cred.username}.png`, fullPage: true });
            log(`✓ Screenshot saved: after_login_${cred.username}.png`);
            
            // Check for error messages
            const errorMsg = await page.locator('.alert-error, .error, .alert-danger, .form-error').textContent().catch(() => null);
            if (errorMsg) {
                log(`✗ Error message: ${errorMsg}`);
                continue;
            }
            
            // Check if login was successful
            if (currentUrl !== workingUrl || 
                currentTitle.toLowerCase().includes('dashboard') ||
                currentTitle.toLowerCase().includes('home') ||
                await page.locator('.AknHeader, .navigation, .oro-navigation').count() > 0) {
                
                log(`\n✓✓✓ LOGIN SUCCESSFUL! ✓✓✓`);
                log(`Logged in as: ${cred.username}`);
                log(`Current page: ${currentTitle}`);
                loginSuccess = true;
                
                // Wait a bit and capture any console errors
                await page.waitForTimeout(3000);
                
                // Take final screenshot of dashboard
                await page.screenshot({ path: '/home/pim/public_html/webapp/dashboard_view.png', fullPage: true });
                log('✓ Dashboard screenshot saved: dashboard_view.png');
                
                break;
            } else {
                log(`✗ Login failed - still on login page`);
            }
            
        } catch (error) {
            log(`✗ Login attempt error: ${error.message}`);
        }
        
        // Reload page for next attempt
        if (!loginSuccess) {
            await page.goto(workingUrl, { waitUntil: 'domcontentloaded' });
        }
    }
    
    // Report results
    log('\n=== TEST SUMMARY ===');
    log(`Working URL: ${workingUrl || 'NOT FOUND'}`);
    log(`Login Form Found: ${loginPageFound ? 'YES' : 'NO'}`);
    log(`Login Success: ${loginSuccess ? 'YES ✓' : 'NO ✗'}`);
    
    if (consoleMessages.length > 0) {
        log('\n=== BROWSER CONSOLE MESSAGES ===');
        consoleMessages.slice(0, 10).forEach(msg => log(msg));
    }
    
    if (networkErrors.length > 0) {
        log('\n=== NETWORK ERRORS (HTTP 4xx/5xx) ===');
        networkErrors.slice(0, 10).forEach(err => log(err));
    }
    
    log('\n=== TEST COMPLETE ===');
    
    // Save report
    fs.writeFileSync('/home/pim/public_html/webapp/LOGIN_TEST_REPORT.txt', report.join('\n'));
    log('\nFull report saved to: LOGIN_TEST_REPORT.txt');
    
    await browser.close();
    
    process.exit(loginSuccess ? 0 : 1);
})();
