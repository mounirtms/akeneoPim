const { chromium } = require('playwright');

async function injectPatchViaDevTools() {
    console.log('🔧 EMERGENCY: Injecting patch via browser JavaScript...\n');
    
    const browser = await chromium.launch({ headless: false });
    const context = await browser.newContext({ 
        ignoreHTTPSErrors: true,
        viewport: { width: 1920, height: 1080 }
    });
    const page = await context.newPage();
    
    try {
        console.log('Step 1: Going to login page...');
        await page.goto('https://pim.technostationery.com/user/login', {
            waitUntil: 'domcontentloaded'
        });
        
        console.log('Step 2: Injecting emergency patch into page...');
        await page.addScriptTag({
            content: `
                console.log('[INJECTED PATCH] Starting...');
                
                window.featureFlags = {
                    initialize: function() {
                        console.log('[INJECTED PATCH] Feature flags initialized');
                        if (typeof jQuery !== 'undefined' && jQuery.Deferred) {
                            return jQuery.Deferred().resolve();
                        }
                        return Promise.resolve();
                    },
                    isEnabled: function(feature) {
                        console.log('[INJECTED PATCH] Feature check:', feature);
                        return true;
                    }
                };
                
                window.r = window.featureFlags;
                window.t = {
                    initialize: function() {
                        console.log('[INJECTED PATCH] Security initialized');
                        if (typeof jQuery !== 'undefined' && jQuery.Deferred) {
                            return jQuery.Deferred().resolve();
                        }
                        return Promise.resolve();
                    }
                };
                
                console.log('[INJECTED PATCH] ✅ Complete');
                console.log('[INJECTED PATCH] window.r.initialize:', typeof window.r.initialize);
            `
        });
        
        console.log('Step 3: Logging in...');
        await page.fill('input[name="_username"]', 'mounir');
        await page.fill('input[name="_password"]', '2026');
        await page.click('button[type="submit"]');
        
        console.log('Step 4: Waiting for navigation...');
        await page.waitForTimeout(5000);
        
        console.log('Step 5: Checking page state...');
        const state = await page.evaluate(() => {
            return {
                url: window.location.href,
                rExists: typeof window.r !== 'undefined',
                rInitExists: typeof window.r?.initialize === 'function',
                loadingVisible: document.querySelector('.AknDefault-progressContainer') ? 
                    window.getComputedStyle(document.querySelector('.AknDefault-progressContainer')).display !== 'none' : false,
                menuExists: document.querySelector('.AknDefault-mainMenu') !== null
            };
        });
        
        console.log('\nResults:');
        console.log('  URL:', state.url);
        console.log('  window.r exists:', state.rExists ? '✅' : '❌');
        console.log('  r.initialize exists:', state.rInitExists ? '✅' : '❌');
        console.log('  Loading screen visible:', state.loadingVisible ? '❌ YES' : '✅ NO');
        console.log('  Menu exists:', state.menuExists ? '✅' : '❌');
        
        console.log('\n⏳ Keeping browser open for 30 seconds to observe behavior...');
        await page.waitForTimeout(30000);
        
    } catch (error) {
        console.error('Error:', error.message);
    } finally {
        await browser.close();
    }
}

injectPatchViaDevTools().catch(console.error);
