const { chromium } = require('playwright');

(async () => {
  console.log('🚀 Starting Comprehensive Akeneo PIM Test');
  console.log('==========================================\n');

  const browser = await chromium.launch({ 
    headless: false,  // Use real browser window
    args: ['--no-sandbox', '--disable-setuid-sandbox', '--ignore-certificate-errors'],
    slowMo: 100  // Slow down actions for visibility
  });
  
  const context = await browser.newContext({
    ignoreHTTPSErrors: true,
    viewport: { width: 1920, height: 1080 }
  });
  
  const page = await context.newPage();
  
  // Collect all console messages
  const consoleMessages = [];
  page.on('console', msg => {
    const text = msg.text();
    consoleMessages.push({ type: msg.type(), text });
    // Log important messages in real-time
    if (text.includes('[Akeneo]') || text.includes('PIM') || text.includes('error')) {
      console.log(`[Browser Console] [${msg.type()}] ${text}`);
    }
  });
  
  // Collect errors
  const errors = [];
  page.on('pageerror', error => {
    console.log(`[Browser Error] ${error.message}`);
    errors.push(error.message);
  });
  
  // Collect network requests
  const failedRequests = [];
  page.on('response', response => {
    if (response.status() >= 400) {
      failedRequests.push({
        url: response.url(),
        status: response.status()
      });
    }
  });
  
  try {
    console.log('📍 Step 1: Loading Akeneo PIM homepage...');
    await page.goto('https://akeneo-pim.vn.co.th', { 
      waitUntil: 'domcontentloaded',
      timeout: 30000 
    });
    
    await page.waitForTimeout(3000);
    
    const currentUrl = page.url();
    console.log(`   Current URL: ${currentUrl}`);
    
    // Check if we're on login page
    if (currentUrl.includes('login')) {
      console.log('\n📍 Step 2: Login page detected, performing login...');
      
      const hasLoginForm = await page.evaluate(() => {
        return document.querySelector('input[name="_username"]') !== null;
      });
      
      if (!hasLoginForm) {
        console.log('   ⚠️  Login form not found, checking page content...');
        const bodyText = await page.evaluate(() => document.body.innerText.substring(0, 200));
        console.log(`   Page content: ${bodyText}`);
      } else {
        console.log('   ✓ Login form found');
        
        await page.fill('input[name="_username"]', 'testuser');
        console.log('   ✓ Username entered');
        
        await page.fill('input[name="_password"]', 'TestPass123!');
        console.log('   ✓ Password entered');
        
        await page.click('button[type="submit"]');
        console.log('   ✓ Login button clicked');
        
        console.log('\n📍 Step 3: Waiting for dashboard to load (20 seconds)...');
        await page.waitForTimeout(20000);
        
        console.log(`   Post-login URL: ${page.url()}`);
      }
    } else {
      console.log('   ℹ️  Already logged in or different page');
    }
    
    console.log('\n📍 Step 4: Analyzing page state...');
    
    // Check loading screen
    const loadingState = await page.evaluate(() => {
      const loading = document.querySelector('.AknDefault-progressContainer');
      if (!loading) return 'not_found';
      const display = window.getComputedStyle(loading).display;
      const visibility = window.getComputedStyle(loading).visibility;
      return { display, visibility, exists: true };
    });
    
    console.log('   Loading Screen Status:');
    console.log(`     - Exists: ${loadingState !== 'not_found'}`);
    if (loadingState !== 'not_found') {
      console.log(`     - Display: ${loadingState.display}`);
      console.log(`     - Visibility: ${loadingState.visibility}`);
      console.log(`     - Hidden: ${loadingState.display === 'none' ? '✅ YES' : '❌ NO'}`);
    }
    
    // Check for navigation menu
    const navState = await page.evaluate(() => {
      const selectors = [
        'nav',
        '.AknMainMenu',
        '[class*="Navigation"]',
        '[class*="Menu"]',
        '[data-testid="navigation"]',
        '.navigation'
      ];
      
      for (let selector of selectors) {
        const element = document.querySelector(selector);
        if (element) {
          return {
            found: true,
            selector,
            visible: window.getComputedStyle(element).display !== 'none',
            html: element.outerHTML.substring(0, 200)
          };
        }
      }
      return { found: false };
    });
    
    console.log('\n   Navigation Menu Status:');
    console.log(`     - Found: ${navState.found ? '✅ YES' : '❌ NO'}`);
    if (navState.found) {
      console.log(`     - Selector: ${navState.selector}`);
      console.log(`     - Visible: ${navState.visible ? '✅ YES' : '❌ NO'}`);
      console.log(`     - HTML Preview: ${navState.html.substring(0, 100)}...`);
    }
    
    // Check app content
    const appState = await page.evaluate(() => {
      const app = document.querySelector('.app');
      if (!app) return { exists: false };
      
      const children = app.children.length;
      const hasContent = app.innerHTML.length > 100;
      const textContent = app.textContent.substring(0, 100);
      
      return {
        exists: true,
        children,
        hasContent,
        textContent,
        htmlLength: app.innerHTML.length
      };
    });
    
    console.log('\n   App Container Status:');
    console.log(`     - Exists: ${appState.exists ? '✅ YES' : '❌ NO'}`);
    if (appState.exists) {
      console.log(`     - Children: ${appState.children}`);
      console.log(`     - HTML Length: ${appState.htmlLength} chars`);
      console.log(`     - Has Content: ${appState.hasContent ? '✅ YES' : '❌ NO'}`);
      console.log(`     - Text Preview: ${appState.textContent.trim()}`);
    }
    
    // Check JavaScript bundles loaded
    console.log('\n📍 Step 5: Checking JavaScript dependencies...');
    const jsState = await page.evaluate(() => {
      return {
        jQuery: typeof jQuery !== 'undefined' ? jQuery.fn.jquery : 'not loaded',
        underscore: typeof _ !== 'undefined' ? '✓ loaded' : '✗ not loaded',
        Backbone: typeof Backbone !== 'undefined' ? '✓ loaded' : '✗ not loaded',
        React: typeof React !== 'undefined' ? '✓ loaded' : '✗ not loaded',
        requirejs: typeof requirejs !== 'undefined' ? '✓ loaded' : '✗ not loaded'
      };
    });
    
    console.log('   JavaScript Libraries:');
    console.log(`     - jQuery: ${jsState.jQuery}`);
    console.log(`     - Underscore: ${jsState.underscore}`);
    console.log(`     - Backbone: ${jsState.Backbone}`);
    console.log(`     - React: ${jsState.React}`);
    console.log(`     - RequireJS: ${jsState.requirejs}`);
    
    // Check RequireJS modules
    const requirejsState = await page.evaluate(() => {
      if (typeof requirejs === 'undefined') return { available: false };
      
      try {
        const config = requirejs.s.contexts._.config;
        const defined = Object.keys(requirejs.s.contexts._.defined || {});
        
        return {
          available: true,
          baseUrl: config.baseUrl,
          pathsConfigured: Object.keys(config.paths || {}),
          definedModules: defined.slice(0, 10)
        };
      } catch(e) {
        return { available: true, error: e.message };
      }
    });
    
    console.log('\n   RequireJS Status:');
    console.log(`     - Available: ${requirejsState.available ? '✅ YES' : '❌ NO'}`);
    if (requirejsState.available && !requirejsState.error) {
      console.log(`     - Base URL: ${requirejsState.baseUrl}`);
      console.log(`     - Configured Paths: ${requirejsState.pathsConfigured.join(', ')}`);
      console.log(`     - Defined Modules: ${requirejsState.definedModules.length} (showing first 10)`);
      requirejsState.definedModules.forEach(mod => console.log(`       * ${mod}`));
    }
    
    // Filter and show Akeneo console messages
    console.log('\n📍 Step 6: Akeneo Initialization Messages...');
    const akeneoMessages = consoleMessages.filter(m => 
      m.text.includes('[Akeneo]') || 
      m.text.includes('PIM') ||
      m.text.includes('form-builder') ||
      m.text.includes('Form built')
    );
    
    if (akeneoMessages.length > 0) {
      console.log(`   Found ${akeneoMessages.length} initialization messages:`);
      akeneoMessages.forEach(m => console.log(`     [${m.type}] ${m.text}`));
    } else {
      console.log('   ⚠️  No Akeneo initialization messages found');
    }
    
    // Show failed requests
    if (failedRequests.length > 0) {
      console.log('\n⚠️  Failed HTTP Requests:');
      failedRequests.slice(0, 5).forEach(req => {
        console.log(`     ${req.status} - ${req.url.substring(0, 100)}`);
      });
    }
    
    // Show JavaScript errors
    if (errors.length > 0) {
      console.log('\n❌ JavaScript Errors:');
      errors.slice(0, 5).forEach(err => {
        console.log(`     ${err}`);
      });
    }
    
    // Take screenshots
    console.log('\n📸 Taking screenshots...');
    await page.screenshot({ 
      path: '/home/pim/public_html/webapp/test_full_page.png', 
      fullPage: true 
    });
    console.log('   ✓ Full page screenshot saved: test_full_page.png');
    
    await page.screenshot({ 
      path: '/home/pim/public_html/webapp/test_viewport.png'
    });
    console.log('   ✓ Viewport screenshot saved: test_viewport.png');
    
    // Final verdict
    console.log('\n' + '='.repeat(60));
    console.log('📊 FINAL TEST RESULTS');
    console.log('='.repeat(60));
    
    const loadingHidden = loadingState === 'not_found' || loadingState.display === 'none';
    const navPresent = navState.found && navState.visible;
    const jsLoaded = jsState.jQuery !== 'not loaded' && 
                     jsState.requirejs === '✓ loaded';
    const hasContent = appState.exists && appState.hasContent;
    
    console.log(`Loading Screen Hidden:    ${loadingHidden ? '✅ PASS' : '❌ FAIL'}`);
    console.log(`Navigation Menu Present:  ${navPresent ? '✅ PASS' : '❌ FAIL'}`);
    console.log(`JavaScript Loaded:        ${jsLoaded ? '✅ PASS' : '❌ FAIL'}`);
    console.log(`App Has Content:          ${hasContent ? '✅ PASS' : '❌ FAIL'}`);
    console.log(`No JavaScript Errors:     ${errors.length === 0 ? '✅ PASS' : '❌ FAIL'}`);
    
    const overallSuccess = loadingHidden && jsLoaded && errors.length === 0;
    console.log('\n' + '='.repeat(60));
    console.log(`OVERALL STATUS: ${overallSuccess ? '✅ PARTIALLY SUCCESSFUL' : '❌ NEEDS ATTENTION'}`);
    console.log('='.repeat(60));
    
    if (!navPresent) {
      console.log('\n⚠️  REMAINING ISSUE: Navigation menu not rendering');
      console.log('   This indicates the form-builder initialization is not completing.');
    }
    
    // Keep browser open for 10 seconds to observe
    console.log('\n⏳ Keeping browser open for 10 seconds for observation...');
    await page.waitForTimeout(10000);
    
  } catch (error) {
    console.error('\n❌ Test Failed:', error.message);
    console.error(error.stack);
  } finally {
    await browser.close();
    console.log('\n✓ Browser closed. Test complete.');
  }
})();
