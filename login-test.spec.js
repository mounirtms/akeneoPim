const { test, expect } = require('@playwright/test');

test('Login test with testadmin credentials', async ({ page }) => {
  // Capture console logs
  const logs = [];
  page.on('console', msg => {
    logs.push({ type: msg.type(), text: msg.text() });
    console.log(`CONSOLE: ${msg.type()} - ${msg.text()}`);
  });

  // Capture network errors
  const errors = [];
  page.on('requestfailed', request => {
    errors.push({ url: request.url(), error: request.failure().errorText });
    console.log(`REQUEST FAILED: ${request.url()} - ${request.failure().errorText}`);
  });

  page.on('response', async response => {
    if (response.status() >= 400) {
      errors.push({ url: response.url(), status: response.status() });
      console.log(`HTTP ERROR: ${response.status()} - ${response.url()}`);
    }
  });

  try {
    // Navigate to login page
    console.log('Navigating to login page...');
    await page.goto('https://pim.technostationery.com/user/login', { 
      waitUntil: 'networkidle',
      timeout: 30000 
    });

    // Take screenshot of login page
    await page.screenshot({ path: '/tmp/login_page.png' });
    console.log('Screenshot saved: /tmp/login_page.png');

    // Fill login form
    await page.fill('input[name="_username"]', 'testadmin');
    await page.fill('input[name="_password"]', 'testpass');
    
    console.log('Submitting login form...');
    await Promise.all([
      page.waitForNavigation({ waitUntil: 'networkidle', timeout: 15000 }),
      page.click('button[type="submit"]')
    ]);
    
    // Take screenshot after login attempt
    await page.screenshot({ path: '/tmp/after_login.png', fullPage: true });
    console.log('Screenshot saved: /tmp/after_login.png');

    // Check if logged in
    const url = page.url();
    console.log(`Current URL after login: ${url}`);
    
    const isLoggedIn = url.includes('/#') || !url.includes('/user/login');
    console.log(`Login successful: ${isLoggedIn}`);

    // Check for error messages
    const errorText = await page.textContent('.alert-danger, .flash-error, .error').catch(() => null);
    if (errorText) {
      console.log(`ERROR MESSAGE: ${errorText}`);
    }

    // Wait a bit for any JS errors to appear
    await page.waitForTimeout(3000);
    
    // Take final screenshot
    await page.screenshot({ path: '/tmp/after_login_dashboard.png', fullPage: true });

    // Save logs
    require('fs').writeFileSync('/tmp/playwright_login_logs.json', JSON.stringify({
      logs,
      errors,
      finalUrl: url,
      isLoggedIn,
      errorMessage: errorText
    }, null, 2));

    expect(isLoggedIn).toBe(true);

  } catch (error) {
    console.error(`TEST FAILED: ${error.message}`);
    await page.screenshot({ path: '/tmp/login_error.png' });
    throw error;
  }
});
