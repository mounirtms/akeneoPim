const { chromium } = require('playwright');

(async () => {
  const browser = await chromium.launch({ headless: true });
  const page = await browser.newPage();
  
  const messages = [];
  const errors = [];
  
  page.on('console', msg => messages.push(msg.text()));
  page.on('pageerror', error => errors.push(error.message));
  
  await page.goto('https://pim.technostationery.com/user/login', { waitUntil: 'networkidle' });
  await page.fill('input[name="_username"]', 'testuser');
  await page.fill('input[name="_password"]', 'TestPass123!');
  await page.click('button[type="submit"]');
  
  console.log('Waiting for dashboard to load (15 seconds)...');
  await page.waitForTimeout(15000);
  
  const status = await page.evaluate(() => {
    return {
      url: window.location.href,
      title: document.title,
      loadingVisible: document.querySelector('.AknDefault-progressContainer') !== null,
      hasNavMenu: document.querySelector('nav') !== null,
      hasHeader: document.querySelector('header') !== null,
      hasSidebar: document.querySelector('.AknDefault-sidebar') !== null,
      hasContent: document.querySelector('.AknDefault-contentWithBottom') !== null,
      bodyClasses: document.body.className,
      appContent: document.querySelector('.app').innerHTML.length,
      webpackJsonp: typeof window.webpackJsonp !== 'undefined',
      requirejsModules: typeof require !== 'undefined' && require.s?.contexts?._?.defined ? 
        Object.keys(require.s.contexts._.defined).length : 0,
    };
  });
  
  console.log('\n=== DASHBOARD STATUS ===');
  console.log(JSON.stringify(status, null, 2));
  
  console.log('\n=== PAGE ERRORS ===');
  if (errors.length > 0) {
    errors.forEach(err => console.log('❌', err));
  } else {
    console.log('✅ No errors');
  }
  
  console.log('\n=== KEY CONSOLE MESSAGES ===');
  messages.filter(m => 
    m.includes('Akeneo') || 
    m.includes('webpack') || 
    m.includes('Loading entry point') ||
    m.includes('form-builder')
  ).forEach(msg => console.log(msg));
  
  await page.screenshot({ path: 'test_final_dashboard.png', fullPage: true });
  console.log('\n📸 Screenshot: test_final_dashboard.png');
  
  // Final verdict
  if (status.hasNavMenu && status.hasContent && !status.loadingVisible) {
    console.log('\n✅ SUCCESS: Dashboard loaded successfully!');
  } else if (!status.loadingVisible && status.appContent > 1000) {
    console.log('\n⚠️  PARTIAL: Loading screen hidden but UI incomplete');
  } else {
    console.log('\n❌ FAILED: Dashboard still on loading screen');
  }
  
  await browser.close();
})();
