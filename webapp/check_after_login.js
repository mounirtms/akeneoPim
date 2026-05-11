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
    console.log('🔍 Testing after login...\n');
    
    await page.goto('https://akeneo-pim.vn.co.th', { 
      waitUntil: 'domcontentloaded',
      timeout: 20000 
    });
    
    await page.waitForTimeout(2000);
    
    const currentUrl = page.url();
    console.log('📍 Initial URL:', currentUrl);
    
    if (currentUrl.includes('login')) {
      console.log('🔐 Logging in...');
      await page.fill('input[name="_username"]', 'testuser');
      await page.fill('input[name="_password"]', 'TestPass123!');
      await page.click('button[type="submit"]');
      
      console.log('⏳ Waiting for dashboard to load...');
      await page.waitForTimeout(10000); // Wait 10 seconds for full load
      
      const afterLoginUrl = page.url();
      console.log('📍 After login URL:', afterLoginUrl);
    }
    
    console.log('\n📦 Loaded JavaScript Files:');
    console.log('===========================');
    loadedScripts.forEach(file => console.log(`  ${file}`));
    
    const hasMain = loadedScripts.some(f => f.includes('main.min.js'));
    const hasVendor = loadedScripts.some(f => f.includes('vendor.min.js'));
    
    console.log('\n🔍 Webpack Bundle Status:');
    console.log('=========================');
    console.log('main.min.js:', hasMain ? '✅ LOADED' : '❌ NOT LOADED');
    console.log('vendor.min.js:', hasVendor ? '✅ LOADED' : '❌ NOT LOADED');
    
    console.log('\n📝 Console Messages (filtered):');
    console.log('================================');
    const filtered = consoleMessages.filter(m => 
      m.includes('[Akeneo]') || 
      m.includes('Bootstrap') ||
      m.toLowerCase().includes('webpack')
    );
    
    if (filtered.length > 0) {
      filtered.forEach(m => console.log(m));
    } else {
      console.log('No Akeneo/Bootstrap/webpack messages found');
    }
    
    // Check UI state
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
    
    await page.screenshot({ path: '/home/pim/public_html/webapp/check_after_login.png', fullPage: true });
    console.log('\n📸 Screenshot saved');
    
  } catch (error) {
    console.error('❌ Test error:', error.message);
  } finally {
    await browser.close();
  }
})();
