const { chromium } = require('playwright');

(async () => {
  const browser = await chromium.launch({ 
    headless: true,
    args: ['--no-sandbox', '--disable-setuid-sandbox']
  });
  
  const context = await browser.newContext();
  const page = await context.newPage();
  
  const consoleMessages = [];
  page.on('console', msg => consoleMessages.push(`[${msg.type()}] ${msg.text()}`));
  
  const errors = [];
  page.on('pageerror', error => errors.push(error.message));
  
  try {
    console.log('🔍 Testing manual initialization approach...\n');
    
    await page.goto('http://127.0.0.1:8081', { 
      waitUntil: 'domcontentloaded',
      timeout: 20000 
    });
    
    await page.waitForTimeout(2000);
    
    if (page.url().includes('login')) {
      console.log('🔐 Logging in...');
      await page.fill('input[name="_username"]', 'testuser');
      await page.fill('input[name="_password"]', 'TestPass123!');
      await page.click('button[type="submit"]');
      console.log('⏳ Waiting for initialization...');
      await page.waitForTimeout(15000);
    }
    
    // Check for initialization messages
    const initMsgs = consoleMessages.filter(m => 
      m.includes('[Akeneo]') || 
      m.includes('Form built') ||
      m.includes('initialized')
    );
    
    console.log('📝 Initialization Messages:');
    if (initMsgs.length > 0) {
      initMsgs.forEach(m => console.log(m));
    } else {
      console.log('❌ No initialization messages found');
    }
    
    // Check for errors
    if (errors.length > 0) {
      console.log('\n❌ JavaScript Errors:');
      errors.slice(0, 5).forEach(e => console.log(e));
    }
    
    // Check UI state
    const loadingVisible = await page.evaluate(() => {
      const loading = document.querySelector('.AknDefault-progressContainer');
      return loading ? window.getComputedStyle(loading).display !== 'none' : false;
    });
    
    const hasNav = await page.evaluate(() => {
      return document.querySelector('nav') !== null || 
             document.querySelector('.AknMainMenu') !== null ||
             document.querySelector('[class*="Navigation"]') !== null;
    });
    
    const appContent = await page.evaluate(() => {
      const app = document.querySelector('.app');
      return app ? app.innerHTML.length : 0;
    });
    
    console.log('\n📊 Final Status:');
    console.log('===============');
    console.log('Loading Screen:', loadingVisible ? '❌ VISIBLE' : '✅ HIDDEN');
    console.log('Navigation Menu:', hasNav ? '✅ PRESENT' : '❌ MISSING');
    console.log('App Content Length:', appContent, 'characters');
    
    await page.screenshot({ path: '/home/pim/public_html/webapp/test_manual_init.png', fullPage: true });
    console.log('\n📸 Screenshot saved to test_manual_init.png');
    
  } catch (error) {
    console.error('❌ Test error:', error.message);
  } finally {
    await browser.close();
  }
})();
