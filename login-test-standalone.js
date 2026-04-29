// Standalone Playwright test without requiring @playwright/test package
const { chromium } = require('playwright');

(async () => {
  const logs = [];
  const errors = [];
  
  console.log('Launching Chromium...');
  const browser = await chromium.launch({ headless: true });
  const context = await browser.newContext({ ignoreHTTPSErrors: true });
  const page = await context.newPage();

  // Capture console logs
  page.on('console', msg => {
    logs.push({ type: msg.type(), text: msg.text() });
    console.log(`BROWSER CONSOLE: ${msg.type()} - ${msg.text().substring(0, 100)}`);
  });

  // Capture failed requests
  page.on('requestfailed', request => {
    errors.push({ url: request.url(), error: request.failure()?.errorText || 'unknown' });
    console.log(`REQUEST FAILED: ${request.url()}`);
  });

  try {
    console.log('Navigating to login page...');
    await page.goto('https://pim.technostationery.com/user/login', { waitUntil: 'networkidle', timeout: 30000 });
    await page.screenshot({ path: '/tmp/pw_login_page.png' });
    console.log('Login page loaded, screenshot saved');

    console.log('Filling login form...');
    await page.fill('input[name="_username"]', 'testadmin');
    await page.fill('input[name="_password"]', 'testpass');
    
    console.log('Submitting form...');
    await Promise.all([
      page.waitForNavigation({ waitUntil: 'networkidle', timeout: 15000 }),
      page.click('button[type="submit"]')
    ]);

    await page.waitForTimeout(3000);
    const url = page.url();
    console.log(`URL after login: ${url}`);
    
    await page.screenshot({ path: '/tmp/pw_after_login.png', fullPage: true });
    
    const isLoggedIn = url.includes('/#') || !url.includes('/user/login');
    console.log(`Login successful: ${isLoggedIn}`);

    // Check for JS errors in logs
    const jsErrors = logs.filter(l => l.type === 'error');
    console.log(`\nJavaScript errors found: ${jsErrors.length}`);
    if (jsErrors.length > 0) {
      jsErrors.slice(0, 10).forEach(e => console.log(`  - ${e.text.substring(0, 120)}`));
    }

    // Check for failed requests
    console.log(`\nFailed requests: ${errors.length}`);
    if (errors.length > 0) {
      errors.slice(0, 10).forEach(e => console.log(`  - ${e.url} (${e.error})`));
    }

    // Save comprehensive logs
    require('fs').writeFileSync('/tmp/playwright_full_logs.json', JSON.stringify({
      logs,
      errors,
      finalUrl: url,
      isLoggedIn,
      timestamp: new Date().toISOString()
    }, null, 2));

    console.log(`\nFull logs saved to /tmp/playwright_full_logs.json`);
    console.log(`\nTEST RESULT: ${isLoggedIn ? 'PASSED' : 'FAILED'}`);
    
  } catch (error) {
    console.error(`TEST ERROR: ${error.message}`);
    await page.screenshot({ path: '/tmp/pw_error.png' });
  } finally {
    await browser.close();
  }
})();
