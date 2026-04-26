const { chromium } = require('playwright');

(async () => {
  const browser = await chromium.launch({ headless: true });
  const context = await browser.newContext({ ignoreHTTPSErrors: true });
  const page = await context.newPage();
  
  console.log('=== TESTING PIM UI LOADING WITH ES6 ENTRY POINT ===\n');
  
  // Navigate to login
  await page.goto('https://pim.technostationery.com/user/login', { 
    waitUntil: 'networkidle',
    timeout: 30000 
  });
  
  console.log('✓ Login page loaded');
  
  // Login
  await page.fill('input[name="_username"]', 'admin');
  await page.fill('input[name="_password"]', 'Admin1234!');
  await page.click('button[type="submit"]');
  
  console.log('✓ Login submitted');
  
  // Wait for redirect to dashboard
  await page.waitForURL('**/dashboard', { timeout: 10000 });
  console.log('✓ Redirected to dashboard:', page.url());
  
  // Wait a bit for JS to execute
  await page.waitForTimeout(5000);
  
  console.log('\n=== CHECKING UI STATE ===');
  
  // Check for loading container
  const loadingContainer = await page.$('.loading-container');
  const loadingVisible = loadingContainer ? await loadingContainer.isVisible() : false;
  console.log('Loading container visible:', loadingVisible);
  
  // Check for app element
  const appElement = await page.$('.app');
  console.log('App element present:', !!appElement);
  
  // Check for dashboard content
  const dashboardContent = await page.$('#dashboard');
  console.log('Dashboard content present:', !!dashboardContent);
  
  // Check for navigation
  const navigation = await page.$('.navigation, nav');
  console.log('Navigation present:', !!navigation);
  
  // Check for main content area
  const mainContent = await page.$('.main-content, main, [role="main"]');
  console.log('Main content present:', !!mainContent);
  
  console.log('\n=== CHECKING JAVASCRIPT STATE ===');
  
  const jsState = await page.evaluate(() => {
    return {
      hasRequire: typeof require !== 'undefined',
      hasDefine: typeof define !== 'undefined',
      hasWindowPim: typeof window.pim !== 'undefined',
      hasBackbone: typeof Backbone !== 'undefined',
      hasJQuery: typeof jQuery !== 'undefined',
      bodyClasses: document.body.className,
      appElement: !!document.querySelector('.app'),
      appHasChildren: document.querySelector('.app')?.children.length || 0
    };
  });
  
  console.log('window.pim initialized:', jsState.hasWindowPim);
  console.log('jQuery available:', jsState.hasJQuery);
  console.log('Backbone available:', jsState.hasBackbone);
  console.log('App element children count:', jsState.appHasChildren);
  console.log('Body classes:', jsState.bodyClasses || '(none)');
  
  // Check console for errors
  console.log('\n=== CONSOLE MESSAGES ===');
  const logs = [];
  page.on('console', msg => logs.push(`${msg.type()}: ${msg.text()}`));
  
  await page.waitForTimeout(2000);
  
  if (logs.length > 0) {
    logs.slice(0, 10).forEach(log => console.log(log));
  } else {
    console.log('No console messages captured');
  }
  
  // Take screenshot
  await page.screenshot({ path: '/tmp/pim_ui_after_fix.png', fullPage: true });
  console.log('\n✓ Screenshot saved to /tmp/pim_ui_after_fix.png');
  
  // Final verdict
  console.log('\n=== FINAL VERDICT ===');
  if (jsState.appHasChildren > 0 && !loadingVisible) {
    console.log('✅ SUCCESS! The PIM UI has loaded and rendered!');
    console.log(`   App element has ${jsState.appHasChildren} child elements`);
  } else if (loadingVisible) {
    console.log('⚠️  Still loading... UI may be rendering');
  } else {
    console.log('❌ UI did not render. App element has no children.');
  }
  
  await browser.close();
})();
