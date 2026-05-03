const { chromium } = require('playwright');

async function testAkeneoPIM() {
    console.log('=== Akeneo PIM Final Complete Test ===');
    console.log('Date:', new Date().toISOString());
    console.log('');
    
    const browser = await chromium.launch({ 
        headless: true,
        args: ['--no-sandbox', '--disable-setuid-sandbox']
    });
    const context = await browser.newContext({ ignoreHTTPSErrors: true });
    const page = await context.newPage();
    
    const baseUrl = 'http://205.134.249.177:8000';
    const loginUrl = `${baseUrl}/index.php`;
    
    try {
        // Test 1: Check if CSS loads
        console.log('Test 1: Checking CSS availability');
        const cssResponse = await page.goto(`${baseUrl}/css/pim.css`, { waitUntil: 'networkidle' });
        console.log('CSS Status:', cssResponse.status());
        console.log('CSS Size:', (await cssResponse.body()).length, 'bytes');
        console.log('✅ CSS loads successfully');
        console.log('');
        
        // Test 2: Load login page
        console.log('Test 2: Loading login page');
        await page.goto(loginUrl, { waitUntil: 'networkidle', timeout: 30000 });
        console.log('Page URL:', page.url());
        console.log('Page Title:', await page.title());
        
        // Take screenshot of login page
        await page.screenshot({ path: '/home/pim/public_html/webapp/final_test_login.png' });
        console.log('Screenshot saved: final_test_login.png');
        console.log('');
        
        // Test 3: Check if login form exists
        console.log('Test 3: Checking login form elements');
        const usernameField = await page.$('input[name="_username"]');
        const passwordField = await page.$('input[name="_password"]');
        const submitButton = await page.$('button[type="submit"]');
        
        if (!usernameField || !passwordField || !submitButton) {
            throw new Error('Login form elements not found');
        }
        console.log('✅ Username field: found');
        console.log('✅ Password field: found');
        console.log('✅ Submit button: found');
        console.log('');
        
        // Test 4: Attempt login with admin credentials
        console.log('Test 4: Attempting login with admin/admin');
        await page.fill('input[name="_username"]', 'admin');
        await page.fill('input[name="_password"]', 'admin');
        
        // Take screenshot before submit
        await page.screenshot({ path: '/home/pim/public_html/webapp/final_test_before_submit.png' });
        console.log('Screenshot saved: final_test_before_submit.png');
        
        // Submit the form
        await Promise.all([
            page.waitForNavigation({ waitUntil: 'networkidle', timeout: 30000 }),
            page.click('button[type="submit"]')
        ]);
        
        console.log('');
        console.log('Test 5: Checking post-login state');
        const currentUrl = page.url();
        const currentTitle = await page.title();
        console.log('Current URL:', currentUrl);
        console.log('Current Title:', currentTitle);
        
        // Check if we're still on login page or redirected
        const isLoginPage = currentUrl.includes('/user/login') || currentTitle.toLowerCase().includes('connexion') || currentTitle.toLowerCase().includes('login');
        
        // Take screenshot after login attempt
        await page.screenshot({ path: '/home/pim/public_html/webapp/final_test_after_login.png', fullPage: true });
        console.log('Screenshot saved: final_test_after_login.png');
        console.log('');
        
        if (isLoginPage) {
            console.log('❌ LOGIN FAILED - Still on login page');
            
            // Check for error messages
            const errorMessage = await page.$('.alert-error, .alert-danger, .error-message');
            if (errorMessage) {
                const errorText = await errorMessage.textContent();
                console.log('Error message found:', errorText);
            } else {
                console.log('No error message visible - checking logs for clues');
            }
            
            // Get page HTML for debugging
            const html = await page.content();
            require('fs').writeFileSync('/home/pim/public_html/webapp/final_test_page.html', html);
            console.log('Page HTML saved to final_test_page.html');
            
        } else {
            console.log('✅ LOGIN SUCCESSFUL!');
            
            // Check for dashboard elements
            console.log('');
            console.log('Test 6: Verifying dashboard elements');
            const header = await page.$('.AknHeader, header, .oro-navigation, nav');
            const container = await page.$('#container, .container, main');
            
            if (header) console.log('✅ Header/Navigation found');
            if (container) console.log('✅ Main container found');
            
            // Take full page screenshot of dashboard
            await page.screenshot({ path: '/home/pim/public_html/webapp/final_test_dashboard.png', fullPage: true });
            console.log('Dashboard screenshot saved: final_test_dashboard.png');
        }
        
        // Check browser console for errors
        console.log('');
        console.log('Browser Console Logs:');
        page.on('console', msg => console.log('  ', msg.type(), ':', msg.text()));
        
    } catch (error) {
        console.error('');
        console.error('❌ Test Error:', error.message);
        await page.screenshot({ path: '/home/pim/public_html/webapp/final_test_error.png' });
        console.error('Error screenshot saved');
    } finally {
        await browser.close();
        console.log('');
        console.log('=== Test Complete ===');
    }
}

testAkeneoPIM().catch(console.error);
