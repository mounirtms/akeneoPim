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
  
  const failed404 = [];
  
  page.on('response', response => {
    if (response.status() === 404) {
      failed404.push(response.url());
    }
  });
  
  const consoleMessages = [];
  page.on('console', msg => consoleMessages.push(`[${msg.type()}] ${msg.text()}`));
  
  try {
    await page.goto('https://akeneo-pim.vn.co.th', { 
      waitUntil: 'domcontentloaded',
      timeout: 20000 
    });
    
    await page.waitForTimeout(2000);
    
    console.log('❌ 404 Errors:');
    console.log('==============');
    if (failed404.length > 0) {
      failed404.forEach(url => console.log(url));
    } else {
      console.log('None');
    }
    
    console.log('\n📝 All Console Messages:');
    console.log('========================');
    consoleMessages.forEach(m => console.log(m));
    
  } catch (error) {
    console.error('Test error:', error.message);
  } finally {
    await browser.close();
  }
})();
