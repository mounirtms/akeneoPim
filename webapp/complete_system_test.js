const playwright = require('playwright');

(async () => {
  console.log('🔍 COMPLETE SYSTEM TEST - POST-TEMPLATE FIX VERIFICATION');
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
    
    page.on('console', msg => {
      const type = msg.type();
      const text = msg.text();
      
      if (type === 'error') errors.push(text);
      else if (type === 'warning') warnings.push(text);
      else if (text.includes('[PimApp]') || text.includes('[Akeneo]')) {
        pimLogs.push(text);
      }
    });
    
    console.log('📍 Step 1: Navigate to login...');
    await page.goto('https://pim.technostationery.com/user/login', { 
      waitUntil: 'domcontentloaded', 
      timeout: 60000 
    });
    
    console.log('📍 Step 2: Login...');
    await page.fill('input[name="_username"]', 'admin');
    await page.fill('input[name="_password"]', 'admin');
    await page.click('button[type="submit"]');
    
    console.log('📍 Step 3: Wait for dashboard (60 seconds)...');
    await page.waitForTimeout(60000);
    
    const currentUrl = page.url();
    console.log(`\n📍 Current URL: ${currentUrl}`);
    
    console.log('\n' + '='.repeat(80));
    console.log('📊 TEMPLATE FIX VERIFICATION');
    console.log('='.repeat(80));
    
    // Check for PimApp debug logs
    console.log('\n🔍 PimApp Debug Logs:');
    if (pimLogs.length > 0) {
      pimLogs.forEach(log => console.log(`   ${log}`));
    } else {
      console.log('   ⚠️  No PimApp debug logs found');
    }
    
    // Check UI state
    const uiState = await page.evaluate(() => {
      return {
        title: document.title,
        hasAppContainer: !!document.querySelector('.app'),
        hasPage: !!document.querySelector('#page'),
        hasContainer: !!document.querySelector('#container'),
        hasMenu: !!document.querySelector('[data-drop-zone="menu"]'),
        menuHasContent: !!document.querySelector('[data-drop-zone="menu"] > *'),
        containerHasContent: !!document.querySelector('#container > *'),
        loadingVisible: !!document.querySelector('.hash-loading-mask[style*="display: block"]') ||
                       !!document.querySelector('.progress-container[style*="display: block"]'),
        bodyClasses: document.body.className,
        pageHTML: document.querySelector('#page') ? 'exists' : 'missing'
      };
    });
    
    console.log('\n🖥️  UI State:');
    console.log(`   Title: ${uiState.title}`);
    console.log(`   App Container: ${uiState.hasAppContainer ? '✅' : '❌'}`);
    console.log(`   Page Element: ${uiState.hasPage ? '✅' : '❌'}`);
    console.log(`   Container: ${uiState.hasContainer ? '✅' : '❌'}`);
    console.log(`   Menu Zone: ${uiState.hasMenu ? '✅' : '❌'}`);
    console.log(`   Menu Content: ${uiState.menuHasContent ? '✅' : '❌'}`);
    console.log(`   Container Content: ${uiState.containerHasContent ? '✅' : '❌'}`);
    console.log(`   Loading State: ${uiState.loadingVisible ? '⚠️  VISIBLE (STUCK)' : '✅ Hidden'}`);
    
    // Check RequireJS modules
    const moduleState = await page.evaluate(() => {
      if (typeof window.requirejs === 'undefined') {
        return { available: false };
      }
      
      const modules = window.requirejs.s.contexts._.defined;
      return {
        available: true,
        count: Object.keys(modules).length,
        hasPimApp: !!modules['pim/app'],
        hasTemplate: !!modules['pim/template/app']
      };
    });
    
    console.log('\n📦 Module State:');
    if (moduleState.available) {
      console.log(`   RequireJS: ✅ (${moduleState.count} modules)`);
      console.log(`   pim/app: ${moduleState.hasPimApp ? '✅' : '❌'}`);
      console.log(`   pim/template/app: ${moduleState.hasTemplate ? '✅' : '❌'}`);
    } else {
      console.log('   RequireJS: ❌ Not loaded');
    }
    
    // Error analysis
    console.log('\n🐛 Error Analysis:');
    console.log(`   Total Errors: ${errors.length}`);
    console.log(`   Total Warnings: ${warnings.length}`);
    
    const templateErrors = errors.filter(e => e.includes('template') || e.includes('replace is not a function'));
    const configErrors = errors.filter(e => e.includes('config'));
    const formBuilderErrors = errors.filter(e => e.includes('Failed to build form'));
    
    if (templateErrors.length > 0) {
      console.log(`   ⚠️  Template Errors: ${templateErrors.length}`);
      templateErrors.slice(0, 2).forEach(e => {
        console.log(`      - ${e.substring(0, 150)}...`);
      });
    }
    
    if (formBuilderErrors.length > 0) {
      console.log(`   ⚠️  Form Builder Errors: ${formBuilderErrors.length}`);
    }
    
    // Final diagnosis
    console.log('\n' + '='.repeat(80));
    console.log('🎯 DIAGNOSIS');
    console.log('='.repeat(80));
    
    let status = 'UNKNOWN';
    const issues = [];
    const successes = [];
    
    if (uiState.hasPage && uiState.hasContainer && uiState.hasMenu) {
      successes.push('✅ Main UI structure created successfully');
      if (uiState.menuHasContent && uiState.containerHasContent) {
        status = 'OPERATIONAL';
        successes.push('✅ Menu and dashboard content rendered');
      } else if (uiState.menuHasContent) {
        status = 'PARTIAL';
        successes.push('✅ Menu rendered');
        issues.push('⚠️  Dashboard content not rendered');
      } else {
        status = 'BLOCKED';
        issues.push('❌ No content rendered in menu or container');
      }
    } else {
      status = 'CRITICAL';
      issues.push('❌ Main UI structure not created');
    }
    
    if (templateErrors.length === 0) {
      successes.push('✅ No template compilation errors');
    } else {
      issues.push(`❌ ${templateErrors.length} template error(s) detected`);
    }
    
    if (moduleState.available && moduleState.count >= 58) {
      successes.push(`✅ ${moduleState.count} RequireJS modules loaded`);
    } else if (moduleState.available) {
      issues.push(`⚠️  Only ${moduleState.count} modules loaded (expected 58+)`);
    } else {
      issues.push('❌ RequireJS not loaded');
    }
    
    console.log('\n📋 Successes:');
    successes.forEach(s => console.log(`   ${s}`));
    
    if (issues.length > 0) {
      console.log('\n📋 Issues:');
      issues.forEach(i => console.log(`   ${i}`));
    }
    
    console.log('\n' + '='.repeat(80));
    console.log(`🎖️  OVERALL STATUS: ${status}`);
    console.log('='.repeat(80));
    
    if (status === 'OPERATIONAL') {
      console.log('\n✅ SUCCESS: System is fully operational!');
      console.log('   - Dashboard rendered correctly');
      console.log('   - Menu navigation available');
      console.log('   - All critical modules loaded');
    } else if (status === 'PARTIAL') {
      console.log('\n⚠️  PARTIAL: System partially working');
      console.log('   - Main structure created');
      console.log('   - Some components not rendering');
      console.log('   - Further investigation needed');
    } else if (status === 'BLOCKED') {
      console.log('\n❌ BLOCKED: System initialization incomplete');
      console.log('   - Structure created but empty');
      console.log('   - Content rendering failed');
      console.log('   - Template compilation may still be blocking');
    } else {
      console.log('\n🔴 CRITICAL: System not functional');
      console.log('   - Main UI structure not created');
      console.log('   - Initialization completely failed');
      console.log('   - Immediate intervention required');
    }
    
    await page.screenshot({ path: 'complete_system_test.png', fullPage: true });
    console.log('\n📸 Screenshot: complete_system_test.png');
    
    console.log('\n' + '='.repeat(80));
    console.log('✓ Test complete');
    console.log('='.repeat(80));
    
  } catch (error) {
    console.error('❌ Test error:', error.message);
  } finally {
    await browser.close();
  }
})();
