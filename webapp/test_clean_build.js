const { chromium } = require('playwright');

(async () => {
  const browser = await chromium.launch({ headless: true });
  const context = await browser.newContext({ ignoreHTTPSErrors: true });
  const page = await context.newPage();
  
  const consoleMessages = [];
  page.on('console', msg => consoleMessages.push(`[${msg.type()}] ${msg.text()}`));
  
  const errors = [];
  page.on('pageerror', error => errors.push(error.toString()));
  
  console.log('=== TESTING CLEAN BUILD ===\n');
  
  // Login
  await page.goto('https://pim.technostationery.com/user/login', { 
    waitUntil: 'networkidle',
    timeout: 30000 
  });
  
  await page.fill('input[name="_username"]', 'admin');
  await page.fill('input[name="_password"]', 'Admin1234!');
  await page.click('button[type="submit"]');
  
  // Wait for dashboard
  await page.waitForURL('**/dashboard', { timeout: 10000 });
  console.log('✓ Dashboard reached\n');
  
  // Wait for UI to render
  await page.waitForTimeout(10000);
  
  // Check UI state
  const state = await page.evaluate(() => {
    const app = document.querySelector('.app');
    return {
      appExists: !!app,
      appChildCount: app ? app.children.length : 0,
      hasLoading: !!document.querySelector('.AknDefault-progressContainer, .loading-container'),
      hasNav: !!document.querySelector('.navigation, nav, .AknHeader'),
      bodyClasses: document.body.className
    };
  });
  
  console.log('=== UI STATE ===');
  console.log('App exists:', state.appExists);
  console.log('App children:', state.appChildCount);
  console.log('Loading visible:', state.hasLoading);
  console.log('Navigation present:', state.hasNav);
  console.log('Body classes:', state.bodyClasses || '(none)');
  
  console.log('\n=== CONSOLE MESSAGES (first 10) ===');
  consoleMessages.slice(0, 10).forEach((msg, i) => console.log(`${i+1}. ${msg}`));
  
  console.log('\n=== ERRORS ===');
  if (errors.length > 0) {
    errors.forEach((err, i) => console.log(`${i+1}. ${err}`));
  } else {
    console.log('No JavaScript errors');
  }
  
  await page.screenshot({ path: '/tmp/clean_build_test.png' });
  console.log('\n✓ Screenshot: /tmp/clean_build_test.png');
  
  console.log('\n=== RESULT ===');
  if (state.hasNav || state.appChildCount > 1) {
    console.log('✅ UI LOADED SUCCESSFULLY!');
  } else if (state.hasLoading) {
    console.log('⏳ Still loading (may need more time or has issue)');
  } else {
    console.log('❌ UI did not render');
  }
  
  await browser.close();
})();
