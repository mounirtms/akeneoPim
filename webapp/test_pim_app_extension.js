const { chromium } = require('playwright');

(async () => {
  console.log('\n================================================================================');
  console.log('PIM-APP EXTENSION & LOGIN TEST');
  console.log('================================================================================\n');

  const browser = await chromium.launch({ headless: true });
  const context = await browser.newContext({
    ignoreHTTPSErrors: true,
    viewport: { width: 1920, height: 1080 }
  });
  const page = await context.newPage();

  // Track console messages
  const consoleErrors = [];
  const jsErrors = [];
  const networkErrors = [];

  page.on('console', msg => {
    if (msg.type() === 'error') {
      const text = msg.text();
      consoleErrors.push(text);
      
      // Check for specific errors
      if (text.includes('pim-app') && text.includes('not found')) {
        console.log('❌ CRITICAL: pim-app extension not found error detected!');
        console.log('   Error:', text.substring(0, 150));
      }
      if (text.includes('extensions.filter is not a function')) {
        console.log('❌ CRITICAL: extensions.filter error detected!');
      }
    }
  });

  page.on('pageerror', error => {
    jsErrors.push(error.message);
  });

  page.on('requestfailed', request => {
    const url = request.url();
    if (!url.includes('analytics') && !url.includes('facebook') && !url.includes('clarity') && !url.includes('doubleclick')) {
      networkErrors.push({ url, failure: request.failure().errorText });
    }
  });

  try {
    // Step 1: Load login page
    console.log('Step 1: Loading login page...');
    await page.goto('https://pim.technostationery.com/user/login', { 
      waitUntil: 'networkidle',
      timeout: 30000 
    });
    console.log('✓ Login page loaded');

    // Step 2: Wait for RequireJS to initialize
    console.log('\nStep 2: Waiting for RequireJS initialization...');
    await page.waitForTimeout(3000);

    // Step 3: Check if extensions.json loaded
    console.log('\nStep 3: Checking extensions.json...');
    const extensionsCheck = await page.evaluate(() => {
      return fetch('/js/extensions.json')
        .then(r => r.json())
        .then(data => {
          return {
            success: true,
            extensionsCount: Object.keys(data.extensions || {}).length,
            hasPimApp: !!data.extensions['pim-app'],
            pimAppModule: data.extensions['pim-app']?.module
          };
        })
        .catch(err => ({ success: false, error: err.message }));
    });

    if (extensionsCheck.success) {
      console.log('✓ extensions.json loaded successfully');
      console.log(`  - Total extensions: ${extensionsCheck.extensionsCount}`);
      console.log(`  - Has pim-app: ${extensionsCheck.hasPimApp ? '✓ YES' : '✗ NO'}`);
      if (extensionsCheck.hasPimApp) {
        console.log(`  - pim-app module: ${extensionsCheck.pimAppModule}`);
      }
    } else {
      console.log('✗ Failed to load extensions.json:', extensionsCheck.error);
    }

    // Step 4: Check for form builder errors
    console.log('\nStep 4: Checking for form builder initialization...');
    await page.waitForTimeout(2000);

    const formBuilderStatus = await page.evaluate(() => {
      const errors = [];
      const logs = window.console._logs || [];
      
      // Check if form builder error occurred
      const formBuilderError = logs.find(log => 
        log.includes('Failed to build form') || 
        log.includes('pim-app') && log.includes('not found')
      );
      
      return {
        hasFormBuilderError: !!formBuilderError,
        errorMessage: formBuilderError || null
      };
    });

    if (!formBuilderStatus.hasFormBuilderError) {
      console.log('✓ No form builder errors detected');
    } else {
      console.log('✗ Form builder error:', formBuilderStatus.errorMessage);
    }

    // Step 5: Test login functionality
    console.log('\nStep 5: Testing login form...');
    await page.fill('#_username', 'mounir');
    await page.fill('#_password', '2026');
    console.log('✓ Credentials entered');

    // Take screenshot before submit
    await page.screenshot({ path: 'webapp/test_before_login.png' });
    console.log('✓ Screenshot saved: test_before_login.png');

    // Submit login
    console.log('\nStep 6: Submitting login form...');
    await page.click('button[type="submit"]');
    
    // Wait for navigation or error
    try {
      await page.waitForNavigation({ timeout: 10000, waitUntil: 'networkidle' });
      console.log('✓ Navigation occurred after login');

      // Check current URL
      const currentUrl = page.url();
      console.log(`  Current URL: ${currentUrl}`);

      // Take screenshot after login
      await page.screenshot({ path: 'webapp/test_after_login.png' });
      console.log('✓ Screenshot saved: test_after_login.png');

      // Check if we're on dashboard
      if (currentUrl.includes('/user/login')) {
        console.log('⚠ Still on login page - checking for errors...');
        const loginError = await page.$('.alert-error');
        if (loginError) {
          const errorText = await loginError.textContent();
          console.log('✗ Login error:', errorText);
        }
      } else {
        console.log('✓ Successfully navigated away from login page');
        
        // Check for PIM UI elements
        const hasPimUI = await page.evaluate(() => {
          return document.querySelector('#pim-app, .AknDefault-mainContent, [data-target="pim-app"]') !== null;
        });
        
        if (hasPimUI) {
          console.log('✓ PIM UI elements detected on page');
        } else {
          console.log('⚠ PIM UI elements not found - may still be loading');
        }
      }
    } catch (error) {
      console.log('⚠ No navigation after login:', error.message);
      await page.screenshot({ path: 'webapp/test_login_timeout.png' });
      console.log('✓ Screenshot saved: test_login_timeout.png');
    }

    // Summary
    console.log('\n================================================================================');
    console.log('TEST SUMMARY');
    console.log('================================================================================');
    console.log(`Console Errors: ${consoleErrors.length}`);
    console.log(`JavaScript Errors: ${jsErrors.length}`);
    console.log(`Network Errors (non-analytics): ${networkErrors.length}`);
    
    // Check for critical errors
    const criticalErrors = consoleErrors.filter(err => 
      (err.includes('pim-app') && err.includes('not found')) ||
      err.includes('extensions.filter is not a function') ||
      err.includes('MIME type')
    );

    if (criticalErrors.length === 0) {
      console.log('\n✅ NO CRITICAL ERRORS - PIM APP SHOULD BE FUNCTIONAL');
    } else {
      console.log('\n❌ CRITICAL ERRORS FOUND:');
      criticalErrors.forEach((err, i) => {
        console.log(`  ${i + 1}. ${err.substring(0, 100)}`);
      });
    }

    if (networkErrors.length > 0) {
      console.log('\nNetwork Errors:');
      networkErrors.forEach((err, i) => {
        console.log(`  ${i + 1}. ${err.url} - ${err.failure}`);
      });
    }

    console.log('================================================================================\n');

  } catch (error) {
    console.error('❌ Test failed:', error.message);
  } finally {
    await browser.close();
  }
})();
