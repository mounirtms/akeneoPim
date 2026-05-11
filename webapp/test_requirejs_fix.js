const playwright = require('playwright');

(async () => {
    const browser = await playwright.chromium.launch({ headless: true });
    const context = await browser.newContext({
        ignoreHTTPSErrors: true
    });
    const page = await context.newPage();
    
    // Collect console messages
    const consoleMessages = [];
    page.on('console', msg => {
        consoleMessages.push(`${msg.type()}: ${msg.text()}`);
    });
    
    // Collect errors
    const errors = [];
    page.on('pageerror', error => {
        errors.push(error.toString());
    });
    
    try {
        console.log('🔍 Testing RequireJS configuration...\n');
        
        // Navigate to login page
        await page.goto('https://pim.technostationery.com/user/login', {
            waitUntil: 'networkidle',
            timeout: 30000
        });
        
        // Login
        await page.fill('input[name="_username"]', 'testuser');
        await page.fill('input[name="_password"]', 'TestPass123!');
        await page.click('button[type="submit"]');
        
        console.log('⏳ Waiting for dashboard initialization...\n');
        
        // Wait for navigation and initial load
        await page.waitForLoadState('networkidle', { timeout: 30000 });
        
        // Wait a bit for JavaScript initialization
        await page.waitForTimeout(5000);
        
        // Check the page state
        const loadingVisible = await page.isVisible('.AknDefault-progressContainer');
        const menuVisible = await page.isVisible('.AknDefault-mainMenu, nav.AknMainMenu');
        
        // Get RequireJS module count
        const requirejsModules = await page.evaluate(() => {
            if (typeof requirejs !== 'undefined' && typeof requirejs.s !== 'undefined') {
                return Object.keys(requirejs.s.contexts._.defined).length;
            }
            return 0;
        });
        
        // Check for specific errors
        const hasRequireJSError = consoleMessages.some(msg => 
            msg.includes('Failed to load entry point') || 
            msg.includes('Script error') ||
            msg.includes('MIME type')
        );
        
        // Get specific console messages about module loading
        const moduleMessages = consoleMessages.filter(msg => 
            msg.includes('[Akeneo]') || 
            msg.includes('[module-registry]') ||
            msg.includes('RequireJS')
        );
        
        console.log('📊 Test Results:');
        console.log('================');
        console.log(`Loading Screen: ${loadingVisible ? '❌ VISIBLE' : '✅ HIDDEN'}`);
        console.log(`Navigation Menu: ${menuVisible ? '✅ VISIBLE' : '❌ MISSING'}`);
        console.log(`RequireJS Modules Loaded: ${requirejsModules}`);
        console.log(`RequireJS Errors: ${hasRequireJSError ? '❌ YES' : '✅ NO'}`);
        console.log(`Page Errors: ${errors.length}`);
        
        console.log('\n📝 Relevant Console Messages:');
        console.log('=============================');
        moduleMessages.forEach(msg => console.log(`  ${msg}`));
        
        if (errors.length > 0) {
            console.log('\n❌ Page Errors:');
            console.log('===============');
            errors.forEach(err => console.log(`  ${err}`));
        }
        
        // Take screenshot
        await page.screenshot({ path: '/home/pim/public_html/webapp/test_requirejs_fix.png', fullPage: true });
        console.log('\n📸 Screenshot saved to test_requirejs_fix.png');
        
        // Final verdict
        console.log('\n🎯 Final Verdict:');
        console.log('=================');
        if (!loadingVisible && menuVisible && !hasRequireJSError) {
            console.log('✅ SUCCESS: Dashboard initialized correctly!');
        } else if (hasRequireJSError) {
            console.log('❌ FAILED: RequireJS module loading errors detected');
            console.log('   Issue: Module path resolution failing');
        } else if (loadingVisible) {
            console.log('⚠️  PARTIAL: Dashboard still loading');
            console.log('   Possible causes:');
            console.log('   - RequireJS config incomplete');
            console.log('   - Module loading slow');
            console.log('   - JavaScript initialization blocked');
        } else {
            console.log('⚠️  UNKNOWN: Check console messages above');
        }
        
    } catch (error) {
        console.error('❌ Test failed with error:', error.message);
    } finally {
        await browser.close();
    }
})();
