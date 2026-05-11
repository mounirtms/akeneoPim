const { chromium } = require('playwright');

(async () => {
  const browser = await chromium.launch({ headless: true });
  const page = await browser.newPage();
  
  const messages = [];
  const scripts = [];
  
  page.on('console', msg => messages.push(msg.text()));
  page.on('response', async (response) => {
    const url = response.url();
    if (url.includes('.js') && (url.includes('vendor') || url.includes('main'))) {
      scripts.push({
        url: url.split('/').pop(),
        status: response.status(),
        time: new Date().toISOString()
      });
    }
  });
  
  await page.goto('https://pim.technostationery.com/user/login', { waitUntil: 'networkidle' });
  await page.fill('input[name="_username"]', 'testuser');
  await page.fill('input[name="_password"]', 'TestPass123!');
  await page.click('button[type="submit"]');
  
  await page.waitForTimeout(5000);
  
  console.log('=== SCRIPT LOAD ORDER ===');
  scripts.forEach(s => console.log(`${s.url} - Status: ${s.status}`));
  
  console.log('\n=== CONSOLE MESSAGES (last 10) ===');
  messages.slice(-10).forEach(msg => console.log(msg));
  
  const status = await page.evaluate(() => {
    return {
      webpackJsonp: typeof window.webpackJsonp !== 'undefined' ? window.webpackJsonp.length : 0,
      installedChunks: typeof window.webpackJsonp !== 'undefined' ? 'exists' : 'missing',
    };
  });
  
  console.log('\n=== WEBPACK STATUS ===');
  console.log(JSON.stringify(status, null, 2));
  
  await browser.close();
})();
