/**
 * Phase 11: Comprehensive Playwright Browser Test Suite
 * Tests cache configurations, network performance, and routing
 */

const { chromium } = require('playwright');

// Configuration
const BASE_URL = 'https://pim.technostationery.com';
const LOCALHOST_URL = 'http://localhost';
const TIMEOUT = 30000;

// Test results storage
const results = {
  tests: [],
  startTime: new Date(),
  endTime: null,
  summary: {
    passed: 0,
    failed: 0,
    warnings: 0
  }
};

// Helper function to log test result
function logTest(name, status, details) {
  const test = {
    name,
    status, // 'PASS', 'FAIL', 'WARN'
    details,
    timestamp: new Date().toISOString()
  };
  results.tests.push(test);
  
  const icon = status === 'PASS' ? '✅' : status === 'FAIL' ? '❌' : '⚠️';
  console.log(`${icon} ${name}`);
  if (details) {
    console.log(`   ${details}`);
  }
  
  if (status === 'PASS') results.summary.passed++;
  else if (status === 'FAIL') results.summary.failed++;
  else results.summary.warnings++;
}

// Test 1: Production Homepage Access
async function testProductionHomepage(page) {
  console.log('\n=== Test 1: Production Homepage Access ===');
  try {
    const response = await page.goto(BASE_URL, { 
      waitUntil: 'domcontentloaded',
      timeout: TIMEOUT 
    });
    
    const status = response.status();
    const headers = response.headers();
    const finalUrl = page.url();
    
    console.log(`Status: ${status}`);
    console.log(`Final URL: ${finalUrl}`);
    console.log(`Server: ${headers['server'] || 'N/A'}`);
    console.log(`CF-Cache-Status: ${headers['cf-cache-status'] || 'N/A'}`);
    console.log(`X-Cache: ${headers['x-cache'] || 'N/A'}`);
    
    if (status === 200 || status === 302) {
      logTest('Production Homepage', 'PASS', `Status ${status}, redirected to ${finalUrl}`);
    } else if (status === 404) {
      logTest('Production Homepage', 'FAIL', `Status 404 - routing not working`);
    } else if (status === 403) {
      logTest('Production Homepage', 'FAIL', `Status 403 - Cloudflare blocking`);
    } else {
      logTest('Production Homepage', 'WARN', `Unexpected status ${status}`);
    }
    
    return { status, headers, finalUrl };
  } catch (error) {
    logTest('Production Homepage', 'FAIL', `Error: ${error.message}`);
    return null;
  }
}

// Test 2: Login Page Access
async function testLoginPage(page) {
  console.log('\n=== Test 2: Login Page Access ===');
  try {
    const response = await page.goto(`${BASE_URL}/user/login`, {
      waitUntil: 'domcontentloaded',
      timeout: TIMEOUT
    });
    
    const status = response.status();
    const finalUrl = page.url();
    
    console.log(`Status: ${status}`);
    console.log(`Final URL: ${finalUrl}`);
    
    // Check if login form is present
    const hasLoginForm = await page.locator('form[name="oro_user_login"]').count() > 0;
    const hasUsernameField = await page.locator('input[name="_username"]').count() > 0;
    
    console.log(`Login form present: ${hasLoginForm}`);
    console.log(`Username field present: ${hasUsernameField}`);
    
    if (status === 200 && (hasLoginForm || hasUsernameField)) {
      logTest('Login Page Access', 'PASS', 'Status 200, form visible');
    } else if (status === 404) {
      logTest('Login Page Access', 'FAIL', 'Status 404 - routing broken');
    } else {
      logTest('Login Page Access', 'WARN', `Status ${status}, form visible: ${hasLoginForm}`);
    }
    
    return { status, finalUrl, hasLoginForm };
  } catch (error) {
    logTest('Login Page Access', 'FAIL', `Error: ${error.message}`);
    return null;
  }
}

// Test 3: Static Asset Loading
async function testStaticAssets(page) {
  console.log('\n=== Test 3: Static Asset Loading ===');
  const assets = [
    '/bundles/oroui/img/logo.svg',
    '/bundles/oroui/css/style.css',
    '/bundles/oroui/js/app.js'
  ];
  
  let passedCount = 0;
  let failedCount = 0;
  
  for (const asset of assets) {
    try {
      const response = await page.goto(`${BASE_URL}${asset}`, {
        waitUntil: 'domcontentloaded',
        timeout: 10000
      });
      
      const status = response.status();
      const contentType = response.headers()['content-type'] || 'unknown';
      const cacheStatus = response.headers()['cf-cache-status'] || 'N/A';
      
      console.log(`${asset}: ${status} (${contentType}) [CF: ${cacheStatus}]`);
      
      if (status === 200) {
        passedCount++;
      } else {
        failedCount++;
      }
    } catch (error) {
      console.log(`${asset}: FAILED - ${error.message}`);
      failedCount++;
    }
  }
  
  if (failedCount === 0) {
    logTest('Static Assets', 'PASS', `All ${passedCount} assets loaded successfully`);
  } else if (passedCount > 0) {
    logTest('Static Assets', 'WARN', `${passedCount} passed, ${failedCount} failed`);
  } else {
    logTest('Static Assets', 'FAIL', `All ${failedCount} assets failed to load`);
  }
  
  return { passed: passedCount, failed: failedCount };
}

