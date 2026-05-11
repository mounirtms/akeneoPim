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
  
  // Collect all console messages
  const consoleMessages = [];
  page.on('console', msg => {
    consoleMessages.push({
      type: msg.type(),
      text: msg.text()
    });
  });
  
  // Collect errors
  const errors = [];
  page.on('pageerror', error => {
    errors.push(error.message);
  });
  
  console.log('🔍 Testing bootstrap entry point...');
  
  try {
    await page.goto('https://akeneo-pim.vn.co.th', { 
      waitUntil: 'networkidle',
      timeout: 30000 
    });
    
    // Wait a bit for login redirect or dashboard
    await page.waitForTimeout(2000);
    
    const currentUrl = page.url();
    console.log('📍 Current URL:', currentUrl);
    
    if (currentUrl.includes('login')) {
      console.log('🔐 Logging in...');
      await page.fill('input[name="_username"]', 'testuser');
      await page.fill('input[name="_password"]', 'TestPass123!');
      await page.click('button[type="submit"]');
      
      await page.waitForTimeout(5000);
    }
    
    console.log('\n📊 All Console Messages:');
    console.log('========================');
    consoleMessages.forEach(msg => {
      console.log(`[${msg.type}] ${msg.text}`);
    });
    
    console.log('\n❌ All Errors:');
    console.log('==============');
    if (errors.length > 0) {
      errors.forEach(err => console.log(err));
    } else {
      console.log('No errors detected');
    }
    
    // Check if bootstrap messages appear
    const bootstrapMessages = consoleMessages.filter(m => 
      m.text.includes('[Akeneo Bootstrap]')
    );
    
    console.log('\n🎯 Bootstrap Messages:');
    console.log('=====================');
    if (bootstrapMessages.length > 0) {
      bootstrapMessages.forEach(msg => {
        console.log(`[${msg.type}] ${msg.text}`);
      });
    } else {
      console.log('❌ No bootstrap messages found - entry point not executing');
    }
    
    // Check module loading
    const moduleErrors = consoleMessages.filter(m => 
      m.text.includes('Module name') || 
      m.text.includes('has not been loaded') ||
      m.text.toLowerCase().includes('error')
    );
    
    if (moduleErrors.length > 0) {
      console.log('\n⚠️ Module Loading Issues:');
      console.log('=========================');
      moduleErrors.forEach(msg => {
        console.log(`[${msg.type}] ${msg.text}`);
      });
    }
    
    await page.screenshot({ path: '/home/pim/public_html/webapp/test_bootstrap_detailed.png', fullPage: true });
    
  } catch (error) {
    console.error('Test error:', error.message);
  } finally {
    await browser.close();
  }
})();
