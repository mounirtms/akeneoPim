const playwright = require('playwright');

(async () => {
  console.log('🔍 ULTIMATE DIAGNOSTIC TEST - COMPLETE SYSTEM ANALYSIS');
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
    const logs = [];
    
    page.on('console', msg => {
      const type = msg.type();
      const text = msg.text();
      
      if (type === 'error') errors.push(text);
      else if (type === 'warning') warnings.push(text);
      else if (type === 'log' && (text.includes('[') || text.includes('PIM') || text.includes('Akeneo'))) {
        logs.push(text);
      }
    });
    
    console.log('📍 Step 1: Navigate and login...');
    await page.goto('https://pim.technostationery.com/user/login', { 
      waitUntil: 'domcontentloaded', 
      timeout: 60000 
    });
    
    await page.fill('input[name="_username"]', 'admin');
    await page.fill('input[name="_password"]', 'admin');
    await page.click('button[type="submit"]');
    
    console.log('📍 Step 2: Wait for page load...');
    await page.waitForTimeout(45000);
    
    const currentUrl = page.url();
    console.log(`\n📍 Current URL: ${currentUrl}`);
    
    console.log('\n' + '='.repeat(80));
    console.log('📊 MODULE LOADING STATUS');
    console.log('='.repeat(80));
    
    const moduleStatus = await page.evaluate(() => {
      if (typeof window.requirejs === 'undefined') {
        return { available: false, reason: 'RequireJS not loaded' };
      }
      
      const defined = window.requirejs.s.contexts._.defined;
      const moduleCount = Object.keys(defined).length;
      
      const critical = {
        'jquery': !!defined['jquery'],
        'underscore': !!defined['underscore'],
        'backbone': !!defined['backbone'],
        'pim/app': !!defined['pim/app'],
        'pim/template/app': !!defined['pim/template/app'],
        'pimui/js/view/base': !!defined['pimui/js/view/base'],
        'pim/form-builder': !!defined['pim/form-builder'],
        'pim/router': !!defined['pim/router']
      };
      
      return {
        available: true,
        total: moduleCount,
        critical: critical,
        allModules: Object.keys(defined).sort()
      };
    });
    
    if (moduleStatus.available) {
      console.log(`\n✅ RequireJS Active - ${moduleStatus.total} modules loaded`);
      console.log('\n🔑 Critical Modules:');
      Object.entries(moduleStatus.critical).forEach(([name, loaded]) => {
        console.log(`   ${loaded ? '✅' : '❌'} ${name}`);
      });
    } else {
      console.log(`\n❌ RequireJS Status: ${moduleStatus.reason}`);
    }
    
    console.log('\n' + '='.repeat(80));
    console.log('🎯 UI ELEMENT STATUS');
    console.log('='.repeat(80));
    
    const uiStatus = await page.evaluate(() => {
      const checks = {
        appContainer: !!document.querySelector('.app'),
        loadingMask: !!document.querySelector('.hash-loading-mask'),
        loadingMaskVisible: document.querySelector('.hash-loading-mask')?.style.display !== 'none',
        progressContainer: !!document.querySelector('.progress-container'),
        progressVisible: document.querySelector('.progress-container')?.style.display !== 'none',
        pageElement: !!document.querySelector('#page'),
        containerElement: !!document.querySelector('#container'),
        menuZone: !!document.querySelector('[data-drop-zone="menu"]'),
        hasMenuContent: !!document.querySelector('[data-drop-zone="menu"] > *'),
        containerHasContent: !!document.querySelector('#container > *')
      };
      
      return {
        ...checks,
        pageTitle: document.title,
        bodyHtml: document.body.innerHTML.substring(0, 500)
      };
    });
    
    console.log('\n🖼️  UI Elements:');
    console.log(`   App Container: ${uiStatus.appContainer ? '✅' : '❌'}`);
    console.log(`   Page Element: ${uiStatus.pageElement ? '✅' : '❌'}`);
    console.log(`   Container Element: ${uiStatus.containerElement ? '✅' : '❌'}`);
    console.log(`   Menu Zone: ${uiStatus.menuZone ? '✅' : '❌'}`);
    console.log(`   Menu Has Content: ${uiStatus.hasMenuContent ? '✅' : '❌'}`);
    console.log(`   Container Has Content: ${uiStatus.containerHasContent ? '✅' : '❌'}`);
    console.log(`   Loading Mask: ${uiStatus.loadingMask ? (uiStatus.loadingMaskVisible ? '⚠️  VISIBLE' : '✅ Hidden') : '❌'}`);
    console.log(`   Progress Container: ${uiStatus.progressContainer ? (uiStatus.progressVisible ? '⚠️  VISIBLE' : '✅ Hidden') : '❌'}`);
    
    console.log('\n' + '='.repeat(80));
    console.log('🐛 ERROR SUMMARY');
    console.log('='.repeat(80));
    
    console.log(`\n📊 Counts: ${errors.length} errors, ${warnings.length} warnings, ${logs.length} logs`);
    
    if (errors.length > 0) {
      console.log('\n🔴 Errors (first 5):');
      errors.slice(0, 5).forEach((err, i) => {
        const preview = err.length > 150 ? err.substring(0, 150) + '...' : err;
        console.log(`   [${i + 1}] ${preview}`);
      });
    }
    
    if (logs.length > 0) {
      console.log('\n📝 Important Logs (first 10):');
      logs.slice(0, 10).forEach((log, i) => {
        console.log(`   [${i + 1}] ${log}`);
      });
    }
    
    console.log('\n' + '='.repeat(80));
    console.log('🎯 FINAL DIAGNOSIS');
    console.log('='.repeat(80));
    
    const diagnosis = [];
    
    if (!moduleStatus.available) {
      diagnosis.push('❌ CRITICAL: RequireJS not loaded - JavaScript initialization failed');
    } else if (moduleStatus.total < 50) {
      diagnosis.push('⚠️  WARNING: Only ' + moduleStatus.total + ' modules loaded (expected 58+)');
    } else {
      diagnosis.push('✅ GOOD: ' + moduleStatus.total + ' RequireJS modules loaded successfully');
    }
    
    if (uiStatus.pageElement && uiStatus.menuZone) {
      diagnosis.push('✅ GOOD: Main UI structure created (app container, page, menu zones)');
    } else {
      diagnosis.push('❌ CRITICAL: Main UI structure not created - form builder failed');
    }
    
    if (uiStatus.loadingMaskVisible || uiStatus.progressVisible) {
      diagnosis.push('⚠️  WARNING: Loading indicators still visible - initialization incomplete');
    }
    
    if (!uiStatus.hasMenuContent) {
      diagnosis.push('❌ ISSUE: Menu zone empty - menu module not rendering');
    }
    
    if (!uiStatus.containerHasContent) {
      diagnosis.push('❌ ISSUE: Container empty - dashboard content not rendered');
    }
    
    if (errors.length > 0) {
      const hasTemplateError = errors.some(e => e.includes('replace is not a function'));
      const hasConfigError = errors.some(e => e.includes('config'));
      
      if (hasTemplateError) {
        diagnosis.push('🔴 BLOCKER: Template compilation error - _.template() receiving non-string input');
      }
      if (hasConfigError) {
        diagnosis.push('⚠️  WARNING: Module configuration errors detected');
      }
    }
    
    console.log('\n📋 Diagnosis Results:');
    diagnosis.forEach(d => console.log(`   ${d}`));
    
    // Calculate overall status
    const criticalIssues = diagnosis.filter(d => d.includes('CRITICAL')).length;
    const blockerIssues = diagnosis.filter(d => d.includes('BLOCKER')).length;
    const warningCount = diagnosis.filter(d => d.includes('WARNING')).length;
    const goodCount = diagnosis.filter(d => d.includes('GOOD')).length;
    
    console.log('\n' + '='.repeat(80));
    console.log('📊 OVERALL SYSTEM STATUS');
    console.log('='.repeat(80));
    
    if (criticalIssues === 0 && blockerIssues === 0 && goodCount >= 2) {
      console.log('\n✅ STATUS: OPERATIONAL');
      console.log('   System is functioning correctly');
      console.log('   Dashboard should be accessible');
    } else if (blockerIssues > 0) {
      console.log('\n🔴 STATUS: BLOCKED');
      console.log('   Critical blockers preventing operation');
      console.log('   Immediate attention required');
    } else if (criticalIssues > 0) {
      console.log('\n❌ STATUS: CRITICAL ISSUES');
      console.log('   Major issues preventing full functionality');
      console.log('   Partial operation may be possible');
    } else {
      console.log('\n⚠️  STATUS: DEGRADED');
      console.log('   System partially functional');
      console.log('   Some features may not work correctly');
    }
    
    await page.screenshot({ path: 'ultimate_diagnostic_test.png', fullPage: true });
    console.log('\n📸 Screenshot saved: ultimate_diagnostic_test.png');
    
    console.log('\n' + '='.repeat(80));
    console.log('✓ Diagnostic complete');
    console.log('='.repeat(80));
    
  } catch (error) {
    console.error('❌ Test error:', error.message);
  } finally {
    await browser.close();
  }
})();
