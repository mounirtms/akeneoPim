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
  
  const consoleMessages = [];
  page.on('console', msg => consoleMessages.push(`[${msg.type()}] ${msg.text()}`));
  
  const errors = [];
  page.on('pageerror', error => errors.push(error.message));
  
  console.log('🔍 Testing application initialization...\n');
  
  try {
    // Use domcontentloaded instead of networkidle to avoid timeout
    await page.goto('https://akeneo-pim.vn.co.th', { 
      waitUntil: 'domcontentloaded',
      timeout: 20000 
    });
    
    await page.waitForTimeout(3000);
    
    const currentUrl = page.url();
    console.log('📍 URL:', currentUrl);
    
    if (currentUrl.includes('login')) {
      console.log('🔐 Logging in...');
      await page.fill('input[name="_username"]', 'testuser');
      await page.fill('input[name="_password"]', 'TestPass123!');
      await page.click('button[type="submit"]');
      await page.waitForTimeout(8000); // Wait longer for initialization
    }
    
    // Check for bootstrap messages
    const hasBootstrap = consoleMessages.some(m => m.includes('[Akeneo Bootstrap]'));
    console.log('\n🎯 Bootstrap Execution:', hasBootstrap ? '✅ YES' : '❌ NO');
    
    if (hasBootstrap) {
      console.log('\n📝 Bootstrap Messages:');
      consoleMessages.filter(m => m.includes('[Akeneo Bootstrap]')).forEach(m => console.log(m));
    }
    
    // Check for form builder errors
    const formBuilderErrors = consoleMessages.filter(m => 
      m.toLowerCase().includes('form') || 
      m.toLowerCase().includes('builder') ||
      m.toLowerCase().includes('error')
    );
    
    if (formBuilderErrors.length > 0) {
      console.log('\n⚠️ Form Builder Related Messages:');
      formBuilderErrors.forEach(m => console.log(m));
    }
    
    // Check page errors
    if (errors.length > 0) {
      console.log('\n❌ Page Errors:');
      errors.forEach(e => console.log(e));
    }
    
    // Check loading screen
    const loadingVisible = await page.evaluate(() => {
      const loading = document.querySelector('.AknDefault-progressContainer');
      return loading ? window.getComputedStyle(loading).display !== 'none' : false;
    });
    
    // Check navigation
    const hasNav = await page.evaluate(() => {
      return document.querySelector('nav') !== null || 
             document.querySelector('.AknMainMenu') !== null;
    });
    
    console.log('\n📊 UI Status:');
    console.log('=============');
    console.log('Loading Screen:', loadingVisible ? '❌ VISIBLE' : '✅ HIDDEN');
    console.log('Navigation Menu:', hasNav ? '✅ PRESENT' : '❌ MISSING');
    
    await page.screenshot({ path: '/home/pim/public_html/webapp/simple_test.png', fullPage: true });
    console.log('\n📸 Screenshot saved to simple_test.png');
    
  } catch (error) {
    console.error('❌ Test error:', error.message);
  } finally {
    await browser.close();
  }
})();
