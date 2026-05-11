const { chromium } = require('playwright');

(async () => {
  console.log('Testing new RequireJS-based template...\n');
  
  const browser = await chromium.launch({ headless: true });
  const context = await browser.newContext({
    ignoreHTTPSErrors: true
  });
  const page = await context.newPage();

  // Collect console messages
  const consoleMessages = [];
  page.on('console', msg => {
    const text = msg.text();
    consoleMessages.push(`[${msg.type()}] ${text}`);
    console.log(`  Console: [${msg.type()}] ${text}`);
  });

  // Collect errors
  const errors = [];
  page.on('pageerror', error => {
    errors.push(error.message);
    console.log(`  ❌ Error: ${error.message}`);
  });

  try {
    console.log('Step 1: Logging in as mounir...');
    await page.goto('https://pim.technostationery.com/user/login', { 
      waitUntil: 'networkidle',
      timeout: 30000 
    });
    
    await page.fill('input[name="_username"]', 'mounir');
    await page.fill('input[name="_password"]', 'Mounirbh84@');
    await page.click('button[type="submit"]');
    
    console.log('Step 2: Waiting for dashboard to load (60 seconds)...');
    await page.waitForURL(/\/#\/dashboard/, { timeout: 10000 });
    
    // Wait for loading screen to disappear OR dashboard to appear
    await page.waitForFunction(() => {
      const loadingContainer = document.querySelector('.AknDefault-progressContainer');
      const hasNav = document.querySelector('nav') !== null;
      const hasHeader = document.querySelector('header') !== null;
      const hasMain = document.querySelector('main') !== null;
      
      return hasNav || hasHeader || hasMain || (loadingContainer && loadingContainer.style.display === 'none');
    }, { timeout: 60000 });

    // Wait a bit more for JavaScript to initialize
    await page.waitForTimeout(5000);

    console.log('\nStep 3: Checking page state...');
    const pageState = await page.evaluate(() => {
      return {
        url: window.location.href,
        title: document.title,
        hasLoadingText: document.body.innerText.includes('Loading'),
        hasNav: document.querySelector('nav') !== null,
        hasHeader: document.querySelector('header') !== null,
        hasMain: document.querySelector('main') !== null,
        hasSidebar: document.querySelector('.AknDefault-mainContent') !== null,
        hasContent: document.querySelector('.content') !== null,
        loadingContainerVisible: window.getComputedStyle(document.querySelector('.AknDefault-progressContainer') || document.createElement('div')).display !== 'none',
        appClasses: document.querySelector('.app') ? document.querySelector('.app').className : 'NO APP ELEMENT',
        bodyClasses: document.body.className,
        requireJsDefined: typeof require !== 'undefined',
        jQueryDefined: typeof jQuery !== 'undefined',
        backboneDefined: typeof Backbone !== 'undefined'
      };
    });

    console.log('\n=== PAGE STATE ===');
    console.log(`  URL: ${pageState.url}`);
    console.log(`  Title: ${pageState.title}`);
    console.log(`  RequireJS defined: ${pageState.requireJsDefined}`);
    console.log(`  jQuery defined: ${pageState.jQueryDefined}`);
    console.log(`  Backbone defined: ${pageState.backboneDefined}`);
    console.log(`  Has "Loading" text: ${pageState.hasLoadingText}`);
    console.log(`  Loading container visible: ${pageState.loadingContainerVisible}`);
    console.log(`  App classes: ${pageState.appClasses}`);
    console.log(`  Body classes: ${pageState.bodyClasses}`);
    console.log(`\n=== DASHBOARD ELEMENTS ===`);
    console.log(`  ${pageState.hasNav ? '✅' : '❌'} nav`);
    console.log(`  ${pageState.hasHeader ? '✅' : '❌'} header`);
    console.log(`  ${pageState.hasMain ? '✅' : '❌'} main`);
    console.log(`  ${pageState.hasSidebar ? '✅' : '❌'} sidebar (.AknDefault-mainContent)`);
    console.log(`  ${pageState.hasContent ? '✅' : '❌'} content`);

    // Take screenshot
    await page.screenshot({ path: '/home/pim/public_html/webapp/test_new_template.png', fullPage: true });
    console.log('\n  Screenshot saved: test_new_template.png');

    // Save HTML for debugging
    const html = await page.content();
    require('fs').writeFileSync('/home/pim/public_html/webapp/test_new_template_page.html', html);
    console.log('  HTML saved: test_new_template_page.html');

    console.log(`\n=== CONSOLE MESSAGES (${consoleMessages.length}) ===`);
    consoleMessages.slice(-20).forEach(msg => console.log(`  ${msg}`));

    console.log(`\n=== ERRORS (${errors.length}) ===`);
    if (errors.length > 0) {
      errors.forEach(err => console.log(`  ❌ ${err}`));
    } else {
      console.log('  ✅ No JavaScript errors!');
    }

    // Final verdict
    const success = (pageState.hasNav || pageState.hasHeader || pageState.hasMain) && !pageState.loadingContainerVisible;
    console.log(`\n=== VERDICT ===`);
    console.log(success ? '✅ Dashboard loaded successfully!' : '❌ Still stuck on loading screen');

  } catch (error) {
    console.error(`\n❌ Test failed: ${error.message}`);
  } finally {
    await browser.close();
  }
})();
