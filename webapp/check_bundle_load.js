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
      loadedScripts.push(response.url());
    }
  });
  
  const consoleMessages = [];
  page.on('console', msg => consoleMessages.push(`[${msg.type()}] ${msg.text()}`));
  
  try {
    await page.goto('https://akeneo-pim.vn.co.th', { 
      waitUntil: 'domcontentloaded',
      timeout: 20000 
    });
    
    await page.waitForTimeout(3000);
    
    console.log('📦 Loaded JavaScript Files:');
    console.log('===========================');
    loadedScripts.forEach(url => {
      const filename = url.split('/').pop().split('?')[0];
      console.log(`  ${filename}`);
    });
    
    const hasMain = loadedScripts.some(url => url.includes('main.min.js'));
    const hasVendor = loadedScripts.some(url => url.includes('vendor.min.js'));
    
    console.log('\n🔍 Bundle Status:');
    console.log('================');
    console.log('main.min.js:', hasMain ? '✅ LOADED' : '❌ NOT LOADED');
    console.log('vendor.min.js:', hasVendor ? '✅ LOADED' : '❌ NOT LOADED');
    
    console.log('\n📝 Key Console Messages:');
    console.log('========================');
    const keyMessages = consoleMessages.filter(m => 
      m.includes('[Akeneo]') || 
      m.includes('Bootstrap') ||
      m.includes('webpack') ||
      m.toLowerCase().includes('error')
    );
    keyMessages.forEach(m => console.log(m));
    
    if (keyMessages.length === 0) {
      console.log('No key messages found');
    }
    
  } catch (error) {
    console.error('Test error:', error.message);
  } finally {
    await browser.close();
  }
})();
