const { chromium } = require('playwright');

(async () => {
  const browser = await chromium.launch({ headless: true });
  const page = await browser.newPage();
  
  await page.goto('https://pim.technostationery.com/user/login', { waitUntil: 'networkidle' });
  await page.fill('input[name="_username"]', 'testuser');
  await page.fill('input[name="_password"]', 'TestPass123!');
  await page.click('button[type="submit"]');
  
  await page.waitForTimeout(5000);
  
  // Check webpack internals
  const webpackInfo = await page.evaluate(() => {
    const info = {
      webpackJsonpExists: typeof window.webpackJsonp !== 'undefined',
      webpackJsonpLength: window.webpackJsonp ? window.webpackJsonp.length : 0,
      requirejsExists: typeof requirejs !== 'undefined',
      requireExists: typeof require !== 'undefined',
    };
    
    // Try to manually execute the entry point
    if (typeof require !== 'undefined' && typeof require.defined !== 'undefined') {
      info.requireDefined = Object.keys(require.s?.contexts?._?.defined || {});
    }
    
    // Check if we can access webpack modules directly
    if (typeof window.webpackJsonp !== 'undefined' && window.webpackJsonp.length > 0) {
      info.webpackChunks = window.webpackJsonp.map((chunk, idx) => ({
        index: idx,
        hasModules: Array.isArray(chunk) && chunk.length > 1,
        moduleCount: Array.isArray(chunk) && chunk[1] ? Object.keys(chunk[1]).length : 0
      }));
    }
    
    return info;
  });
  
  console.log('=== WEBPACK MODULE INFO ===');
  console.log(JSON.stringify(webpackInfo, null, 2));
  
  await browser.close();
})();
