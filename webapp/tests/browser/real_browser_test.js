const { chromium } = require('playwright');

/**
 * Real Browser Testing with Comprehensive Console Log Capture
 * Runs in headless mode but captures all console output
 */

async function runRealBrowserTest() {
  console.log('\n================================================================================');
  console.log('REAL BROWSER TEST - Comprehensive Console & Network Capture');
  console.log('================================================================================\n');

  const baseUrl = 'https://pim.technostationery.com';
  const credentials = { username: 'mounir', password: '2026' };

  const browser = await chromium.launch({ 
    headless: true,
    args: ['--disable-dev-shm-usage']
  });

  const context = await browser.newContext({
    ignoreHTTPSErrors: true,
    viewport: { width: 1920, height: 1080 }
  });

  const page = await context.newPage();

  // Comprehensive logging arrays
  const consoleLogs = [];
  const jsErrors = [];
  const networkErrors = [];
  const allRequests = [];
  const allResponses = [];

  // Capture ALL console messages with full details
  page.on('console', msg => {
    const logEntry = {
      type: msg.type(),
      text: msg.text(),
      args: msg.args().length,
      location: msg.location(),
      timestamp: new Date().toISOString()
    };
    consoleLogs.push(logEntry);
    
    const prefix = {
      'error': '❌',
      'warning': '⚠️ ',
      'info': 'ℹ️ ',
      'log': '📝'
    }[msg.type()] || '📝';
    
    console.log(`[CONSOLE ${prefix}] ${msg.text()}`);
  });

  // Capture JavaScript errors
  page.on('pageerror', error => {
    jsErrors.push({
      message: error.message,
      stack: error.stack,
      timestamp: new Date().toISOString()
    });
    console.log(`\n❌ JS ERROR: ${error.message}\n`);
  });

  // Capture network failures
  page.on('requestfailed', request => {
    const errorEntry = {
      url: request.url(),
      failure: request.failure()?.errorText,
      method: request.method(),
      timestamp: new Date().toISOString()
    };
    networkErrors.push(errorEntry);
    
    if (!request.url().includes('analytics') && 
        !request.url().includes('facebook') && 
        !request.url().includes('clarity') &&
        !request.url().includes('doubleclick')) {
      console.log(`⚠️  NETWORK FAIL: ${request.url().substring(0, 100)}`);
    }
  });

  // Capture all requests
  page.on('request', request => {
    allRequests.push({
      url: request.url(),
      method: request.method(),
      resourceType: request.resourceType(),
      timestamp: new Date().toISOString()
    });
  });

  // Capture all responses
  page.on('response', response => {
    allResponses.push({
      url: response.url(),
      status: response.status(),
      statusText: response.statusText(),
      contentType: response.headers()['content-type'],
      timestamp: new Date().toISOString()
    });
  });

  try {
    // Step 1: Load login page
    console.log('\n📍 Step 1: Loading login page...');
    console.log('─'.repeat(80));
    await page.goto(`${baseUrl}/user/login`, { 
      waitUntil: 'networkidle',
      timeout: 30000 
    });
    console.log('✓ Login page loaded\n');
    await page.screenshot({ path: 'tests/browser/screenshots/01_login_page.png', fullPage: true });

    // Wait for page to render
    await page.waitForTimeout(3000);

    // Step 2: Analyze form
    console.log('📍 Step 2: Analyzing login form structure...');
    console.log('─'.repeat(80));
    
    const formAnalysis = await page.evaluate(() => {
      const forms = Array.from(document.querySelectorAll('form'));
      const inputs = Array.from(document.querySelectorAll('input'));
      const buttons = Array.from(document.querySelectorAll('button'));
      
      return {
        formCount: forms.length,
        forms: forms.map(f => ({
          id: f.id,
          name: f.name,
          action: f.action,
          method: f.method,
          className: f.className,
          fields: Array.from(f.querySelectorAll('input')).map(i => ({
            type: i.type,
            name: i.name,
            id: i.id,
            required: i.required,
            placeholder: i.placeholder
          }))
        })),
        inputs: inputs.map(i => ({
          type: i.type,
          name: i.name,
          id: i.id,
          className: i.className
        })),
        buttons: buttons.map(b => ({
          type: b.type,
          text: b.textContent?.trim(),
          id: b.id,
          className: b.className
        })),
        csrfToken: document.querySelector('input[name="_csrf_token"]')?.value || 'NOT FOUND'
      };
    });

    console.log(`Forms found: ${formAnalysis.formCount}`);
    console.log(`Inputs found: ${formAnalysis.inputs.length}`);
    console.log(`Buttons found: ${formAnalysis.buttons.length}`);
    console.log(`CSRF token: ${formAnalysis.csrfToken.substring(0, 20)}...`);
    
    formAnalysis.forms.forEach((form, idx) => {
      console.log(`\nForm ${idx + 1}:`);
      console.log(`  Action: ${form.action}`);
      console.log(`  Method: ${form.method}`);
      form.fields.forEach(field => {
        console.log(`  Field: ${field.type} [name="${field.name}"] required=${field.required}`);
      });
    });

    // Step 3: Fill and submit form
    console.log('\n📍 Step 3: Filling form and submitting...');
    console.log('─'.repeat(80));

    const loginResult = await page.evaluate(async (creds) => {
      const usernameInput = document.querySelector('input[name="_username"]') || 
                           document.querySelector('input[type="text"]');
      const passwordInput = document.querySelector('input[name="_password"]') || 
                           document.querySelector('input[type="password"]');
      const submitButton = document.querySelector('button[type="submit"]');
      
      if (!usernameInput || !passwordInput || !submitButton) {
        return { success: false, error: 'Form elements not found' };
      }
      
      usernameInput.value = creds.username;
      passwordInput.value = creds.password;
      
      // Dispatch input events to trigger validation
      usernameInput.dispatchEvent(new Event('input', { bubbles: true }));
      passwordInput.dispatchEvent(new Event('input', { bubbles: true }));
      
      return { 
        success: true,
        usernameSet: usernameInput.value === creds.username,
        passwordSet: passwordInput.value.length === creds.password.length
      };
    }, credentials);

    console.log(`Form fill result: ${JSON.stringify(loginResult)}`);
    
    if (!loginResult.success) {
      throw new Error(loginResult.error);
    }

    await page.screenshot({ path: 'tests/browser/screenshots/02_form_filled.png', fullPage: true });

    // Click submit button
    console.log('\nSubmitting form...');
    await Promise.all([
      page.waitForNavigation({ timeout: 15000 }).catch(() => null),
      page.click('button[type="submit"]')
    ]);

    await page.waitForTimeout(5000);
    await page.screenshot({ path: 'tests/browser/screenshots/03_after_submit.png', fullPage: true });

    // Step 4: Check result
    console.log('\n📍 Step 4: Checking authentication result...');
    console.log('─'.repeat(80));

    const currentUrl = page.url();
    console.log(`Current URL: ${currentUrl}`);

    const pageAnalysis = await page.evaluate(() => {
      return {
        url: window.location.href,
        title: document.title,
        bodyClasses: document.body.className,
        hasErrorAlert: !!document.querySelector('.alert-error, .error'),
        errorText: document.querySelector('.alert-error, .error')?.textContent?.trim(),
        hasPimApp: !!document.querySelector('#pim-app'),
        hasMainContent: !!document.querySelector('.AknDefault-mainContent'),
        linkCount: document.querySelectorAll('a').length,
        scriptCount: document.querySelectorAll('script').length
      };
    });

    console.log('\nPage Analysis:');
    console.log(`  Title: ${pageAnalysis.title}`);
    console.log(`  Has error: ${pageAnalysis.hasErrorAlert}`);
    if (pageAnalysis.errorText) {
      console.log(`  Error text: ${pageAnalysis.errorText}`);
    }
    console.log(`  Has PIM app: ${pageAnalysis.hasPimApp}`);
    console.log(`  Has main content: ${pageAnalysis.hasMainContent}`);
    console.log(`  Links: ${pageAnalysis.linkCount}`);
    console.log(`  Scripts: ${pageAnalysis.scriptCount}`);

    const isLoggedIn = !currentUrl.includes('/user/login');
    console.log(`\n${isLoggedIn ? '✅ SUCCESS' : '❌ FAIL'}: ${isLoggedIn ? 'Login successful' : 'Still on login page'}`);

    if (isLoggedIn) {
      await page.waitForTimeout(3000);
      await page.screenshot({ path: 'tests/browser/screenshots/04_dashboard.png', fullPage: true });
    }

  } catch (error) {
    console.error('\n❌ Test Error:', error.message);
    try {
      await page.screenshot({ path: 'tests/browser/screenshots/error.png', fullPage: true });
    } catch (e) {}
  } finally {
    // Save comprehensive report
    const report = {
      timestamp: new Date().toISOString(),
      summary: {
        consoleLogs: consoleLogs.length,
        jsErrors: jsErrors.length,
        networkErrors: networkErrors.length,
        totalRequests: allRequests.length,
        totalResponses: allResponses.length
      },
      consoleLogs,
      jsErrors,
      networkErrors,
      requests: allRequests.slice(0, 100), // Limit to first 100
      responses: allResponses.slice(0, 100)
    };

    const fs = require('fs');
    fs.writeFileSync(
      'tests/browser/reports/real_browser_test_report.json',
      JSON.stringify(report, null, 2)
    );

    console.log('\n================================================================================');
    console.log('TEST SUMMARY');
    console.log('================================================================================');
    console.log(`Console logs: ${consoleLogs.length}`);
    console.log(`JS errors: ${jsErrors.length}`);
    console.log(`Network errors: ${networkErrors.length}`);
    console.log(`Total requests: ${allRequests.length}`);
    console.log(`Total responses: ${allResponses.length}`);
    console.log('\n✓ Report saved: tests/browser/reports/real_browser_test_report.json');
    console.log('✓ Screenshots: tests/browser/screenshots/');
    console.log('================================================================================\n');

    await context.close();
    await browser.close();
  }
}

runRealBrowserTest().catch(console.error);
