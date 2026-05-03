const { chromium } = require('playwright');

(async () => {
    const browser = await chromium.launch({ 
        headless: true,
        args: ['--no-sandbox', '--disable-setuid-sandbox']
    });
    const page = await browser.newPage();
    
    console.log('=== Testing Login After ACL Fix ===\n');
    
    const testUrl = 'http://205.134.249.177:8000/index.php';
    
    try {
        await page.goto(testUrl, { waitUntil: 'networkidle', timeout: 30000 });
        console.log('✓ Page loaded');
        
        // Fill login form
        await page.fill('input[name="_username"]', 'admin');
        await page.fill('input[name="_password"]', 'admin');
        console.log('✓ Credentials entered: admin/admin');
        
        // Take screenshot before
        await page.screenshot({ path: '/home/pim/public_html/webapp/test_before_acl_fix.png' });
        
        // Submit
        await page.click('button[type="submit"]');
        console.log('✓ Login submitted');
        
        // Wait for response
        await page.waitForTimeout(5000);
        
        const finalUrl = page.url();
        const finalTitle = await page.title();
        
        console.log(`\nFinal URL: ${finalUrl}`);
        console.log(`Final Title: ${finalTitle}`);
        
        // Take screenshot after
        await page.screenshot({ path: '/home/pim/public_html/webapp/test_after_acl_fix.png', fullPage: true });
        
        // Check for success
        const isLoggedIn = !finalUrl.includes('login') && finalUrl !== testUrl;
        
        console.log(`\n${isLoggedIn ? '✓✓✓ LOGIN SUCCESSFUL!' : '✗ Login still failing'}`);
        console.log(`Still on login page: ${finalUrl.includes('login') ? 'YES' : 'NO'}`);
        
        await browser.close();
        process.exit(isLoggedIn ? 0 : 1);
        
    } catch (error) {
        console.log(`\n✗ Error: ${error.message}`);
        await browser.close();
        process.exit(1);
    }
})();
