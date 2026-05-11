const playwright = require('playwright');

(async () => {
  console.log('🔍 FINAL DEVELOPMENT MODE TEST - CREDENTIALS: mounir/2026');
  console.log('='.repeat(80));
  
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
    
    const errors = [];
    const warnings = [];
    const pimLogs = [];
    const allLogs = [];
    
    page.on('console', msg => {
      const type = msg.type();
      const text = msg.text();
      
      allLogs.push(`[${type}] ${text}`);
      
      if (type === 'error') errors.push(text);
      else if (type === 'warning') warnings.push(text);
      else if (text.includes('[PimApp]') || text.includes('[Akeneo]') || text.includes('[require]')) {
        pimLogs.push(text);
      }
    });
    
    page.on('pageerror', err => {
      errors.push(`[PageError] ${err.message}`);
    });
    
    console.log('📍 Step 1: Navigate to login page...');
    await page.goto('https://pim.technostationery.com/user/login', { 
      waitUntil: 'domcontentloaded', 
      timeout: 60000 
    });
    
    console.log('📍 Step 2: Login with mounir/2026...');
    await page.fill('input[name="_username"]', 'mounir');
    await page.fill('input[name="_password"]', '2026');
    await page.click('button[type="submit"]');
    
    console.log('📍 Step 3: Wait for dashboard (60 seconds)...');
    await page.waitForTimeout(60000);
    
    const currentUrl = page.url();
    const pageTitle = await page.title();
    
    console.log('\n' + '='.repeat(80));
    console.log('📊 SYSTEM STATUS');
    console.log('='.repeat(80));
    console.log(`\n📍 Current URL: ${currentUrl}`);
    console.log(`📍 Page Title: ${pageTitle}`);
    
    // Check if we're still on login page or redirected to dashboard
    const isLoginPage = currentUrl.includes('/user/login');
    const isDashboard = currentUrl.includes('#/dashboard') || currentUrl.includes('/dashboard');
    
    if (isLoginPage) {
      console.log('\n⚠️  WARNING: Still on login page - login may have failed');
      
      // Check for error messages
      const loginError = await page.evaluate(() => {
        const errorMsg = document.querySelector('.alert-error, .alert-danger, .error-message');
        return errorMsg ? errorMsg.textContent.trim() : null;
      });
      
      if (loginError) {
        console.log(`\n❌ Login Error: ${loginError}`);
      }
    } else {
      console.log('\n✅ Successfully redirected from login page');
    }
    
    // Check UI state
    const uiState = await page.evaluate(() => {
      return {
        hasAppContainer: !!document.querySelector('.app'),
        hasPage: !!document.querySelector('#page'),
        hasContainer: !!document.querySelector('#container'),
        hasMenu: !!document.querySelector('[data-drop-zone="menu"]'),
        menuHasContent: !!document.querySelector('[data-drop-zone="menu"] > *'),
        containerHasContent: !!document.querySelector('#container > *'),
        loadingVisible: !!document.querySelector('.hash-loading-mask:not([style*="display: none"])') ||
                       !!document.querySelector('.progress-container:not([style*="display: none"])'),
        bodyClasses: document.body.className,
        hasCssLoaded: !!document.querySelector('link[href*="pim.css"]'),
        cssLinks: Array.from(document.querySelectorAll('link[rel="stylesheet"]')).map(l => l.href)
      };
    });
    
    console.log('\n🖥️  UI Elements:');
    console.log(`   App Container: ${uiState.hasAppContainer ? '✅' : '❌'}`);
    console.log(`   Page Element: ${uiState.hasPage ? '✅' : '❌'}`);
    console.log(`   Container: ${uiState.hasContainer ? '✅' : '❌'}`);
    console.log(`   Menu Zone: ${uiState.hasMenu ? '✅' : '❌'}`);
    console.log(`   Menu Content: ${uiState.menuHasContent ? '✅' : '❌'}`);
    console.log(`   Container Content: ${uiState.containerHasContent ? '✅' : '❌'}`);
    console.log(`   Loading State: ${uiState.loadingVisible ? '⚠️  VISIBLE' : '✅ Hidden'}`);
    console.log(`   CSS Loaded: ${uiState.hasCssLoaded ? '✅' : '❌'}`);
    
    // Check RequireJS
    const moduleState = await page.evaluate(() => {
      if (typeof window.requirejs === 'undefined') {
        return { available: false };
      }
      
      const modules = window.requirejs.s.contexts._.defined;
      return {
        available: true,
        count: Object.keys(modules).length,
        hasPimApp: !!modules['pim/app'],
        hasTemplate: !!modules['pim/template/app'],
        hasBaseView: !!modules['pimui/js/view/base']
      };
    });
    
    console.log('\n📦 RequireJS Modules:');
    if (moduleState.available) {
      console.log(`   ✅ RequireJS Active (${moduleState.count} modules)`);
      console.log(`   pim/app: ${moduleState.hasPimApp ? '✅' : '❌'}`);
      console.log(`   pim/template/app: ${moduleState.hasTemplate ? '✅' : '❌'}`);
      console.log(`   BaseView: ${moduleState.hasBaseView ? '✅' : '❌'}`);
    } else {
      console.log('   ❌ RequireJS not loaded');
    }
    
    // PimApp debug logs
    console.log('\n🔍 PimApp Debug Logs:');
    if (pimLogs.length > 0) {
      pimLogs.forEach(log => console.log(`   ${log}`));
    } else {
      console.log('   ⚠️  No PimApp debug logs found');
    }
    
    // Error analysis
    console.log('\n🐛 Error Analysis:');
    console.log(`   Total Errors: ${errors.length}`);
    console.log(`   Total Warnings: ${warnings.length}`);
    
    if (errors.length > 0) {
      console.log('\n   Top Errors:');
      errors.slice(0, 5).forEach((err, i) => {
        const preview = err.length > 150 ? err.substring(0, 150) + '...' : err;
        console.log(`   [${i + 1}] ${preview}`);
      });
    }
    
    // CSS check
    console.log('\n🎨 CSS Status:');
    console.log(`   CSS Links Found: ${uiState.cssLinks.length}`);
    if (uiState.cssLinks.length > 0) {
      console.log('   Stylesheets:');
      uiState.cssLinks.forEach(link => {
        const shortLink = link.replace('https://pim.technostationery.com', '');
        console.log(`      - ${shortLink}`);
      });
    }
    
    // Final diagnosis
    console.log('\n' + '='.repeat(80));
    console.log('🎯 FINAL DIAGNOSIS');
    console.log('='.repeat(80));
    
    let status = 'UNKNOWN';
    const issues = [];
    const successes = [];
    
    if (isLoginPage) {
      status = 'LOGIN_FAILED';
      issues.push('❌ Login with mounir/2026 failed - still on login page');
      issues.push('   → Check if credentials are correct');
      issues.push('   → Verify user account exists and is active');
    } else if (uiState.hasPage && uiState.hasContainer && uiState.hasMenu) {
      if (uiState.menuHasContent && uiState.containerHasContent) {
        status = 'OPERATIONAL';
        successes.push('✅ Dashboard fully rendered');
        successes.push('✅ Menu navigation available');
        successes.push('✅ Container has content');
      } else if (uiState.menuHasContent || uiState.containerHasContent) {
        status = 'PARTIAL';
        successes.push('✅ Main structure created');
        if (uiState.menuHasContent) successes.push('✅ Menu rendered');
        if (!uiState.containerHasContent) issues.push('⚠️  Container empty');
      } else {
        status = 'BLOCKED';
        successes.push('✅ UI structure created');
        issues.push('❌ No content rendered');
      }
    } else {
      status = 'CRITICAL';
      issues.push('❌ Main UI structure not created');
    }
    
    if (moduleState.available && moduleState.count >= 50) {
      successes.push(`✅ ${moduleState.count} RequireJS modules loaded`);
    }
    
    if (errors.length === 0) {
      successes.push('✅ No JavaScript errors');
    } else {
      issues.push(`⚠️  ${errors.length} error(s) detected`);
    }
    
    console.log('\n📋 Successes:');
    if (successes.length > 0) {
      successes.forEach(s => console.log(`   ${s}`));
    } else {
      console.log('   None');
    }
    
    console.log('\n📋 Issues:');
    if (issues.length > 0) {
      issues.forEach(i => console.log(`   ${i}`));
    } else {
      console.log('   None');
    }
    
    console.log('\n' + '='.repeat(80));
    console.log(`🎖️  OVERALL STATUS: ${status}`);
    console.log('='.repeat(80));
    
    if (status === 'LOGIN_FAILED') {
      console.log('\n❌ LOGIN FAILURE');
      console.log('   - Credentials mounir/2026 did not work');
      console.log('   - Need to verify correct username/password');
      console.log('   - Check user account status in database');
      console.log('   - Verify CSRF token handling');
    } else if (status === 'OPERATIONAL') {
      console.log('\n✅ SUCCESS: System fully operational!');
      console.log('   - Login successful');
      console.log('   - Dashboard rendered');
      console.log('   - Menu navigation ready');
      console.log('   - All modules loaded');
    } else if (status === 'PARTIAL') {
      console.log('\n⚠️  PARTIAL: System partially working');
      console.log('   - Login successful');
      console.log('   - Main structure created');
      console.log('   - Some components not rendering');
    } else if (status === 'BLOCKED') {
      console.log('\n❌ BLOCKED: Content not rendering');
      console.log('   - Structure created but empty');
      console.log('   - Template compilation may be blocked');
    } else {
      console.log('\n🔴 CRITICAL: System not functional');
      console.log('   - Initialization failed');
    }
    
    await page.screenshot({ path: 'final_dev_test_mounir.png', fullPage: true });
    console.log('\n📸 Screenshot: final_dev_test_mounir.png');
    
    console.log('\n' + '='.repeat(80));
    console.log('✓ Test complete');
    console.log('='.repeat(80));
    
  } catch (error) {
    console.error('\n❌ Test error:', error.message);
    console.error(error.stack);
  } finally {
    await browser.close();
  }
})();
