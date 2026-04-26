const { chromium } = require('playwright');

(async () => {
  const browser = await chromium.launch({ headless: true });
  const context = await browser.newContext({
    ignoreHTTPSErrors: true
  });
  const page = await context.newPage();

  // Capture console logs
  const consoleLogs = [];
  page.on('console', msg => {
    consoleLogs.push(`[${msg.type()}] ${msg.text()}`);
  });

  // Capture errors
  const errors = [];
  page.on('pageerror', err => {
    errors.push(err.toString());
  });

  try {
    console.log('🔐 Testing login and dashboard on OLD BRANCH...\n');
    
    // Navigate to login page
    await page.goto('https://pim.technostationery.com/user/login', { 
      waitUntil: 'networkidle',
      timeout: 15000 
    });
    console.log('✓ Login page loaded');
    
    // Fill in credentials
    await page.fill('input[name="_username"]', 'testadmin');
    await page.fill('input[name="_password"]', 'testpass');
    
    // Click login
    await page.click('button[type="submit"]');
    console.log('✓ Login submitted');
    
    // Wait for navigation
    await page.waitForTimeout(5000);
    
    const currentUrl = page.url();
    const pageTitle = await page.title();
    console.log(`\n📍 Current URL: ${currentUrl}`);
    console.log(`📄 Page Title: ${pageTitle}`);
    
    // Check for loading screen
    const loadingScreen = await page.locator('.loading-mask').isVisible().catch(() => false);
    console.log(`⏳ Loading screen visible: ${loadingScreen}`);
    
    // Check for dashboard menu
    await page.waitForTimeout(8000);
    const menuVisible = await page.locator('#navigation, .AknColumn-navigation, nav').first().isVisible().catch(() => false);
    console.log(`📊 Dashboard menu visible: ${menuVisible}`);
    
    // Check for app container
    const appContainerExists = await page.locator('#app, .app, [data-app]').first().isVisible().catch(() => false);
    console.log(`📦 App container visible: ${appContainerExists}`);
    
    // Take screenshot
    await page.screenshot({ path: '/tmp/oldbranch_fixed_dashboard.png', fullPage: true });
    console.log('\n📸 Screenshot saved to /tmp/oldbranch_fixed_dashboard.png');
    
    // Log console messages
    if (consoleLogs.length > 0) {
      console.log('\n📋 Console logs (last 15):');
      consoleLogs.slice(-15).forEach(log => console.log(`  ${log}`));
    }
    
    // Log errors
    if (errors.length > 0) {
      console.log('\n❌ JavaScript errors:');
      errors.forEach(err => console.log(`  ${err}`));
    }
    
    // Final status
    console.log('\n=== DASHBOARD TEST RESULT ===');
    if (menuVisible && !loadingScreen) {
      console.log('✅ DASHBOARD IS WORKING!');
    } else if (!loadingScreen) {
      console.log('⚠️  Loading screen cleared but dashboard not fully loaded');
    } else {
      console.log('❌ Dashboard still stuck on loading screen');
    }
    
  } catch (error) {
    console.error('❌ Test failed:', error.message);
  } finally {
    await browser.close();
  }
})();
