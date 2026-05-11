const playwright = require('playwright');
const fs = require('fs');

(async () => {
    console.log('╔════════════════════════════════════════════════════════════╗');
    console.log('║     COMPREHENSIVE PIM UI MONKEY TEST - Phase 7 & 8        ║');
    console.log('╚════════════════════════════════════════════════════════════╝\n');

    const browser = await playwright.chromium.launch({ 
        headless: true,
        args: ['--no-sandbox', '--disable-setuid-sandbox']
    });
    const context = await browser.newContext({
        ignoreHTTPSErrors: true,
        viewport: { width: 1920, height: 1080 }
    });
    const page = await context.newPage();

    const testResults = {
        timestamp: new Date().toISOString(),
        fixes_applied: {
            extensions_json: true,
            r_initialize_patch: 'pending'
        },
        tests: {},
        errors: [],
        warnings: [],
        ui_elements: {},
        menu_items: [],
        monkey_test_clicks: [],
        screenshots: []
    };

    // Capture all console messages
    const consoleMessages = [];
    page.on('console', msg => {
        const text = msg.text();
        consoleMessages.push({ type: msg.type(), message: text, timestamp: new Date().toISOString() });
        console.log(`[${msg.type().toUpperCase()}] ${text}`);
    });

    // Capture all errors
    page.on('pageerror', error => {
        testResults.errors.push({ 
            message: error.message, 
            stack: error.stack,
            timestamp: new Date().toISOString()
        });
        console.log(`[ERROR] ${error.message}`);
    });

    try {
        console.log('\n📋 Test Phase 1: Verify extensions.json fix...');
        const extResponse = await page.goto('https://pim.technostationery.com/js/extensions.json', {
            timeout: 10000
        });
        testResults.tests.extensions_json = {
            status: extResponse.status(),
            ok: extResponse.ok(),
            content: await extResponse.text()
        };
        console.log(`   ${extResponse.ok() ? '✅' : '❌'} extensions.json: HTTP ${extResponse.status()}`);

        console.log('\n📋 Test Phase 2: Login and reach dashboard...');
        await page.goto('https://pim.technostationery.com/user/login', { 
            timeout: 30000, 
            waitUntil: 'networkidle' 
        });
        
        await page.screenshot({ path: 'monkey_test_1_login.png', fullPage: true });
        testResults.screenshots.push('monkey_test_1_login.png');
        
        await page.fill('input[name="_username"]', 'mounir');
        await page.fill('input[name="_password"]', '2026');
        await page.click('button[type="submit"]');
        
        console.log('   ⏳ Waiting for dashboard to load...');
        await page.waitForTimeout(8000);

        await page.screenshot({ path: 'monkey_test_2_dashboard.png', fullPage: true });
        testResults.screenshots.push('monkey_test_2_dashboard.png');

        console.log('\n📋 Test Phase 3: Check for r.initialize error...');
        const hasInitError = testResults.errors.some(e => e.message.includes('r.initialize'));
        testResults.tests.r_initialize_error = !hasInitError;
        console.log(`   ${hasInitError ? '❌' : '✅'} r.initialize error: ${hasInitError ? 'STILL EXISTS' : 'FIXED'}`);

        console.log('\n📋 Test Phase 4: Analyze page state after fixes...');
        const pageState = await page.evaluate(() => {
            return {
                url: window.location.href,
                title: document.title,
                // Check for loading screen
                loadingScreen: document.querySelector('.AknDefault-progressContainer'),
                loadingVisible: document.querySelector('.AknDefault-progressContainer') ? 
                    window.getComputedStyle(document.querySelector('.AknDefault-progressContainer')).display !== 'none' : false,
                // Check for menu
                mainMenu: document.querySelector('.AknDefault-mainMenu'),
                menuVisible: document.querySelector('.AknDefault-mainMenu') ? 
                    window.getComputedStyle(document.querySelector('.AknDefault-mainMenu')).display !== 'none' : false,
                // Check for app container
                appContainer: document.querySelector('.app'),
                // Find all visible navigation elements
                navElements: Array.from(document.querySelectorAll('nav, [role="navigation"], .navigation, .menu')).map(el => ({
                    tagName: el.tagName,
                    className: el.className,
                    id: el.id,
                    visible: window.getComputedStyle(el).display !== 'none'
                })),
                // Find all clickable elements
                clickableElements: Array.from(document.querySelectorAll('a, button, [role="button"]')).length,
                // Check libraries
                libraries: {
                    jQuery: typeof jQuery !== 'undefined' ? jQuery.fn.jquery : 'not loaded',
                    Backbone: typeof Backbone !== 'undefined' ? Backbone.VERSION : 'not loaded',
                    RequireJS: typeof requirejs !== 'undefined',
                    pimInit: typeof pimInit === 'function'
                }
            };
        });

        testResults.tests.page_state = pageState;
        console.log(`   URL: ${pageState.url}`);
        console.log(`   Title: ${pageState.title}`);
        console.log(`   Loading screen: ${pageState.loadingScreen ? 'EXISTS' : 'NOT FOUND'} (${pageState.loadingVisible ? 'VISIBLE' : 'HIDDEN'})`);
        console.log(`   Main menu: ${pageState.mainMenu ? 'EXISTS' : 'NOT FOUND'} (${pageState.menuVisible ? 'VISIBLE' : 'HIDDEN'})`);
        console.log(`   App container: ${pageState.appContainer ? 'EXISTS' : 'NOT FOUND'}`);
        console.log(`   Nav elements found: ${pageState.navElements.length}`);
        console.log(`   Clickable elements: ${pageState.clickableElements}`);

        console.log('\n📋 Test Phase 5: MONKEY TEST - Find and test all UI elements...');
        
        // Wait a bit more for dynamic content
        await page.waitForTimeout(3000);

        // Find all interactive elements
        const interactiveElements = await page.evaluate(() => {
            const elements = [];
            const selectors = [
                'a[href]:not([disabled])',
                'button:not([disabled])',
                '[role="button"]:not([disabled])',
                '[role="menuitem"]:not([disabled])',
                'input[type="button"]:not([disabled])',
                'input[type="submit"]:not([disabled])',
                '.clickable:not([disabled])',
                '[onclick]:not([disabled])'
            ];
            
            selectors.forEach(selector => {
                document.querySelectorAll(selector).forEach(el => {
                    const rect = el.getBoundingClientRect();
                    const isVisible = rect.width > 0 && rect.height > 0 && 
                                    window.getComputedStyle(el).display !== 'none' &&
                                    window.getComputedStyle(el).visibility !== 'hidden';
                    
                    if (isVisible) {
                        elements.push({
                            tagName: el.tagName,
                            type: el.type || 'N/A',
                            className: el.className,
                            id: el.id,
                            text: el.textContent.trim().substring(0, 50),
                            href: el.href || '',
                            x: rect.x,
                            y: rect.y
                        });
                    }
                });
            });
            
            return elements;
        });

        console.log(`   Found ${interactiveElements.length} interactive elements`);
        testResults.ui_elements.interactive = interactiveElements;

        // Try to find menu items specifically
        const menuItems = await page.evaluate(() => {
            const items = [];
            const menuSelectors = [
                '.AknDefault-mainMenu a',
                '.navigation a',
                '[role="navigation"] a',
                '.menu-item',
                '[data-menu]',
                '.sidebar a',
                '.nav-link'
            ];
            
            menuSelectors.forEach(selector => {
                document.querySelectorAll(selector).forEach(el => {
                    const rect = el.getBoundingClientRect();
                    if (rect.width > 0 && rect.height > 0) {
                        items.push({
                            selector: selector,
                            text: el.textContent.trim(),
                            href: el.href || '',
                            className: el.className
                        });
                    }
                });
            });
            
            return items;
        });

        console.log(`   Found ${menuItems.length} menu items`);
        testResults.menu_items = menuItems;

        if (menuItems.length > 0) {
            console.log('\n   Menu items found:');
            menuItems.slice(0, 10).forEach((item, idx) => {
                console.log(`     ${idx + 1}. ${item.text} (${item.selector})`);
            });
        }

        console.log('\n📋 Test Phase 6: MONKEY TEST - Random clicking...');
        
        // Try clicking on a few elements if they exist
        let clickCount = 0;
        const maxClicks = 5;

        for (let i = 0; i < Math.min(interactiveElements.length, maxClicks); i++) {
            try {
                const element = interactiveElements[i];
                console.log(`   Attempting click ${i+1}: "${element.text}" (${element.tagName})`);
                
                // Try to click using text or selector
                if (element.text && element.text.length > 0) {
                    try {
                        await page.click(`text=${element.text.substring(0, 30)}`, { timeout: 2000 });
                        clickCount++;
                        testResults.monkey_test_clicks.push({
                            success: true,
                            element: element.text,
                            tag: element.tagName
                        });
                        await page.waitForTimeout(1000);
                        console.log(`      ✅ Click successful`);
                    } catch (clickErr) {
                        console.log(`      ⚠️  Click failed: ${clickErr.message.substring(0, 50)}`);
                        testResults.monkey_test_clicks.push({
                            success: false,
                            element: element.text,
                            error: clickErr.message
                        });
                    }
                }
            } catch (err) {
                console.log(`      ❌ Error: ${err.message.substring(0, 50)}`);
            }
        }

        console.log(`   Completed ${clickCount} successful clicks`);

        console.log('\n📋 Test Phase 7: Check DOM structure for PIM components...');
        const domStructure = await page.evaluate(() => {
            return {
                bodyClasses: document.body.className,
                hasBackboneView: document.querySelector('[data-view]') !== null,
                hasReactRoot: document.querySelector('[data-reactroot]') !== null,
                mainContainers: Array.from(document.querySelectorAll('[class*="Container"], [class*="Wrapper"]')).map(el => el.className),
                formElements: document.querySelectorAll('form').length,
                inputElements: document.querySelectorAll('input, select, textarea').length,
                totalDivs: document.querySelectorAll('div').length
            };
        });

        testResults.tests.dom_structure = domStructure;
        console.log(`   Body classes: ${domStructure.bodyClasses}`);
        console.log(`   Has Backbone views: ${domStructure.hasBackboneView}`);
        console.log(`   Has React components: ${domStructure.hasReactRoot}`);
        console.log(`   Forms: ${domStructure.formElements}`);
        console.log(`   Input elements: ${domStructure.inputElements}`);

        console.log('\n📋 Test Phase 8: Check RequireJS module status...');
        const requireJsStatus = await page.evaluate(() => {
            if (typeof requirejs === 'undefined') {
                return { available: false };
            }
            
            const context = requirejs.s?.contexts?._;
            return {
                available: true,
                defined: context?.defined ? Object.keys(context.defined) : [],
                registry: context?.registry ? Object.keys(context.registry) : [],
                config: context?.config || {}
            };
        });

        testResults.tests.requirejs_status = requireJsStatus;
        console.log(`   RequireJS available: ${requireJsStatus.available}`);
        if (requireJsStatus.available) {
            console.log(`   Defined modules: ${requireJsStatus.defined.length}`);
            console.log(`   Registry modules: ${requireJsStatus.registry.length}`);
            if (requireJsStatus.defined.length > 0) {
                console.log(`   Sample modules: ${requireJsStatus.defined.slice(0, 5).join(', ')}`);
            }
        }

        // Final screenshot
        await page.screenshot({ path: 'monkey_test_3_final.png', fullPage: true });
        testResults.screenshots.push('monkey_test_3_final.png');

    } catch (error) {
        console.error('\n❌ Test error:', error.message);
        testResults.errors.push({ 
            fatal: true, 
            message: error.message, 
            stack: error.stack 
        });
    }

    // Save results
    testResults.console_messages = consoleMessages;
    fs.writeFileSync('monkey_test_results.json', JSON.stringify(testResults, null, 2));

    console.log('\n╔════════════════════════════════════════════════════════════╗');
    console.log('║                    MONKEY TEST SUMMARY                     ║');
    console.log('╚════════════════════════════════════════════════════════════╝');
    console.log(`\n📊 Test Results:`);
    console.log(`  ✓ extensions.json: ${testResults.tests.extensions_json?.ok ? 'HTTP 200 ✅' : 'FAILED ❌'}`);
    console.log(`  ✓ r.initialize error: ${testResults.tests.r_initialize_error ? 'FIXED ✅' : 'STILL EXISTS ❌'}`);
    console.log(`  ✓ Interactive elements found: ${testResults.ui_elements.interactive?.length || 0}`);
    console.log(`  ✓ Menu items found: ${testResults.menu_items?.length || 0}`);
    console.log(`  ✓ Successful clicks: ${testResults.monkey_test_clicks.filter(c => c.success).length}`);
    console.log(`  ✓ Console messages: ${consoleMessages.length}`);
    console.log(`  ✓ Errors captured: ${testResults.errors.length}`);
    console.log(`\n✅ Results saved: monkey_test_results.json`);
    console.log(`✅ Screenshots: ${testResults.screenshots.join(', ')}\n`);

    await browser.close();
})();
