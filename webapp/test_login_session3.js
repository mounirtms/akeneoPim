const { chromium } = require('playwright');

(async () => {
    const browser = await chromium.launch({ 
        headless: true,
        args: ['--no-sandbox', '--disable-setuid-sandbox']
    });
    const page = await browser.newPage();
    
    console.log('=== SESSION 3: Testing Login with Fixed Sessions ===\n');
    
    const testUrl = 'http://205.134.249.177:8000/index.php';
    
    try {
        console.log('Loading page...');
        await page.goto(testUrl, { waitUntil: 'networkidle', timeout: 30000 });
        console.log('✓ Page loaded');
        
        // Fill login form
        await page.fill('input[name="_username"]', 'admin');
        await page.fill('input[name="_password"]', 'admin');
        console.log('✓ Credentials entered: admin/admin');
        
        // Screenshot before
        await page.screenshot({ path: '/home/pim/public_html/webapp/session3_before_login.png' });
        
        // Submit
        await page.click('button[type="submit"]');
        console.log('✓ Login submitted');
        
        // Wait for navigation
        await page.waitForTimeout(8000);
        
        const finalUrl = page.url();
        const finalTitle = await page.title();
        
        console.log(`\nAfter Login:`);
        console.log(`  URL: ${finalUrl}`);
        console.log(`  Title: ${finalTitle}`);
        
        // Screenshot after
        await page.screenshot({ 
            path: '/home/pim/public_html/webapp/session3_after_login.png', 
            fullPage: true 
        });
        
        // Check for dashboard elements
        const hasDashboard = await page.locator('.AknHeader, .oro-navigation, nav, #container').count();
        const hasError = await page.locator('.alert-error, .alert-danger, .error').count();
        
        console.log(`  Dashboard elements: ${hasDashboard}`);
        console.log(`  Error messages: ${hasError}`);
        
        // Determine success
        const stillOnLogin = finalUrl.includes('login');
        const isLoggedIn = !stillOnLogin && (hasDashboard > 0 || finalUrl !== testUrl);
        
        console.log(`\n${isLoggedIn ? '✓✓✓ LOGIN SUCCESSFUL! ✓✓✓' : '✗ Login still failing'}`);
        console.log(`Still on login page: ${stillOnLogin ? 'YES' : 'NO'}`);
        
        if (isLoggedIn) {
            console.log('\n🎉 SUCCESS! User is logged in to Akeneo PIM!');
        }
        
        await browser.close();
        process.exit(isLoggedIn ? 0 : 1);
        
    } catch (error) {
        console.log(`\n✗ Error: ${error.message}`);
        await browser.close();
        process.exit(1);
    }
})();
