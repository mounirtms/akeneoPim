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
    await page.goto('http://127.0.0.1:8081', { 
      waitUntil: 'domcontentloaded',
      timeout: 20000 
    });
    
    await page.waitForTimeout(2000);
    
    if (page.url().includes('login')) {
      await page.fill('input[name="_username"]', 'testuser');
      await page.fill('input[name="_password"]', 'TestPass123!');
      await page.click('button[type="submit"]');
      await page.waitForTimeout(15000);
    }
    
    console.log('ALL CONSOLE MESSAGES:');
    console.log('=====================');
    consoleMessages.forEach((m, i) => console.log(`${i+1}. ${m}`));
    
    if (errors.length > 0) {
      console.log('\nALL ERRORS:');
      console.log('===========');
      errors.forEach((e, i) => console.log(`${i+1}. ${e}`));
    }
    
  } catch (error) {
    console.error('Test error:', error.message);
  } finally {
    await browser.close();
  }
})();
