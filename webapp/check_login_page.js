const playwright = require('playwright');

(async () => {
  console.log('🔍 Checking Login Page State');
  console.log('='.repeat(60));
  
  const browser = await playwright.chromium.launch({
    headless: true,
    args: ['--no-sandbox', '--disable-setuid-sandbox']
  });
  
  try {
    const context = await browser.newContext({
      ignoreHTTPSErrors: true,
      viewport: { width: 1920, height: 1080 }
    });
    
    const page = await context.newPage();
    
    // Capture console messages
    page.on('console', msg => {
      const type = msg.type();
      if (type === 'error' || type === 'warning') {
        console.log(`[Browser] [${type}] ${msg.text()}`);
      }
    });
    
    console.log('📍 Navigating to login page...');
    await page.goto('https://pim.technostationery.com/user/login', {
      waitUntil: 'networkidle',
      timeout: 30000
    });
    
    console.log('✓ Page loaded');
    
    // Take screenshot
    await page.screenshot({ path: 'login-page-state.png', fullPage: true });
    console.log('✓ Screenshot saved: login-page-state.png');
    
    // Analyze page content
    const pageInfo = await page.evaluate(() => {
      return {
        title: document.title,
        url: window.location.href,
        bodyText: document.body.innerText.substring(0, 500),
        hasUsernameField: !!document.querySelector('#_username'),
        hasPasswordField: !!document.querySelector('#_password'),
        hasLoginForm: !!document.querySelector('form'),
        allInputs: Array.from(document.querySelectorAll('input')).map(inp => ({
          id: inp.id,
          name: inp.name,
          type: inp.type
        })),
        bodyHTML: document.body.innerHTML.substring(0, 1000)
      };
    });
    
    console.log('\n📊 Page Analysis:');
    console.log('  Title:', pageInfo.title);
    console.log('  URL:', pageInfo.url);
    console.log('  Has Username Field:', pageInfo.hasUsernameField);
    console.log('  Has Password Field:', pageInfo.hasPasswordField);
    console.log('  Has Login Form:', pageInfo.hasLoginForm);
    console.log('\n📝 All Input Fields:', JSON.stringify(pageInfo.allInputs, null, 2));
    console.log('\n📄 Body Text (first 500 chars):', pageInfo.bodyText);
    console.log('\n🔍 Body HTML (first 1000 chars):', pageInfo.bodyHTML);
    
  } catch (error) {
    console.error('❌ Error:', error.message);
  } finally {
    await browser.close();
    console.log('\n✓ Browser closed');
  }
})();
