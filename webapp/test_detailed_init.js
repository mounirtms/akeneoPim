const { chromium } = require('playwright');

(async () => {
  const browser = await chromium.launch({ headless: true });
  const page = await browser.newPage();
  
  const messages = [];
  page.on('console', msg => messages.push(msg.text()));
  
  await page.goto('https://pim.technostationery.com/user/login', { waitUntil: 'networkidle' });
  await page.fill('input[name="_username"]', 'testuser');
  await page.fill('input[name="_password"]', 'TestPass123!');
  await page.click('button[type="submit"]');
  
  await page.waitForTimeout(5000);
  
  console.log('=== ALL CONSOLE MESSAGES ===');
  messages.forEach(msg => console.log(msg));
  
  const status = await page.evaluate(() => {
    return {
      webpackJsonp: typeof webpackJsonp !== 'undefined',
      pimInit: typeof window.pimInit,
      BackboneHistory: typeof Backbone !== 'undefined' && Backbone.history ? 'exists' : 'missing',
      requirejsModules: typeof require !== 'undefined' ? Object.keys(require.s?.contexts?._?.defined || {}).length : 0,
    };
  });
  
  console.log('\n=== STATUS ===');
  console.log(JSON.stringify(status, null, 2));
  
  await browser.close();
})();
