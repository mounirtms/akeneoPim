const playwright = require('playwright');

(async () => {
  console.log('🎯 FINAL COMPLETE SYSTEM TEST - Login, Dashboard & Navigation');
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
    const consoleMessages = [];
    
    page.on('console', msg => {
      const type = msg.type();
      const text = msg.text();
      consoleMessages.push(`[${type}] ${text}`);
      if (type === 'error') errors.push(text);
    });
    
    page.on('pageerror', err => {
      errors.push(`[PageError] ${err.message}`);
    });
    
    console.log('\n📍 Step 1: Navigate to login page...');
    await page.goto('https://pim.technostationery.com/user/login', { 
      waitUntil: 'domcontentloaded',
      timeout: 30000 
    });
    
    console.log('📍 Step 2: Login with mounir/2026...');
    await page.fill('input[name="_username"]', 'mounir');
    await page.fill('input[name="_password"]', '2026');
    
    await Promise.all([
      page.waitForNavigation({ waitUntil: 'domcontentloaded', timeout: 20000 }).catch(() => null),
      page.click('button[type="submit"]')
    ]);
    
    const currentUrl = page.url();
    
    if (!currentUrl.includes('#/')) {
      console.log('\n❌ LOGIN FAILED');
      await browser.close();
      return;
    }
    
    console.log('\n✅ LOGIN SUCCESS - Waiting for dashboard...\n');
    
    // Wait for dashboard initialization
    console.log('⏳ Waiting 90 seconds for full dashboard load...');
    await page.waitForTimeout(90000);
    
    // Check dashboard state
    const dashboardState = await page.evaluate(() => {
      return {
        url: window.location.href,
        title: document.title,
        hasRequireJS: typeof window.requirejs !== 'undefined',
        moduleCount: window.requirejs ? Object.keys(window.requirejs.s.contexts._.defined).length : 0,
        hasPage: !!document.querySelector('#page'),
        hasContainer: !!document.querySelector('#container'),
        hasMenu: !!document.querySelector('[data-drop-zone="menu"]'),
        hasMenuContent: !!document.querySelector('[data-drop-zone="menu"] > *'),
        hasContainerContent: !!document.querySelector('#container > *'),
        hasOverlay: !!document.querySelector('#overlay'),
        loadingVisible: !!document.querySelector('.hash-loading-mask:not([style*="display: none"])'),
        bodyClasses: document.body.className,
        mainElements: {
          page: document.querySelector('#page') ? 'exists' : 'missing',
          container: document.querySelector('#container') ? 'exists' : 'missing',
          menu: document.querySelector('[data-drop-zone="menu"]') ? 'exists' : 'missing',
          overlay: document.querySelector('#overlay') ? 'exists' : 'missing'
        }
      };
    });
    
    console.log('\n📊 DASHBOARD STATE:');
    console.log('='.repeat(80));
    console.log(`URL: ${dashboardState.url}`);
    console.log(`Title: ${dashboardState.title}`);
    console.log(`RequireJS: ${dashboardState.hasRequireJS ? '✅' : '❌'}`);
    console.log(`Modules Loaded: ${dashboardState.moduleCount}`);
    console.log(`Body Classes: ${dashboardState.bodyClasses || '(none)'}`);
    
    console.log('\n📦 UI Elements:');
    console.log(`   #page: ${dashboardState.hasPage ? '✅' : '❌'} ${dashboardState.mainElements.page}`);
    console.log(`   #container: ${dashboardState.hasContainer ? '✅' : '❌'} ${dashboardState.mainElements.container}`);
    console.log(`   Menu zone: ${dashboardState.hasMenu ? '✅' : '❌'} ${dashboardState.mainElements.menu}`);
    console.log(`   Menu content: ${dashboardState.hasMenuContent ? '✅' : '❌'}`);
    console.log(`   Container content: ${dashboardState.hasContainerContent ? '✅' : '❌'}`);
    console.log(`   Loading mask: ${dashboardState.loadingVisible ? '⚠️  VISIBLE' : '✅ Hidden'}`);
    
    // Determine system status
    let status = 'UNKNOWN';
    const issues = [];
    const successes = [];
    
    if (dashboardState.hasRequireJS && dashboardState.moduleCount > 0) {
      successes.push(`✅ ${dashboardState.moduleCount} RequireJS modules loaded`);
    }
    
    if (dashboardState.hasPage && dashboardState.hasContainer) {
      successes.push('✅ Main UI structure created');
    } else {
      issues.push('❌ Main UI structure not created');
    }
    
    if (dashboardState.hasMenuContent || dashboardState.hasContainerContent) {
      successes.push('✅ Content rendering detected');
    } else {
      issues.push('❌ No content rendered in UI');
    }
    
    if (dashboardState.moduleCount >= 50) {
      status = 'OPERATIONAL';
    } else if (dashboardState.moduleCount >= 30) {
      status = 'PARTIAL';
    } else {
      status = 'LIMITED';
    }
    
    console.log('\n🔍 ERROR ANALYSIS:');
    console.log(`Total Errors: ${errors.length}`);
    if (errors.length > 0) {
      console.log('\nTop Errors:');
      const uniqueErrors = [...new Set(errors)];
      uniqueErrors.slice(0, 5).forEach((err, i) => {
        const preview = err.length > 100 ? err.substring(0, 100) + '...' : err;
        console.log(`   ${i + 1}. ${preview}`);
      });
    }
    
    console.log('\n📋 SUCCESSES:');
    successes.forEach(s => console.log(`   ${s}`));
    
    if (issues.length > 0) {
      console.log('\n⚠️  ISSUES:');
      issues.forEach(i => console.log(`   ${i}`));
    }
    
    console.log('\n' + '='.repeat(80));
    console.log(`🎖️  OVERALL STATUS: ${status}`);
    console.log('='.repeat(80));
    
    if (status === 'OPERATIONAL') {
      console.log('\n🎉 SUCCESS: System fully operational!');
    } else if (status === 'PARTIAL') {
      console.log('\n⚠️  PARTIAL: System partially working');
    } else {
      console.log('\n⚠️  LIMITED: Basic functionality only');
    }
    
    await page.screenshot({ path: 'final_complete_test.png', fullPage: true });
    console.log('\n📸 Screenshot: final_complete_test.png');
    
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
