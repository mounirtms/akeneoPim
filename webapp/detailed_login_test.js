const playwright = require('playwright');

(async () => {
  console.log('🔍 DETAILED LOGIN DIAGNOSTIC TEST');
  console.log('='.repeat(80));
  
  const browser = await playwright.chromium.launch({
    headless: true,
    args: ['--no-sandbox', '--disable-setuid-sandbox']
  });
  
  try {
    const context = await browser.newContext({
      ignoreHTTPSErrors: true,
      viewport: { width: 1920, height: 1080 }
    });
    
    const page = await context.newPage();
    
    const errors = [];
    const networkRequests = [];
    
    page.on('console', msg => {
      const type = msg.type();
      const text = msg.text();
      if (type === 'error') errors.push(text);
    });
    
    page.on('request', request => {
      networkRequests.push({
        url: request.url(),
        method: request.method(),
        postData: request.postData()
      });
    });
    
    page.on('response', async response => {
      if (response.url().includes('/user/login')) {
        console.log(`\n📡 Login Response: ${response.status()} ${response.statusText()}`);
      }
    });
    
    console.log('📍 Step 1: Navigate to login page...');
    await page.goto('https://pim.technostationery.com/user/login', { 
      waitUntil: 'networkidle', 
      timeout: 30000 
    });
    
    // Get form details
    const formDetails = await page.evaluate(() => {
      const form = document.querySelector('form');
      const usernameInput = document.querySelector('input[name="_username"]');
      const passwordInput = document.querySelector('input[name="_password"]');
      const csrfInput = document.querySelector('input[name="_csrf_token"]');
      const submitButton = document.querySelector('button[type="submit"]');
      
      return {
        formExists: !!form,
        formAction: form ? form.action : null,
        formMethod: form ? form.method : null,
        usernameExists: !!usernameInput,
        passwordExists: !!passwordInput,
        csrfExists: !!csrfInput,
        csrfValue: csrfInput ? csrfInput.value : null,
        submitExists: !!submitButton,
        submitDisabled: submitButton ? submitButton.disabled : null
      };
    });
    
    console.log('\n📋 Form Details:');
    console.log(`   Form exists: ${formDetails.formExists ? '✅' : '❌'}`);
    console.log(`   Form action: ${formDetails.formAction}`);
    console.log(`   Form method: ${formDetails.formMethod}`);
    console.log(`   Username field: ${formDetails.usernameExists ? '✅' : '❌'}`);
    console.log(`   Password field: ${formDetails.passwordExists ? '✅' : '❌'}`);
    console.log(`   CSRF token: ${formDetails.csrfExists ? '✅' : '❌'}`);
    console.log(`   CSRF value: ${formDetails.csrfValue ? formDetails.csrfValue.substring(0, 20) + '...' : 'N/A'}`);
    console.log(`   Submit button: ${formDetails.submitExists ? '✅' : '❌'}`);
    console.log(`   Button disabled: ${formDetails.submitDisabled}`);
    
    console.log('\n📍 Step 2: Fill form fields...');
    await page.fill('input[name="_username"]', 'mounir');
    await page.fill('input[name="_password"]', '2026');
    
    // Verify fields are filled
    const fieldValues = await page.evaluate(() => {
      return {
        username: document.querySelector('input[name="_username"]').value,
        password: document.querySelector('input[name="_password"]').value
      };
    });
    
    console.log(`   Username field value: "${fieldValues.username}"`);
    console.log(`   Password field value: "${fieldValues.password.replace(/./g, '*')}"`);
    
    console.log('\n📍 Step 3: Submit form...');
    
    // Wait for navigation after clicking submit
    const [response] = await Promise.all([
      page.waitForResponse(response => 
        response.url().includes('/user/login') && 
        response.request().method() === 'POST',
        { timeout: 10000 }
      ).catch(() => null),
      page.click('button[type="submit"]')
    ]);
    
    if (response) {
      console.log(`   Form submitted: POST ${response.url()}`);
      console.log(`   Response status: ${response.status()}`);
      console.log(`   Response type: ${response.headers()['content-type']}`);
    }
    
    // Wait for page to settle
    await page.waitForTimeout(5000);
    
    const currentUrl = page.url();
    console.log(`\n📍 Current URL after submit: ${currentUrl}`);
    
    // Check for error messages
    const errorMessages = await page.evaluate(() => {
      const errors = [];
      
      // Common error selectors
      const selectors = [
        '.alert-error',
        '.alert-danger',
        '.error-message',
        '.flash-error',
        '.AknMessageBar--error',
        '[class*="error"]'
      ];
      
      selectors.forEach(selector => {
        const elements = document.querySelectorAll(selector);
        elements.forEach(el => {
          const text = el.textContent.trim();
          if (text && !errors.includes(text)) {
            errors.push(text);
          }
        });
      });
      
      return errors;
    });
    
    if (errorMessages.length > 0) {
      console.log('\n⚠️  Error messages found:');
      errorMessages.forEach(msg => console.log(`   - ${msg}`));
    } else {
      console.log('\n✅ No error messages on page');
    }
    
    // Check if we're redirected
    const isLoginPage = currentUrl.includes('/user/login');
    const isDashboard = currentUrl.includes('#/') || currentUrl.includes('/dashboard');
    
    console.log('\n📊 Login Result:');
    if (isLoginPage) {
      console.log('   ❌ Still on login page - login FAILED');
      console.log('   → Check server logs for authentication errors');
      console.log('   → Verify user is enabled in database');
      console.log('   → Check Symfony security configuration');
    } else if (isDashboard) {
      console.log('   ✅ Redirected to dashboard - login SUCCESS');
    } else {
      console.log(`   ⚠️  Redirected to: ${currentUrl}`);
    }
    
    // Network analysis
    const loginRequests = networkRequests.filter(r => 
      r.url.includes('/user/login') && r.method === 'POST'
    );
    
    if (loginRequests.length > 0) {
      console.log('\n📡 Network Requests:');
      loginRequests.forEach((req, i) => {
        console.log(`   [${i + 1}] POST ${req.url}`);
        if (req.postData) {
          const postDataPreview = req.postData.substring(0, 100);
          console.log(`       Data: ${postDataPreview}...`);
        }
      });
    }
    
    await page.screenshot({ path: 'detailed_login_test.png', fullPage: true });
    console.log('\n📸 Screenshot saved: detailed_login_test.png');
    
    console.log('\n' + '='.repeat(80));
    console.log('✓ Diagnostic test complete');
    console.log('='.repeat(80));
    
  } catch (error) {
    console.error('\n❌ Test error:', error.message);
    console.error(error.stack);
  } finally {
    await browser.close();
  }
})();
