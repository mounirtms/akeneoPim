const { chromium } = require('playwright');

(async () => {
  const browser = await chromium.launch({ headless: true });
  const context = await browser.newContext({
    ignoreHTTPSErrors: true
  });
  const page = await context.newPage();

  // Capture ALL console logs
  const consoleLogs = [];
  page.on('console', msg => {
    const type = msg.type();
    const text = msg.text();
    consoleLogs.push(`[${type.toUpperCase()}] ${text}`);
  });

  // Capture errors
  const errors = [];
  page.on('pageerror', err => {
    errors.push(`PAGE ERROR: ${err.toString()}`);
  });

  // Capture network failures
  page.on('requestfailed', request => {
    consoleLogs.push(`[NETWORK FAILED] ${request.url()}`);
  });

  try {
    console.log('🔍 Capturing console logs after login...\n');
    
    // Navigate to login page
    await page.goto('https://pim.technostationery.com/user/login', { 
      waitUntil: 'networkidle',
      timeout: 15000 
    });
    
    // Fill in credentials
    await page.fill('input[name="_username"]', 'testadmin');
    await page.fill('input[name="_password"]', 'testpass');
    
    // Click login
    await page.click('button[type="submit"]');
    
    // Wait for page to load
    await page.waitForTimeout(10000);
    
    console.log('=== CONSOLE LOGS (ALL) ===\n');
    consoleLogs.forEach(log => console.log(log));
    
    if (errors.length > 0) {
      console.log('\n=== PAGE ERRORS ===\n');
      errors.forEach(err => console.log(err));
    }
    
    // Check page state
    console.log('\n=== PAGE STATE ===');
    const currentUrl = page.url();
    const pageTitle = await page.title();
    console.log(`URL: ${currentUrl}`);
    console.log(`Title: ${pageTitle}`);
    
    // Check what scripts loaded
    const scripts = await page.$$eval('script[src]', scripts => 
      scripts.map(s => s.getAttribute('src'))
    );
    console.log(`\nLoaded scripts (${scripts.length}):`);
    scripts.slice(0, 15).forEach(src => console.log(`  - ${src}`));
    
  } catch (error) {
    console.error('❌ Test failed:', error.message);
  } finally {
    await browser.close();
  }
})();
