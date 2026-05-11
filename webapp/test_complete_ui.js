const { chromium } = require('playwright');

(async () => {
  const browser = await chromium.launch({ headless: true });
  const context = await browser.newContext({
    ignoreHTTPSErrors: true,
    viewport: { width: 1920, height: 1080 }
  });
  const page = await context.newPage();

  console.log('=== Akeneo PIM Complete UI Test ===\n');

  // Collect console messages
  const consoleMessages = [];
  const consoleErrors = [];
  
  page.on('console', msg => {
    const text = msg.text();
    consoleMessages.push(`[${msg.type()}] ${text}`);
    if (msg.type() === 'error') {
      consoleErrors.push(text);
    }
  });

  // Collect network errors
  const networkErrors = [];
  page.on('response', response => {
    if (response.status() >= 400) {
      networkErrors.push(`${response.status()} ${response.url()}`);
    }
  });

  try {
    // Step 1: Load login page
    console.log('Step 1: Loading login page...');
    await page.goto('https://pim.technostationery.com/user/login', {
      waitUntil: 'networkidle',
      timeout: 30000
    });
    console.log('✓ Login page loaded\n');

    // Step 2: Perform login
    console.log('Step 2: Logging in...');
    await page.fill('input[name="_username"]', 'admin');
    await page.fill('input[name="_password"]', 'Admin1234!');
    await page.click('button[type="submit"]');
    
    // Wait for navigation
    await page.waitForLoadState('networkidle', { timeout: 30000 });
    const currentUrl = page.url();
    console.log(`✓ Redirected to: ${currentUrl}\n`);

    // Step 3: Wait for page to fully load
    console.log('Step 3: Waiting for page initialization...');
    await page.waitForTimeout(5000);

    // Step 4: Check JavaScript globals
    console.log('Step 4: Checking JavaScript globals...');
    const globals = await page.evaluate(() => {
      return {
        jQuery: typeof jQuery !== 'undefined',
        $: typeof $ !== 'undefined',
        _: typeof _ !== 'undefined',
        Backbone: typeof Backbone !== 'undefined',
        React: typeof React !== 'undefined',
        ReactDOM: typeof ReactDOM !== 'undefined',
        fos: typeof fos !== 'undefined',
        require: typeof require !== 'undefined',
        define: typeof define !== 'undefined',
        pim: typeof window.pim !== 'undefined',
        process: typeof process !== 'undefined'
      };
    });

    console.log('Global Objects Available:');
    Object.entries(globals).forEach(([key, value]) => {
      console.log(`  ${value ? '✓' : '✗'} ${key}: ${value}`);
    });
    console.log('');

    // Step 5: Check page elements
    console.log('Step 5: Checking page elements...');
    const elements = await page.evaluate(() => {
      return {
        app: document.querySelectorAll('.app').length,
        loadingScreen: document.querySelectorAll('.AknDefault-progressContainer').length,
        loadingText: document.body.textContent.includes('Loading'),
        mainContent: document.querySelectorAll('.AknDefault-mainContent').length,
        navigation: document.querySelectorAll('.AknDefault-navigation').length,
        container: document.querySelectorAll('#container').length,
        hashLoadingMask: document.querySelectorAll('.hash-loading-mask').length
      };
    });

    console.log('Page Elements:');
    Object.entries(elements).forEach(([key, value]) => {
      console.log(`  - ${key}: ${value}`);
    });
    console.log('');

    // Step 6: Check if SPA initialized
    const spaInitialized = elements.mainContent > 0 && !elements.loadingText;
    console.log(`Step 6: SPA Initialization Status: ${spaInitialized ? '✅ SUCCESS' : '❌ FAILED'}\n`);

    // Step 7: Console messages summary
    console.log('Step 7: Console Messages Summary:');
    console.log(`  Total messages: ${consoleMessages.length}`);
    console.log(`  Errors: ${consoleErrors.length}`);
    
    if (consoleErrors.length > 0) {
      console.log('\n  Console Errors:');
      consoleErrors.slice(0, 10).forEach(err => {
        console.log(`    - ${err.substring(0, 100)}`);
      });
      if (consoleErrors.length > 10) {
        console.log(`    ... and ${consoleErrors.length - 10} more errors`);
      }
    }
    console.log('');

    // Step 8: Network errors summary
    console.log('Step 8: Network Errors:');
    if (networkErrors.length > 0) {
      networkErrors.slice(0, 10).forEach(err => {
        console.log(`  ❌ ${err}`);
      });
      if (networkErrors.length > 10) {
        console.log(`  ... and ${networkErrors.length - 10} more errors`);
      }
    } else {
      console.log('  ✅ No network errors detected');
    }
    console.log('');

    // Step 9: Take screenshot
    await page.screenshot({ path: '/tmp/akeneo_ui_complete_test.png', fullPage: true });
    console.log('Screenshot saved: /tmp/akeneo_ui_complete_test.png\n');

    // Step 10: Final diagnosis
    console.log('=== DIAGNOSIS ===');
    if (spaInitialized) {
      console.log('✅ SUCCESS: Akeneo PIM UI is fully functional!');
      console.log('   - All JavaScript libraries loaded correctly');
      console.log('   - SPA initialized and mounted');
      console.log('   - Main content rendered');
    } else {
      console.log('❌ ISSUE DETECTED:');
      if (!globals.jQuery) console.log('   - jQuery not loaded');
      if (!globals._) console.log('   - Underscore not loaded');
      if (!globals.Backbone) console.log('   - Backbone not loaded');
      if (!globals.React) console.log('   - React not loaded');
      if (!globals.require || !globals.define) console.log('   - AMD (require/define) not available');
      if (!globals.pim) console.log('   - PIM namespace not initialized');
      if (elements.loadingText) console.log('   - Still stuck on loading screen');
      if (networkErrors.length > 0) console.log(`   - ${networkErrors.length} network errors detected`);
    }
    console.log('');

  } catch (error) {
    console.error('Test failed with error:', error.message);
  } finally {
    await browser.close();
  }
})();
