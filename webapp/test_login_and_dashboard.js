const { chromium } = require('playwright');

(async () => {
  const browser = await chromium.launch({ headless: true });
  const page = await browser.newPage();
  
  console.log('=== TESTING LOGIN AND DASHBOARD LOADING ===\n');
  
  try {
    // Step 1: Load login page
    console.log('Step 1: Loading login page...');
    await page.goto('https://pim.technostationery.com/user/login', { 
      waitUntil: 'networkidle',
      timeout: 30000 
    });
    console.log('✅ Login page loaded\n');
    
    // Step 2: Login
    console.log('Step 2: Logging in as admin...');
    await page.fill('input[name="_username"]', 'admin');
    await page.fill('input[name="_password"]', 'Admin1234!');
    await page.click('button[type="submit"]');
    
    // Wait for navigation
    await page.waitForLoadState('networkidle', { timeout: 30000 });
    
    const currentUrl = page.url();
    console.log(`✅ Logged in, redirected to: ${currentUrl}\n`);
    
    // Step 3: Wait and check for loading screen
    console.log('Step 3: Checking for loading screen...');
    await page.waitForTimeout(3000);
    
    const loadingVisible = await page.evaluate(() => {
      const loadingContainer = document.querySelector('.loading-container');
      const loadingMask = document.querySelector('.hash-loading-mask');
      return {
        loadingContainer: loadingContainer ? window.getComputedStyle(loadingContainer).display : 'not found',
        loadingMask: loadingMask ? window.getComputedStyle(loadingMask).display : 'not found',
        bodyClasses: document.body.className
      };
    });
    
    console.log('Loading elements status:');
    console.log(`  Loading container: ${loadingVisible.loadingContainer}`);
    console.log(`  Loading mask: ${loadingVisible.loadingMask}`);
    console.log(`  Body classes: ${loadingVisible.bodyClasses}\n`);
    
    // Step 4: Check for main content
    console.log('Step 4: Checking for main PIM UI content...');
    
    const uiStatus = await page.evaluate(() => {
      return {
        hasApp: !!document.querySelector('.app'),
        hasDashboard: !!document.querySelector('[class*="dashboard"]'),
        hasNavigation: !!document.querySelector('.AknHeader, .navigation, nav'),
        hasMainContent: !!document.querySelector('.main-content, #container'),
        visibleText: document.body.innerText.substring(0, 200),
        requireDefined: typeof require !== 'undefined',
        defineDefined: typeof define !== 'undefined',
        pimDefined: typeof pim !== 'undefined',
        windowPim: typeof window.pim !== 'undefined'
      };
    });
    
    console.log('UI Status:');
    console.log(`  .app element: ${uiStatus.hasApp ? '✅' : '❌'}`);
    console.log(`  Dashboard: ${uiStatus.hasDashboard ? '✅' : '❌'}`);
    console.log(`  Navigation: ${uiStatus.hasNavigation ? '✅' : '❌'}`);
    console.log(`  Main Content: ${uiStatus.hasMainContent ? '✅' : '❌'}`);
    console.log(`  AMD require(): ${uiStatus.requireDefined ? '✅' : '❌'}`);
    console.log(`  AMD define(): ${uiStatus.defineDefined ? '✅' : '❌'}`);
    console.log(`  window.pim: ${uiStatus.windowPim ? '✅' : '❌'}\n`);
    
    console.log('Visible text preview:');
    console.log(`  "${uiStatus.visibleText}"\n`);
    
    // Step 5: Check console errors
    const logs = [];
    page.on('console', msg => logs.push({ type: msg.type(), text: msg.text() }));
    
    await page.waitForTimeout(2000);
    
    const errors = logs.filter(log => log.type === 'error');
    console.log(`Console errors: ${errors.length}`);
    if (errors.length > 0) {
      console.log('Errors:');
      errors.slice(0, 5).forEach(err => console.log(`  - ${err.text}`));
    }
    
    // Step 6: Take screenshot
    await page.screenshot({ path: '/tmp/pim_after_login.png', fullPage: true });
    console.log('\n📸 Screenshot saved: /tmp/pim_after_login.png');
    
    // Step 7: Diagnosis
    console.log('\n=== DIAGNOSIS ===');
    if (loadingVisible.loadingContainer !== 'none' && loadingVisible.loadingContainer !== 'not found') {
      console.log('❌ PROBLEM: Loading screen still visible!');
      console.log('   The loading container is not hidden.');
    }
    
    if (!uiStatus.requireDefined || !uiStatus.defineDefined) {
      console.log('❌ PROBLEM: AMD (require/define) not available!');
      console.log('   RequireJS may not be loaded or configured.');
    }
    
    if (!uiStatus.windowPim) {
      console.log('❌ PROBLEM: window.pim not initialized!');
      console.log('   The PIM application has not started.');
    }
    
    if (!uiStatus.hasNavigation && !uiStatus.hasMainContent) {
      console.log('❌ PROBLEM: No main UI elements rendered!');
      console.log('   The SPA has not mounted.');
    }
    
    if (loadingVisible.loadingContainer === 'none' && uiStatus.hasNavigation) {
      console.log('✅ SUCCESS: Dashboard loaded correctly!');
    }
    
  } catch (error) {
    console.error('\n❌ Test failed:', error.message);
  } finally {
    await browser.close();
  }
})();
