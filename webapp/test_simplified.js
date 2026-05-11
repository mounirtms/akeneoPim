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
    console.log('🔍 Testing simplified template...\n');
    
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
      await page.waitForTimeout(12000);
    }
    
    console.log('📝 Bootstrap Messages:');
    const bootstrapMsgs = consoleMessages.filter(m => m.includes('Bootstrap'));
    if (bootstrapMsgs.length > 0) {
      bootstrapMsgs.forEach(m => console.log(m));
    } else {
      console.log('❌ No bootstrap messages found');
    }
    
    console.log('\n📝 CSP Errors:');
    const cspErrors = consoleMessages.filter(m => m.includes('Content Security Policy'));
    if (cspErrors.length > 0) {
      console.log(`Found ${cspErrors.length} CSP errors (showing first 3):`);
      cspErrors.slice(0, 3).forEach(m => console.log(m));
    } else {
      console.log('✅ No CSP errors');
    }
    
    console.log('\n❌ JavaScript Errors:');
    if (errors.length > 0) {
      console.log(`Found ${errors.length} errors (showing first 5):`);
      errors.slice(0, 5).forEach(e => console.log(e));
    } else {
      console.log('✅ No JavaScript errors');
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
    
    await page.screenshot({ path: '/home/pim/public_html/webapp/test_simplified.png', fullPage: true });
    console.log('\n📸 Screenshot saved');
    
  } catch (error) {
    console.error('❌ Test error:', error.message);
  } finally {
    await browser.close();
  }
})();
