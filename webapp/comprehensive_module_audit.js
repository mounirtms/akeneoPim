const playwright = require('playwright');

(async () => {
  console.log('🔍 COMPREHENSIVE MODULE AUDIT');
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
    
    // Track all network requests
    const failedRequests = [];
    const successRequests = [];
    
    page.on('response', response => {
      const url = response.url();
      const status = response.status();
      
      if (url.includes('/bundles/') || url.includes('/dist/')) {
        if (status >= 400) {
          failedRequests.push({ url, status });
        } else if (status === 200) {
          successRequests.push(url);
        }
      }
    });
    
    // Capture all console messages
    const consoleMessages = {
      errors: [],
      warnings: [],
      logs: []
    };
    
    page.on('console', msg => {
      const type = msg.type();
      const text = msg.text();
      
      if (type === 'error') consoleMessages.errors.push(text);
      else if (type === 'warning') consoleMessages.warnings.push(text);
      else if (type === 'log') consoleMessages.logs.push(text);
    });
    
    console.log('📍 Step 1: Navigating to login...');
    await page.goto('https://pim.technostationery.com/user/login', {
      waitUntil: 'networkidle',
      timeout: 30000
    });
    
    console.log('📍 Step 2: Logging in...');
    await page.fill('#username_input', 'testuser');
    await page.fill('#password_input', 'TestPass123!');
    await page.click('button[type="submit"]');
    
    console.log('📍 Step 3: Waiting for dashboard (45 seconds)...');
    await page.waitForTimeout(45000);
    
    console.log('\n' + '='.repeat(70));
    console.log('📊 NETWORK ANALYSIS');
    console.log('='.repeat(70));
    
    console.log(`\n✅ Successful Requests: ${successRequests.length}`);
    console.log(`❌ Failed Requests: ${failedRequests.length}\n`);
    
    if (failedRequests.length > 0) {
      console.log('Failed Request Details:');
      failedRequests.forEach(req => {
        const path = req.url.replace('https://pim.technostationery.com', '');
        console.log(`  [${req.status}] ${path}`);
      });
    }
    
    console.log('\n' + '='.repeat(70));
    console.log('🐛 CONSOLE ERRORS');
    console.log('='.repeat(70));
    
    if (consoleMessages.errors.length > 0) {
      console.log(`\nTotal Errors: ${consoleMessages.errors.length}\n`);
      
      // Group similar errors
      const errorGroups = {};
      consoleMessages.errors.forEach(err => {
        const key = err.substring(0, 100);
        if (!errorGroups[key]) {
          errorGroups[key] = { count: 0, example: err };
        }
        errorGroups[key].count++;
      });
      
      Object.values(errorGroups).forEach(group => {
        console.log(`[×${group.count}] ${group.example.substring(0, 200)}...`);
        console.log('');
      });
    } else {
      console.log('\n✅ No console errors\n');
    }
    
    console.log('='.repeat(70));
    console.log('⚠️  CONSOLE WARNINGS');
    console.log('='.repeat(70));
    
    if (consoleMessages.warnings.length > 0) {
      console.log(`\nTotal Warnings: ${consoleMessages.warnings.length}\n`);
      
      // Show unique warnings
      const uniqueWarnings = [...new Set(consoleMessages.warnings)];
      uniqueWarnings.slice(0, 5).forEach(warn => {
        console.log(`  ${warn.substring(0, 150)}...`);
      });
      
      if (uniqueWarnings.length > 5) {
        console.log(`  ... and ${uniqueWarnings.length - 5} more`);
      }
    }
    
    console.log('\n' + '='.repeat(70));
    console.log('📦 REQUIREJS MODULE ANALYSIS');
    console.log('='.repeat(70));
    
    const moduleAnalysis = await page.evaluate(() => {
      const analysis = {
        requirejsLoaded: typeof requirejs !== 'undefined',
        definedModules: [],
        failedModules: [],
        registeredModules: [],
        webpackLoaded: typeof __webpack_require__ !== 'undefined'
      };
      
      if (typeof requirejs !== 'undefined' && requirejs.s && requirejs.s.contexts) {
        const ctx = requirejs.s.contexts._;
        
        if (ctx.defined) {
          analysis.definedModules = Object.keys(ctx.defined);
        }
        
        if (ctx.registry) {
          analysis.registeredModules = Object.keys(ctx.registry);
        }
        
        // Check for common critical modules
        const criticalModules = [
          'pim/app',
          'pim/form-builder',
          'pim/form-registry',
          'pimui/js/pim-app',
          'pimui/js/view/base',
          'pimui/js/fetcher-registry',
          'backbone',
          'underscore',
          'jquery'
        ];
        
        analysis.criticalModuleStatus = {};
        criticalModules.forEach(mod => {
          if (ctx.defined && ctx.defined[mod]) {
            analysis.criticalModuleStatus[mod] = 'defined';
          } else if (ctx.registry && ctx.registry[mod]) {
            analysis.criticalModuleStatus[mod] = 'registered';
          } else {
            analysis.criticalModuleStatus[mod] = 'missing';
          }
        });
      }
      
      return analysis;
    });
    
    console.log(`\nRequireJS: ${moduleAnalysis.requirejsLoaded ? '✅ Loaded' : '❌ Not loaded'}`);
    console.log(`Webpack: ${moduleAnalysis.webpackLoaded ? '✅ Loaded' : '❌ Not loaded'}`);
    console.log(`\nDefined Modules: ${moduleAnalysis.definedModules.length}`);
    console.log(`Registered Modules: ${moduleAnalysis.registeredModules.length}`);
    
    console.log('\n📌 Critical Module Status:');
    Object.entries(moduleAnalysis.criticalModuleStatus).forEach(([mod, status]) => {
      const icon = status === 'defined' ? '✅' : status === 'registered' ? '⚠️ ' : '❌';
      console.log(`  ${icon} ${mod}: ${status}`);
    });
    
    if (moduleAnalysis.definedModules.length > 0) {
      console.log('\n📋 All Defined Modules:');
      moduleAnalysis.definedModules.forEach(mod => {
        console.log(`  - ${mod}`);
      });
    }
    
    console.log('\n' + '='.repeat(70));
    console.log('🎯 UI STATE ANALYSIS');
    console.log('='.repeat(70));
    
    const uiState = await page.evaluate(() => {
      return {
        title: document.title,
        url: window.location.href,
        hasApp: !!document.querySelector('.app'),
        hasLoadingMask: !!document.querySelector('.AknLoadingMask'),
        hasProgressContainer: !!document.querySelector('.AknDefault-progressContainer'),
        hasMenu: !!document.querySelector('[data-drop-zone="menu"]'),
        hasPage: !!document.querySelector('#page'),
        hasContainer: !!document.querySelector('#container'),
        bodyClasses: document.body.className,
        appInnerHTML: document.querySelector('.app') ? 
          document.querySelector('.app').innerHTML.substring(0, 500) : 'N/A'
      };
    });
    
    console.log(`\nPage Title: ${uiState.title}`);
    console.log(`Current URL: ${uiState.url}`);
    console.log(`\nUI Elements:`);
    console.log(`  .app container: ${uiState.hasApp ? '✅' : '❌'}`);
    console.log(`  Loading mask: ${uiState.hasLoadingMask ? '⚠️  YES (stuck)' : '✅ NO'}`);
    console.log(`  Progress container: ${uiState.hasProgressContainer ? '⚠️  YES (stuck)' : '✅ NO'}`);
    console.log(`  Menu zone: ${uiState.hasMenu ? '✅' : '❌'}`);
    console.log(`  #page: ${uiState.hasPage ? '✅' : '❌'}`);
    console.log(`  #container: ${uiState.hasContainer ? '✅' : '❌'}`);
    
    await page.screenshot({ path: 'comprehensive_audit.png', fullPage: true });
    console.log('\n📸 Screenshot saved: comprehensive_audit.png');
    
    console.log('\n' + '='.repeat(70));
    console.log('💡 RECOMMENDATIONS');
    console.log('='.repeat(70));
    
    const recommendations = [];
    
    if (failedRequests.length > 0) {
      recommendations.push('• Fix 404 errors for missing module files');
    }
    
    if (moduleAnalysis.criticalModuleStatus['pim/app'] !== 'defined') {
      recommendations.push('• Ensure pim/app module is properly loaded via RequireJS');
    }
    
    if (consoleMessages.errors.some(e => e.includes('e.replace is not a function'))) {
      recommendations.push('• Fix template compilation issue (webpack vs RequireJS conflict)');
    }
    
    if (uiState.hasProgressContainer) {
      recommendations.push('• Application stuck in loading state - form builder failed');
    }
    
    if (!uiState.hasMenu) {
      recommendations.push('• Menu rendering blocked by initialization failure');
    }
    
    if (recommendations.length > 0) {
      console.log('\n');
      recommendations.forEach(rec => console.log(rec));
    } else {
      console.log('\n✅ No critical issues detected');
    }
    
    console.log('\n' + '='.repeat(70));
    
  } catch (error) {
    console.error('\n❌ Audit error:', error.message);
  } finally {
    await browser.close();
    console.log('\n✓ Audit complete. Browser closed.\n');
  }
})();
