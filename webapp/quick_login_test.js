const playwright = require('playwright');

(async () => {
  console.log('🎯 QUICK LOGIN TEST - Verify Authentication Works');
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
    
    console.log('\n📍 Navigate to login page...');
    await page.goto('https://pim.technostationery.com/user/login', { 
      waitUntil: 'domcontentloaded',
      timeout: 30000 
    });
    
    console.log('📍 Login with mounir/2026...');
    await page.fill('input[name="_username"]', 'mounir');
    await page.fill('input[name="_password"]', '2026');
    
    await Promise.all([
      page.waitForNavigation({ timeout: 15000 }).catch(() => null),
      page.click('button[type="submit"]')
    ]);
    
    await page.waitForTimeout(5000);
    
    const currentUrl = page.url();
    const isDashboard = currentUrl.includes('#/') || currentUrl.includes('/dashboard');
    
    console.log(`\n📊 RESULT:`);
    console.log(`   URL: ${currentUrl}`);
    console.log(`   Status: ${isDashboard ? '✅ LOGIN SUCCESS' : '❌ LOGIN FAILED'}`);
    
    if (isDashboard) {
      console.log('\n🎉 AUTHENTICATION WORKING!');
      console.log('   ✅ Credentials: mounir/2026');
      console.log('   ✅ Redirect to dashboard successful');
      console.log('   ✅ Session established');
    }
    
    await page.screenshot({ path: 'quick_login_test.png' });
    
  } catch (error) {
    console.error('\n❌ Error:', error.message);
  } finally {
    await browser.close();
  }
})();
