const playwright = require('playwright');

(async () => {
  console.log('🔍 DEV MODE LOGIN TEST - Detailed Error Capture');
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
    
    console.log('📍 Step 1: Navigate to login page...');
    await page.goto('https://pim.technostationery.com/user/login', { 
      waitUntil: 'domcontentloaded',
      timeout: 30000 
    });
    
    // Wait for form
    await page.waitForSelector('form.Form', { timeout: 10000 });
    
    console.log('📍 Step 2: Fill credentials (mounir/2026)...');
    await page.fill('input[name="_username"]', 'mounir');
    await page.fill('input[name="_password"]', '2026');
    
    console.log('📍 Step 3: Submit form and capture redirect...');
    const [response] = await Promise.all([
      page.waitForNavigation({ waitUntil: 'domcontentloaded', timeout: 15000 }).catch(() => null),
      page.click('button[type="submit"]')
    ]);
    
    await page.waitForTimeout(5000);
    
    const currentUrl = page.url();
    const pageTitle = await page.title();
    
    console.log(`\n📍 Result URL: ${currentUrl}`);
    console.log(`📍 Page Title: ${pageTitle}`);
    
    // Check for error messages
    const errorMessage = await page.evaluate(() => {
      const helper = document.querySelector('.Helper');
      const alert = document.querySelector('.alert-error, .alert-danger');
      const flash = document.querySelector('.flash-error');
      
      if (helper) return helper.textContent.trim();
      if (alert) return alert.textContent.trim();
      if (flash) return flash.textContent.trim();
      
      return null;
    });
    
    if (errorMessage) {
      console.log(`\n⚠️  Error Message: ${errorMessage}`);
    }
    
    // Check if logged in
    const isLoginPage = currentUrl.includes('/user/login');
    const isDashboard = currentUrl.includes('#/') || currentUrl.includes('/dashboard');
    
    if (!isLoginPage && !isDashboard) {
      console.log(`\n✅ Redirected to: ${currentUrl}`);
    } else if (isLoginPage) {
      console.log('\n❌ Still on login page - login FAILED');
    } else if (isDashboard) {
      console.log('\n✅ LOGIN SUCCESS - Dashboard loaded!');
    }
    
    await page.screenshot({ path: 'dev_mode_login_test.png', fullPage: true });
    console.log('\n📸 Screenshot: dev_mode_login_test.png');
    
  } catch (error) {
    console.error('\n❌ Test error:', error.message);
  } finally {
    await browser.close();
  }
})();
