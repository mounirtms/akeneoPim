const { chromium } = require('playwright');

(async () => {
  const browser = await chromium.launch({ headless: true });
  const context = await browser.newContext({ ignoreHTTPSErrors: true });
  const page = await context.newPage();
  
  // Capture all console messages
  const consoleMessages = [];
  page.on('console', msg => {
    consoleMessages.push({
      type: msg.type(),
      text: msg.text()
    });
  });
  
  // Capture errors
  const errors = [];
  page.on('pageerror', error => {
    errors.push(error.toString());
  });
  
  console.log('=== DETAILED UI STATE CHECK ===\n');
  
  // Navigate to login
  await page.goto('https://pim.technostationery.com/user/login', { 
    waitUntil: 'networkidle',
    timeout: 30000 
  });
  
  // Login
  await page.fill('input[name="_username"]', 'admin');
  await page.fill('input[name="_password"]', 'Admin1234!');
  await page.click('button[type="submit"]');
  
  // Wait for dashboard
  await page.waitForURL('**/dashboard', { timeout: 10000 });
  console.log('✓ Dashboard loaded\n');
  
  // Wait for potential rendering
  await page.waitForTimeout(8000);
  
  // Get detailed DOM state
  const domState = await page.evaluate(() => {
    const app = document.querySelector('.app');
    const getElementInfo = (el) => {
      if (!el) return null;
      return {
        tagName: el.tagName,
        className: el.className,
        id: el.id,
        childCount: el.children.length,
        innerHTML: el.innerHTML.substring(0, 500),
        attributes: Array.from(el.attributes).map(a => `${a.name}="${a.value}"`).join(' ')
      };
    };
    
    return {
      app: getElementInfo(app),
      appChildren: app ? Array.from(app.children).map(getElementInfo) : [],
      bodyClasses: document.body.className,
      allScripts: Array.from(document.scripts).map(s => ({
        src: s.src,
        loaded: s.readyState || 'loaded'
      })),
      formBuilder: typeof window.formBuilder,
      pimNamespace: Object.keys(window).filter(k => k.toLowerCase().includes('pim'))
    };
  });
  
  console.log('=== APP ELEMENT ===');
  if (domState.app) {
    console.log('Tag:', domState.app.tagName);
    console.log('Class:', domState.app.className || '(none)');
    console.log('ID:', domState.app.id || '(none)');
    console.log('Children:', domState.app.childCount);
    console.log('Attributes:', domState.app.attributes);
    console.log('\nFirst child info:');
    if (domState.appChildren[0]) {
      console.log('  Tag:', domState.appChildren[0].tagName);
      console.log('  Class:', domState.appChildren[0].className || '(none)');
      console.log('  Children:', domState.appChildren[0].childCount);
      console.log('  HTML preview:', domState.appChildren[0].innerHTML.substring(0, 200));
    }
  }
  
  console.log('\n=== WINDOW OBJECTS ===');
  console.log('PIM-related keys:', domState.pimNamespace.join(', ') || '(none)');
  console.log('formBuilder type:', domState.formBuilder);
  
  console.log('\n=== CONSOLE MESSAGES (', consoleMessages.length, ') ===');
  consoleMessages.slice(0, 20).forEach((msg, i) => {
    console.log(`${i+1}. [${msg.type}] ${msg.text}`);
  });
  
  console.log('\n=== PAGE ERRORS (', errors.length, ') ===');
  errors.forEach((err, i) => {
    console.log(`${i+1}. ${err}`);
  });
  
  // Check if form is actually building
  const isBuilding = await page.evaluate(() => {
    const app = document.querySelector('.app');
    return {
      hasData: !!app?.dataset,
      dataAttributes: app ? Object.keys(app.dataset) : [],
      computedStyle: app ? window.getComputedStyle(app).display : null
    };
  });
  
  console.log('\n=== APP DATA ATTRIBUTES ===');
  console.log('Has dataset:', isBuilding.hasData);
  console.log('Data attributes:', isBuilding.dataAttributes.join(', ') || '(none)');
  console.log('Display style:', isBuilding.computedStyle);
  
  await browser.close();
})();
