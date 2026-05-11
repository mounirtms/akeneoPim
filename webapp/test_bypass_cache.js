const { chromium } = require('playwright');

(async () => {
  const browser = await chromium.launch({ headless: true });
  const context = await browser.newContext({
    extraHTTPHeaders: {
      'Cache-Control': 'no-cache, no-store, must-revalidate',
      'Pragma': 'no-cache',
      'Expires': '0'
    }
  });
  const page = await context.newPage();
  
  const messages = [];
  page.on('console', msg => messages.push(msg.text()));
  
  // Add cache-busting query parameter
  const timestamp = Date.now();
  await page.goto(`https://pim.technostationery.com/user/login?nocache=${timestamp}`, { 
    waitUntil: 'networkidle' 
  });
  
  await page.fill('input[name="_username"]', 'testuser');
  await page.fill('input[name="_password"]', 'TestPass123!');
  await page.click('button[type="submit"]');
  
  await page.waitForTimeout(10000);
  
  console.log('=== CONSOLE MESSAGES ===');
  messages.forEach(msg => console.log(msg));
  
  const status = await page.evaluate(() => {
    return {
      url: window.location.href,
      title: document.title,
      loadingVisible: document.querySelector('.AknDefault-progressContainer') !== null,
      navMenu: document.querySelector('nav') !== null,
    };
  });
  
  console.log('\n=== PAGE STATUS ===');
  console.log(JSON.stringify(status, null, 2));
  
  await browser.close();
})();
