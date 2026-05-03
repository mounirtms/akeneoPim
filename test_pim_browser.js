const { chromium } = require('playwright');

async function testAkeneoPIM() {
    console.log('===========================================');
    console.log('Akeneo PIM - Chromium Browser Test');
    console.log('===========================================\n');

    const browser = await chromium.launch({
        headless: false,
        args: ['--no-sandbox', '--disable-setuid-sandbox']
    });

    const context = await browser.newContext({
        viewport: { width: 1920, height: 1080 },
        ignoreHTTPSErrors: true
    });

    const page = await context.newPage();

    // Listen for console messages
    page.on('console', msg => {
        const type = msg.type();
        if (type === 'error' || type === 'warning') {
            console.log(`[Browser ${type.toUpperCase()}]:`, msg.text());
        }
    });

    // Listen for page errors
    page.on('pageerror', error => {
        console.log('[Page Error]:', error.message);
    });

    try {
        console.log('Step 1: Navigating to Akeneo PIM login page...');
        
        // Try different possible URLs
        const urls = [
            'http://localhost/public/index.php',
            'http://localhost/index.php',
            'http://localhost',
            'http://pim.local',
            'http://127.0.0.1/public/index.php'
        ];

        let loaded = false;
        let finalUrl = '';

        for (const url of urls) {
            try {
                console.log(`  Trying: ${url}`);
                const response = await page.goto(url, { 
                    waitUntil: 'domcontentloaded',
                    timeout: 10000 
                });
                
                if (response && (response.status() === 200 || response.status() === 302)) {
                    console.log(`  ✓ Successfully loaded: ${url} (HTTP ${response.status()})`);
                    finalUrl = url;
                    loaded = true;
                    break;
                }
            } catch (e) {
                console.log(`  ✗ Failed: ${url} - ${e.message}`);
            }
        }

        if (!loaded) {
            throw new Error('Could not load any URL - check web server configuration');
        }

        console.log(`\nStep 2: Analyzing page content...`);
        
        // Wait a moment for page to render
        await page.waitForTimeout(2000);

        // Get page title
        const title = await page.title();
        console.log(`  Page title: "${title}"`);

        // Check for manifest.json error
        const manifestError = await page.evaluate(() => {
            const logs = performance.getEntriesByType('resource');
            return logs.some(log => log.name.includes('manifest.json') && log.transferSize === 0);
        });

        if (manifestError) {
            console.log('  ⚠ Warning: manifest.json may not be loading correctly');
        } else {
            console.log('  ✓ No manifest.json errors detected');
        }

        // Check if login form exists
        const hasLoginForm = await page.evaluate(() => {
            return document.querySelector('input[name="_username"]') !== null ||
                   document.querySelector('input[type="text"]') !== null ||
                   document.querySelector('form') !== null;
        });

        console.log(`  Login form present: ${hasLoginForm ? '✓ Yes' : '✗ No'}`);

        // Check for CSS loading
        const cssLoaded = await page.evaluate(() => {
            const styles = window.getComputedStyle(document.body);
            return styles.fontFamily !== '' && styles.fontFamily !== 'Times New Roman';
        });

        console.log(`  CSS loaded: ${cssLoaded ? '✓ Yes' : '✗ No'}`);

        // Get body HTML to check content
        const bodyText = await page.evaluate(() => document.body.innerText);
        const hasAkeneoContent = bodyText.toLowerCase().includes('akeneo') || 
                                 bodyText.toLowerCase().includes('login') ||
                                 bodyText.toLowerCase().includes('pim');

        console.log(`  Akeneo content detected: ${hasAkeneoContent ? '✓ Yes' : '✗ No'}`);

        // Take screenshot
        console.log('\nStep 3: Taking screenshot...');
        await page.screenshot({ 
            path: '/home/pim/public_html/screenshot_login.png',
            fullPage: true 
        });
        console.log('  ✓ Screenshot saved: screenshot_login.png');

        // Try to login if form is present
        if (hasLoginForm) {
            console.log('\nStep 4: Attempting login...');
            
            // Try to find username field
            const usernameSelector = 'input[name="_username"], input[type="text"], input#username';
            const passwordSelector = 'input[name="_password"], input[type="password"], input#password';
            
            try {
                await page.fill(usernameSelector, 'admin', { timeout: 5000 });
                console.log('  ✓ Username entered: admin');
                
                await page.fill(passwordSelector, 'admin', { timeout: 5000 });
                console.log('  ✓ Password entered');

                // Find and click submit button
                const submitSelector = 'button[type="submit"], input[type="submit"], button:has-text("Log in")';
                await page.click(submitSelector, { timeout: 5000 });
                console.log('  ✓ Login button clicked');

                // Wait for navigation or error
                await page.waitForTimeout(3000);

                const currentUrl = page.url();
                console.log(`  Current URL: ${currentUrl}`);

                // Check if we're still on login page or moved to dashboard
                const stillOnLogin = currentUrl.includes('login') || currentUrl === finalUrl;
                
                if (!stillOnLogin) {
                    console.log('  ✓ Login successful - redirected to dashboard!');
                    
                    // Take screenshot of dashboard
                    await page.screenshot({ 
                        path: '/home/pim/public_html/screenshot_dashboard.png',
                        fullPage: true 
                    });
                    console.log('  ✓ Dashboard screenshot saved');

                    // Check for dashboard elements
                    const dashboardTitle = await page.title();
                    console.log(`  Dashboard title: "${dashboardTitle}"`);

                } else {
                    console.log('  ⚠ Still on login page - check credentials or errors');
                    
                    // Check for error messages
                    const errorText = await page.evaluate(() => {
                        const errorEl = document.querySelector('.alert-error, .error, .alert-danger');
                        return errorEl ? errorEl.innerText : null;
                    });
                    
                    if (errorText) {
                        console.log(`  Error message: "${errorText}"`);
                    }
                }

            } catch (loginError) {
                console.log(`  ✗ Login attempt failed: ${loginError.message}`);
            }
        }

        console.log('\nStep 5: Checking console errors...');
        // Console errors were already logged via listener above

        console.log('\n===========================================');
        console.log('Test Summary:');
        console.log('===========================================');
        console.log(`✓ Browser launched successfully`);
        console.log(`✓ Page loaded: ${finalUrl}`);
        console.log(`✓ Page title: "${title}"`);
        console.log(`✓ Screenshots captured`);
        console.log('===========================================\n');

        // Keep browser open for inspection
        console.log('Browser will remain open for 30 seconds for inspection...');
        await page.waitForTimeout(30000);

    } catch (error) {
        console.error('\n✗ Test failed:', error.message);
        console.error('Stack:', error.stack);
    } finally {
        await browser.close();
        console.log('\nBrowser closed. Test complete.');
    }
}

testAkeneoPIM().catch(console.error);
