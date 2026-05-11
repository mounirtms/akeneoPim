const { chromium } = require('playwright');

(async () => {
  const browser = await chromium.launch({ headless: true });
  const page = await browser.newPage();
  
  // Listen to console messages
  page.on('console', msg => console.log('[BROWSER]', msg.text()));
  
  await page.goto('https://pim.technostationery.com/user/login', { waitUntil: 'networkidle' });
  await page.fill('input[name="_username"]', 'testuser');
  await page.fill('input[name="_password"]', 'TestPass123!');
  await page.click('button[type="submit"]');
  
  await page.waitForTimeout(3000);
  
  // Check webpack status
  const webpackStatus = await page.evaluate(() => {
    return {
      webpackJsonp: typeof window.webpackJsonp !== 'undefined',
      webpackJsonpLength: window.webpackJsonp ? window.webpackJsonp.length : 0,
      jQuery: typeof jQuery !== 'undefined',
      Backbone: typeof Backbone !== 'undefined',
      define: typeof define !== 'undefined',
      require: typeof require !== 'undefined',
      requirejs: typeof requirejs !== 'undefined',
    };
  });
  
  console.log('=== WEBPACK STATUS ===');
  console.log(JSON.stringify(webpackStatus, null, 2));
  
  await browser.close();
})();
