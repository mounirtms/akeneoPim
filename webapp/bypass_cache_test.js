const { chromium } = require('playwright');
const fs = require('fs');

async function bypassCacheTest() {
    console.log('🚀 CACHE BYPASS TEST - Using Unique Parameters\n');
    console.log('=' .repeat(60));
    
    const timestamp = Date.now();
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

    const consoleMessages = [];
    const errors = [];
    
    page.on('console', msg => {
        const text = msg.text();
        consoleMessages.push({ type: msg.type(), text });
        if (text.includes('[Akeneo Patch]') || text.includes('r.initialize')) {
            console.log(`[CONSOLE ${msg.type()}] ${text}`);
        }
    });
    
    page.on('pageerror', error => {
        errors.push(error.message);
        console.log(`[ERROR] ${error.message}`);
    });

    try {
        // Login with cache bypass
        console.log('\n📝 Step 1: Login (bypassing Cloudflare cache)');
        await page.goto(`https://pim.technostationery.com/user/login?_=${timestamp}`, {
            waitUntil: 'networkidle',
            timeout: 30000
        });
        
        await page.fill('input[name="_username"]', 'mounir');
        await page.fill('input[name="_password"]', '2026');
        await page.click('button[type="submit"]');
        
        await page.waitForTimeout(5000); // Wait longer for full page load
        
        console.log('\n🔍 Step 2: Check Console for Patch Messages');
        const patchMessages = consoleMessages.filter(m => 
            m.text.includes('[Akeneo Patch]') || 
            m.text.includes('patch') ||
            m.text.includes('featureFlags')
        );
        
        console.log(`Found ${patchMessages.length} patch-related messages:`);
        patchMessages.forEach(msg => console.log(`  [${msg.type}] ${msg.text}`));
        
        console.log('\n🧪 Step 3: Check Runtime State');
        const state = await page.evaluate(() => {
            return {
                rExists: typeof window.r !== 'undefined',
                rHasInitialize: typeof window.r?.initialize === 'function',
                featureFlagsExists: typeof window.featureFlags !== 'undefined',
                featureFlagsHasInit: typeof window.featureFlags?.initialize === 'function',
                jQuery: typeof jQuery !== 'undefined' ? jQuery.fn.jquery : 'not loaded',
                url: window.location.href
            };
        });
        
        console.log('\nRuntime State:');
        console.log(`  window.r exists: ${state.rExists ? '✅' : '❌'}`);
        console.log(`  r.initialize exists: ${state.rHasInitialize ? '✅' : '❌'}`);
        console.log(`  window.featureFlags exists: ${state.featureFlagsExists ? '✅' : '❌'}`);
        console.log(`  featureFlags.initialize exists: ${state.featureFlagsHasInit ? '✅' : '❌'}`);
        console.log(`  jQuery: ${state.jQuery}`);
        console.log(`  Current URL: ${state.url}`);
        
        console.log('\n⚠️  Step 4: Check for r.initialize Error');
        const hasError = errors.some(e => e.includes('r.initialize is not a function'));
        console.log(`  r.initialize error: ${hasError ? '❌ YES (STILL BROKEN)' : '✅ NO (FIXED!)'}`);
        
        if (hasError) {
            console.log('\n❌ PATCH NOT WORKING - Likely causes:');
            console.log('  1. Cloudflare 24hr cache TTL not expired yet');
            console.log('  2. Template changes need more time to propagate');
            console.log('  3. Need to manually purge Cloudflare cache');
        } else {
            console.log('\n✅ SUCCESS! Patch is working!');
        }
        
        await page.screenshot({ path: 'bypass_cache_test.png', fullPage: true });
        
        // Save results
        const results = {
            timestamp: new Date().toISOString(),
            patchMessages,
            state,
            hasRInitializeError: hasError,
            errors,
            success: !hasError && state.rHasInitialize
        };
        
        fs.writeFileSync('bypass_cache_results.json', JSON.stringify(results, null, 2));
        console.log('\n💾 Results saved to: bypass_cache_results.json');

    } catch (error) {
        console.error('\n❌ TEST FAILED:', error.message);
    } finally {
        await browser.close();
    }
}

bypassCacheTest().catch(console.error);
