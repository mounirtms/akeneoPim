const { chromium } = require('playwright');

(async () => {
  const browser = await chromium.launch({ headless: true });
  const context = await browser.newContext({ ignoreHTTPSErrors: true });
  const page = await context.newPage();
  
  // Capture all console messages
  const consoleMessages = [];
  page.on('console', msg => {
    consoleMessages.push(`[${msg.type()}] ${msg.text()}`);
  });
  
  // Capture errors
  const errors = [];
  page.on('pageerror', error => {
    errors.push(error.toString());
  });
  
  console.log('=== TESTING FINAL UI FIX ===\n');
  
  // Navigate to login
  await page.goto('https://pim.technostationery.com/user/login', { 
    waitUntil: 'networkidle',
    timeout: 30000 
  });
  
  // Login
  await page.fill('input[name="_username"]', 'admin');
  await page.fill('input[name="_password"]', 'Admin1234!');
  await page.click('button[type="submit"]');
  
  // Wait for dashboard
  await page.waitForURL('**/dashboard', { timeout: 10000 });
  console.log('✓ Dashboard URL reached\n');
  
  // Wait for potential rendering (longer wait for initialization)
  await page.waitForTimeout(10000);
  
  // Check UI state
  const uiState = await page.evaluate(() => {
    const app = document.querySelector('.app');
    return {
      appExists: !!app,
      appChildCount: app ? app.children.length : 0,
      appInnerHTML: app ? app.innerHTML.substring(0, 300) : '',
      loadingVisible: !!document.querySelector('.loading-container, .AknDefault-progressContainer'),
      hasNavigation: !!document.querySelector('.navigation, nav, .AknHeader'),
      hasDashboard: !!document.querySelector('#dashboard, .dashboard'),
      bodyClasses: document.body.className
    };
  });
  
  console.log('=== UI STATE ===');
  console.log('App element exists:', uiState.appExists);
  console.log('App children count:', uiState.appChildCount);
  console.log('Loading screen visible:', uiState.loadingVisible);
  console.log('Has navigation:', uiState.hasNavigation);
  console.log('Has dashboard:', uiState.hasDashboard);
  console.log('Body classes:', uiState.bodyClasses || '(none)');
  
  console.log('\n=== CONSOLE MESSAGES ===');
  consoleMessages.forEach((msg, i) => {
    if (i < 30) console.log(`${i + 1}. ${msg}`);
  });
  if (consoleMessages.length > 30) {
    console.log(`... and ${consoleMessages.length - 30} more messages`);
  }
  
  console.log('\n=== ERRORS ===');
  if (errors.length > 0) {
    errors.forEach((err, i) => console.log(`${i + 1}. ${err}`));
  } else {
    console.log('No JavaScript errors');
  }
  
  // Take screenshot
  await page.screenshot({ path: '/tmp/pim_final_fix.png', fullPage: true });
  console.log('\n✓ Screenshot saved to /tmp/pim_final_fix.png');
  
  // Final verdict
  console.log('\n=== FINAL VERDICT ===');
  if (uiState.appChildCount > 1 || uiState.hasNavigation || uiState.hasDashboard) {
    console.log('✅✅✅ SUCCESS! The PIM UI has loaded!');
    console.log(`   App has ${uiState.appChildCount} children`);
    console.log(`   Navigation: ${uiState.hasNavigation ? 'YES' : 'NO'}`);
    console.log(`   Dashboard: ${uiState.hasDashboard ? 'YES' : 'NO'}`);
  } else if (uiState.loadingVisible) {
    console.log('⏳ Still loading...');
  } else {
    console.log('❌ UI did not fully render');
    console.log('App HTML preview:', uiState.appInnerHTML);
  }
  
  await browser.close();
})();
