const playwright = require('playwright');

(async () => {
  console.log('🔍 TEMPLATE COMPILATION DEBUG TEST');
  console.log('='.repeat(70));
  
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
    
    // Capture all console messages with full detail
    page.on('console', async msg => {
      const type = msg.type();
      const text = msg.text();
      console.log(`[${type}] ${text}`);
    });
    
    console.log('📍 Navigating to login...');
    await page.goto('https://pim.technostationery.com/user/login', { waitUntil: 'networkidle', timeout: 60000 });
    
    console.log('📍 Logging in...');
    await page.fill('input[name="_username"]', 'admin');
    await page.fill('input[name="_password"]', 'admin');
    await page.click('button[type="submit"]');
    
    console.log('📍 Waiting for dashboard...');
    await page.waitForTimeout(15000);
    
    console.log('\n📊 Checking template module:');
    const templateCheck = await page.evaluate(() => {
      try {
        const template = requirejs('pim/template/app');
        return {
          exists: true,
          type: typeof template,
          isString: typeof template === 'string',
          length: typeof template === 'string' ? template.length : 0,
          firstChars: typeof template === 'string' ? template.substring(0, 50) : '',
          isFunction: typeof template === 'function'
        };
      } catch(e) {
        return { exists: false, error: e.message };
      }
    });
    console.log('Template module:', JSON.stringify(templateCheck, null, 2));
    
    console.log('\n📊 Checking underscore template:');
    const underscoreCheck = await page.evaluate(() => {
      try {
        const _ = requirejs('underscore');
        const testStr = '<div>test</div>';
        const compiled = _.template(testStr);
        return {
          underscoreExists: typeof _ !== 'undefined',
          templateFunction: typeof _.template,
          compiledType: typeof compiled,
          testCompile: 'success'
        };
      } catch(e) {
        return { error: e.message, stack: e.stack };
      }
    });
    console.log('Underscore check:', JSON.stringify(underscoreCheck, null, 2));
    
    console.log('\n📊 Testing actual template compilation:');
    const compilationTest = await page.evaluate(() => {
      try {
        const _ = requirejs('underscore');
        const template = requirejs('pim/template/app');
        console.log('Template type before compile:', typeof template);
        console.log('Template value:', template);
        const compiled = _.template(template);
        return {
          success: true,
          compiledType: typeof compiled
        };
      } catch(e) {
        return { 
          success: false, 
          error: e.message, 
          stack: e.stack,
          templateType: typeof template
        };
      }
    });
    console.log('Compilation test:', JSON.stringify(compilationTest, null, 2));
    
  } catch (error) {
    console.error('Test error:', error.message);
  } finally {
    await browser.close();
  }
})();
