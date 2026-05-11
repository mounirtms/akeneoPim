const playwright = require('playwright');

(async () => {
  console.log('🔍 COMPREHENSIVE FINAL TEST - ALL CREDENTIALS');
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
    
    const credentials = [
      { username: 'admin', password: 'admin', label: 'Admin (admin/admin)' },
      { username: 'mounir', password: '2026', label: 'Mounir (mounir/2026)' }
    ];
    
    for (const cred of credentials) {
      console.log(`\n${'='.repeat(80)}`);
      console.log(`Testing: ${cred.label}`);
      console.log('='.repeat(80));
      
      console.log('📍 Navigate to login page...');
      await page.goto('https://pim.technostationery.com/user/login', { 
        waitUntil: 'networkidle',
        timeout: 30000 
      });
      
      // Check if form exists
      const formExists = await page.evaluate(() => {
        return !!document.querySelector('form');
      });
      
      if (!formExists) {
        console.log('❌ Login form not found on page');
        continue;
      }
      
      console.log(`📍 Fill credentials: ${cred.username} / ${'*'.repeat(cred.password.length)}`);
      await page.fill('input[name="_username"]', cred.username);
      await page.fill('input[name="_password"]', cred.password);
      
      console.log('📍 Submit form...');
      await page.click('button[type="submit"]');
      
      // Wait for response
      await page.waitForTimeout(15000);
      
      const currentUrl = page.url();
      const pageTitle = await page.title();
      
      console.log(`📍 Result URL: ${currentUrl}`);
      console.log(`📍 Page Title: ${pageTitle}`);
      
      const isLoginPage = currentUrl.includes('/user/login');
      
      if (!isLoginPage) {
        console.log(`\n✅ LOGIN SUCCESS for ${cred.username}!`);
        console.log('   Checking dashboard state...');
        
        // Wait for PIM to initialize
        await page.waitForTimeout(30000);
        
        const dashboardState = await page.evaluate(() => {
          return {
            hasRequireJS: typeof window.requirejs !== 'undefined',
            moduleCount: window.requirejs ? Object.keys(window.requirejs.s.contexts._.defined).length : 0,
            hasPage: !!document.querySelector('#page'),
            hasContainer: !!document.querySelector('#container'),
            hasMenu: !!document.querySelector('[data-drop-zone="menu"]'),
            menuHasContent: !!document.querySelector('[data-drop-zone="menu"] > *'),
            containerHasContent: !!document.querySelector('#container > *')
          };
        });
        
        console.log('\n📊 Dashboard State:');
        console.log(`   RequireJS: ${dashboardState.hasRequireJS ? '✅' : '❌'}`);
        console.log(`   Modules loaded: ${dashboardState.moduleCount}`);
        console.log(`   Page element: ${dashboardState.hasPage ? '✅' : '❌'}`);
        console.log(`   Container: ${dashboardState.hasContainer ? '✅' : '❌'}`);
        console.log(`   Menu: ${dashboardState.hasMenu ? '✅' : '❌'}`);
        console.log(`   Menu content: ${dashboardState.menuHasContent ? '✅' : '❌'}`);
        console.log(`   Container content: ${dashboardState.containerHasContent ? '✅' : '❌'}`);
        
        if (dashboardState.hasPage && dashboardState.hasContainer && dashboardState.moduleCount > 50) {
          console.log('\n🎉 SYSTEM FULLY OPERATIONAL!');
        } else {
          console.log('\n⚠️  Dashboard partially loaded');
        }
        
        await page.screenshot({ path: `success_${cred.username}.png`, fullPage: true });
        console.log(`📸 Screenshot saved: success_${cred.username}.png`);
        
        // Logout for next test
        await page.goto('https://pim.technostationery.com/user/logout', {
          waitUntil: 'networkidle',
          timeout: 10000
        });
        await page.waitForTimeout(2000);
        
      } else {
        console.log(`\n❌ LOGIN FAILED for ${cred.username}`);
        
        // Check for error messages
        const errorMsg = await page.evaluate(() => {
          const selectors = ['.alert-error', '.alert-danger', '.error-message', '.flash-error'];
          for (const sel of selectors) {
            const elem = document.querySelector(sel);
            if (elem) return elem.textContent.trim();
          }
          return null;
        });
        
        if (errorMsg) {
          console.log(`   Error message: ${errorMsg}`);
        }
      }
    }
    
    console.log('\n' + '='.repeat(80));
    console.log('✓ All credential tests complete');
    console.log('='.repeat(80));
    
  } catch (error) {
    console.error('\n❌ Test error:', error.message);
    console.error(error.stack);
  } finally {
    await browser.close();
  }
})();
