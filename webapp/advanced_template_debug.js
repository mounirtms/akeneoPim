const playwright = require('playwright');

(async () => {
  console.log('🔍 ADVANCED TEMPLATE COMPILATION DEBUG');
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
    
    // Track template compilation attempts
    const templateIssues = [];
    
    page.on('console', async msg => {
      const text = msg.text();
      if (text.includes('template') || text.includes('Template') || text.includes('replace')) {
        templateIssues.push(text);
      }
    });
    
    console.log('📍 Navigating to login...');
    await page.goto('https://pim.technostationery.com/user/login', { waitUntil: 'networkidle', timeout: 60000 });
    
    console.log('📍 Logging in...');
    await page.fill('input[name="_username"]', 'admin');
    await page.fill('input[name="_password"]', 'admin');
    await page.click('button[type="submit"]');
    
    console.log('📍 Waiting for dashboard (20 seconds)...');
    await page.waitForTimeout(20000);
    
    console.log('\n📊 Checking module loading in window context:');
    const moduleCheck = await page.evaluate(() => {
      return {
        requirejsExists: typeof window.requirejs !== 'undefined',
        defineExists: typeof window.define !== 'undefined',
        requireExists: typeof window.require !== 'undefined',
        jqueryExists: typeof window.jQuery !== 'undefined',
        underscoreExists: typeof window._ !== 'undefined',
        backboneExists: typeof window.Backbone !== 'undefined'
      };
    });
    console.log('Window context:', JSON.stringify(moduleCheck, null, 2));
    
    if (moduleCheck.requirejsExists) {
      console.log('\n📊 Checking RequireJS modules:');
      const reqCheck = await page.evaluate(() => {
        return new Promise((resolve) => {
          try {
            window.require(['pim/template/app', 'underscore', 'pim/app'], 
              function(template, _, PimApp) {
                resolve({
                  success: true,
                  templateType: typeof template,
                  templateIsString: typeof template === 'string',
                  templateLength: template ? template.length : 0,
                  templatePreview: template ? template.substring(0, 100) : '',
                  underscoreExists: typeof _ !== 'undefined',
                  underscoreTemplateType: typeof _.template,
                  pimAppType: typeof PimApp
                });
              },
              function(err) {
                resolve({
                  success: false,
                  error: err.toString()
                });
              }
            );
          } catch(e) {
            resolve({ success: false, error: e.message });
          }
        });
      });
      console.log('RequireJS modules check:', JSON.stringify(reqCheck, null, 2));
      
      if (reqCheck.success && reqCheck.templateIsString) {
        console.log('\n📊 Testing template compilation:');
        const compileTest = await page.evaluate(() => {
          return new Promise((resolve) => {
            window.require(['pim/template/app', 'underscore'], 
              function(template, _) {
                try {
                  console.log('[DEBUG] Template value:', template);
                  console.log('[DEBUG] Template type:', typeof template);
                  console.log('[DEBUG] Underscore type:', typeof _);
                  console.log('[DEBUG] _.template type:', typeof _.template);
                  
                  const compiled = _.template(template);
                  const rendered = compiled({});
                  
                  resolve({
                    success: true,
                    compiledType: typeof compiled,
                    renderedType: typeof rendered,
                    renderedLength: rendered.length,
                    renderedPreview: rendered.substring(0, 200)
                  });
                } catch(e) {
                  resolve({
                    success: false,
                    error: e.message,
                    stack: e.stack,
                    templateActualType: typeof template
                  });
                }
              }
            );
          });
        });
        console.log('Template compilation test:', JSON.stringify(compileTest, null, 2));
      }
    }
    
    console.log('\n📋 Template-related console messages:');
    templateIssues.forEach(msg => console.log('  -', msg));
    
  } catch (error) {
    console.error('Test error:', error.message);
  } finally {
    await browser.close();
  }
})();
