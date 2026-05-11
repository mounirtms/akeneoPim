const playwright = require('playwright');

(async () => {
  console.log('🎯 FINAL VERIFICATION TEST');
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
    
    // Track console for specific errors
    const errors = [];
    const criticalLogs = [];
    
    page.on('console', msg => {
      const text = msg.text();
      const type = msg.type();
      
      if (type === 'error' && !text.includes('css/pim.css')) {
        errors.push(text);
      }
      
      if (text.includes('[pim/app]') || 
          text.includes('[require-context]') || 
          text.includes('[Akeneo]') ||
          text.includes('pim-app')) {
        criticalLogs.push(`[${type}] ${text}`);
      }
    });
    
    console.log('📍 Logging in...');
    await page.goto('https://pim.technostationery.com/user/login', {
      waitUntil: 'networkidle',
      timeout: 30000
    });
    
    await page.fill('#username_input', 'testuser');
    await page.fill('#password_input', 'TestPass123!');
    await page.click('button[type="submit"]');
    
    console.log('📍 Waiting for initialization (60 seconds)...');
    await page.waitForTimeout(60000);
    
    // Check final state
    const finalState = await page.evaluate(() => {
      return {
        title: document.title,
        url: window.location.href,
        hasMenu: !!document.querySelector('[data-drop-zone="menu"]'),
        hasMenuContent: document.querySelector('[data-drop-zone="menu"]')?.innerHTML || '',
        hasPage: !!document.querySelector('#page'),
        hasContainer: !!document.querySelector('#container'),
        hasProgressContainer: !!document.querySelector('.AknDefault-progressContainer'),
        appHTML: document.querySelector('.app')?.innerHTML.substring(0, 1000) || 'N/A',
        requirejsModules: typeof requirejs !== 'undefined' && requirejs.s?.contexts?._?.defined ? 
          Object.keys(requirejs.s.contexts._.defined).length : 0,
        pimAppDefined: typeof requirejs !== 'undefined' && requirejs.s?.contexts?._?.defined?.['pim/app'] ? 
          'YES' : 'NO'
      };
    });
    
    await page.screenshot({ path: 'final_verification.png', fullPage: true });
    
    console.log('\n' + '='.repeat(70));
    console.log('📊 FINAL TEST RESULTS');
    console.log('='.repeat(70));
    
    console.log(`\nPage Title: ${finalState.title}`);
    console.log(`URL: ${finalState.url}`);
    console.log(`\nUI Elements:`);
    console.log(`  #page: ${finalState.hasPage ? '✅' : '❌'}`);
    console.log(`  #container: ${finalState.hasContainer ? '✅' : '❌'}`);
    console.log(`  Menu zone: ${finalState.hasMenu ? '✅' : '❌'}`);
    console.log(`  Progress container (should be NO): ${finalState.hasProgressContainer ? '❌ STUCK' : '✅'}`);
    
    console.log(`\nRequireJS Status:`);
    console.log(`  Total modules: ${finalState.requirejsModules}`);
    console.log(`  pim/app defined: ${finalState.pimAppDefined}`);
    
    console.log(`\n📋 Critical Console Logs:`);
    criticalLogs.forEach(log => console.log(`  ${log}`));
    
    console.log(`\n🐛 Errors (${errors.length} total):`);
    if (errors.length > 0) {
      errors.slice(0, 3).forEach(err => {
        console.log(`  ${err.substring(0, 150)}...`);
      });
    } else {
      console.log('  ✅ No errors!');
    }
    
    // Calculate success
    const metrics = {
      login: !finalState.url.includes('/user/login'),
      page: finalState.hasPage,
      container: finalState.hasContainer,
      menu: finalState.hasMenu,
      notStuck: !finalState.hasProgressContainer,
      modulesLoaded: finalState.requirejsModules > 35,
      pimAppLoaded: finalState.pimAppDefined === 'YES'
    };
    
    const successCount = Object.values(metrics).filter(v => v).length;
    const totalCount = Object.keys(metrics).length;
    const successRate = Math.round((successCount / totalCount) * 100);
    
    console.log('\n' + '='.repeat(70));
    console.log(`🎯 SUCCESS RATE: ${successRate}% (${successCount}/${totalCount} metrics passing)`);
    console.log('='.repeat(70));
    
    if (finalState.hasMenu && finalState.hasPage) {
      console.log('\n🎉 SUCCESS! Dashboard loaded successfully!');
    } else if (!finalState.hasProgressContainer) {
      console.log('\n⚠️  PARTIAL SUCCESS: Loading screen cleared but UI incomplete');
    } else {
      console.log('\n❌ FAILED: Still stuck in loading state');
    }
    
    console.log('\n📸 Screenshot saved: final_verification.png\n');
    
  } catch (error) {
    console.error('\n❌ Test error:', error.message);
  } finally {
    await browser.close();
  }
})();
