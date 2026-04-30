const { chromium } = require('playwright');

(async () => {
  const browser = await chromium.launch({ headless: true });
  const context = await browser.newContext();
  const page = await context.newPage();
  
  // Capture all console messages
  page.on('console', msg => {
    if (msg.type() === 'error' || msg.type() === 'warning') {
      console.log(`  [${msg.type().toUpperCase()}] ${msg.text().substring(0, 200)}`);
    }
  });
  
  // Capture all network requests
  page.on('response', async response => {
    const url = response.url();
    if (url.includes('/rest/') || url.includes('/api/') || url.includes('/localization/')) {
      console.log(`  ${response.status()} ${response.url()}`);
      if (response.status() >= 400) {
        const body = await response.text().catch(() => '');
        console.log(`    Body: ${body.substring(0, 200)}`);
      }
    }
  });

  console.log('1. Navigating to login...');
  await page.goto('https://pim.technostationery.com/user/login', { waitUntil: 'networkidle', timeout: 30000 });
  
  console.log('2. Logging in...');
  await page.fill('#username_input', 'testadmin');
  await page.fill('#password_input', 'testpass');
  await page.click('#_submit');
  await page.waitForLoadState('networkidle', { timeout: 30000 });
  
  console.log('3. Waiting for redirect after login...');
  await page.waitForTimeout(5000);
  
  console.log('4. Current URL:', page.url());
  
  console.log('5. Checking cookies...');
  const cookies = await context.cookies();
  console.log(`   Found ${cookies.length} cookies`);
  cookies.forEach(c => console.log(`   - ${c.name}: ${c.value.substring(0, 30)}...`));
  
  console.log('6. Navigating to dashboard...');
  await page.goto('https://pim.technostationery.com/', { waitUntil: 'networkidle', timeout: 30000 });
  await page.waitForTimeout(5000);
  
  console.log('7. Taking screenshot...');
  await page.screenshot({ path: '/home/pim/public_html/webapp/test-results-live/debug-dashboard.png', fullPage: true });
  
  console.log('8. Checking page content...');
  const content = await page.content();
  console.log(`   Page length: ${content.length} chars`);
  console.log(`   Has "app" div: ${content.includes('class="app"')}`);
  console.log(`   Has "Loading": ${content.includes('Loading')}`);
  console.log(`   Has "AknDefault": ${content.includes('AknDefault')}`);
  
  const text = await page.innerText('body').catch(() => '');
  console.log(`   Body text (first 300 chars): ${text.substring(0, 300)}`);
  
  console.log('9. Evaluating JS state...');
  const jsState = await page.evaluate(() => {
    return {
      hasjQuery: typeof $ !== 'undefined',
      hasRequire: typeof require !== 'undefined',
      hasPimApp: typeof window.PimApp !== 'undefined',
      hasFosRouter: typeof fos !== 'undefined',
    };
  });
  console.log(`   JS state:`, jsState);
  
  console.log('10. Testing API calls manually...');
  const apiTest = await page.evaluate(async () => {
    try {
      const userResp = await $.get('/rest/user/');
      console.log('User response:', JSON.stringify(userResp).substring(0, 200));
      return { userOk: true, userData: JSON.stringify(userResp).substring(0, 100) };
    } catch(e) {
      return { userOk: false, error: e.message };
    }
  });
  console.log(`   API test:`, apiTest);
  
  console.log('11. Checking require modules...');
  const moduleTest = await page.evaluate(() => {
    return new Promise((resolve) => {
      require(['pim/init-translator', 'pim/fetcher-registry', 'pim/form-builder', 'pim/user-context', 'pim/date-context'], function(translator, fetcher, formBuilder, userCtx, dateCtx) {
        resolve({
          hasTranslator: !!translator,
          hasFetcher: !!fetcher,
          hasFormBuilder: !!formBuilder,
          hasUserContext: !!userCtx,
          hasDateContext: !!dateCtx,
          fetcherKeys: fetcher ? Object.keys(fetcher).join(', ') : 'none',
        });
      }, function(err) {
        resolve({ error: err.requireModules ? err.requireModules.join(', ') : err.message });
      });
    });
  });
  console.log(`   Module test:`, moduleTest);
  
  console.log('12. Testing configure() chain directly...');
  const configureTest = await page.evaluate(() => {
    return new Promise((resolve) => {
      require(['pim/fetcher-registry', 'pim/user-context', 'pim/date-context', 'pim/init-translator'], function(FetcherRegistry, UserContext, DateContext, initTranslator) {
        try {
          FetcherRegistry.initialize().then(() => {
            console.log('FetcherRegistry initialized OK');
            return UserContext.initialize();
          }).then(() => {
            console.log('UserContext initialized OK');
            return DateContext.initialize();
          }).then(() => {
            console.log('DateContext initialized OK');
            return initTranslator.fetch();
          }).then(() => {
            console.log('initTranslator.fetch() OK');
            resolve({ success: true });
          }).catch(err => {
            console.log('Chain failed:', err);
            resolve({ success: false, error: typeof err === 'object' ? JSON.stringify(err).substring(0, 200) : err });
          });
        } catch(e) {
          resolve({ success: false, error: e.message });
        }
      }, function(err) {
        resolve({ error: 'Module load failed: ' + (err.requireModules ? err.requireModules.join(', ') : err.message) });
      });
    });
  });
  console.log(`   Configure test:`, configureTest);
  
  await browser.close();
  console.log('\nDone.');
})();
