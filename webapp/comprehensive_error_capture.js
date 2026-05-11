const playwright = require('playwright');
const fs = require('fs');

(async () => {
    console.log('\n╔════════════════════════════════════════════════════════════╗');
    console.log('║   COMPREHENSIVE ERROR CAPTURE & DETAILED LOG ANALYSIS     ║');
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
    
    // Comprehensive logging
    const logs = {
        console: [],
        errors: [],
        warnings: [],
        network: [],
        networkErrors: [],
        requests: []
    };
    
    // Capture all console messages
    page.on('console', msg => {
        const entry = {
            timestamp: new Date().toISOString(),
            type: msg.type(),
            text: msg.text(),
            location: msg.location(),
            args: msg.args().length
        };
        
        logs.console.push(entry);
        
        const icon = msg.type() === 'error' ? '❌' : 
                     msg.type() === 'warning' ? '⚠️' : 
                     msg.type() === 'info' ? 'ℹ️' : '📝';
        
        console.log(`${icon} [${msg.type().toUpperCase()}] ${msg.text()}`);
    });
    
    // Capture page errors
    page.on('pageerror', err => {
        logs.errors.push({
            timestamp: new Date().toISOString(),
            message: err.message,
            stack: err.stack,
            name: err.name
        });
        console.log(`❌ [PAGE ERROR] ${err.message}`);
    });
    
    // Capture network failures
    page.on('requestfailed', request => {
        logs.networkErrors.push({
            timestamp: new Date().toISOString(),
            url: request.url(),
            method: request.method(),
            resourceType: request.resourceType(),
            failure: request.failure()
        });
        console.log(`🔴 [NETWORK FAILED] ${request.url()}`);
    });
    
    // Capture all requests
    page.on('request', request => {
        logs.requests.push({
            timestamp: new Date().toISOString(),
            url: request.url(),
            method: request.method(),
            resourceType: request.resourceType(),
            headers: request.headers()
        });
    });
    
    // Capture responses
    page.on('response', response => {
        const url = response.url();
        logs.network.push({
            timestamp: new Date().toISOString(),
            url: url,
            status: response.status(),
            statusText: response.statusText(),
            contentType: response.headers()['content-type'],
            resourceType: response.request().resourceType()
        });
        
        // Log non-200 responses
        if (response.status() !== 200 && response.status() !== 304) {
            console.log(`⚠️  [HTTP ${response.status()}] ${url}`);
        }
        
        // Log 404s specifically
        if (response.status() === 404) {
            console.log(`   🔍 404 NOT FOUND: ${url}`);
        }
    });
    
    const report = {
        timestamp: new Date().toISOString(),
        phases: {},
        summary: {},
        errors: {
            extensions: [],
            initialize: [],
            moduleLoading: [],
            routing: [],
            other: []
        }
    };
    
    try {
        // ═══════════════════════════════════════════════════════════
        // PHASE 1: LOGIN PAGE ANALYSIS
        // ═══════════════════════════════════════════════════════════
        console.log('\n═══ PHASE 1: LOGIN PAGE DETAILED ANALYSIS ═══\n');
        
        await page.goto('https://pim.technostationery.com/user/login', { 
            waitUntil: 'networkidle',
            timeout: 30000 
        });
        
        await page.waitForTimeout(3000);
        
        const loginAnalysis = await page.evaluate(() => {
            return {
                title: document.title,
                url: window.location.href,
                hasForm: document.querySelector('form') !== null,
                libraries: {
                    jQuery: typeof jQuery !== 'undefined' ? jQuery.fn.jquery : null,
                    requirejs: typeof requirejs !== 'undefined',
                    underscore: typeof _ !== 'undefined',
                    backbone: typeof Backbone !== 'undefined'
                },
                scripts: Array.from(document.scripts).map(s => ({
                    src: s.src,
                    type: s.type,
                    async: s.async,
                    defer: s.defer
                })),
                stylesheets: Array.from(document.styleSheets).map(s => ({
                    href: s.href,
                    disabled: s.disabled
                }))
            };
        });
        
        console.log('Login Page Analysis:');
        console.log(`  Title: ${loginAnalysis.title}`);
        console.log(`  URL: ${loginAnalysis.url}`);
        console.log(`  Form present: ${loginAnalysis.hasForm}`);
        console.log(`  Scripts loaded: ${loginAnalysis.scripts.length}`);
        console.log(`  Stylesheets: ${loginAnalysis.stylesheets.length}`);
        console.log('  Libraries:');
        Object.entries(loginAnalysis.libraries).forEach(([name, value]) => {
            console.log(`    - ${name}: ${value || 'not loaded'}`);
        });
        
        report.phases.loginPage = loginAnalysis;
        await page.screenshot({ path: 'error_capture_1_login.png' });
        
        // ═══════════════════════════════════════════════════════════
        // PHASE 2: LOGIN SUBMISSION
        // ═══════════════════════════════════════════════════════════
        console.log('\n═══ PHASE 2: LOGIN SUBMISSION ═══\n');
        
        await page.fill('input[name="_username"]', 'mounir');
        await page.fill('input[name="_password"]', '2026');
        
        console.log('Submitting login...');
        await page.click('button[type="submit"]');
        
        // Wait for navigation with extended timeout
        try {
            await page.waitForNavigation({ 
                waitUntil: 'networkidle',
                timeout: 45000 
            });
        } catch (e) {
            console.log('⚠️  Navigation timeout - checking current state...');
        }
        
        await page.waitForTimeout(5000);
        
        // ═══════════════════════════════════════════════════════════
        // PHASE 3: POST-LOGIN DETAILED ANALYSIS
        // ═══════════════════════════════════════════════════════════
        console.log('\n═══ PHASE 3: POST-LOGIN DETAILED ANALYSIS ═══\n');
        
        const postLoginAnalysis = await page.evaluate(() => {
            const analysis = {
                url: window.location.href,
                title: document.title,
                hash: window.location.hash,
                libraries: {
                    jQuery: typeof jQuery !== 'undefined' ? jQuery.fn.jquery : null,
                    requirejs: typeof requirejs !== 'undefined',
                    underscore: typeof _ !== 'undefined' ? _.VERSION : null,
                    backbone: typeof Backbone !== 'undefined' ? Backbone.VERSION : null,
                    react: typeof React !== 'undefined' ? React.version : null,
                    webpack: typeof __webpack_require__ !== 'undefined'
                },
                globals: {
                    pimInit: typeof window.pimInit,
                    Routing: typeof Routing,
                    fos: typeof fos
                },
                dom: {
                    bodyClasses: document.body.className,
                    appDiv: document.querySelector('.app') !== null,
                    rootDiv: document.querySelector('#root') !== null,
                    loadingVisible: (() => {
                        const loader = document.querySelector('.AknDefault-progressContainer');
                        return loader ? (loader.offsetWidth > 0) : false;
                    })(),
                    menuSelectors: {
                        '.AknDefault-mainMenu': document.querySelector('.AknDefault-mainMenu') !== null,
                        'nav': document.querySelector('nav') !== null,
                        '[role="navigation"]': document.querySelector('[role="navigation"]') !== null
                    }
                },
                requirejsModules: typeof requirejs !== 'undefined' && requirejs.s ? 
                    Object.keys(requirejs.s.contexts._.defined || {}).slice(0, 20) : [],
                errors: {
                    lastError: window.lastError || null
                }
            };
            
            return analysis;
        });
        
        console.log('\nPost-Login Analysis:');
        console.log(`  URL: ${postLoginAnalysis.url}`);
        console.log(`  Title: ${postLoginAnalysis.title}`);
        console.log(`  Hash: ${postLoginAnalysis.hash}`);
        
        console.log('\n  Libraries:');
        Object.entries(postLoginAnalysis.libraries).forEach(([name, value]) => {
            const status = value ? '✅' : '❌';
            console.log(`    ${status} ${name}: ${value || 'not loaded'}`);
        });
        
        console.log('\n  Global Functions:');
        Object.entries(postLoginAnalysis.globals).forEach(([name, value]) => {
            console.log(`    - ${name}: ${value}`);
        });
        
        console.log('\n  DOM State:');
        console.log(`    - Body classes: ${postLoginAnalysis.dom.bodyClasses || '(none)'}`);
        console.log(`    - .app div: ${postLoginAnalysis.dom.appDiv ? 'exists' : 'missing'}`);
        console.log(`    - #root div: ${postLoginAnalysis.dom.rootDiv ? 'exists' : 'missing'}`);
        console.log(`    - Loading visible: ${postLoginAnalysis.dom.loadingVisible ? 'YES ⚠️' : 'NO ✅'}`);
        
        console.log('\n  Menu Elements:');
        Object.entries(postLoginAnalysis.dom.menuSelectors).forEach(([sel, exists]) => {
            console.log(`    - ${sel}: ${exists ? 'found ✅' : 'not found ❌'}`);
        });
        
        if (postLoginAnalysis.requirejsModules.length > 0) {
            console.log('\n  RequireJS Modules (first 20):');
            postLoginAnalysis.requirejsModules.forEach((mod, i) => {
                console.log(`    ${i + 1}. ${mod}`);
            });
        }
        
        report.phases.postLogin = postLoginAnalysis;
        await page.screenshot({ path: 'error_capture_2_dashboard.png', fullPage: true });
        
        // ═══════════════════════════════════════════════════════════
        // PHASE 4: ERROR CATEGORIZATION
        // ═══════════════════════════════════════════════════════════
        console.log('\n═══ PHASE 4: ERROR CATEGORIZATION ═══\n');
        
        logs.errors.forEach(err => {
            if (err.message.includes('extensions.json')) {
                report.errors.extensions.push(err);
            } else if (err.message.includes('initialize') || err.message.includes('r.initialize')) {
                report.errors.initialize.push(err);
            } else if (err.message.includes('module') || err.message.includes('require')) {
                report.errors.moduleLoading.push(err);
            } else if (err.message.includes('route') || err.message.includes('Router')) {
                report.errors.routing.push(err);
            } else {
                report.errors.other.push(err);
            }
        });
        
        logs.networkErrors.forEach(netErr => {
            if (netErr.url.includes('extensions.json')) {
                report.errors.extensions.push({
                    type: 'network',
                    url: netErr.url,
                    failure: netErr.failure
                });
            }
        });
        
        console.log('Error Breakdown:');
        console.log(`  extensions.json errors: ${report.errors.extensions.length}`);
        console.log(`  initialize errors: ${report.errors.initialize.length}`);
        console.log(`  module loading errors: ${report.errors.moduleLoading.length}`);
        console.log(`  routing errors: ${report.errors.routing.length}`);
        console.log(`  other errors: ${report.errors.other.length}`);
        
        // Detail extensions.json errors
        if (report.errors.extensions.length > 0) {
            console.log('\n  📋 extensions.json Issues:');
            report.errors.extensions.forEach((err, i) => {
                if (err.type === 'network') {
                    console.log(`    ${i + 1}. Network failure: ${err.url}`);
                    console.log(`       Reason: ${err.failure?.errorText || 'unknown'}`);
                } else {
                    console.log(`    ${i + 1}. ${err.message}`);
                }
            });
        }
        
        // Detail initialize errors
        if (report.errors.initialize.length > 0) {
            console.log('\n  ⚙️  initialize() Errors:');
            report.errors.initialize.forEach((err, i) => {
                console.log(`    ${i + 1}. ${err.message}`);
                if (err.stack) {
                    const stackLines = err.stack.split('\n').slice(0, 3);
                    stackLines.forEach(line => {
                        console.log(`       ${line.trim()}`);
                    });
                }
            });
        }
        
        // ═══════════════════════════════════════════════════════════
        // PHASE 5: NETWORK ANALYSIS
        // ═══════════════════════════════════════════════════════════
        console.log('\n═══ PHASE 5: NETWORK RESOURCE ANALYSIS ═══\n');
        
        const resourceStats = {
            total: logs.network.length,
            by_status: {},
            by_type: {},
            failed: logs.networkErrors.length,
            notFound: logs.network.filter(r => r.status === 404).length
        };
        
        logs.network.forEach(res => {
            // Count by status
            resourceStats.by_status[res.status] = (resourceStats.by_status[res.status] || 0) + 1;
            
            // Count by type
            const type = res.resourceType || 'other';
            resourceStats.by_type[type] = (resourceStats.by_type[type] || 0) + 1;
        });
        
        console.log(`Total requests: ${resourceStats.total}`);
        console.log(`Failed requests: ${resourceStats.failed}`);
        console.log(`404 Not Found: ${resourceStats.notFound}`);
        
        console.log('\nBy HTTP Status:');
        Object.entries(resourceStats.by_status)
            .sort((a, b) => b[1] - a[1])
            .forEach(([status, count]) => {
                const icon = status === '200' ? '✅' : status === '304' ? '🔄' : status === '404' ? '❌' : '⚠️';
                console.log(`  ${icon} ${status}: ${count}`);
            });
        
        console.log('\nBy Resource Type:');
        Object.entries(resourceStats.by_type)
            .sort((a, b) => b[1] - a[1])
            .forEach(([type, count]) => {
                console.log(`  - ${type}: ${count}`);
            });
        
        // List all 404s
        const notFound = logs.network.filter(r => r.status === 404);
        if (notFound.length > 0) {
            console.log('\n  📋 404 Not Found Resources:');
            notFound.forEach((res, i) => {
                console.log(`    ${i + 1}. ${res.url}`);
            });
        }
        
        report.networkStats = resourceStats;
        report.notFoundResources = notFound;
        
        // ═══════════════════════════════════════════════════════════
        // FINAL SUMMARY
        // ═══════════════════════════════════════════════════════════
        console.log('\n╔════════════════════════════════════════════════════════════╗');
        console.log('║                   COMPREHENSIVE SUMMARY                    ║');
        console.log('╚════════════════════════════════════════════════════════════╝\n');
        
        report.summary = {
            totalConsoleMessages: logs.console.length,
            totalErrors: logs.errors.length,
            totalNetworkErrors: logs.networkErrors.length,
            totalRequests: logs.requests.length,
            jQueryLoaded: postLoginAnalysis.libraries.jQuery !== null,
            dashboardReached: postLoginAnalysis.url.includes('dashboard') || postLoginAnalysis.hash.includes('dashboard'),
            menuVisible: Object.values(postLoginAnalysis.dom.menuSelectors).some(v => v),
            loadingStuck: postLoginAnalysis.dom.loadingVisible
        };
        
        console.log('Metrics:');
        console.log(`  📊 Console messages: ${report.summary.totalConsoleMessages}`);
        console.log(`  ❌ Page errors: ${report.summary.totalErrors}`);
        console.log(`  🔴 Network errors: ${report.summary.totalNetworkErrors}`);
        console.log(`  🌐 Total requests: ${report.summary.totalRequests}`);
        
        console.log('\nStatus:');
        console.log(`  ${report.summary.jQueryLoaded ? '✅' : '❌'} jQuery loaded`);
        console.log(`  ${report.summary.dashboardReached ? '✅' : '❌'} Dashboard reached`);
        console.log(`  ${report.summary.menuVisible ? '✅' : '❌'} Menu visible`);
        console.log(`  ${report.summary.loadingStuck ? '⚠️ STUCK' : '✅'} Loading screen`);
        
        // Save comprehensive report
        report.logs = logs;
        fs.writeFileSync('comprehensive_error_report.json', JSON.stringify(report, null, 2));
        console.log('\n📄 Comprehensive report saved: comprehensive_error_report.json');
        
        // Save detailed logs
        fs.writeFileSync('detailed_console_logs.json', JSON.stringify(logs.console, null, 2));
        fs.writeFileSync('detailed_errors.json', JSON.stringify(logs.errors, null, 2));
        fs.writeFileSync('detailed_network.json', JSON.stringify(logs.network, null, 2));
        
        console.log('📄 Detailed logs saved:');
        console.log('   - detailed_console_logs.json');
        console.log('   - detailed_errors.json');
        console.log('   - detailed_network.json');
        
        console.log('\n═══════════════════════════════════════════════════════════\n');
        
    } catch (err) {
        console.error('\n❌ Test error:', err.message);
        report.testError = {
            message: err.message,
            stack: err.stack
        };
        fs.writeFileSync('comprehensive_error_report.json', JSON.stringify(report, null, 2));
    } finally {
        await browser.close();
    }
})();
