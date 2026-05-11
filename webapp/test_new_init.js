const { chromium } = require('playwright');

(async () => {
  const browser = await chromium.launch({ headless: true });
  const page = await browser.newPage();
  
  const messages = [];
  page.on('console', msg => messages.push(msg.text()));
  
  await page.goto('https://pim.technostationery.com/user/login', { waitUntil: 'networkidle' });
  await page.fill('input[name="_username"]', 'testuser');
  await page.fill('input[name="_password"]', 'TestPass123!');
  await page.click('button[type="submit"]');
  
  // Wait longer for initialization
  await page.waitForTimeout(10000);
  
  console.log('=== CONSOLE MESSAGES ===');
  messages.forEach(msg => console.log(msg));
  
  const status = await page.evaluate(() => {
    return {
      url: window.location.href,
      title: document.title,
      loadingVisible: document.querySelector('.AknDefault-progressContainer') !== null,
      appContent: document.querySelector('.app').innerHTML.length,
      navMenu: document.querySelector('nav') !== null,
      bodyClasses: document.body.className,
    };
  });
  
  console.log('\n=== PAGE STATUS ===');
  console.log(JSON.stringify(status, null, 2));
  
  await page.screenshot({ path: 'test_new_init.png', fullPage: true });
  console.log('\n📸 Screenshot: test_new_init.png');
  
  await browser.close();
})();
