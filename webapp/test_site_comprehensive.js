const playwright = require('playwright');

(async () => {
    console.log('🔍 Comprehensive Site Test - Dashboard Loading Investigation\n');
    
    const browser = await playwright.chromium.launch({
        headless: true,
        args: ['--no-sandbox', '--disable-setuid-sandbox']
    });
    
    const context = await browser.newContext({
        ignoreHTTPSErrors: true,
        viewport: { width: 1920, height: 1080 }
    });
    
    const page = await context.newPage();
    
    // Track all errors
    const errors = {
        console: [],
        network: [],
        page: []
    };
    
    page.on('console', msg => {
        if (msg.type() === 'error') {
            errors.console.push(msg.text());
        }
    });
    
    page.on('pageerror', error => {
        errors.page.push(error.message);
    });
    
    page.on('requestfailed', request => {
        errors.network.push(`${request.url()} - ${request.failure().errorText}`);
    });
    
    try {
        console.log('Step 1: Loading homepage...');
        const homeResponse = await page.goto('https://pim.technostationery.com/', { 
            waitUntil: 'networkidle',
            timeout: 30000 
        });
        
        console.log(`   Status: ${homeResponse.status()}`);
        console.log(`   URL: ${page.url()}`);
        
        // Check if redirected to login
        if (page.url().includes('/user/login') || page.url().includes('/login')) {
            console.log('   ✅ Redirected to login page\n');
            
            console.log('Step 2: Logging in...');
            await page.waitForSelector('input[name="_username"]', { timeout: 10000 });
            await page.fill('input[name="_username"]', 'mounir');
            await page.fill('input[name="_password"]', '2026');
            
            console.log('   Submitting credentials...');
            await Promise.all([
                page.waitForNavigation({ timeout: 10000 }),
                page.click('button[type="submit"]')
            ]);
            
            console.log(`   Post-login URL: ${page.url()}`);
            
            if (page.url().includes('/dashboard') || page.url().includes('/#/')) {
                console.log('   ✅ Successfully logged in and redirected\n');
                
                console.log('Step 3: Analyzing dashboard page...');
                
                // Wait a moment for any JavaScript to load
                await page.waitForTimeout(5000);
                
                // Check for key elements
                const pageContent = await page.content();
                const bodyText = await page.textContent('body');
                
                console.log(`   Page title: ${await page.title()}`);
                console.log(`   Body text length: ${bodyText.length} characters`);
                
                // Check for specific elements
                const checks = {
                    'Loading text': bodyText.includes('Loading'),
                    'RequireJS script': pageContent.includes('require.js') || pageContent.includes('requirejs'),
                    'Bootstrap script': pageContent.includes('bootstrap.js'),
                    'Main CSS': pageContent.includes('main.min.css') || pageContent.includes('main.css'),
                    'Vendor JS': pageContent.includes('vendor.min.js'),
                    'Main JS': pageContent.includes('main.min.js'),
                    '#page div': await page.$('#page') !== null,
                    '#container div': await page.$('#container') !== null,
                    '.AknHeader': await page.$('.AknHeader') !== null,
                    '[data-testid="pim-menu"]': await page.$('[data-testid="pim-menu"]') !== null
                };
                
                console.log('\n   📊 Dashboard Element Checks:');
                for (const [check, result] of Object.entries(checks)) {
                    console.log(`      ${result ? '✅' : '❌'} ${check}`);
                }
                
                // Check network requests
                console.log('\n   📡 Checking critical resources...');
                const resources = await page.evaluate(() => {
                    return performance.getEntriesByType('resource').map(r => ({
                        name: r.name.split('/').pop(),
                        type: r.initiatorType,
                        duration: r.duration
                    })).filter(r => 
                        r.name.includes('.js') || 
                        r.name.includes('.css') || 
                        r.name === ''
                    ).slice(0, 20);
                });
                
                resources.forEach(r => {
                    console.log(`      ${r.name || 'document'} (${r.type}) - ${r.duration.toFixed(0)}ms`);
                });
                
                // Take screenshot
                console.log('\n   📸 Taking screenshot...');
                await page.screenshot({ 
                    path: '/home/pim/public_html/webapp/dashboard_current_state.png', 
                    fullPage: true 
                });
                console.log('      Saved: dashboard_current_state.png');
                
                // Check for any visible text content
                const visibleText = await page.evaluate(() => {
                    const walker = document.createTreeWalker(
                        document.body,
                        NodeFilter.SHOW_TEXT,
                        null
                    );
                    
                    let texts = [];
                    let node;
                    while(node = walker.nextNode()) {
                        const text = node.textContent.trim();
                        if (text.length > 0) {
                            texts.push(text);
                        }
                    }
                    return texts.slice(0, 20);
                });
                
                console.log('\n   📝 Visible text on page:');
                visibleText.forEach(text => {
                    if (text.length < 100) {
                        console.log(`      "${text}"`);
                    }
                });
                
            } else {
                console.log('   ❌ Did not redirect to dashboard\n');
            }
            
        } else {
            console.log(`   ⚠️ Not redirected to login. Current URL: ${page.url()}\n`);
        }
        
        // Report errors
        console.log('\n📋 Error Summary:');
        console.log(`   Console Errors: ${errors.console.length}`);
        console.log(`   Page Errors: ${errors.page.length}`);
        console.log(`   Network Errors: ${errors.network.length}`);
        
        if (errors.console.length > 0) {
            console.log('\n   🔴 Console Errors (first 5):');
            errors.console.slice(0, 5).forEach((err, i) => {
                console.log(`      ${i + 1}. ${err.substring(0, 150)}`);
            });
        }
        
        if (errors.page.length > 0) {
            console.log('\n   🔴 Page Errors (first 5):');
            errors.page.slice(0, 5).forEach((err, i) => {
                console.log(`      ${i + 1}. ${err.substring(0, 150)}`);
            });
        }
        
        if (errors.network.length > 0) {
            console.log('\n   🔴 Network Errors (first 5):');
            errors.network.slice(0, 5).forEach((err, i) => {
                console.log(`      ${i + 1}. ${err.substring(0, 150)}`);
            });
        }
        
    } catch (error) {
        console.error('\n❌ TEST FAILED:', error.message);
    } finally {
        await browser.close();
    }
    
    console.log('\n✅ Test Complete');
})();
