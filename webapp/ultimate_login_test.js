const { chromium } = require('playwright');

async function ultimateTest() {
    console.log('=== ULTIMATE AKENEO PIM LOGIN TEST ===');
    console.log('Date:', new Date().toISOString());
    console.log('');
    
    const browser = await chromium.launch({ 
        headless: true,
        args: ['--no-sandbox', '--disable-setuid-sandbox']
    });
    
    const context = await browser.newContext({ 
        ignoreHTTPSErrors: true,
        extraHTTPHeaders: {
            'Accept-Language': 'en-US,en;q=0.9'
        }
    });
    
    const page = await context.newPage();
    
    // Capture console logs
    const consoleMessages = [];
    page.on('console', msg => {
        consoleMessages.push(`[${msg.type()}] ${msg.text()}`);
    });
    
    // Capture network requests
    const networkLog = [];
    page.on('response', response => {
        networkLog.push(`${response.status()} ${response.url()}`);
    });
    
    const baseUrl = 'http://205.134.249.177:8000';
    
    try {
        console.log('Step 1: Navigate to login page');
        await page.goto(`${baseUrl}/index.php`, { waitUntil: 'domcontentloaded', timeout: 30000 });
        console.log('✅ Page loaded');
        console.log('   URL:', page.url());
        console.log('   Title:', await page.title());
        
        // Save initial page screenshot
        await page.screenshot({ path: 'ultimate_test_step1_login.png' });
        
        console.log('');
        console.log('Step 2: Fill login credentials');
        await page.waitForSelector('input[name="_username"]', { timeout: 10000 });
        await page.fill('input[name="_username"]', 'admin');
        await page.fill('input[name="_password"]', 'admin');
        console.log('✅ Credentials entered: admin/admin');
        
        // Screenshot with credentials filled
        await page.screenshot({ path: 'ultimate_test_step2_filled.png' });
        
        console.log('');
        console.log('Step 3: Submit login form');
        
        // Click submit and wait for response
        const [response] = await Promise.all([
            page.waitForResponse(response => 
                response.url().includes('login') || 
                response.url().includes('dashboard') || 
                response.url().includes('index.php'), 
                { timeout: 30000 }
            ),
            page.click('button[type="submit"]')
        ]);
        
        console.log('✅ Form submitted');
        console.log('   Response status:', response.status());
        console.log('   Response URL:', response.url());
        
        // Wait a bit for any redirects
        await page.waitForTimeout(3000);
        
        console.log('');
        console.log('Step 4: Analyze post-login state');
        const finalUrl = page.url();
        const finalTitle = await page.title();
        
        console.log('   Final URL:', finalUrl);
        console.log('   Final Title:', finalTitle);
        
        // Take screenshot of final state
        await page.screenshot({ path: 'ultimate_test_step4_final.png', fullPage: true });
        
        // Check if still on login page
        const isStillLoginPage = finalUrl.includes('/user/login') || 
                                  finalTitle.toLowerCase().includes('connexion') ||
                                  finalTitle.toLowerCase().includes('login');
        
        console.log('');
        if (isStillLoginPage) {
            console.log('⚠️  Still on login page - checking for errors');
            
            // Look for error messages
            const errorSelectors = [
                '.alert-error',
                '.alert-danger', 
                '.error-message',
                '[class*="error"]',
                '.flash-error'
            ];
            
            for (const selector of errorSelectors) {
                const elem = await page.$(selector);
                if (elem) {
                    const text = await elem.textContent();
                    console.log('   Error found:', text.trim());
                }
            }
            
            // Check for CSRF token
            const csrfToken = await page.$('input[name="_csrf_token"]');
            console.log('   CSRF token present:', csrfToken !== null);
            
            console.log('');
            console.log('❌ LOGIN FAILED');
            
        } else {
            console.log('✅ LOGIN SUCCESSFUL - Redirected away from login page!');
            
            // Check for dashboard elements
            const dashboardChecks = [
                { selector: '.AknHeader', name: 'Akeneo Header' },
                { selector: 'header', name: 'HTML Header' },
                { selector: '.oro-navigation', name: 'Oro Navigation' },
                { selector: 'nav', name: 'Navigation' },
                { selector: '#container', name: 'Container' },
                { selector: '.container', name: 'Container (class)' },
                { selector: 'main', name: 'Main Content' }
            ];
            
            console.log('');
            console.log('Dashboard Elements:');
            for (const check of dashboardChecks) {
                const elem = await page.$(check.selector);
                if (elem) {
                    console.log(`   ✅ ${check.name} found`);
                }
            }
        }
        
        // Display network log summary
        console.log('');
        console.log('Network Summary (key requests):');
        networkLog.slice(-10).forEach(log => console.log('   ', log));
        
        // Display console messages
        if (consoleMessages.length > 0) {
            console.log('');
            console.log('Browser Console Messages:');
            consoleMessages.slice(0, 10).forEach(msg => console.log('   ', msg));
        }
        
        console.log('');
        console.log('Screenshots saved:');
        console.log('   - ultimate_test_step1_login.png');
        console.log('   - ultimate_test_step2_filled.png');
        console.log('   - ultimate_test_step4_final.png');
        
    } catch (error) {
        console.error('');
        console.error('❌ ERROR:', error.message);
        await page.screenshot({ path: 'ultimate_test_error.png' });
    } finally {
        await browser.close();
        console.log('');
        console.log('=== TEST COMPLETE ===');
    }
}

ultimateTest().catch(console.error);
