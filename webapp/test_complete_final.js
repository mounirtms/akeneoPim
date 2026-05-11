const { chromium } = require('playwright');

(async () => {
  const browser = await chromium.launch({ headless: true });
  const page = await browser.newPage();
  
  const messages = [];
  const errors = [];
  
  page.on('console', msg => messages.push(msg.text()));
  page.on('pageerror', error => errors.push(error.message));
  
  console.log('🚀 Starting comprehensive final test...\n');
  
  await page.goto('https://pim.technostationery.com/user/login', { waitUntil: 'networkidle' });
  await page.fill('input[name="_username"]', 'testuser');
  await page.fill('input[name="_password"]', 'TestPass123!');
  await page.click('button[type="submit"]');
  
  console.log('⏳ Waiting for dashboard initialization (20 seconds)...');
  await page.waitForTimeout(20000);
  
  const status = await page.evaluate(() => {
    return {
      url: window.location.href,
      title: document.title,
      loadingVisible: document.querySelector('.AknDefault-progressContainer') !== null,
      hasNavMenu: document.querySelector('nav') !== null,
      hasHeader: document.querySelector('header') !== null,
      hasSidebar: document.querySelector('.AknDefault-sidebar') !== null,
      hasMainContent: document.querySelector('.AknDefault-contentWithBottom') !== null,
      hasMenuItems: document.querySelectorAll('nav a').length,
      bodyClasses: document.body.className,
      appContentLength: document.querySelector('.app').innerHTML.length,
      requirejsModules: typeof require !== 'undefined' && require.s?.contexts?._?.defined ? 
        Object.keys(require.s.contexts._.defined).length : 0,
      webpackLoaded: typeof window.webpackJsonp !== 'undefined',
    };
  });
  
  console.log('\n═══════════════════════════════════════');
  console.log('        FINAL TEST RESULTS');
  console.log('═══════════════════════════════════════\n');
  
  console.log('📍 URL:', status.url);
  console.log('📄 Title:', status.title);
  console.log('🔧 Webpack Loaded:', status.webpackLoaded ? '✅' : '❌');
  console.log('📦 RequireJS Modules:', status.requirejsModules);
  console.log('📏 App Content:', status.appContentLength, 'characters');
  
  console.log('\n--- UI ELEMENTS ---');
  console.log('Loading Screen:', status.loadingVisible ? '❌ VISIBLE' : '✅ HIDDEN');
  console.log('Navigation Menu:', status.hasNavMenu ? '✅ PRESENT' : '❌ MISSING');
  console.log('Header:', status.hasHeader ? '✅ PRESENT' : '❌ MISSING');
  console.log('Sidebar:', status.hasSidebar ? '✅ PRESENT' : '❌ MISSING');
  console.log('Main Content:', status.hasMainContent ? '✅ PRESENT' : '❌ MISSING');
  console.log('Menu Items Count:', status.hasMenuItems);
  
  console.log('\n--- ERRORS ---');
  if (errors.length > 0) {
    console.log('❌ JavaScript Errors:', errors.length);
    errors.forEach((err, i) => console.log(`  ${i + 1}. ${err}`));
  } else {
    console.log('✅ No JavaScript errors');
  }
  
  console.log('\n--- KEY CONSOLE MESSAGES ---');
  messages.filter(m => 
    m.includes('Akeneo') || 
    m.includes('webpack') || 
    m.includes('Loading entry') ||
    m.includes('form-builder') ||
    m.includes('pim-app')
  ).forEach(msg => console.log('  📝', msg));
  
  await page.screenshot({ path: 'test_complete_final.png', fullPage: true });
  console.log('\n📸 Screenshot saved: test_complete_final.png');
  
  console.log('\n═══════════════════════════════════════');
  console.log('           FINAL VERDICT');
  console.log('═══════════════════════════════════════\n');
  
  if (status.hasNavMenu && status.hasMainContent && !status.loadingVisible) {
    console.log('✅ SUCCESS! Dashboard loaded successfully!');
    console.log('   All UI elements rendered correctly.');
  } else if (!status.loadingVisible && status.appContentLength > 1000) {
    console.log('⚠️  PARTIAL SUCCESS');
    console.log('   Loading screen hidden but UI incomplete.');
    console.log('   RequireJS modules:', status.requirejsModules);
  } else {
    console.log('❌ FAILED: Dashboard still on loading screen');
    console.log('   Possible causes:');
    console.log('   - Cache not fully cleared');
    console.log('   - Module registry not loading');
    console.log('   - Entry point not executing');
  }
  
  console.log('\n═══════════════════════════════════════\n');
  
  await browser.close();
})();
