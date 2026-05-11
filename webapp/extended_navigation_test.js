const { chromium } = require('playwright');

(async () => {
  console.log('🚀 Starting Extended Navigation Test with Chromium');
  console.log('====================================================\n');

  const browser = await chromium.launch({ headless: true });
  const context = await browser.newContext();
  const page = await context.newPage();

  // Capture all console messages
  const consoleMessages = [];
  page.on('console', msg => {
    consoleMessages.push({
      type: msg.type(),
      text: msg.text(),
      location: msg.location()
    });
    console.log(`[Browser] [${msg.type()}] ${msg.text()}`);
  });

  // Capture network requests
  const requests = [];
  page.on('request', request => {
    requests.push({
      url: request.url(),
      method: request.method(),
      resourceType: request.resourceType()
    });
  });

  // Capture responses
  const responses = [];
  page.on('response', response => {
    responses.push({
      url: response.url(),
      status: response.status(),
      statusText: response.statusText()
    });
  });

  try {
    console.log('📍 Step 1: Loading Akeneo PIM and logging in...');
    await page.goto('https://pim.technostationery.com/user/login', { 
      waitUntil: 'networkidle',
      timeout: 30000 
    });

    await page.fill('#_username', 'testuser');
    await page.fill('#_password', 'TestPass123!');
    await page.click('button[type="submit"]');
    console.log('   ✓ Login submitted\n');

    console.log('📍 Step 2: Waiting for dashboard with extended timeout (60 seconds)...');
    await page.waitForTimeout(60000);

    console.log('\n📍 Step 3: Analyzing page state after 60 seconds...');
    
    // Check loading screen
    const loadingScreen = await page.$('.AknLoadingMask');
    const loadingVisible = loadingScreen ? await loadingScreen.isVisible() : false;
    console.log(`   Loading screen visible: ${loadingVisible ? '❌ YES (STUCK)' : '✅ NO'}`);

    // Check for navigation menu
    const menuSelectors = [
      '.AknHeader-menu',
      '[data-drop-zone="menu"]',
      '.AknMenu',
      'nav.navigation'
    ];

    console.log('\n   Testing menu selectors:');
    for (const selector of menuSelectors) {
      const element = await page.$(selector);
      if (element) {
        const visible = await element.isVisible();
        const html = await element.innerHTML();
        console.log(`   ${selector}: ${visible ? '✅' : '❌'} (HTML: ${html.length} chars)`);
      } else {
        console.log(`   ${selector}: ❌ NOT FOUND`);
      }
    }

    // Check RequireJS module status
    console.log('\n📍 Step 4: Checking RequireJS module registration...');
    const moduleStatus = await page.evaluate(() => {
      if (typeof requirejs === 'undefined') return { error: 'RequireJS not found' };
      
      const status = {
        defined: [],
        contexts: {}
      };

      // Check defined modules
      if (requirejs.s && requirejs.s.contexts && requirejs.s.contexts._) {
        const context = requirejs.s.contexts._;
        if (context.defined) {
          status.defined = Object.keys(context.defined);
        }
        if (context.registry) {
          status.contexts.registry = Object.keys(context.registry);
        }
      }

      // Try to check if pim/app is available
      try {
        const isPimAppDefined = requirejs.defined && requirejs.defined('pim/app');
        status.pimAppDefined = isPimAppDefined;
      } catch(e) {
        status.pimAppError = e.message;
      }

      return status;
    });
    
    console.log(`   Defined modules: ${moduleStatus.defined?.length || 0}`);
    console.log(`   pim/app defined: ${moduleStatus.pimAppDefined ? '✅' : '❌'}`);
    if (moduleStatus.pimAppError) {
      console.log(`   Error: ${moduleStatus.pimAppError}`);
    }

    // Check if form-builder executed
    console.log('\n📍 Step 5: Checking form builder execution...');
    const formBuilderStatus = await page.evaluate(() => {
      const status = {
        appContainer: document.querySelector('.app') !== null,
        appChildren: 0,
        pageContainer: document.querySelector('#page') !== null,
        containerChildren: 0
      };

      const app = document.querySelector('.app');
      if (app) {
        status.appChildren = app.children.length;
        status.appHTML = app.innerHTML.substring(0, 500);
      }

      const container = document.querySelector('#container');
      if (container) {
        status.containerChildren = container.children.length;
      }

      return status;
    });

    console.log(`   .app container: ${formBuilderStatus.appContainer ? '✅' : '❌'}`);
    console.log(`   .app children: ${formBuilderStatus.appChildren}`);
    console.log(`   #page container: ${formBuilderStatus.pageContainer ? '✅' : '❌'}`);
    console.log(`   #container children: ${formBuilderStatus.containerChildren}`);

    // Network analysis
    console.log('\n📍 Step 6: Network activity analysis...');
    const failedRequests = responses.filter(r => r.status >= 400);
    const jsRequests = requests.filter(r => r.resourceType === 'script');
    
    console.log(`   Total requests: ${requests.length}`);
    console.log(`   JS requests: ${jsRequests.length}`);
    console.log(`   Failed requests: ${failedRequests.length}`);
    
    if (failedRequests.length > 0) {
      console.log('\n   ⚠️  Failed requests:');
      failedRequests.forEach(r => {
        console.log(`   [${r.status}] ${r.url}`);
      });
    }

    // Console message analysis
    console.log('\n📍 Step 7: Console message analysis...');
    const errors = consoleMessages.filter(m => m.type === 'error');
    const warnings = consoleMessages.filter(m => m.type === 'warning');
    const logs = consoleMessages.filter(m => m.type === 'log');
    
    console.log(`   Total console messages: ${consoleMessages.length}`);
    console.log(`   Errors: ${errors.length}`);
    console.log(`   Warnings: ${warnings.length}`);
    console.log(`   Logs: ${logs.length}`);

    // Save detailed report
    const report = {
      timestamp: new Date().toISOString(),
      loadingScreenVisible: loadingVisible,
      moduleStatus,
      formBuilderStatus,
      networkSummary: {
        total: requests.length,
        jsRequests: jsRequests.length,
        failed: failedRequests.length
      },
      consoleSummary: {
        total: consoleMessages.length,
        errors: errors.length,
        warnings: warnings.length,
        logs: logs.length
      },
      failedRequests,
      errorMessages: errors.slice(0, 10),
      warningMessages: warnings.slice(0, 10)
    };

    const fs = require('fs');
    fs.writeFileSync('extended_test_report.json', JSON.stringify(report, null, 2));
    console.log('\n✅ Detailed report saved to: extended_test_report.json');

    // Take screenshot
    await page.screenshot({ path: 'extended_test_screenshot.png', fullPage: true });
    console.log('✅ Screenshot saved to: extended_test_screenshot.png');

  } catch (error) {
    console.error('❌ Test failed:', error.message);
  } finally {
    await browser.close();
    console.log('\n✓ Test complete. Browser closed.');
  }
})();
