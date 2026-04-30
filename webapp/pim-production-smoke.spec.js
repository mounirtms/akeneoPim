// @ts-check
const { test, expect } = require('@playwright/test');

test.describe('Akeneo PIM Production Smoke Tests', () => {
  
  test('PIM homepage loads and redirects to login', async ({ page }) => {
    // Track all requests to check for 404s
    const failedRequests = [];
    
    page.on('response', async (response) => {
      if (response.status() === 404) {
        failedRequests.push(response.url());
      }
    });
    
    // Navigate to PIM
    const response = await page.goto('https://pim.technostationery.com/');
    
    // Should redirect to login or load successfully
    expect([200, 302]).toContain(response.status());
    
    // Wait for page to fully load
    await page.waitForLoadState('networkidle');
    
    // Check that we have some content
    const body = await page.locator('body');
    await expect(body).toBeVisible();
    
    // Report any 404s
    if (failedRequests.length > 0) {
      console.log('⚠️ 404 errors detected:', failedRequests);
    }
    
    // No critical 404s on main assets
    const critical404s = failedRequests.filter(url => 
      url.includes('/css/pim.css') || 
      url.includes('/dist/main.min.js') ||
      url.includes('/dist/vendor.min.js') ||
      url.includes('/js/extensions.json')
    );
    
    expect(critical404s).toHaveLength(0);
  });

  test('CSS and JS assets load correctly', async ({ page }) => {
    await page.goto('https://pim.technostationery.com/');
    await page.waitForLoadState('networkidle');
    
    // Check CSS is loaded
    const cssLink = page.locator('link[rel="stylesheet"][href*="pim.css"]');
    await expect(cssLink).toHaveCount(1);
    
    // Check main JS bundles are loaded
    const scripts = await page.locator('script[src*="dist/"]').all();
    expect(scripts.length).toBeGreaterThan(0);
  });

  test('Login page is accessible', async ({ page }) => {
    const response = await page.goto('https://pim.technostationery.com/user/login');
    expect(response.status()).toBe(200);
    
    // Check for login form elements
    await page.waitForLoadState('networkidle');
    
    // Should have a login form
    const form = page.locator('form');
    await expect(form).toHaveCount(1);
  });

  test('Extensions.json is available', async ({ page }) => {
    const response = await page.goto('https://pim.technostationery.com/js/extensions.json');
    expect(response.status()).toBe(200);
    
    const json = await response.json();
    expect(json).toHaveProperty('extensions');
    expect(json).toHaveProperty('attribute_fields');
  });

  test('Bundle assets are accessible', async ({ page }) => {
    // Test FOS JS routing
    const fosResponse = await page.goto('https://pim.technostationery.com/bundles/fosjsrouting/js/router.min.js');
    expect(fosResponse.status()).toBe(200);
  });

  test('No JavaScript console errors on load', async ({ page }) => {
    const consoleErrors = [];
    
    page.on('console', msg => {
      if (msg.type() === 'error') {
        consoleErrors.push(msg.text());
      }
    });
    
    await page.goto('https://pim.technostationery.com/');
    await page.waitForLoadState('networkidle');
    
    // Filter out known non-critical errors
    const criticalErrors = consoleErrors.filter(err => 
      !err.includes('favicon') && // Ignore favicon errors
      !err.includes('Failed to load resource') // Generic resource loading
    );
    
    // Should have no critical JS errors
    expect(criticalErrors).toHaveLength(0);
  });
});
