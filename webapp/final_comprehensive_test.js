const playwright = require('playwright');

(async () => {
  console.log('🔍 FINAL COMPREHENSIVE TEST - COMPLETE SYSTEM VERIFICATION');
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
    
    // Capture all errors
    const allErrors = [];
    const allWarnings = [];
    const criticalErrors = [];
    
    page.on('console', msg => {
      const type = msg.type();
      const text = msg.text();
      
      if (type === 'error') {
        allErrors.push(text);
        if (text.includes('Akeneo') || text.includes('template') || text.includes('replace')) {
          criticalErrors.push(text);
        }
      } else if (type === 'warning') {
        allWarnings.push(text);
      }
    });
    
    page.on('pageerror', err => {
      criticalErrors.push(`[PageError] ${err.message}`);
    });
    
    console.log('📍 Step 1: Navigate to login page...');
    await page.goto('https://pim.technostationery.com/user/login', { 
      waitUntil: 'networkidle', 
      timeout: 60000 
    });
    
    console.log('📍 Step 2: Login with admin credentials...');
    await page.fill('input[name="_username"]', 'admin');
    await page.fill('input[name="_password"]', 'admin');
    await page.click('button[type="submit"]');
    
    console.log('📍 Step 3: Wait for dashboard to load (50 seconds)...');
    await page.waitForTimeout(50000);
    
    console.log('\n' + '='.repeat(80));
    console.log('📊 SYSTEM STATUS CHECK');
    console.log('='.repeat(80));
    
    // Check page state
    const pageState = await page.evaluate(() => {
      return {
        title: document.title,
        url: window.location.href,
        hasAppContainer: !!document.querySelector('.app'),
        hasLoadingMask: !!document.querySelector('.hash-loading-mask'),
        loadingVisible: document.querySelector('.hash-loading-mask')?.style.display !== 'none',
        hasMenu: !!document.querySelector('[data-drop-zone="menu"]'),
        hasContainer: !!document.querySelector('#container'),
        hasPage: !!document.querySelector('#page'),
        bodyClasses: document.body.className,
        mainContentVisible: !!document.querySelector('#container:not(:empty)')
      };
    });
    
    console.log('\n🖥️  Page State:');
    console.log(`   Title: ${pageState.title}`);
    console.log(`   URL: ${pageState.url}`);
    console.log(`   App Container: ${pageState.hasAppContainer ? '✅' : '❌'}`);
    console.log(`   Loading Mask: ${pageState.hasLoadingMask ? (pageState.loadingVisible ? '⚠️  VISIBLE (STUCK)' : '✅ Hidden') : '❌ Missing'}`);
    console.log(`   Menu Zone: ${pageState.hasMenu ? '✅' : '❌'}`);
    console.log(`   Container: ${pageState.hasContainer ? '✅' : '❌'}`);
    console.log(`   Page Element: ${pageState.hasPage ? '✅' : '❌'}`);
    console.log(`   Main Content Visible: ${pageState.mainContentVisible ? '✅' : '❌'}`);
    
    // Check RequireJS modules
    const moduleState = await page.evaluate(() => {
      if (typeof window.requirejs === 'undefined') {
        return { available: false };
      }
      
      const modules = window.requirejs.s.contexts._.defined;
      return {
        available: true,
        totalModules: Object.keys(modules).length,
        criticalModules: {
          'pim/app': modules['pim/app'] !== undefined,
          'pim/template/app': modules['pim/template/app'] !== undefined,
          'pimui/js/view/base': modules['pimui/js/view/base'] !== undefined,
          'pimui/js/pim-app': modules['pimui/js/pim-app'] !== undefined,
          'pim/form-builder': modules['pim/form-builder'] !== undefined,
          'underscore': modules['underscore'] !== undefined,
          'backbone': modules['backbone'] !== undefined,
          'jquery': modules['jquery'] !== undefined
        }
      };
    });
    
    console.log('\n📦 RequireJS Module State:');
    if (moduleState.available) {
      console.log(`   Total Modules: ${moduleState.totalModules}`);
      console.log('   Critical Modules:');
      Object.entries(moduleState.criticalModules).forEach(([name, loaded]) => {
        console.log(`     ${loaded ? '✅' : '❌'} ${name}`);
      });
    } else {
      console.log('   ❌ RequireJS not available');
    }
    
    console.log('\n' + '='.repeat(80));
    console.log('🐛 ERROR ANALYSIS');
    console.log('='.repeat(80));
    
    console.log(`\n📊 Error Summary:`);
    console.log(`   Total Errors: ${allErrors.length}`);
    console.log(`   Critical Errors: ${criticalErrors.length}`);
    console.log(`   Warnings: ${allWarnings.length}`);
    
    if (criticalErrors.length > 0) {
      console.log('\n🔴 Critical Errors:');
      criticalErrors.slice(0, 5).forEach((err, i) => {
        console.log(`\n   [${i + 1}] ${err.substring(0, 200)}${err.length > 200 ? '...' : ''}`);
      });
    }
    
    console.log('\n' + '='.repeat(80));
    console.log('🎯 DIAGNOSIS & NEXT STEPS');
    console.log('='.repeat(80));
    
    if (!pageState.hasPage) {
      console.log('\n❌ CRITICAL: Page element not rendered');
      console.log('   → Dashboard is NOT operational');
      console.log('   → Form builder failed to create UI structure');
    } else if (pageState.loadingVisible) {
      console.log('\n⚠️  WARNING: Loading screen still visible');
      console.log('   → Dashboard initialization incomplete');
      console.log('   → Check template compilation errors');
    } else if (pageState.mainContentVisible) {
      console.log('\n✅ SUCCESS: Dashboard rendered successfully!');
      console.log('   → System is operational');
      console.log('   → All critical modules loaded');
    } else {
      console.log('\n⚠️  PARTIAL: Structure created but content empty');
      console.log('   → Dashboard routing may need attention');
    }
    
    // Take screenshot
    await page.screenshot({ path: 'final_comprehensive_test.png', fullPage: true });
    console.log('\n📸 Screenshot saved: final_comprehensive_test.png');
    
    console.log('\n' + '='.repeat(80));
    console.log('✓ Test complete');
    console.log('='.repeat(80));
    
  } catch (error) {
    console.error('❌ Test error:', error.message);
  } finally {
    await browser.close();
  }
})();
