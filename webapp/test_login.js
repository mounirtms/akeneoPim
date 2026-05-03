const { chromium } = require('playwright');

(async () => {
    const browser = await chromium.launch({ headless: true });
    const context = await browser.newContext();
    const page = await context.newPage();
    
    console.log('=== AKENEO PIM LOGIN TEST ===\n');
    
    // Test multiple possible URLs
    const urls = [
        'https://ded701.inmotionhosting.com/public/',
        'https://ded701.inmotionhosting.com/public/index.php',
        'https://ded701.inmotionhosting.com/',
        'https://ded701.inmotionhosting.com/index.php'
    ];
    
    let workingUrl = null;
    
    for (const url of urls) {
        try {
            console.log(`Testing URL: ${url}`);
            const response = await page.goto(url, { waitUntil: 'networkidle', timeout: 30000 });
            const title = await page.title();
            const statusCode = response.status();
            
            console.log(`  Status: ${statusCode}`);
            console.log(`  Title: ${title}`);
            
            if (statusCode === 200 && !title.includes('404') && !title.includes('Error')) {
                workingUrl = url;
                console.log(`  ✓ This URL works!\n`);
                break;
            }
            console.log(`  ✗ Not the right URL\n`);
        } catch (error) {
            console.log(`  ✗ Error: ${error.message}\n`);
        }
    }
    
    if (!workingUrl) {
        console.log('ERROR: Could not find working URL');
        await browser.close();
        process.exit(1);
    }
    
    console.log(`\n=== ATTEMPTING LOGIN ===`);
    console.log(`Working URL: ${workingUrl}\n`);
    
    // Wait for login form
    try {
        await page.waitForSelector('input[name="_username"], input#username, input[type="text"]', { timeout: 10000 });
        console.log('✓ Login form found');
        
        // Try different login credentials
        const credentials = [
            { username: 'admin', password: 'admin' },
            { username: 'finaladmin', password: 'Admin@2024!' }
        ];
        
        for (const cred of credentials) {
            console.log(`\nTrying credentials: ${cred.username} / ${cred.password}`);
            
            // Fill in the form
            await page.fill('input[name="_username"], input#username, input[type="text"]', cred.username);
            await page.fill('input[name="_password"], input#password, input[type="password"]', cred.password);
            
            // Take screenshot before login
            await page.screenshot({ path: '/home/pim/public_html/webapp/before_login.png', fullPage: true });
            console.log('Screenshot saved: before_login.png');
            
            // Submit the form
            await page.click('button[type="submit"], input[type="submit"], .login-button');
            
            // Wait for navigation
            await page.waitForLoadState('networkidle', { timeout: 15000 });
            
            const afterLoginUrl = page.url();
            const afterLoginTitle = await page.title();
            
            console.log(`After login URL: ${afterLoginUrl}`);
            console.log(`After login title: ${afterLoginTitle}`);
            
            // Take screenshot after login
            await page.screenshot({ path: '/home/pim/public_html/webapp/after_login.png', fullPage: true });
            console.log('Screenshot saved: after_login.png');
            
            // Check if login was successful
            if (afterLoginUrl.includes('dashboard') || afterLoginUrl !== workingUrl || afterLoginTitle.includes('Dashboard')) {
                console.log(`\n✓✓✓ LOGIN SUCCESSFUL with ${cred.username}! ✓✓✓`);
                
                // Get console errors
                const errors = [];
                page.on('console', msg => {
                    if (msg.type() === 'error') {
                        errors.push(msg.text());
                    }
                });
                
                // Wait a bit to capture any errors
                await page.waitForTimeout(3000);
                
                if (errors.length > 0) {
                    console.log('\nConsole Errors:');
                    errors.forEach(err => console.log(`  - ${err}`));
                }
                
                break;
            } else {
                console.log(`✗ Login failed with ${cred.username}`);
                
                // Check for error messages
                const errorMsg = await page.textContent('body').catch(() => '');
                if (errorMsg.includes('Invalid') || errorMsg.includes('incorrect') || errorMsg.includes('error')) {
                    console.log(`Error message: ${errorMsg.substring(0, 200)}`);
                }
            }
        }
        
    } catch (error) {
        console.log(`✗ Login attempt failed: ${error.message}`);
        await page.screenshot({ path: '/home/pim/public_html/webapp/error_page.png', fullPage: true });
        console.log('Error screenshot saved: error_page.png');
    }
    
    console.log('\n=== TEST COMPLETE ===');
    await browser.close();
})();