// Test 4: Cache Headers Analysis
async function testCacheHeaders(page) {
  console.log('\n=== Test 4: Cache Headers Analysis ===');
  try {
    const response = await page.goto(BASE_URL, {
      waitUntil: 'domcontentloaded',
      timeout: TIMEOUT
    });
    
    const headers = response.headers();
    
    const cacheHeaders = {
      'cache-control': headers['cache-control'],
      'x-cache': headers['x-cache'],
      'cf-cache-status': headers['cf-cache-status'],
      'age': headers['age'],
      'x-varnish': headers['x-varnish'],
      'via': headers['via']
    };
    
    console.log('Cache Headers:');
    Object.entries(cacheHeaders).forEach(([key, value]) => {
      console.log(`  ${key}: ${value || 'not present'}`);
    });
    
    const hasVarnish = cacheHeaders['x-varnish'] || cacheHeaders['via']?.includes('varnish');
    const hasCloudflare = cacheHeaders['cf-cache-status'] !== undefined;
    
    if (hasVarnish && hasCloudflare) {
      logTest('Cache Headers', 'PASS', 'Both Varnish and Cloudflare headers present');
    } else if (hasCloudflare) {
      logTest('Cache Headers', 'WARN', 'Only Cloudflare headers present (Varnish disabled?)');
    } else {
      logTest('Cache Headers', 'FAIL', 'Missing cache headers');
    }
    
    return cacheHeaders;
  } catch (error) {
    logTest('Cache Headers', 'FAIL', `Error: ${error.message}`);
    return null;
  }
}

// Test 5: Network Timing and Performance
async function testPerformance(page) {
  console.log('\n=== Test 5: Network Timing and Performance ===');
  try {
    const startTime = Date.now();
    
    const response = await page.goto(`${BASE_URL}/user/login`, {
      waitUntil: 'networkidle',
      timeout: TIMEOUT
    });
    
    const loadTime = Date.now() - startTime;
    const timing = response.timing();
    
    const metrics = {
      totalLoadTime: loadTime,
      dnsTime: timing.dnsEnd - timing.dnsStart,
      connectTime: timing.connectEnd - timing.connectStart,
      responseTime: timing.responseEnd - timing.responseStart,
      domContentLoaded: timing.domContentLoadedEventEnd - timing.domContentLoadedEventStart
    };
    
    console.log('Performance Metrics:');
    console.log(`  Total Load Time: ${metrics.totalLoadTime}ms`);
    console.log(`  DNS Lookup: ${metrics.dnsTime}ms`);
    console.log(`  Connection: ${metrics.connectTime}ms`);
    console.log(`  Response: ${metrics.responseTime}ms`);
    console.log(`  DOM Content Loaded: ${metrics.domContentLoaded}ms`);
    
    if (metrics.totalLoadTime < 1000) {
      logTest('Performance', 'PASS', `Load time ${metrics.totalLoadTime}ms (excellent)`);
    } else if (metrics.totalLoadTime < 3000) {
      logTest('Performance', 'WARN', `Load time ${metrics.totalLoadTime}ms (acceptable)`);
    } else {
      logTest('Performance', 'FAIL', `Load time ${metrics.totalLoadTime}ms (too slow)`);
    }
    
    return metrics;
  } catch (error) {
    logTest('Performance', 'FAIL', `Error: ${error.message}`);
    return null;
  }
}

// Test 6: Console Errors Check
async function testConsoleErrors(page) {
  console.log('\n=== Test 6: Console Errors Check ===');
  
  const consoleMessages = [];
  const errors = [];
  
  page.on('console', msg => {
    consoleMessages.push({
      type: msg.type(),
      text: msg.text()
    });
    if (msg.type() === 'error') {
      errors.push(msg.text());
    }
  });
  
  try {
    await page.goto(`${BASE_URL}/user/login`, {
      waitUntil: 'domcontentloaded',
      timeout: TIMEOUT
    });
    
    // Wait a bit for console messages
    await page.waitForTimeout(2000);
    
    console.log(`Total console messages: ${consoleMessages.length}`);
    console.log(`Errors: ${errors.length}`);
    
    if (errors.length > 0) {
      console.log('Console Errors:');
      errors.forEach(err => console.log(`  - ${err}`));
    }
    
    if (errors.length === 0) {
      logTest('Console Errors', 'PASS', 'No JavaScript errors');
    } else if (errors.length < 5) {
      logTest('Console Errors', 'WARN', `${errors.length} errors found`);
    } else {
      logTest('Console Errors', 'FAIL', `${errors.length} errors found`);
    }
    
    return { total: consoleMessages.length, errors: errors.length };
  } catch (error) {
    logTest('Console Errors', 'FAIL', `Error: ${error.message}`);
    return null;
  }
}

