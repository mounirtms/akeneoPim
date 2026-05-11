const { chromium } = require('playwright');
const fs = require('fs');

async function verifyTemplatePatch() {
    console.log('🔍 TEMPLATE PATCH VERIFICATION TEST\n');
    console.log('=' .repeat(60));
    
    const results = {
        timestamp: new Date().toISOString(),
        testName: 'Template Patch Verification',
        phases: []
    };

    const browser = await chromium.launch({ 
        headless: true,
        args: ['--disable-blink-features=AutomationControlled']
    });
    const context = await browser.newContext({
        viewport: { width: 1920, height: 1080 },
        ignoreHTTPSErrors: true,
        userAgent: 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36'
    });
    const page = await context.newPage();

    // Capture console messages and errors
    const consoleMessages = [];
    const errors = [];
    
    page.on('console', msg => {
        const text = msg.text();
        consoleMessages.push({ type: msg.type(), text });
        console.log(`[CONSOLE ${msg.type()}] ${text}`);
    });
    
    page.on('pageerror', error => {
        errors.push(error.message);
        console.log(`[ERROR] ${error.message}`);
    });

    try {
        // PHASE 1: Login
        console.log('\n📝 PHASE 1: Login to PIM');
        console.log('-'.repeat(60));
        
        await page.goto('https://pim.technostationery.com/user/login', {
            waitUntil: 'networkidle',
            timeout: 30000
        });
        
        await page.fill('input[name="_username"]', 'mounir');
        await page.fill('input[name="_password"]', '2026');
        await page.click('button[type="submit"]');
        
        await page.waitForTimeout(3000);
        await page.screenshot({ path: 'template_verify_1_login.png', fullPage: true });
        
        console.log('✅ Login completed');

        // PHASE 2: Check HTML Source for Patch
        console.log('\n🔎 PHASE 2: Check HTML Source for Patch Code');
        console.log('-'.repeat(60));
        
        const htmlContent = await page.content();
        
        const checks = {
            cacheBuster: htmlContent.includes('20260509_000000'),
            criticalFixComment: htmlContent.includes('CRITICAL FIX: Mock feature flags manager'),
            featureFlagsInit: htmlContent.includes('window.featureFlags'),
            rAssignment: htmlContent.includes('window.r = window.featureFlags'),
            patchAppliedLog: htmlContent.includes('[Akeneo] Applying r.initialize patch'),
            patchSuccessLog: htmlContent.includes('[Akeneo] r.initialize patch applied successfully')
        };
        
        console.log('\nHTML Source Checks:');
        console.log(`  Cache Buster (20260509_000000): ${checks.cacheBuster ? '✅' : '❌'}`);
        console.log(`  CRITICAL FIX Comment: ${checks.criticalFixComment ? '✅' : '❌'}`);
        console.log(`  window.featureFlags code: ${checks.featureFlagsInit ? '✅' : '❌'}`);
        console.log(`  window.r assignment: ${checks.rAssignment ? '✅' : '❌'}`);
        console.log(`  Patch apply log: ${checks.patchAppliedLog ? '✅' : '❌'}`);
        console.log(`  Patch success log: ${checks.patchSuccessLog ? '✅' : '❌'}`);
        
        results.phases.push({
            phase: 'HTML Source Check',
            checks,
            allPassed: Object.values(checks).every(v => v)
        });

        // Save HTML snippet for manual inspection
        const patchSection = htmlContent.match(/CRITICAL FIX[\s\S]{0,800}/);
        if (patchSection) {
            fs.writeFileSync('template_patch_snippet.html', patchSection[0]);
            console.log('\n📄 Saved patch snippet to: template_patch_snippet.html');
        }

        // PHASE 3: Check Console Messages
        console.log('\n📢 PHASE 3: Check Console Messages for Patch');
        console.log('-'.repeat(60));
        
        const patchMessages = consoleMessages.filter(m => 
            m.text.includes('[Akeneo]') || 
            m.text.includes('patch') ||
            m.text.includes('featureFlags')
        );
        
        console.log(`\nPatch-related console messages: ${patchMessages.length}`);
        patchMessages.forEach(msg => {
            console.log(`  [${msg.type}] ${msg.text}`);
        });
        
        results.phases.push({
            phase: 'Console Messages',
            patchMessages: patchMessages.map(m => m.text),
            count: patchMessages.length
        });

        // PHASE 4: Check Runtime Objects
        console.log('\n🔬 PHASE 4: Check Runtime Objects in Browser');
        console.log('-'.repeat(60));
        
        const runtimeState = await page.evaluate(() => {
            return {
                windowFeatureFlagsExists: typeof window.featureFlags !== 'undefined',
                windowRExists: typeof window.r !== 'undefined',
                featureFlagsHasInitialize: typeof window.featureFlags?.initialize === 'function',
                rHasInitialize: typeof window.r?.initialize === 'function',
                featureFlagsHasIsEnabled: typeof window.featureFlags?.isEnabled === 'function',
                rEqualsFeatureFlags: window.r === window.featureFlags,
                jQuery: typeof jQuery !== 'undefined' ? jQuery.fn.jquery : 'not loaded',
                Backbone: typeof Backbone !== 'undefined' ? Backbone.VERSION : 'not loaded'
            };
        });
        
        console.log('\nRuntime Object Status:');
        console.log(`  window.featureFlags exists: ${runtimeState.windowFeatureFlagsExists ? '✅' : '❌'}`);
        console.log(`  window.r exists: ${runtimeState.windowRExists ? '✅' : '❌'}`);
        console.log(`  featureFlags.initialize(): ${runtimeState.featureFlagsHasInitialize ? '✅' : '❌'}`);
        console.log(`  r.initialize(): ${runtimeState.rHasInitialize ? '✅' : '❌'}`);
        console.log(`  featureFlags.isEnabled(): ${runtimeState.featureFlagsHasIsEnabled ? '✅' : '❌'}`);
        console.log(`  r === featureFlags: ${runtimeState.rEqualsFeatureFlags ? '✅' : '❌'}`);
        console.log(`  jQuery: ${runtimeState.jQuery}`);
        console.log(`  Backbone: ${runtimeState.Backbone}`);
        
        results.phases.push({
            phase: 'Runtime Objects',
            ...runtimeState,
            allPassed: runtimeState.rHasInitialize && runtimeState.featureFlagsHasInitialize
        });

        // PHASE 5: Check for Original Error
        console.log('\n⚠️  PHASE 5: Check for "r.initialize is not a function" Error');
        console.log('-'.repeat(60));
        
        const hasRInitializeError = errors.some(e => 
            e.includes('r.initialize is not a function') ||
            e.includes('r.initialize') ||
            e.includes('TypeError')
        );
        
        const relevantErrors = errors.filter(e => 
            e.includes('initialize') || 
            e.includes('TypeError') ||
            e.includes('undefined')
        );
        
        console.log(`\nr.initialize error detected: ${hasRInitializeError ? '❌ YES (BAD)' : '✅ NO (GOOD)'}`);
        console.log(`\nRelevant errors (${relevantErrors.length}):`);
        relevantErrors.forEach(err => console.log(`  ❌ ${err}`));
        
        results.phases.push({
            phase: 'Error Check',
            hasRInitializeError,
            errorCount: relevantErrors.length,
            errors: relevantErrors
        });

        // PHASE 6: Test Manual r.initialize() Call
        console.log('\n🧪 PHASE 6: Test Manual r.initialize() Call');
        console.log('-'.repeat(60));
        
        const manualTest = await page.evaluate(() => {
            try {
                if (typeof window.r !== 'undefined' && typeof window.r.initialize === 'function') {
                    const result = window.r.initialize();
                    return {
                        success: true,
                        returned: typeof result,
                        isPromise: result && typeof result.then === 'function',
                        message: 'Successfully called r.initialize()'
                    };
                } else {
                    return {
                        success: false,
                        message: 'r.initialize is not available',
                        rType: typeof window.r,
                        rInitType: typeof window.r?.initialize
                    };
                }
            } catch (error) {
                return {
                    success: false,
                    error: error.message
                };
            }
        });
        
        console.log('\nManual Test Result:');
        console.log(JSON.stringify(manualTest, null, 2));
        
        results.phases.push({
            phase: 'Manual Test',
            ...manualTest
        });

        // PHASE 7: Check Page State
        console.log('\n📊 PHASE 7: Check Page State');
        console.log('-'.repeat(60));
        
        const pageState = await page.evaluate(() => {
            return {
                url: window.location.href,
                loadingVisible: document.querySelector('.AknDefault-progressContainer') ? 
                    window.getComputedStyle(document.querySelector('.AknDefault-progressContainer')).display !== 'none' : false,
                menuExists: document.querySelector('.AknDefault-mainMenu') !== null,
                totalLinks: document.querySelectorAll('a').length,
                totalButtons: document.querySelectorAll('button').length,
                bodyClasses: document.body.className
            };
        });
        
        console.log('\nPage State:');
        console.log(`  URL: ${pageState.url}`);
        console.log(`  Loading screen visible: ${pageState.loadingVisible ? '❌ YES' : '✅ NO'}`);
        console.log(`  Menu exists: ${pageState.menuExists ? '✅ YES' : '❌ NO'}`);
        console.log(`  Total links: ${pageState.totalLinks}`);
        console.log(`  Total buttons: ${pageState.totalButtons}`);
        console.log(`  Body classes: ${pageState.bodyClasses || '(none)'}`);
        
        results.phases.push({
            phase: 'Page State',
            ...pageState
        });

        await page.screenshot({ path: 'template_verify_2_final.png', fullPage: true });

        // SUMMARY
        console.log('\n' + '='.repeat(60));
        console.log('📋 SUMMARY');
        console.log('='.repeat(60));
        
        const allChecks = {
            htmlHasPatch: results.phases[0].allPassed,
            runtimeHasPatch: results.phases[2].allPassed,
            noErrors: !results.phases[3].hasRInitializeError,
            manualCallWorks: results.phases[4].success
        };
        
        console.log('\n✅ PASS / ❌ FAIL Summary:');
        console.log(`  HTML contains patch code: ${allChecks.htmlHasPatch ? '✅' : '❌'}`);
        console.log(`  Runtime objects created: ${allChecks.runtimeHasPatch ? '✅' : '❌'}`);
        console.log(`  No r.initialize errors: ${allChecks.noErrors ? '✅' : '❌'}`);
        console.log(`  Manual r.initialize() works: ${allChecks.manualCallWorks ? '✅' : '❌'}`);
        
        const overallSuccess = Object.values(allChecks).every(v => v);
        console.log(`\n🎯 Overall Result: ${overallSuccess ? '✅ PATCH WORKING' : '❌ PATCH NOT WORKING'}`);
        
        results.summary = {
            checks: allChecks,
            overallSuccess,
            totalConsoleMessages: consoleMessages.length,
            totalErrors: errors.length,
            recommendation: overallSuccess ? 
                'Patch is working correctly. Proceed to Phase 9 (Webpack rebuild).' :
                'Patch not loading. Check: 1) Template being used, 2) Cache layers, 3) Cloudflare cache.'
        };

    } catch (error) {
        console.error('\n❌ TEST FAILED:', error.message);
        results.error = error.message;
    } finally {
        await browser.close();
        
        // Save results
        fs.writeFileSync('template_verification_results.json', JSON.stringify(results, null, 2));
        console.log('\n💾 Results saved to: template_verification_results.json');
        console.log('📸 Screenshots saved: template_verify_1_login.png, template_verify_2_final.png');
    }
}

verifyTemplatePatch().catch(console.error);
