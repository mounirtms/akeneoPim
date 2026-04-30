#!/usr/bin/env node
/**
 * Simple Playwright smoke test for Akeneo PIM
 * Run with: node pim-smoke-test.js
 */

const { chromium } = require('playwright');

(async () => {
  console.log('🧪 Starting Akeneo PIM Smoke Tests...\n');
  
  const browser = await chromium.launch({ headless: true });
  const page = await browser.newPage();
  let passed = 0;
  let failed = 0;
  
  try {
    // Test 1: Homepage loads
    console.log('Test 1: PIM homepage loads...');
    const failedRequests = [];
    page.on('response', async (response) => {
      if (response.status() === 404) {
        failedRequests.push(response.url());
      }
    });
    
    const response = await page.goto('https://pim.technostationery.com/');
    if ([200, 302].includes(response.status())) {
      console.log('  ✅ PASS - Homepage loads (status: ' + response.status() + ')');
      passed++;
    } else {
      console.log('  ❌ FAIL - Homepage returned status: ' + response.status());
      failed++;
    }
    
    await page.waitForLoadState('networkidle');
    
    // Test 2: CSS loaded
    console.log('\nTest 2: CSS assets loaded...');
    const cssLink = await page.locator('link[rel="stylesheet"][href*="pim.css"]').count();
    if (cssLink > 0) {
      console.log('  ✅ PASS - pim.css is loaded');
      passed++;
    } else {
      console.log('  ❌ FAIL - pim.css not found');
      failed++;
    }
    
    // Test 3: Critical 404s
    console.log('\nTest 3: No critical asset 404s...');
    const critical404s = failedRequests.filter(url => 
      url.includes('/css/pim.css') || 
      url.includes('/dist/main.min.js') ||
      url.includes('/dist/vendor.min.js') ||
      url.includes('/js/extensions.json')
    );
    
    if (critical404s.length === 0) {
      console.log('  ✅ PASS - No critical 404 errors');
      passed++;
    } else {
      console.log('  ❌ FAIL - Critical 404s found:');
      critical404s.forEach(url => console.log('    - ' + url));
      failed++;
    }
    
    // Test 4: Login page
    console.log('\nTest 4: Login page accessible...');
    const loginResponse = await page.goto('https://pim.technostationery.com/user/login');
    if (loginResponse.status() === 200) {
      console.log('  ✅ PASS - Login page accessible');
      passed++;
    } else {
      console.log('  ❌ FAIL - Login page returned: ' + loginResponse.status());
      failed++;
    }
    
    // Test 5: Extensions.json
    console.log('\nTest 5: Extensions.json available...');
    const extResponse = await page.goto('https://pim.technostationery.com/js/extensions.json');
    if (extResponse.status() === 200) {
      const json = await extResponse.json();
      if (json.extensions && json.attribute_fields) {
        console.log('  ✅ PASS - Extensions.json is valid');
        passed++;
      } else {
        console.log('  ❌ FAIL - Extensions.json missing required properties');
        failed++;
      }
    } else {
      console.log('  ❌ FAIL - Extensions.json returned: ' + extResponse.status());
      failed++;
    }
    
    // Test 6: FOS JS routing
    console.log('\nTest 6: Bundle assets accessible...');
    const fosResponse = await page.goto('https://pim.technostationery.com/bundles/fosjsrouting/js/router.min.js');
    if (fosResponse.status() === 200) {
      console.log('  ✅ PASS - FOS JS routing accessible');
      passed++;
    } else {
      console.log('  ❌ FAIL - FOS JS routing returned: ' + fosResponse.status());
      failed++;
    }
    
    // Summary
    console.log('\n' + '='.repeat(50));
    console.log('📊 Test Results:');
    console.log('  Passed: ' + passed + '/' + (passed + failed));
    console.log('  Failed: ' + failed + '/' + (passed + failed));
    console.log('='.repeat(50));
    
    if (failed === 0) {
      console.log('\n✅ All smoke tests passed!');
    } else {
      console.log('\n⚠️  ' + failed + ' test(s) failed');
      process.exit(1);
    }
    
  } catch (error) {
    console.error('\n❌ Test execution failed:', error.message);
    process.exit(1);
  } finally {
    await browser.close();
  }
})();