// Test 7: Network Request Analysis
async function testNetworkRequests(page) {
  console.log('\n=== Test 7: Network Request Analysis ===');
  
  const requests = [];
  const failed = [];
  
  page.on('request', request => {
    requests.push({
      url: request.url(),
      method: request.method(),
      resourceType: request.resourceType()
    });
  });
  
  page.on('requestfailed', request => {
    failed.push({
      url: request.url(),
      failure: request.failure()
    });
  });
  
  try {
    await page.goto(`${BASE_URL}/user/login`, {
      waitUntil: 'networkidle',
      timeout: TIMEOUT
    });
    
    console.log(`Total requests: ${requests.length}`);
    console.log(`Failed requests: ${failed.length}`);
    
    // Categorize requests
    const byType = {};
    requests.forEach(req => {
      byType[req.resourceType] = (byType[req.resourceType] || 0) + 1;
    });
    
    console.log('Requests by type:');
    Object.entries(byType).forEach(([type, count]) => {
      console.log(`  ${type}: ${count}`);
    });
    
    if (failed.length > 0) {
      console.log('Failed requests:');
      failed.forEach(req => {
        console.log(`  - ${req.url}: ${req.failure?.errorText || 'unknown'}`);
      });
    }
    
    if (failed.length === 0) {
      logTest('Network Requests', 'PASS', `All ${requests.length} requests successful`);
    } else if (failed.length < 5) {
      logTest('Network Requests', 'WARN', `${failed.length} of ${requests.length} requests failed`);
    } else {
      logTest('Network Requests', 'FAIL', `${failed.length} of ${requests.length} requests failed`);
    }
    
    return { total: requests.length, failed: failed.length, byType };
  } catch (error) {
    logTest('Network Requests', 'FAIL', `Error: ${error.message}`);
    return null;
  }
}

// Test 8: Localhost Test (if Apache is accessible)
async function testLocalhost(page) {
  console.log('\n=== Test 8: Localhost Access Test ===');
  try {
    const response = await page.goto(`${LOCALHOST_URL}/user/login`, {
      waitUntil: 'domcontentloaded',
      timeout: 10000
    });
    
    const status = response.status();
    console.log(`Localhost status: ${status}`);
    
    if (status === 200 || status === 302) {
      logTest('Localhost Access', 'PASS', `Status ${status}`);
    } else if (status === 404) {
      logTest('Localhost Access', 'FAIL', 'Status 404 - .htaccess not working');
    } else {
      logTest('Localhost Access', 'WARN', `Status ${status}`);
    }
    
    return { status };
  } catch (error) {
    logTest('Localhost Access', 'WARN', `Could not connect to localhost (expected if remote)`);
    return null;
  }
}

// Main test runner
async function runTests() {
  console.log('====================================');
  console.log('Phase 11: Playwright Comprehensive Tests');
  console.log('====================================');
  console.log(`Start Time: ${results.startTime.toISOString()}`);
  console.log(`Target: ${BASE_URL}`);
  console.log('====================================\n');
  
  let browser;
  try {
    // Launch browser
    browser = await chromium.launch({
      headless: true,
      args: ['--no-sandbox', '--disable-setuid-sandbox']
    });
    
    const context = await browser.newContext({
      ignoreHTTPSErrors: true,
      userAgent: 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 Phase11-Playwright-Test'
    });
    
    const page = await context.newPage();
    
    // Run all tests
    await testProductionHomepage(page);
    await testLoginPage(page);
    await testStaticAssets(page);
    await testCacheHeaders(page);
    await testPerformance(page);
    await testConsoleErrors(page);
    await testNetworkRequests(page);
    await testLocalhost(page);
    
    // Close browser
    await browser.close();
    
  } catch (error) {
    console.error('Fatal error:', error);
    if (browser) await browser.close();
  }
  
  // Print summary
  results.endTime = new Date();
  const duration = (results.endTime - results.startTime) / 1000;
  
  console.log('\n====================================');
  console.log('Test Summary');
  console.log('====================================');
  console.log(`✅ Passed: ${results.summary.passed}`);
  console.log(`❌ Failed: ${results.summary.failed}`);
  console.log(`⚠️  Warnings: ${results.summary.warnings}`);
  console.log(`Total Tests: ${results.tests.length}`);
  console.log(`Duration: ${duration.toFixed(2)}s`);
  console.log(`Success Rate: ${((results.summary.passed / results.tests.length) * 100).toFixed(1)}%`);
  console.log('====================================');
  
  // Save results to file
  const fs = require('fs');
  const reportPath = '/home/pim/public_html/PHASE11_PLAYWRIGHT_TEST_REPORT.json';
  fs.writeFileSync(reportPath, JSON.stringify(results, null, 2));
  console.log(`\nDetailed report saved to: ${reportPath}`);
  
  // Exit with appropriate code
  process.exit(results.summary.failed > 0 ? 1 : 0);
}

// Run tests
runTests().catch(error => {
  console.error('Unhandled error:', error);
  process.exit(1);
});
