const playwright = require('playwright');
const fs = require('fs');

(async () => {
    console.log('╔════════════════════════════════════════════════════════════╗');
    console.log('║         ADVANCED DIAGNOSTIC TEST - PHASE 6                 ║');
    console.log('╚════════════════════════════════════════════════════════════╝\n');

    const browser = await playwright.chromium.launch({ headless: true });
    const context = await browser.newContext({
        ignoreHTTPSErrors: true,
        viewport: { width: 1920, height: 1080 }
    });
    const page = await context.newPage();

    const diagnostics = {
        timestamp: new Date().toISOString(),
        tests: {},
        errors: [],
        warnings: [],
        resources: {},
        mainJsAnalysis: {},
        extensionsJsonAnalysis: {},
        webpackAnalysis: {}
    };

    // Capture all console messages
    page.on('console', msg => {
        const text = msg.text();
        console.log(`[CONSOLE ${msg.type().toUpperCase()}] ${text}`);
        diagnostics.warnings.push({ type: msg.type(), message: text });
    });

    // Capture all errors
    page.on('pageerror', error => {
        console.log(`[PAGE ERROR] ${error.message}`);
        diagnostics.errors.push({ 
            message: error.message, 
            stack: error.stack,
            timestamp: new Date().toISOString()
        });
    });

    // Network monitoring
    const networkLog = [];
    page.on('response', response => {
        networkLog.push({
            url: response.url(),
            status: response.status(),
            contentType: response.headers()['content-type'],
            ok: response.ok()
        });
    });

    try {
        console.log('\n📋 Test 1: Check extensions.json availability...');
        
        // Direct check for extensions.json
        const extensionsUrls = [
            'https://pim.technostationery.com/js/extensions.json',
            'https://pim.technostationery.com/public/js/extensions.json',
            'https://pim.technostationery.com/bundles/extensions.json',
            'https://pim.technostationery.com/dist/extensions.json',
            'https://pim.technostationery.com/config/extensions.json'
        ];

        for (const url of extensionsUrls) {
            try {
                const response = await page.goto(url, { timeout: 5000, waitUntil: 'domcontentloaded' });
                diagnostics.extensionsJsonAnalysis[url] = {
                    status: response.status(),
                    found: response.ok(),
                    contentType: response.headers()['content-type']
                };
                console.log(`   ${response.ok() ? '✅' : '❌'} ${url} - Status: ${response.status()}`);
                
                if (response.ok()) {
                    const content = await response.text();
                    diagnostics.extensionsJsonAnalysis[url].content = content.substring(0, 500);
                }
            } catch (err) {
                diagnostics.extensionsJsonAnalysis[url] = { error: err.message };
                console.log(`   ❌ ${url} - Error: ${err.message}`);
            }
        }

        console.log('\n📋 Test 2: Analyze main.min.js for r.initialize...');
        
        const mainJsResponse = await page.goto('https://pim.technostationery.com/dist/main.min.js?v=20260508_194500', { 
            timeout: 10000, 
            waitUntil: 'domcontentloaded' 
        });
        
        const mainJsContent = await mainJsResponse.text();
        diagnostics.mainJsAnalysis.size = mainJsContent.length;
        diagnostics.mainJsAnalysis.hasInitialize = mainJsContent.includes('.initialize');
        diagnostics.mainJsAnalysis.initializeCount = (mainJsContent.match(/\.initialize/g) || []).length;
        diagnostics.mainJsAnalysis.hasWebpackRequire = mainJsContent.includes('__webpack_require__');
        diagnostics.mainJsAnalysis.webpackRequireCount = (mainJsContent.match(/__webpack_require__/g) || []).length;
        
        // Search for initialize patterns
        const initializePatterns = [
            /r\.initialize\s*=/g,
            /initialize:\s*function/g,
            /\.prototype\.initialize/g,
            /initialize:\s*\(/g
        ];
        
        initializePatterns.forEach((pattern, idx) => {
            const matches = mainJsContent.match(pattern) || [];
            diagnostics.mainJsAnalysis[`pattern${idx+1}`] = {
                pattern: pattern.toString(),
                count: matches.length,
                found: matches.length > 0
            };
        });

        // Extract context around error location (line 2:374152)
        const errorContext = mainJsContent.substring(374100, 374250);
        diagnostics.mainJsAnalysis.errorContext = errorContext;
        
        console.log(`   📦 File size: ${mainJsContent.length} bytes`);
        console.log(`   🔍 Contains '.initialize': ${diagnostics.mainJsAnalysis.hasInitialize} (${diagnostics.mainJsAnalysis.initializeCount} occurrences)`);
        console.log(`   🔍 Contains '__webpack_require__': ${diagnostics.mainJsAnalysis.hasWebpackRequire} (${diagnostics.mainJsAnalysis.webpackRequireCount} occurrences)`);
        console.log(`   📍 Error context at ~374152: "${errorContext.substring(0, 50)}..."`);

        console.log('\n📋 Test 3: Check webpack bundling...');
        
        await page.goto('https://pim.technostationery.com/user/login', { 
            timeout: 30000, 
            waitUntil: 'networkidle' 
        });
        
        await page.fill('input[name="_username"]', 'mounir');
        await page.fill('input[name="_password"]', '2026');
        await page.click('button[type="submit"]');
        await page.waitForTimeout(5000);

        const webpackCheck = await page.evaluate(() => {
            return {
                webpackDefined: typeof __webpack_require__ !== 'undefined',
                webpackType: typeof __webpack_require__,
                windowKeys: Object.keys(window).filter(k => k.includes('webpack')),
                requireJsDefined: typeof requirejs !== 'undefined',
                requireJsConfig: typeof requirejs !== 'undefined' ? requirejs.s?.contexts?._?.config : null,
                backboneVersion: typeof Backbone !== 'undefined' ? Backbone.VERSION : null,
                backboneRouterExists: typeof Backbone !== 'undefined' && typeof Backbone.Router !== 'undefined',
                mainModules: typeof window.pimInit === 'function',
                documentReadyState: document.readyState
            };
        });
        
        diagnostics.webpackAnalysis = webpackCheck;
        
        console.log(`   ${webpackCheck.webpackDefined ? '✅' : '❌'} __webpack_require__ defined: ${webpackCheck.webpackDefined}`);
        console.log(`   ${webpackCheck.requireJsDefined ? '✅' : '❌'} RequireJS defined: ${webpackCheck.requireJsDefined}`);
        console.log(`   ${webpackCheck.backboneRouterExists ? '✅' : '❌'} Backbone.Router exists: ${webpackCheck.backboneRouterExists}`);
        console.log(`   ${webpackCheck.mainModules ? '✅' : '❌'} pimInit() function exists: ${webpackCheck.mainModules}`);

        console.log('\n📋 Test 4: Analyze getExtensionMap function...');
        
        const extensionMapAnalysis = await page.evaluate(() => {
            let analysis = { found: false };
            
            // Try to find getExtensionMap in window
            const searchObject = (obj, path = 'window') => {
                for (let key in obj) {
                    if (key === 'getExtensionMap') {
                        analysis.found = true;
                        analysis.location = `${path}.${key}`;
                        analysis.type = typeof obj[key];
                        return true;
                    }
                }
                return false;
            };
            
            searchObject(window);
            
            // Check if it's in require modules
            if (typeof requirejs !== 'undefined' && requirejs.s?.contexts?._?.defined) {
                analysis.requireModules = Object.keys(requirejs.s.contexts._.defined);
            }
            
            return analysis;
        });
        
        diagnostics.tests.extensionMapAnalysis = extensionMapAnalysis;
        console.log(`   ${extensionMapAnalysis.found ? '✅' : '❌'} getExtensionMap found: ${extensionMapAnalysis.found}`);
        if (extensionMapAnalysis.found) {
            console.log(`   📍 Location: ${extensionMapAnalysis.location}`);
        }

        console.log('\n📋 Test 5: Check module loading order...');
        
        const moduleLoadOrder = networkLog.filter(r => 
            r.url.includes('.js') && 
            r.url.includes('pim.technostationery.com')
        ).map(r => ({
            file: r.url.split('/').pop().split('?')[0],
            status: r.status,
            ok: r.ok
        }));
        
        diagnostics.tests.moduleLoadOrder = moduleLoadOrder;
        moduleLoadOrder.forEach(mod => {
            console.log(`   ${mod.ok ? '✅' : '❌'} ${mod.file} (${mod.status})`);
        });

        console.log('\n📋 Test 6: Check for Akeneo module definitions...');
        
        const akeneoModules = await page.evaluate(() => {
            const modules = {
                pimExtension: typeof window.pim !== 'undefined' && typeof window.pim.extension !== 'undefined',
                pimRouter: typeof window.pim !== 'undefined' && typeof window.pim.router !== 'undefined',
                pimApp: typeof window.pim !== 'undefined' && typeof window.pim.app !== 'undefined',
                registeredModules: []
            };
            
            if (typeof requirejs !== 'undefined' && requirejs.s?.contexts?._?.defined) {
                modules.registeredModules = Object.keys(requirejs.s.contexts._.defined)
                    .filter(m => m.includes('pim/') || m.includes('oro/') || m.includes('akeneo/'));
            }
            
            return modules;
        });
        
        diagnostics.tests.akeneoModules = akeneoModules;
        console.log(`   ${akeneoModules.pimExtension ? '✅' : '❌'} pim.extension defined: ${akeneoModules.pimExtension}`);
        console.log(`   ${akeneoModules.pimRouter ? '✅' : '❌'} pim.router defined: ${akeneoModules.pimRouter}`);
        console.log(`   ${akeneoModules.pimApp ? '✅' : '❌'} pim.app defined: ${akeneoModules.pimApp}`);
        console.log(`   📦 Registered modules: ${akeneoModules.registeredModules.length}`);

        // Take screenshot
        await page.screenshot({ path: 'diagnostic_dashboard.png', fullPage: true });
        diagnostics.tests.screenshotTaken = 'diagnostic_dashboard.png';

    } catch (error) {
        console.error('\n❌ Test error:', error.message);
        diagnostics.errors.push({ fatal: true, message: error.message, stack: error.stack });
    }

    // Save comprehensive diagnostics
    fs.writeFileSync('advanced_diagnostics.json', JSON.stringify(diagnostics, null, 2));
    
    console.log('\n╔════════════════════════════════════════════════════════════╗');
    console.log('║                    DIAGNOSTIC SUMMARY                      ║');
    console.log('╚════════════════════════════════════════════════════════════╝');
    console.log(`\n📊 Total errors captured: ${diagnostics.errors.length}`);
    console.log(`📊 Total warnings: ${diagnostics.warnings.length}`);
    console.log(`📊 Network requests: ${networkLog.length}`);
    console.log(`\n✅ Diagnostic report saved: advanced_diagnostics.json`);
    console.log(`✅ Screenshot saved: diagnostic_dashboard.png\n`);

    await browser.close();
})();
