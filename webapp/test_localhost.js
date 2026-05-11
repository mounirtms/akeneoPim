const { chromium } = require('playwright');

(async () => {
  const browser = await chromium.launch({ headless: true });
  const page = await browser.newPage();
  
  const messages = [];
  
  page.on('console', msg => messages.push(msg.text()));
  
  // Access via localhost to bypass Cloudflare/Varnish
  await page.goto('http://127.0.0.1:8080/user/login', { waitUntil: 'networkidle' });
  await page.fill('input[name="_username"]', 'testuser');
  await page.fill('input[name="_password"]', 'TestPass123!');
  await page.click('button[type="submit"]');
  
  console.log('Waiting for dashboard (15 seconds)...');
  await page.waitForTimeout(15000);
  
  const status = await page.evaluate(() => {
    return {
      url: window.location.href,
      title: document.title,
      loadingVisible: document.querySelector('.AknDefault-progressContainer') !== null,
      hasNavMenu: document.querySelector('nav') !== null,
      requirejsModules: typeof require !== 'undefined' && require.s?.contexts?._?.defined ? 
        Object.keys(require.s.contexts._.defined).length : 0,
      cacheBuster: document.querySelector('script[src*="cache_buster"]')?.src || 'not found',
    };
  });
  
  console.log('\n=== LOCALHOST TEST ===');
  console.log(JSON.stringify(status, null, 2));
  
  console.log('\n=== CONSOLE MESSAGES ===');
  messages.filter(m => m.includes('Akeneo') || m.includes('webpack') || m.includes('Loading')).forEach(msg => console.log(msg));
  
  await page.screenshot({ path: 'test_localhost.png', fullPage: true });
  
  await browser.close();
})();
