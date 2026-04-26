const { chromium } = require('playwright');

(async () => {
  const browser = await chromium.launch({ headless: true });
  const page = await browser.newPage();
  
  console.log('=== TESTING LOGIN PAGE STYLES ===\n');
  
  try {
    // Load login page
    console.log('Loading login page...');
    await page.goto('https://pim.technostationery.com/user/login', { 
      waitUntil: 'networkidle',
      timeout: 30000 
    });
    
    // Check if CSS loaded
    const cssResponse = await page.evaluate(() => {
      const link = document.querySelector('link[href*="pim.css"]');
      return {
        exists: !!link,
        href: link ? link.href : null,
        loaded: link ? !link.sheet ? false : true : false
      };
    });
    
    console.log(`CSS Link: ${cssResponse.exists ? '✅' : '❌'}`);
    console.log(`CSS URL: ${cssResponse.href || 'Not found'}`);
    console.log(`CSS Loaded: ${cssResponse.loaded ? '✅' : '❌'}\n`);
    
    // Check for styled elements
    const styledElements = await page.evaluate(() => {
      const loginForm = document.querySelector('form[name="pim_user_security_login"]');
      const usernameInput = document.querySelector('input[name="_username"]');
      const passwordInput = document.querySelector('input[name="_password"]');
      const submitButton = document.querySelector('button[type="submit"]');
      
      const getComputedStyles = (el) => {
        if (!el) return null;
        const computed = window.getComputedStyle(el);
        return {
          display: computed.display,
          backgroundColor: computed.backgroundColor,
          padding: computed.padding,
          margin: computed.margin,
          fontSize: computed.fontSize,
          hasStyles: computed.backgroundColor !== 'rgba(0, 0, 0, 0)' || 
                     computed.padding !== '0px' ||
                     computed.margin !== '0px'
        };
      };
      
      return {
        form: {
          exists: !!loginForm,
          styles: getComputedStyles(loginForm)
        },
        username: {
          exists: !!usernameInput,
          styles: getComputedStyles(usernameInput)
        },
        password: {
          exists: !!passwordInput,
          styles: getComputedStyles(passwordInput)
        },
        button: {
          exists: !!submitButton,
          styles: getComputedStyles(submitButton)
        }
      };
    });
    
    console.log('=== FORM ELEMENTS ===');
    console.log(`Login Form: ${styledElements.form.exists ? '✅' : '❌'}`);
    if (styledElements.form.exists) {
      console.log(`  Has Styles: ${styledElements.form.styles?.hasStyles ? '✅' : '❌'}`);
      console.log(`  Background: ${styledElements.form.styles?.backgroundColor || 'none'}`);
    }
    
    console.log(`Username Input: ${styledElements.username.exists ? '✅' : '❌'}`);
    if (styledElements.username.exists) {
      console.log(`  Has Styles: ${styledElements.username.styles?.hasStyles ? '✅' : '❌'}`);
      console.log(`  Padding: ${styledElements.username.styles?.padding || 'none'}`);
    }
    
    console.log(`Password Input: ${styledElements.password.exists ? '✅' : '❌'}`);
    if (styledElements.password.exists) {
      console.log(`  Has Styles: ${styledElements.password.styles?.hasStyles ? '✅' : '❌'}`);
    }
    
    console.log(`Submit Button: ${styledElements.button.exists ? '✅' : '❌'}`);
    if (styledElements.button.exists) {
      console.log(`  Has Styles: ${styledElements.button.styles?.hasStyles ? '✅' : '❌'}`);
      console.log(`  Background: ${styledElements.button.styles?.backgroundColor || 'none'}`);
    }
    
    // Check for network errors
    console.log('\n=== NETWORK RESOURCES ===');
    const resources = await page.evaluate(() => {
      return performance.getEntriesByType('resource')
        .filter(r => r.name.includes('pim.css') || r.name.includes('.css'))
        .map(r => ({
          url: r.name,
          status: r.responseStatus || 'loaded',
          size: r.transferSize || 0
        }));
    });
    
    resources.forEach(r => {
      console.log(`${r.status === 0 || r.status >= 200 && r.status < 300 ? '✅' : '❌'} ${r.url}`);
      console.log(`   Size: ${(r.size / 1024).toFixed(2)} KB`);
    });
    
    // Take screenshot
    await page.screenshot({ path: '/tmp/akeneo_login_with_styles.png', fullPage: true });
    console.log('\n📸 Screenshot saved to: /tmp/akeneo_login_with_styles.png');
    
    console.log('\n✅ Test completed successfully!');
    
  } catch (error) {
    console.error('\n❌ Test failed:', error.message);
  } finally {
    await browser.close();
  }
})();
