const { chromium } = require('playwright');

(async () => {
  const browser = await chromium.launch({ headless: true });
  const context = await browser.newContext({ ignoreHTTPSErrors: true });
  const page = await context.newPage();
  
  const consoleMessages = [];
  page.on('console', msg => {
    const type = msg.type();
    if (['error', 'warning'].includes(type)) {
      consoleMessages.push(`[${type}] ${msg.text()}`);
    }
  });
  
  const errors = [];
  page.on('pageerror', error => errors.push(error.toString()));
  
  console.log('=== CHECKING PIM UI STYLES & CONSOLE ERRORS ===\n');
  
  // Login
  await page.goto('https://pim.technostationery.com/user/login', { 
    waitUntil: 'networkidle',
    timeout: 30000 
  });
  
  await page.fill('input[name="_username"]', 'admin');
  await page.fill('input[name="_password"]', 'Admin1234!');
  await page.click('button[type="submit"]');
  
  // Wait for dashboard
  await page.waitForNavigation({ waitUntil: 'networkidle', timeout: 15000 });
  console.log('✓ Logged in successfully\n');
  
  await page.waitForTimeout(3000);
  
  // Check menu elements
  const menuState = await page.evaluate(() => {
    const menu = document.querySelector('.AknHeader, .navigation, nav');
    const menuItems = document.querySelectorAll('.AknHeader .navigation-item, nav a, .menu-item');
    
    return {
      menuExists: !!menu,
      menuClasses: menu ? menu.className : 'none',
      menuItemCount: menuItems.length,
      menuHTML: menu ? menu.outerHTML.substring(0, 500) : 'not found',
      computedStyles: menu ? {
        display: window.getComputedStyle(menu).display,
        position: window.getComputedStyle(menu).position,
        backgroundColor: window.getComputedStyle(menu).backgroundColor,
        zIndex: window.getComputedStyle(menu).zIndex
      } : null
    };
  });
  
  console.log('=== MENU STATE ===');
  console.log('Menu exists:', menuState.menuExists);
  console.log('Menu classes:', menuState.menuClasses);
  console.log('Menu items count:', menuState.menuItemCount);
  console.log('Menu styles:', JSON.stringify(menuState.computedStyles, null, 2));
  
  console.log('\n=== CONSOLE ERRORS & WARNINGS ===');
  if (consoleMessages.length > 0) {
    consoleMessages.forEach((msg, i) => console.log(`${i+1}. ${msg}`));
  } else {
    console.log('No errors or warnings');
  }
  
  console.log('\n=== PAGE ERRORS ===');
  if (errors.length > 0) {
    errors.forEach((err, i) => console.log(`${i+1}. ${err}`));
  } else {
    console.log('No page errors');
  }
  
  // Take screenshot
  await page.screenshot({ path: '/tmp/pim_ui_working.png', fullPage: true });
  console.log('\n✓ Screenshot saved: /tmp/pim_ui_working.png');
  
  await browser.close();
})();
