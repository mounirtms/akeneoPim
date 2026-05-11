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
  
  await page.waitForTimeout(5000);
  
  // Deep webpack inspection
  const debug = await page.evaluate(() => {
    const info = {
      errors: [],
      warnings: [],
      moduleInfo: {}
    };
    
    try {
      // Check if webpack bootstrap executed
      if (typeof window.webpackJsonp !== 'undefined') {
        const chunks = window.webpackJsonp;
        info.chunkCount = chunks.length;
        
        // Try to find the webpack module cache
        // Webpack 4 stores modules in a closure, but we can check what's available
        
        // Check if there's a __webpack_require__ function in global scope
        const globalKeys = Object.keys(window).filter(k => k.includes('webpack'));
        info.webpackGlobals = globalKeys;
        
        // Check if any Akeneo modules are defined in RequireJS
        if (typeof require !== 'undefined' && require.s && require.s.contexts) {
          const ctx = require.s.contexts._;
          if (ctx && ctx.defined) {
            info.requirejsModules = Object.keys(ctx.defined);
          }
          if (ctx && ctx.registry) {
            info.requirejsRegistry = Object.keys(ctx.registry);
          }
        }
        
        // Check for pim/form-builder module
        if (typeof require !== 'undefined') {
          try {
            const formBuilder = require('pim/form-builder');
            info.formBuilderFound = typeof formBuilder;
          } catch (e) {
            info.formBuilderError = e.message;
          }
        }
      }
    } catch (e) {
      info.errors.push(e.message);
    }
    
    return info;
  });
  
  console.log('=== DEEP WEBPACK DEBUG ===');
  console.log(JSON.stringify(debug, null, 2));
  
  console.log('\n=== PAGE ERRORS ===');
  if (errors.length > 0) {
    errors.forEach(err => console.log('❌', err));
  } else {
    console.log('✅ No page errors');
  }
  
  console.log('\n=== RELEVANT CONSOLE MESSAGES ===');
  messages.filter(m => m.includes('Akeneo') || m.includes('webpack') || m.includes('require')).forEach(msg => console.log(msg));
  
  await browser.close();
})();
