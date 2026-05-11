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
    console.log('🔍 Testing with full console output...\n');
    
    await page.goto('http://127.0.0.1:8081', { 
      waitUntil: 'domcontentloaded',
      timeout: 20000 
    });
    
    await page.waitForTimeout(2000);
    
    if (page.url().includes('login')) {
      await page.fill('input[name="_username"]', 'testuser');
      await page.fill('input[name="_password"]', 'TestPass123!');
      await page.click('button[type="submit"]');
      await page.waitForTimeout(12000);
    }
    
    console.log('📝 All Console Messages:');
    console.log('========================');
    consoleMessages.forEach(m => console.log(m));
    
    if (errors.length > 0) {
      console.log('\n❌ Page Errors:');
      console.log('===============');
      errors.forEach(e => console.log(e));
    }
    
    const loadingVisible = await page.evaluate(() => {
      const loading = document.querySelector('.AknDefault-progressContainer');
      return loading ? window.getComputedStyle(loading).display !== 'none' : false;
    });
    
    const hasNav = await page.evaluate(() => {
      return document.querySelector('nav') !== null || 
             document.querySelector('.AknMainMenu') !== null;
    });
    
    console.log('\n📊 Final Status:');
    console.log('================');
    console.log('Loading Screen:', loadingVisible ? '❌ VISIBLE' : '✅ HIDDEN');
    console.log('Navigation Menu:', hasNav ? '✅ PRESENT' : '❌ MISSING');
    
  } catch (error) {
    console.error('❌ Error:', error.message);
  } finally {
    await browser.close();
  }
})();
