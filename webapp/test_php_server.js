const { chromium } = require('playwright');

(async () => {
  const browser = await chromium.launch({ 
    headless: true,
    args: ['--no-sandbox', '--disable-setuid-sandbox']
  });
  
  const context = await browser.newContext();
  const page = await context.newPage();
  
  const loadedScripts = [];
  
  page.on('response', response => {
    if (response.url().includes('.js') && response.status() === 200) {
      const filename = response.url().split('/').pop().split('?')[0];
      if (!loadedScripts.includes(filename)) {
        loadedScripts.push(filename);
      }
    }
  });
  
  const consoleMessages = [];
  page.on('console', msg => consoleMessages.push(`[${msg.type()}] ${msg.text()}`));
  
  try {
    console.log('🔍 Testing PHP built-in server on localhost:8081...\n');
    
    await page.goto('http://127.0.0.1:8081', { 
      waitUntil: 'domcontentloaded',
      timeout: 20000 
    });
    
    await page.waitForTimeout(2000);
    
    const currentUrl = page.url();
    console.log('📍 Current URL:', currentUrl);
    
    if (currentUrl.includes('login')) {
      console.log('🔐 Login page loaded! Logging in...');
      await page.fill('input[name="_username"]', 'testuser');
      await page.fill('input[name="_password"]', 'TestPass123!');
      await page.click('button[type="submit"]');
      
      console.log('⏳ Waiting for dashboard to load...');
      await page.waitForTimeout(12000);
      
      console.log('📍 After login URL:', page.url());
    }
    
    console.log('\n📦 Loaded Scripts:', loadedScripts.length);
    loadedScripts.forEach(f => console.log(`  ${f}`));
    
    const hasMain = loadedScripts.some(f => f.includes('main.min.js'));
    const hasVendor = loadedScripts.some(f => f.includes('vendor.min.js'));
    
    console.log('\n🔍 Webpack Bundles:');
    console.log('==================');
    console.log('main.min.js:', hasMain ? '✅ LOADED' : '❌ NOT LOADED');
    console.log('vendor.min.js:', hasVendor ? '✅ LOADED' : '❌ NOT LOADED');
    
    const bootstrapMsgs = consoleMessages.filter(m => m.includes('Bootstrap'));
    if (bootstrapMsgs.length > 0) {
      console.log('\n🎯 Bootstrap Messages:');
      bootstrapMsgs.forEach(m => console.log(m));
    } else {
      console.log('\n🎯 Bootstrap Messages: None found');
    }
    
    const akenenoMsgs = consoleMessages.filter(m => m.includes('[Akeneo]'));
    if (akenenoMsgs.length > 0) {
      console.log('\n📝 Akeneo Messages:');
      akenenoMsgs.slice(0, 10).forEach(m => console.log(m));
    }
    
    const loadingVisible = await page.evaluate(() => {
      const loading = document.querySelector('.AknDefault-progressContainer');
      return loading ? window.getComputedStyle(loading).display !== 'none' : false;
    });
    
    const hasNav = await page.evaluate(() => {
      return document.querySelector('nav') !== null || 
             document.querySelector('.AknMainMenu') !== null ||
             document.querySelector('[data-test="navigation"]') !== null;
    });
    
    console.log('\n📊 UI Status:');
    console.log('=============');
    console.log('Loading Screen:', loadingVisible ? '❌ VISIBLE' : '✅ HIDDEN');
    console.log('Navigation Menu:', hasNav ? '✅ PRESENT' : '❌ MISSING');
    
    await page.screenshot({ path: '/home/pim/public_html/webapp/test_php_server.png', fullPage: true });
    console.log('\n📸 Screenshot saved to test_php_server.png');
    
  } catch (error) {
    console.error('❌ Error:', error.message);
  } finally {
    await browser.close();
  }
})();
