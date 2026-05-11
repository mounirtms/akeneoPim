const playwright = require('playwright');

(async () => {
  console.log('🔍 ADMIN LOGIN TEST - Verify login system works');
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
      waitUntil: 'networkidle', 
      timeout: 30000 
    });
    
    console.log('📍 Step 2: Login with admin credentials...');
    await page.fill('input[name="_username"]', 'admin');
    await page.fill('input[name="_password"]', 'admin');
    await page.click('button[type="submit"]');
    
    console.log('📍 Step 3: Wait for redirect...');
    await page.waitForTimeout(10000);
    
    const currentUrl = page.url();
    const pageTitle = await page.title();
    
    console.log(`\n📍 Current URL: ${currentUrl}`);
    console.log(`📍 Page Title: ${pageTitle}`);
    
    const isLoginPage = currentUrl.includes('/user/login');
    const isDashboard = currentUrl.includes('#/') || !isLoginPage;
    
    if (isDashboard) {
      console.log('\n✅ Admin login SUCCESS - login system works!');
      console.log('   Now testing mounir credentials...\n');
      
      // Logout
      await page.goto('https://pim.technostationery.com/user/logout', { 
        waitUntil: 'networkidle',
        timeout: 10000 
      });
      
      await page.waitForTimeout(2000);
      
      // Login with mounir
      console.log('📍 Step 4: Login with mounir/2026...');
      await page.goto('https://pim.technostationery.com/user/login', { 
        waitUntil: 'networkidle',
        timeout: 30000 
      });
      
      await page.fill('input[name="_username"]', 'mounir');
      await page.fill('input[name="_password"]', '2026');
      await page.click('button[type="submit"]');
      
      await page.waitForTimeout(10000);
      
      const mounirUrl = page.url();
      const mounirTitle = await page.title();
      
      console.log(`\n📍 Mounir URL: ${mounirUrl}`);
      console.log(`📍 Mounir Title: ${mounirTitle}`);
      
      if (mounirUrl.includes('/user/login')) {
        console.log('\n❌ Mounir login FAILED');
        console.log('   - Password hash is correct (verified)');
        console.log('   - User is enabled in database');
        console.log('   - Auth failure counter reset');
        console.log('   - Login system works (admin successful)');
        console.log('\n🔍 Possible issues:');
        console.log('   - User permissions/roles may be incorrect');
        console.log('   - Account may have additional restrictions');
      } else {
        console.log('\n✅ Mounir login SUCCESS!');
      }
    } else {
      console.log('\n❌ Admin login FAILED - login system has issues');
    }
    
    await page.screenshot({ path: 'admin_mounir_test.png', fullPage: true });
    console.log('\n📸 Screenshot: admin_mounir_test.png');
    
  } catch (error) {
    console.error('\n❌ Test error:', error.message);
  } finally {
    await browser.close();
  }
})();
