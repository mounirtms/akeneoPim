const { chromium } = require('playwright');

(async () => {
  console.log('🚀 Starting Robust Navigation Test');
  console.log('====================================================\n');

  const browser = await chromium.launch({ 
    headless: true,
    args: ['--no-sandbox', '--disable-setuid-sandbox']
  });
  const context = await browser.newContext({
    ignoreHTTPSErrors: true
  });
  const page = await context.newPage();

  // Capture console
  page.on('console', msg => {
    console.log(`[Browser] [${msg.type()}] ${msg.text()}`);
  });

  try {
    console.log('📍 Step 1: Navigating to login page...');
    await page.goto('https://pim.technostationery.com/user/login', { 
      waitUntil: 'domcontentloaded',
      timeout: 60000 
    });
    console.log('   ✓ Page loaded\n');

    // Wait for login form
    console.log('📍 Step 2: Waiting for login form...');
    await page.waitForSelector('#username_input', { timeout: 10000 });
    console.log('   ✓ Login form found\n');

    // Fill credentials
    console.log('📍 Step 3: Entering credentials...');
    await page.fill('#username_input', 'testuser');
    await page.fill('#password_input', 'TestPass123!');
    console.log('   ✓ Credentials entered\n');

    // Submit login
    console.log('📍 Step 4: Submitting login...');
    await page.click('button[type="submit"]');
    console.log('   ✓ Login submitted\n');

    // Wait for redirect
    console.log('📍 Step 5: Waiting for dashboard (40 seconds)...');
    await page.waitForTimeout(40000);
    
    const currentUrl = page.url();
    console.log(`   Current URL: ${currentUrl}\n`);

    // Analyze page state
    console.log('📍 Step 6: Analyzing page state...\n');
    
    const pageAnalysis = await page.evaluate(() => {
      const analysis = {
        title: document.title,
        url: window.location.href,
        bodyClasses: document.body.className,
        hasApp: !!document.querySelector('.app'),
        hasLoadingScreen: !!document.querySelector('.AknLoadingMask'),
        hasMenu: !!document.querySelector('[data-drop-zone="menu"]'),
        appHTML: '',
        menuHTML: '',
        requirejsStatus: 'not loaded',
        definedModules: 0,
        pimAppStatus: 'unknown'
      };

      // Check app container
      const app = document.querySelector('.app');
      if (app) {
        analysis.appHTML = app.innerHTML.substring(0, 300);
      }

      // Check menu zone
      const menuZone = document.querySelector('[data-drop-zone="menu"]');
      if (menuZone) {
        analysis.menuHTML = menuZone.innerHTML.substring(0, 300);
      }

      // Check RequireJS
      if (typeof requirejs !== 'undefined') {
        analysis.requirejsStatus = 'loaded';
        if (requirejs.s && requirejs.s.contexts && requirejs.s.contexts._) {
          const ctx = requirejs.s.contexts._;
          if (ctx.defined) {
            analysis.definedModules = Object.keys(ctx.defined).length;
          }
          // Check pim/app
          if (ctx.defined && ctx.defined['pim/app']) {
            analysis.pimAppStatus = 'defined';
          } else if (ctx.registry && ctx.registry['pim/app']) {
            analysis.pimAppStatus = 'registered but not defined';
          } else {
            analysis.pimAppStatus = 'not found';
          }
        }
      }

      // Check webpack
      if (typeof __webpack_require__ !== 'undefined') {
        analysis.webpackStatus = 'loaded';
      }

      return analysis;
    });

    console.log('   📄 Page Analysis:');
    console.log(`   Title: ${pageAnalysis.title}`);
    console.log(`   .app container: ${pageAnalysis.hasApp ? '✅ YES' : '❌ NO'}`);
    console.log(`   Loading screen: ${pageAnalysis.hasLoadingScreen ? '⚠️  YES' : '✅ NO'}`);
    console.log(`   Menu zone: ${pageAnalysis.hasMenu ? '✅ YES' : '❌ NO'}`);
    console.log(`   RequireJS: ${pageAnalysis.requirejsStatus}`);
    console.log(`   Defined modules: ${pageAnalysis.definedModules}`);
    console.log(`   pim/app status: ${pageAnalysis.pimAppStatus}`);
    
    if (pageAnalysis.appHTML) {
      console.log(`\n   App HTML (first 300 chars):\n   ${pageAnalysis.appHTML}`);
    }

    // Check specific elements
    console.log('\n📍 Step 7: Checking specific UI elements...\n');
    
    const elements = await page.evaluate(() => {
      const selectors = {
        '.AknLoadingMask': 'Loading mask',
        '.AknDefault-progressContainer': 'Progress container',
        '#page': 'Page container',
        '#container': 'Main container',
        '.AknMenu': 'Menu',
        '.navigation': 'Navigation'
      };

      const results = {};
      for (const [selector, name] of Object.entries(selectors)) {
        const el = document.querySelector(selector);
        results[name] = {
          exists: !!el,
          visible: el ? (el.offsetParent !== null) : false,
          display: el ? window.getComputedStyle(el).display : 'n/a'
        };
      }
      return results;
    });

    for (const [name, info] of Object.entries(elements)) {
      const status = info.exists ? (info.visible ? '✅ VISIBLE' : '⚠️  EXISTS (hidden)') : '❌ NOT FOUND';
      console.log(`   ${name}: ${status} (display: ${info.display})`);
    }

    // Screenshot
    console.log('\n📍 Step 8: Taking screenshot...');
    await page.screenshot({ 
      path: 'robust_test_screenshot.png', 
      fullPage: true 
    });
    console.log('   ✓ Screenshot saved\n');

    // Final summary
    console.log('============================================================');
    console.log('📊 TEST SUMMARY');
    console.log('============================================================');
    console.log(`Login: ${currentUrl.includes('/user/login') ? '❌ FAILED' : '✅ SUCCESS'}`);
    console.log(`App Container: ${pageAnalysis.hasApp ? '✅' : '❌'}`);
    console.log(`Loading Screen: ${pageAnalysis.hasLoadingScreen ? '⚠️  STUCK' : '✅'}`);
    console.log(`Menu: ${pageAnalysis.hasMenu ? '✅' : '❌'}`);
    console.log(`RequireJS Modules: ${pageAnalysis.definedModules} defined`);
    console.log(`pim/app: ${pageAnalysis.pimAppStatus}`);
    console.log('============================================================\n');

  } catch (error) {
    console.error('\n❌ Test error:', error.message);
  } finally {
    await browser.close();
    console.log('✓ Test complete. Browser closed.');
  }
})();
