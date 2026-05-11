const playwright = require('playwright');

(async () => {
  console.log('🎯 COMPREHENSIVE PRODUCTION TEST - Login & Dashboard');
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
    const warnings = [];
    
    page.on('console', msg => {
      const type = msg.type();
      const text = msg.text();
      if (type === 'error') errors.push(text);
      else if (type === 'warning') warnings.push(text);
    });
    
    page.on('pageerror', err => {
      errors.push(`[PageError] ${err.message}`);
    });
    
    console.log('\n📍 Step 1: Navigate to login page...');
    await page.goto('https://pim.technostationery.com/user/login', { 
      waitUntil: 'domcontentloaded',
      timeout: 30000 
    });
    
    await page.waitForSelector('form.Form', { timeout: 10000 });
    
    // Check CSS loading
    const cssStatus = await page.evaluate(() => {
      const links = Array.from(document.querySelectorAll('link[rel="stylesheet"]'));
      return {
        count: links.length,
        urls: links.map(l => l.href),
        hasStyles: !!document.querySelector('body[class]')
      };
    });
    
    console.log(`   CSS Files: ${cssStatus.count} loaded`);
    
    console.log('\n📍 Step 2: Login with mounir/2026...');
    await page.fill('input[name="_username"]', 'mounir');
    await page.fill('input[name="_password"]', '2026');
    
    await Promise.all([
      page.waitForNavigation({ waitUntil: 'domcontentloaded', timeout: 20000 }).catch(() => null),
      page.click('button[type="submit"]')
    ]);
    
    await page.waitForTimeout(5000);
    
    const currentUrl = page.url();
    const pageTitle = await page.title();
    
    console.log(`\n📊 RESULT:`);
    console.log(`   URL: ${currentUrl}`);
    console.log(`   Title: ${pageTitle}`);
    
    const isDashboard = currentUrl.includes('#/') || currentUrl.includes('/dashboard');
    const isLoginPage = currentUrl.includes('/user/login');
    
    if (isDashboard) {
      console.log('\n✅ LOGIN SUCCESS!');
      
      console.log('\n📍 Step 3: Wait for dashboard to load (60 seconds)...');
      await page.waitForTimeout(60000);
      
      const dashboardState = await page.evaluate(() => {
        return {
          hasRequireJS: typeof window.requirejs !== 'undefined',
          moduleCount: window.requirejs ? Object.keys(window.requirejs.s.contexts._.defined).length : 0,
          hasPage: !!document.querySelector('#page'),
          hasContainer: !!document.querySelector('#container'),
          hasMenu: !!document.querySelector('[data-drop-zone="menu"]'),
          menuHasContent: !!document.querySelector('[data-drop-zone="menu"] > *'),
          containerHasContent: !!document.querySelector('#container > *'),
          bodyClasses: document.body.className,
          title: document.title
        };
      });
      
      console.log('\n📦 Dashboard State:');
      console.log(`   RequireJS: ${dashboardState.hasRequireJS ? '✅' : '❌'}`);
      console.log(`   Modules: ${dashboardState.moduleCount}`);
      console.log(`   Page: ${dashboardState.hasPage ? '✅' : '❌'}`);
      console.log(`   Container: ${dashboardState.hasContainer ? '✅' : '❌'}`);
      console.log(`   Menu: ${dashboardState.hasMenu ? '✅' : '❌'}`);
      console.log(`   Menu Content: ${dashboardState.menuHasContent ? '✅' : '❌'}`);
      console.log(`   Container Content: ${dashboardState.containerHasContent ? '✅' : '❌'}`);
      console.log(`   Body Classes: ${dashboardState.bodyClasses}`);
      console.log(`   Title: ${dashboardState.title}`);
      
      if (dashboardState.moduleCount >= 50 && dashboardState.hasContainer) {
        console.log('\n🎉 SYSTEM FULLY OPERATIONAL!');
      } else {
        console.log('\n⚠️  Dashboard partially loaded');
      }
      
    } else if (isLoginPage) {
      console.log('\n❌ LOGIN FAILED - Still on login page');
    }
    
    console.log(`\n🐛 Errors: ${errors.length}`);
    console.log(`⚠️  Warnings: ${warnings.length}`);
    
    if (errors.length > 0) {
      console.log('\nTop Errors:');
      errors.slice(0, 3).forEach((err, i) => {
        console.log(`   ${i + 1}. ${err.substring(0, 100)}`);
      });
    }
    
    await page.screenshot({ path: 'production_final_test.png', fullPage: true });
    console.log('\n📸 Screenshot: production_final_test.png');
    
    console.log('\n' + '='.repeat(80));
    console.log('✓ Test complete');
    console.log('='.repeat(80));
    
  } catch (error) {
    console.error('\n❌ Test error:', error.message);
    console.error(error.stack);
  } finally {
    await browser.close();
  }
})();
