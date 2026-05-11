const playwright = require('playwright');
const fs = require('fs');

(async () => {
    console.log('\n╔════════════════════════════════════════════════════════════╗');
    console.log('║   AKENEO PIM - COMPREHENSIVE LOGIN & STABILITY TEST       ║');
    console.log('╚════════════════════════════════════════════════════════════╝\n');
    
    const browser = await playwright.chromium.launch({ 
        headless: true,
        args: ['--no-sandbox', '--disable-setuid-sandbox', '--disable-dev-shm-usage']
    });
    
    const context = await browser.newContext({ 
        ignoreHTTPSErrors: true,
        viewport: { width: 1920, height: 1080 }
    });
    
    const page = await context.newPage();
    
    // Capture all logs
    const logs = [];
    const errors = [];
    const networkErrors = [];
    const resources = [];
    
    page.on('console', msg => {
        const entry = {
            type: msg.type(),
            text: msg.text(),
            location: msg.location()
        };
        logs.push(entry);
        
        const prefix = msg.type() === 'error' ? '❌' : msg.type() === 'warning' ? '⚠️' : 'ℹ️';
        console.log(`${prefix} [CONSOLE ${msg.type().toUpperCase()}] ${msg.text()}`);
    });
    
    page.on('pageerror', err => {
        errors.push({
            message: err.message,
            stack: err.stack
        });
        console.log(`❌ [PAGE ERROR] ${err.message}`);
    });
    
    page.on('requestfailed', request => {
        networkErrors.push({
            url: request.url(),
            failure: request.failure()
        });
        console.log(`❌ [NETWORK ERROR] ${request.url()} - ${request.failure().errorText}`);
    });
    
    page.on('response', response => {
        if (response.url().includes('.js') || response.url().includes('.css')) {
            resources.push({
                url: response.url(),
                status: response.status(),
                type: response.request().resourceType()
            });
        }
    });
    
    const report = {
        timestamp: new Date().toISOString(),
        testDuration: 0,
        phases: {}
    };
    
    try {
        const startTime = Date.now();
        
        // ═══════════════════════════════════════════════════════════
        // PHASE 1: LOGIN PAGE LOAD
        // ═══════════════════════════════════════════════════════════
        console.log('\n═══ PHASE 1: LOADING LOGIN PAGE ═══\n');
        
        await page.goto('https://pim.technostationery.com/user/login', { 
            waitUntil: 'networkidle',
            timeout: 30000 
        });
        
        await page.waitForTimeout(3000);
        
        // Check jQuery on login page
        const jQueryLogin = await page.evaluate(() => {
            return {
                loaded: typeof jQuery !== 'undefined',
                version: typeof jQuery !== 'undefined' ? jQuery.fn.jquery : null,
                globalDollar: typeof $ !== 'undefined',
                globalJQuery: typeof window.jQuery !== 'undefined'
            };
        });
        
        console.log('✓ Login page loaded');
        console.log(`  jQuery loaded: ${jQueryLogin.loaded ? '✅' : '❌'}`);
        console.log(`  jQuery version: ${jQueryLogin.version || 'N/A'}`);
        console.log(`  Global $ available: ${jQueryLogin.globalDollar ? '✅' : '❌'}`);
        console.log(`  Global jQuery available: ${jQueryLogin.globalJQuery ? '✅' : '❌'}`);
        
        await page.screenshot({ path: 'test_phase1_login_page.png' });
        
        report.phases.loginPage = {
            success: true,
            jQuery: jQueryLogin,
            screenshot: 'test_phase1_login_page.png'
        };
        
        // ═══════════════════════════════════════════════════════════
        // PHASE 2: LOGIN SUBMISSION
        // ═══════════════════════════════════════════════════════════
        console.log('\n═══ PHASE 2: SUBMITTING LOGIN ═══\n');
        
        await page.fill('input[name="_username"]', 'mounir');
        await page.fill('input[name="_password"]', '2026');
        console.log('✓ Credentials entered');
        
        await page.screenshot({ path: 'test_phase2_form_filled.png' });
        
        await page.click('button[type="submit"]');
        console.log('✓ Login form submitted');
        
        await page.waitForNavigation({ waitUntil: 'networkidle', timeout: 30000 });
        console.log('✓ Navigation complete');
        
        // ═══════════════════════════════════════════════════════════
        // PHASE 3: DASHBOARD INITIALIZATION
        // ═══════════════════════════════════════════════════════════
        console.log('\n═══ PHASE 3: DASHBOARD INITIALIZATION ═══\n');
        
        await page.waitForTimeout(5000); // Give time for app to initialize
        
        const url = page.url();
        const title = await page.title();
        
        console.log(`✓ Current URL: ${url}`);
        console.log(`✓ Page title: ${title}`);
        
        // Check all libraries
        const libraries = await page.evaluate(() => {
            return {
                jQuery: {
                    loaded: typeof jQuery !== 'undefined',
                    version: typeof jQuery !== 'undefined' ? jQuery.fn.jquery : null
                },
                underscore: {
                    loaded: typeof _ !== 'undefined',
                    version: typeof _ !== 'undefined' && _.VERSION ? _.VERSION : 'unknown'
                },
                backbone: {
                    loaded: typeof Backbone !== 'undefined',
                    version: typeof Backbone !== 'undefined' && Backbone.VERSION ? Backbone.VERSION : 'unknown'
                },
                react: {
                    loaded: typeof React !== 'undefined',
                    version: typeof React !== 'undefined' && React.version ? React.version : 'unknown'
                },
                webpack: {
                    loaded: typeof __webpack_require__ !== 'undefined'
                },
                requirejs: {
                    loaded: typeof requirejs !== 'undefined'
                }
            };
        });
        
        console.log('\nLibrary Status:');
        Object.entries(libraries).forEach(([name, info]) => {
            const status = info.loaded ? '✅' : '❌';
            const version = info.version ? ` (v${info.version})` : '';
            console.log(`  ${status} ${name}${version}`);
        });
        
        await page.screenshot({ path: 'test_phase3_dashboard_init.png' });
        
        report.phases.dashboardInit = {
            url,
            title,
            libraries,
            screenshot: 'test_phase3_dashboard_init.png'
        };
        
        // ═══════════════════════════════════════════════════════════
        // PHASE 4: UI ELEMENT DETECTION
        // ═══════════════════════════════════════════════════════════
        console.log('\n═══ PHASE 4: UI ELEMENT DETECTION ═══\n');
        
        const uiElements = await page.evaluate(() => {
            const selectors = {
                mainMenu: '.AknDefault-mainMenu',
                navigation: '[role="navigation"]',
                nav: 'nav',
                sidebar: '.sidebar',
                menu: '.menu',
                mainContent: '.AknDefault-mainContent',
                app: '.app',
                root: '#root',
                loadingMask: '.hash-loading-mask',
                progressContainer: '.AknDefault-progressContainer'
            };
            
            const found = {};
            Object.entries(selectors).forEach(([name, selector]) => {
                const el = document.querySelector(selector);
                found[name] = {
                    exists: el !== null,
                    visible: el ? (el.offsetWidth > 0 && el.offsetHeight > 0) : false
                };
            });
            
            return {
                selectors: found,
                bodyClasses: document.body.className,
                htmlClasses: document.documentElement.className,
                bodyChildren: document.body.children.length,
                hasLoadingScreen: document.querySelector('.AknDefault-progressContainer') !== null
            };
        });
        
        console.log('\nUI Elements:');
        Object.entries(uiElements.selectors).forEach(([name, info]) => {
            const existsIcon = info.exists ? '✅' : '❌';
            const visibleIcon = info.visible ? '👁️' : '🙈';
            console.log(`  ${existsIcon} ${name}: exists=${info.exists}, visible=${info.visible} ${visibleIcon}`);
        });
        
        console.log(`\nBody classes: ${uiElements.bodyClasses || '(none)'}`);
        console.log(`HTML classes: ${uiElements.htmlClasses || '(none)'}`);
        console.log(`Body children count: ${uiElements.bodyChildren}`);
        console.log(`Loading screen present: ${uiElements.hasLoadingScreen ? '⚠️ YES' : '✅ NO'}`);
        
        await page.screenshot({ path: 'test_phase4_ui_elements.png', fullPage: true });
        
        report.phases.uiElements = {
            elements: uiElements,
            screenshot: 'test_phase4_ui_elements.png'
        };
        
        // ═══════════════════════════════════════════════════════════
        // PHASE 5: WAIT FOR APP INITIALIZATION
        // ═══════════════════════════════════════════════════════════
        console.log('\n═══ PHASE 5: WAITING FOR APP INITIALIZATION ═══\n');
        
        // Wait up to 10 seconds for loading screen to disappear
        let loadingGone = false;
        for (let i = 0; i < 10; i++) {
            await page.waitForTimeout(1000);
            
            const stillLoading = await page.evaluate(() => {
                const loader = document.querySelector('.AknDefault-progressContainer');
                return loader && loader.offsetWidth > 0;
            });
            
            if (!stillLoading) {
                loadingGone = true;
                console.log(`✓ Loading screen disappeared after ${i + 1} seconds`);
                break;
            }
            
            if (i === 9) {
                console.log('⚠️ Loading screen still present after 10 seconds');
            }
        }
        
        await page.screenshot({ path: 'test_phase5_after_wait.png', fullPage: true });
        
        report.phases.appInit = {
            loadingScreenDisappeared: loadingGone,
            screenshot: 'test_phase5_after_wait.png'
        };
        
        // ═══════════════════════════════════════════════════════════
        // PHASE 6: FINAL STATE ANALYSIS
        // ═══════════════════════════════════════════════════════════
        console.log('\n═══ PHASE 6: FINAL STATE ANALYSIS ═══\n');
        
        const finalState = await page.evaluate(() => {
            // Get visible text content
            const bodyText = document.body.innerText.substring(0, 500);
            
            // Check for specific Akeneo elements
            const akeneoIndicators = {
                hasAkeneoText: bodyText.toLowerCase().includes('akeneo'),
                hasDashboardText: bodyText.toLowerCase().includes('dashboard'),
                hasProductText: bodyText.toLowerCase().includes('product'),
                hasLoadingText: bodyText.toLowerCase().includes('loading')
            };
            
            // Get all visible headings
            const headings = Array.from(document.querySelectorAll('h1, h2, h3, h4'))
                .filter(h => h.offsetWidth > 0)
                .map(h => h.innerText)
                .slice(0, 10);
            
            // Get all visible links
            const links = Array.from(document.querySelectorAll('a'))
                .filter(a => a.offsetWidth > 0 && a.innerText.trim())
                .map(a => ({ text: a.innerText.trim(), href: a.href }))
                .slice(0, 20);
            
            return {
                bodyText: bodyText,
                indicators: akeneoIndicators,
                headings,
                links,
                documentReadyState: document.readyState
            };
        });
        
        console.log('Body text preview:');
        console.log('---');
        console.log(finalState.bodyText);
        console.log('---');
        
        console.log('\nContent Indicators:');
        Object.entries(finalState.indicators).forEach(([key, value]) => {
            console.log(`  ${value ? '✅' : '❌'} ${key}`);
        });
        
        if (finalState.headings.length > 0) {
            console.log('\nVisible Headings:');
            finalState.headings.forEach((h, i) => {
                console.log(`  ${i + 1}. ${h}`);
            });
        }
        
        if (finalState.links.length > 0) {
            console.log('\nVisible Links (first 10):');
            finalState.links.slice(0, 10).forEach((link, i) => {
                console.log(`  ${i + 1}. ${link.text}`);
            });
        }
        
        await page.screenshot({ path: 'test_phase6_final_state.png', fullPage: true });
        
        report.phases.finalState = {
            ...finalState,
            screenshot: 'test_phase6_final_state.png'
        };
        
        // ═══════════════════════════════════════════════════════════
        // PHASE 7: RESOURCE ANALYSIS
        // ═══════════════════════════════════════════════════════════
        console.log('\n═══ PHASE 7: RESOURCE ANALYSIS ═══\n');
        
        const jsResources = resources.filter(r => r.url.includes('.js'));
        const cssResources = resources.filter(r => r.url.includes('.css'));
        
        const jsSuccess = jsResources.filter(r => r.status === 200).length;
        const jsFailed = jsResources.filter(r => r.status !== 200).length;
        const cssSuccess = cssResources.filter(r => r.status === 200).length;
        const cssFailed = cssResources.filter(r => r.status !== 200).length;
        
        console.log(`JavaScript Files: ${jsSuccess} loaded, ${jsFailed} failed`);
        console.log(`CSS Files: ${cssSuccess} loaded, ${cssFailed} failed`);
        
        if (jsFailed > 0) {
            console.log('\nFailed JS Resources:');
            jsResources.filter(r => r.status !== 200).forEach(r => {
                console.log(`  ❌ ${r.status} - ${r.url}`);
            });
        }
        
        report.phases.resources = {
            javascript: { success: jsSuccess, failed: jsFailed },
            css: { success: cssSuccess, failed: cssFailed },
            details: resources
        };
        
        // ═══════════════════════════════════════════════════════════
        // FINAL SUMMARY
        // ═══════════════════════════════════════════════════════════
        const endTime = Date.now();
        report.testDuration = endTime - startTime;
        
        console.log('\n╔════════════════════════════════════════════════════════════╗');
        console.log('║                     TEST SUMMARY                           ║');
        console.log('╚════════════════════════════════════════════════════════════╝\n');
        
        console.log(`⏱️  Test Duration: ${report.testDuration}ms (${(report.testDuration / 1000).toFixed(1)}s)`);
        console.log(`📊 Console Logs: ${logs.length}`);
        console.log(`❌ JavaScript Errors: ${errors.length}`);
        console.log(`🌐 Network Errors: ${networkErrors.length}`);
        console.log(`📦 Resources Loaded: ${resources.length}`);
        
        // Determine overall status
        const jQueryWorking = libraries.jquery.loaded;
        const noJQueryErrors = !errors.some(e => e.message.includes('jQuery is not defined'));
        const dashboardReached = url.includes('dashboard') || url.includes('#/');
        const menuVisible = uiElements.selectors.mainMenu?.visible || 
                           uiElements.selectors.navigation?.visible ||
                           uiElements.selectors.nav?.visible;
        
        console.log('\n═══ KEY INDICATORS ═══');
        console.log(`${jQueryWorking ? '✅' : '❌'} jQuery loaded`);
        console.log(`${noJQueryErrors ? '✅' : '❌'} No jQuery errors`);
        console.log(`${dashboardReached ? '✅' : '❌'} Dashboard URL reached`);
        console.log(`${menuVisible ? '✅' : '❌'} Navigation menu visible`);
        console.log(`${loadingGone ? '✅' : '⚠️'} Loading screen cleared`);
        
        const overallSuccess = jQueryWorking && noJQueryErrors && dashboardReached;
        
        report.summary = {
            jQueryWorking,
            noJQueryErrors,
            dashboardReached,
            menuVisible,
            loadingGone,
            overallSuccess,
            logs,
            errors,
            networkErrors
        };
        
        // Save report
        fs.writeFileSync('comprehensive_test_report.json', JSON.stringify(report, null, 2));
        console.log('\n📄 Full report saved: comprehensive_test_report.json');
        
        console.log('\n═══ SCREENSHOTS GENERATED ═══');
        console.log('  1. test_phase1_login_page.png');
        console.log('  2. test_phase2_form_filled.png');
        console.log('  3. test_phase3_dashboard_init.png');
        console.log('  4. test_phase4_ui_elements.png');
        console.log('  5. test_phase5_after_wait.png');
        console.log('  6. test_phase6_final_state.png');
        
        console.log('\n═══════════════════════════════════════════════════════════\n');
        
        if (overallSuccess) {
            console.log('🎉 OVERALL STATUS: SUCCESS ✅');
            if (!menuVisible) {
                console.log('⚠️  NOTE: Menu not visible - may need additional investigation');
            }
        } else {
            console.log('⚠️  OVERALL STATUS: PARTIAL SUCCESS / NEEDS ATTENTION');
            console.log('\nIssues to address:');
            if (!jQueryWorking) console.log('  - jQuery not loading');
            if (!noJQueryErrors) console.log('  - jQuery errors present');
            if (!dashboardReached) console.log('  - Dashboard not reached after login');
        }
        
        console.log('\n');
        
    } catch (err) {
        console.error('\n❌ Test failed with error:', err.message);
        report.error = {
            message: err.message,
            stack: err.stack
        };
        fs.writeFileSync('comprehensive_test_report.json', JSON.stringify(report, null, 2));
    } finally {
        await browser.close();
    }
})();
