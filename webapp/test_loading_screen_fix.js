const { chromium } = require('playwright');

async function testLoadingScreenFix() {
    console.log('🧪 Testing Akeneo PIM Loading Screen Fix\n');
    
    const browser = await chromium.launch({ headless: true });
    const context = await browser.newContext({
        ignoreHTTPSErrors: true,
        viewport: { width: 1920, height: 1080 }
    });
    const page = await context.newPage();
    
    // Track network requests
    const requests = [];
    const failedRequests = [];
    
    page.on('request', request => {
        requests.push({
            url: request.url(),
            method: request.method()
        });
    });
    
    page.on('requestfailed', request => {
        failedRequests.push({
            url: request.url(),
            failure: request.failure()
        });
    });
    
    // Track console messages
    const consoleMessages = [];
    page.on('console', msg => {
        consoleMessages.push({
            type: msg.type(),
            text: msg.text()
        });
    });
    
    try {
        // Step 1: Load login page
        console.log('📥 Step 1: Loading login page...');
        await page.goto('https://pim.technostationery.com/user/login', {
            waitUntil: 'networkidle',
            timeout: 30000
        });
        console.log('✅ Login page loaded\n');
        
        // Step 2: Check for extensions.json availability
        console.log('🔍 Step 2: Checking extensions.json...');
        const extensionsResponse = await page.evaluate(async () => {
            try {
                const response = await fetch('/js/extensions.json');
                return {
                    status: response.status,
                    ok: response.ok,
                    data: await response.json()
                };
            } catch (e) {
                return {
                    status: 0,
                    ok: false,
                    error: e.message
                };
            }
        });
        
        if (extensionsResponse.ok) {
            console.log('✅ extensions.json accessible (HTTP', extensionsResponse.status + ')');
            console.log('   Routes configured:', Object.keys(extensionsResponse.data.routes || {}).length);
        } else {
            console.log('❌ extensions.json NOT accessible');
            console.log('   Status:', extensionsResponse.status);
            console.log('   Error:', extensionsResponse.error);
        }
        console.log('');
        
        // Step 3: Login
        console.log('🔐 Step 3: Logging in...');
        await page.fill('input[name="_username"]', 'testadmin');
        await page.fill('input[name="_password"]', 'testpass');
        await page.click('button[type="submit"]');
        
        // Wait for navigation
        await page.waitForLoadState('networkidle', { timeout: 15000 });
        const currentUrl = page.url();
        console.log('   Current URL:', currentUrl);
        
        if (currentUrl.includes('/user/login')) {
            console.log('❌ Login failed - still on login page\n');
            await browser.close();
            return;
        }
        console.log('✅ Login successful\n');
        
        // Step 4: Check loading screen
        console.log('⏳ Step 4: Checking loading screen behavior...');
        
        // Wait a moment for the page to load
        await page.waitForTimeout(3000);
        
        // Check if loading screen is present
        const loadingScreen = await page.locator('.AknLoadingMask, .loading-mask, [class*="loading"]').first();
        const loadingVisible = await loadingScreen.isVisible().catch(() => false);
        
        if (loadingVisible) {
            console.log('⚠️  Loading screen still visible after 3s');
            
            // Wait longer and check again
            await page.waitForTimeout(5000);
            const stillLoading = await loadingScreen.isVisible().catch(() => false);
            
            if (stillLoading) {
                console.log('❌ Loading screen stuck! (8 seconds elapsed)');
            } else {
                console.log('✅ Loading screen cleared (< 8 seconds)');
            }
        } else {
            console.log('✅ No loading screen found');
        }
        console.log('');
        
        // Step 5: Check dashboard elements
        console.log('🏠 Step 5: Checking dashboard elements...');
        
        const dashboardChecks = {
            app: await page.locator('#app').count(),
            menu: await page.locator('.AknHeader-menuContainer, nav').count(),
            content: await page.locator('[class*="content"], main').count()
        };
        
        console.log('   App container:', dashboardChecks.app > 0 ? '✅' : '❌');
        console.log('   Navigation menu:', dashboardChecks.menu > 0 ? '✅' : '❌');
        console.log('   Content area:', dashboardChecks.content > 0 ? '✅' : '❌');
        console.log('');
        
        // Step 6: Check for critical errors
        console.log('🚨 Step 6: Checking for errors...');
        
        const criticalErrors = failedRequests.filter(req => 
            req.url.includes('extensions.json') ||
            req.url.includes('main.min.js') ||
            req.url.includes('vendor.min.js') ||
            req.url.includes('pim.css')
        );
        
        if (criticalErrors.length > 0) {
            console.log('❌ Critical asset errors found:');
            criticalErrors.forEach(err => {
                console.log('   •', err.url);
            });
        } else {
            console.log('✅ No critical asset errors');
        }
        
        const jsErrors = consoleMessages.filter(msg => msg.type === 'error');
        if (jsErrors.length > 0) {
            console.log('⚠️  JavaScript errors found:', jsErrors.length);
            jsErrors.slice(0, 3).forEach(err => {
                console.log('   •', err.text.substring(0, 100));
            });
        } else {
            console.log('✅ No JavaScript errors');
        }
        console.log('');
        
        // Step 7: Take screenshots
        console.log('📸 Step 7: Capturing screenshots...');
        await page.screenshot({ path: '/tmp/loading_screen_test_full.png', fullPage: true });
        await page.screenshot({ path: '/tmp/loading_screen_test_viewport.png' });
        console.log('   Saved to: /tmp/loading_screen_test_*.png\n');
        
        // Summary
        console.log('═══════════════════════════════════════');
        console.log('  TEST SUMMARY');
        console.log('═══════════════════════════════════════');
        console.log('Login:', currentUrl.includes('/user/login') ? '❌' : '✅');
        console.log('Extensions.json:', extensionsResponse.ok ? '✅' : '❌');
        console.log('Loading Screen:', !loadingVisible ? '✅' : '❌');
        console.log('Dashboard Rendered:', (dashboardChecks.app && dashboardChecks.menu) ? '✅' : '❌');
        console.log('No Critical Errors:', criticalErrors.length === 0 ? '✅' : '❌');
        console.log('═══════════════════════════════════════\n');
        
        const allPassed = 
            !currentUrl.includes('/user/login') &&
            extensionsResponse.ok &&
            !loadingVisible &&
            dashboardChecks.app > 0 &&
            criticalErrors.length === 0;
        
        if (allPassed) {
            console.log('🎉 ALL TESTS PASSED! Loading screen issue FIXED! 🎉\n');
        } else {
            console.log('⚠️  Some issues remain. Check the details above.\n');
        }
        
    } catch (error) {
        console.error('❌ Test failed with error:', error.message);
        await page.screenshot({ path: '/tmp/loading_screen_test_error.png' });
        console.log('Error screenshot saved to: /tmp/loading_screen_test_error.png\n');
    } finally {
        await browser.close();
    }
}

testLoadingScreenFix();
