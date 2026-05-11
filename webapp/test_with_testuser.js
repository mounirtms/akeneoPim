const { chromium } = require('playwright');

(async () => {
  console.log('Testing with fresh test user...\n');
  
  const browser = await chromium.launch({ headless: true });
  const context = await browser.newContext({
    ignoreHTTPSErrors: true
  });
  const page = await context.newPage();

  // Collect console messages
  page.on('console', msg => {
    const text = msg.text();
    if (text.includes('[Akeneo]') || text.includes('Error') || text.includes('error')) {
      console.log(`  [${msg.type()}] ${text}`);
    }
  });

  // Collect errors
  page.on('pageerror', error => {
    console.log(`  ❌ JS Error: ${error.message}`);
  });

  try {
    console.log('Step 1: Going to login page...');
    await page.goto('https://pim.technostationery.com/user/login', { 
      waitUntil: 'domcontentloaded',
      timeout: 30000 
    });
    
    console.log('\nStep 2: Logging in as testuser...');
    await page.fill('input[name="_username"]', 'testuser');
    await page.fill('input[name="_password"]', 'TestPass123!');
    
    await Promise.all([
      page.waitForNavigation({ timeout: 30000 }),
      page.click('button[type="submit"]')
    ]);
    
    console.log(`\nStep 3: After login - URL: ${page.url()}`);
    
    if (page.url().includes('/user/login')) {
      console.log('  ❌ Still on login page');
      const bodyText = await page.evaluate(() => document.body.innerText);
      console.log(`  Message: ${bodyText.substring(0, 200)}`);
      await browser.close();
      return;
    }
    
    console.log('  ✅ Redirected away from login page');
    
    // Wait for page to load
    console.log('\nStep 4: Waiting for dashboard to load (30 seconds)...');
    await page.waitForTimeout(10000);
    
    const state = await page.evaluate(() => ({
      url: window.location.href,
      title: document.title,
      hasNav: document.querySelector('nav') !== null,
      hasHeader: document.querySelector('header') !== null,
      hasMain: document.querySelector('main') !== null,
      hasSidebar: document.querySelector('.AknDefault-mainContent') !== null,
      loadingVisible: document.querySelector('.AknDefault-progressContainer') && 
                      window.getComputedStyle(document.querySelector('.AknDefault-progressContainer')).display !== 'none',
      requireJsDefined: typeof require !== 'undefined',
      jQueryDefined: typeof jQuery !== 'undefined',
      backboneDefined: typeof Backbone !== 'undefined',
      bodyClasses: document.body.className,
      appElement: document.querySelector('.app') ? document.querySelector('.app').innerHTML.substring(0, 300) : 'NO APP'
    }));
    
    console.log('\n=== DASHBOARD STATE ===');
    console.log(`  URL: ${state.url}`);
    console.log(`  Title: ${state.title}`);
    console.log(`  RequireJS: ${state.requireJsDefined ? '✅' : '❌'}`);
    console.log(`  jQuery: ${state.jQueryDefined ? '✅' : '❌'}`);
    console.log(`  Backbone: ${state.backboneDefined ? '✅' : '❌'}`);
    console.log(`  Loading visible: ${state.loadingVisible ? '❌ YES (stuck)' : '✅ NO (good)'}`);
    console.log(`  Body classes: ${state.bodyClasses}`);
    console.log('\n=== UI ELEMENTS ===');
    console.log(`  ${state.hasNav ? '✅' : '❌'} Navigation`);
    console.log(`  ${state.hasHeader ? '✅' : '❌'} Header`);
    console.log(`  ${state.hasMain ? '✅' : '❌'} Main content`);
    console.log(`  ${state.hasSidebar ? '✅' : '❌'} Sidebar`);
    
    await page.screenshot({ path: '/home/pim/public_html/webapp/test_testuser_dashboard.png', fullPage: true });
    console.log('\n  📸 Screenshot saved: test_testuser_dashboard.png');
    
    const html = await page.content();
    require('fs').writeFileSync('/home/pim/public_html/webapp/test_testuser_page.html', html);
    console.log('  💾 HTML saved: test_testuser_page.html');
    
    const success = (state.hasNav || state.hasHeader || state.hasMain) && !state.loadingVisible;
    console.log(`\n=== VERDICT ===`);
    console.log(success ? '✅ Dashboard loaded successfully!' : '❌ Still stuck on loading screen');
    
  } catch (error) {
    console.error(`\n❌ Test failed: ${error.message}`);
  } finally {
    await browser.close();
  }
})();
