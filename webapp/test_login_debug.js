const { chromium } = require('playwright');

(async () => {
  console.log('Testing login and redirect...\n');
  
  const browser = await chromium.launch({ headless: true });
  const context = await browser.newContext({
    ignoreHTTPSErrors: true
  });
  const page = await context.newPage();

  // Collect console messages
  page.on('console', msg => {
    console.log(`  [${msg.type()}] ${msg.text()}`);
  });

  // Collect errors
  page.on('pageerror', error => {
    console.log(`  ❌ Error: ${error.message}`);
  });

  try {
    console.log('Step 1: Going to login page...');
    await page.goto('https://pim.technostationery.com/user/login', { 
      waitUntil: 'domcontentloaded',
      timeout: 30000 
    });
    
    console.log(`  Current URL: ${page.url()}`);
    await page.screenshot({ path: '/home/pim/public_html/webapp/test_login_page.png' });
    
    console.log('\nStep 2: Filling in credentials...');
    await page.fill('input[name="_username"]', 'mounir');
    await page.fill('input[name="_password"]', 'Mounirbh84@');
    
    console.log('\nStep 3: Submitting form...');
    
    // Listen for navigation
    const navigationPromise = page.waitForNavigation({ timeout: 30000 }).catch(e => {
      console.log(`  Navigation timeout: ${e.message}`);
      return null;
    });
    
    await page.click('button[type="submit"]');
    await navigationPromise;
    
    console.log(`\nStep 4: After form submission`);
    console.log(`  Current URL: ${page.url()}`);
    console.log(`  Title: ${await page.title()}`);
    
    // Check if still on login page (error scenario)
    if (page.url().includes('/user/login')) {
      console.log('\n  ⚠️  Still on login page - checking for error messages...');
      const pageContent = await page.content();
      if (pageContent.includes('Invalid credentials') || pageContent.includes('Bad credentials')) {
        console.log('  ❌ Invalid credentials error detected');
      } else {
        console.log('  No error message found, might be other issue');
      }
    } else {
      console.log('  ✅ Redirected away from login page');
    }
    
    await page.screenshot({ path: '/home/pim/public_html/webapp/test_after_login.png' });
    
    // Wait a bit and check state
    await page.waitForTimeout(3000);
    
    const state = await page.evaluate(() => ({
      url: window.location.href,
      title: document.title,
      bodyText: document.body.innerText.substring(0, 500)
    }));
    
    console.log(`\n=== FINAL STATE ===`);
    console.log(`  URL: ${state.url}`);
    console.log(`  Title: ${state.title}`);
    console.log(`  Body preview: ${state.bodyText.substring(0, 200)}...`);

  } catch (error) {
    console.error(`\n❌ Test failed: ${error.message}`);
  } finally {
    await browser.close();
  }
})();
