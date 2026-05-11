const { chromium } = require('playwright');

(async () => {
  const browser = await chromium.launch({ 
    headless: true,
    args: ['--no-sandbox', '--disable-setuid-sandbox', '--ignore-certificate-errors']
  });
  
  const context = await browser.newContext({
    ignoreHTTPSErrors: true
  });
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
    console.log('🔍 Testing direct access to index.php...\n');
    
    // Try accessing index.php directly
    await page.goto('https://akeneo-pim.vn.co.th/index.php', { 
      waitUntil: 'domcontentloaded',
      timeout: 20000 
    });
    
    await page.waitForTimeout(3000);
    
    const currentUrl = page.url();
    console.log('📍 Current URL:', currentUrl);
    
    if (currentUrl.includes('login')) {
      console.log('🔐 Found login page! Logging in...');
      await page.fill('input[name="_username"]', 'testuser');
      await page.fill('input[name="_password"]', 'TestPass123!');
      await page.click('button[type="submit"]');
      
      console.log('⏳ Waiting for dashboard...');
      await page.waitForTimeout(10000);
      
      console.log('📍 After login URL:', page.url());
    }
    
    console.log('\n📦 Loaded Scripts:', loadedScripts.length);
    if (loadedScripts.length > 0) {
      loadedScripts.forEach(f => console.log(`  ${f}`));
    }
    
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
    }
    
    const loadingVisible = await page.evaluate(() => {
      const loading = document.querySelector('.AknDefault-progressContainer');
      return loading ? window.getComputedStyle(loading).display !== 'none' : false;
    });
    
    const hasNav = await page.evaluate(() => {
      return document.querySelector('nav') !== null || 
             document.querySelector('.AknMainMenu') !== null;
    });
    
    console.log('\n📊 UI Status:');
    console.log('=============');
    console.log('Loading Screen:', loadingVisible ? '❌ VISIBLE' : '✅ HIDDEN');
    console.log('Navigation Menu:', hasNav ? '✅ PRESENT' : '❌ MISSING');
    
    await page.screenshot({ path: '/home/pim/public_html/webapp/test_direct_access.png', fullPage: true });
    console.log('\n📸 Screenshot saved');
    
  } catch (error) {
    console.error('❌ Error:', error.message);
  } finally {
    await browser.close();
  }
})();
