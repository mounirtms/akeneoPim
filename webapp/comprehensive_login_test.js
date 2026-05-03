const { chromium } = require('playwright');
const fs = require('fs');

(async () => {
    const browser = await chromium.launch({ 
        headless: true,
        args: ['--no-sandbox', '--disable-setuid-sandbox']
    });
    const context = await browser.newContext();
    const page = await context.newPage();
    
    const report = [];
    const log = (msg) => {
        console.log(msg);
        report.push(msg);
    };
    
    log('=== COMPREHENSIVE LOGIN TEST (Session 3) ===\n');
    
    // Capture errors
    const errors = [];
    page.on('console', msg => {
        if (msg.type() === 'error') {
            errors.push(msg.text());
        }
    });
    
    const testUrl = 'http://205.134.249.177:8000/index.php';
    
    try {
        log('Step 1: Loading login page...');
        await page.goto(testUrl, { waitUntil: 'networkidle', timeout: 30000 });
        log('✓ Page loaded\n');
        
        log('Step 2: Checking page content...');
        const title = await page.title();
        const hasUsername = await page.locator('input[name="_username"]').count();
        const hasPassword = await page.locator('input[name="_password"]').count();
        
        log(`  Title: ${title}`);
        log(`  Username field: ${hasUsername > 0 ? 'Found' : 'NOT FOUND'}`);
        log(`  Password field: ${hasPassword > 0 ? 'Found' : 'NOT FOUND'}`);
        
        if (hasUsername === 0 || hasPassword === 0) {
            log('\n✗ Login form not found! Cannot proceed.');
            await browser.close();
            process.exit(1);
        }
        
        log('\nStep 3: Filling credentials...');
        await page.fill('input[name="_username"]', 'admin');
        await page.fill('input[name="_password"]', 'admin');
        log('✓ Credentials filled: admin/admin\n');
        
        await page.screenshot({ path: '/home/pim/public_html/webapp/final_before_login.png' });
        
        log('Step 4: Submitting login form...');
        await page.click('button[type="submit"]');
        log('✓ Form submitted\n');
        
        log('Step 5: Waiting for response (10 seconds)...');
        await page.waitForTimeout(10000);
        
        const finalUrl = page.url();
        const finalTitle = await page.title();
        
        log('Step 6: Analyzing result...');
        log(`  Final URL: ${finalUrl}`);
        log(`  Final Title: ${finalTitle}`);
        
        // Check page content
        const bodyText = await page.textContent('body').catch(() => '');
        const hasErrorMsg = bodyText.toLowerCase().includes('invalid') || 
                           bodyText.toLowerCase().includes('incorrect');
        
        log(`  Has error message: ${hasErrorMsg ? 'YES' : 'NO'}`);
        
        // Check for Akeneo dashboard elements
        const aknHeader = await page.locator('.AknHeader').count();
        const navigation = await page.locator('.oro-navigation, nav').count();
        const container = await page.locator('#container').count();
        
        log(`  Akeneo header: ${aknHeader}`);
        log(`  Navigation: ${navigation}`);
        log(`  Container: ${container}`);
        
        await page.screenshot({ 
            path: '/home/pim/public_html/webapp/final_after_login.png', 
            fullPage: true 
        });
        
        // Check if we're still on login page
        const stillOnLogin = finalUrl.includes('login');
        const urlChanged = finalUrl !== testUrl;
        const hasDashboardElements = aknHeader > 0 || navigation > 0 || container > 0;
        
        log(`\n  Still on login URL: ${stillOnLogin}`);
        log(`  URL changed: ${urlChanged}`);
        log(`  Has dashboard elements: ${hasDashboardElements}`);
        
        // Determine success
        const isLoggedIn = !stillOnLogin && (urlChanged || hasDashboardElements);
        
        log('\n=== RESULT ===');
        if (isLoggedIn) {
            log('✓✓✓ LOGIN SUCCESSFUL! ✓✓✓');
            log('User has been authenticated and dashboard is accessible!');
        } else {
            log('✗ Login failed - still on login page');
            
            // Check for specific error
            if (hasErrorMsg) {
                log('Reason: Invalid credentials error message displayed');
            } else {
                log('Reason: Unknown - form submits but returns to login');
            }
        }
        
        if (errors.length > 0) {
            log('\nBrowser Console Errors:');
            errors.forEach(err => log(`  - ${err}`));
        }
        
        // Save report
        fs.writeFileSync('/home/pim/public_html/webapp/FINAL_LOGIN_TEST.txt', report.join('\n'));
        
        await browser.close();
        process.exit(isLoggedIn ? 0 : 1);
        
    } catch (error) {
        log(`\n✗ Fatal error: ${error.message}`);
        await page.screenshot({ path: '/home/pim/public_html/webapp/error_final.png' });
        fs.writeFileSync('/home/pim/public_html/webapp/FINAL_LOGIN_TEST.txt', report.join('\n'));
        await browser.close();
        process.exit(1);
    }
})();
