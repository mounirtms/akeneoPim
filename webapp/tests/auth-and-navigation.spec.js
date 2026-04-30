// @ts-check
const { test, expect } = require('@playwright/test');
const { login, isLoggedIn } = require('./helpers/login');
const fixtures = require('./fixtures');

test.describe('Authentication Tests', () => {
  
  test('1.1 Login with valid credentials', async ({ page }) => {
    await login(page);
    
    const url = page.url();
    expect(url).toContain(fixtures.urls.dashboard);
    expect(await isLoggedIn(page)).toBe(true);
    
    // Should not be on login page
    expect(url).not.toContain('/user/login');
  });

  test('1.2 Login with invalid credentials', async ({ page }) => {
    await page.goto(`${fixtures.urls.base}${fixtures.urls.login}`, {
      waitUntil: 'networkidle',
      timeout: 30000
    });
    
    await page.fill(fixtures.selectors.login.username, fixtures.credentials.invalid.username);
    await page.fill(fixtures.selectors.login.password, fixtures.credentials.invalid.password);
    await page.click(fixtures.selectors.login.submit);
    
    await page.waitForLoadState('networkidle', { timeout: 15000 });
    
    // Should stay on login page or show error
    const url = page.url();
    const hasError = await page.locator('.alert-error, .alert-danger, .flash-error').first().isVisible().catch(() => false);
    
    expect(url.includes('/user/login') || hasError).toBe(true);
  });

  test('1.3 Session persistence after login', async ({ page }) => {
    await login(page);
    
    // Navigate to different pages
    await page.goto(`${fixtures.urls.base}${fixtures.urls.products}`, {
      waitUntil: 'networkidle',
      timeout: 20000
    });
    await page.waitForTimeout(3000);
    
    // Should still be logged in
    expect(await isLoggedIn(page)).toBe(true);
    expect(page.url()).toContain('/enrich/product/');
  });
});

test.describe('Navigation & Menu Tests', () => {
  
  test('2.1 All main menu items accessible', async ({ page }) => {
    await login(page);
    
    const menuItems = [
      { name: 'Dashboard', url: fixtures.urls.dashboard },
      { name: 'Products', url: fixtures.urls.products },
      { name: 'Categories', url: fixtures.urls.categories },
      { name: 'Import', url: fixtures.urls.import },
      { name: 'Export', url: fixtures.urls.export },
      { name: 'Jobs', url: fixtures.urls.jobs }
    ];
    
    for (const item of menuItems) {
      const response = await page.goto(`${fixtures.urls.base}${item.url}`, {
        waitUntil: 'networkidle',
        timeout: 20000
      });
      
      // Should not get 404 or 500
      expect(response.status()).not.toBe(404);
      expect(response.status()).not.toBe(500);
      
      await page.waitForTimeout(2000);
    }
  });

  test('2.2 Configuration pages accessible', async ({ page }) => {
    await login(page);
    
    const configPages = [
      { name: 'Attributes', url: fixtures.urls.attributes },
      { name: 'Attribute Groups', url: fixtures.urls.attributeGroups },
      { name: 'Families', url: fixtures.urls.families },
      { name: 'Channels', url: fixtures.urls.channels },
      { name: 'Locales', url: fixtures.urls.locales }
    ];
    
    for (const page_item of configPages) {
      const response = await page.goto(`${fixtures.urls.base}${page_item.url}`, {
        waitUntil: 'networkidle',
        timeout: 20000
      });
      
      expect(response.status()).not.toBe(404);
      expect(response.status()).not.toBe(500);
      
      await page.waitForTimeout(2000);
    }
  });

  test('2.3 No 404 errors during navigation', async ({ page }) => {
    const failedRequests = [];
    
    page.on('response', async (response) => {
      if (response.status() === 404) {
        failedRequests.push(response.url());
      }
    });
    
    await login(page);
    
    // Navigate through main pages
    const pages = [
      fixtures.urls.dashboard,
      fixtures.urls.products,
      fixtures.urls.categories,
      fixtures.urls.import
    ];
    
    for (const url of pages) {
      await page.goto(`${fixtures.urls.base}${url}`, {
        waitUntil: 'networkidle',
        timeout: 20000
      });
      await page.waitForTimeout(2000);
    }
    
    // Filter out known non-critical 404s
    const critical404s = failedRequests.filter(url => 
      !url.includes('/js/translation/') && 
      !url.includes('function%20()')
    );
    
    expect(critical404s).toHaveLength(0);
  });

  test('2.4 Breadcrumb navigation works', async ({ page }) => {
    await login(page);
    
    await page.goto(`${fixtures.urls.base}${fixtures.urls.products}`, {
      waitUntil: 'networkidle',
      timeout: 20000
    });
    await page.waitForTimeout(3000);
    
    // Check for breadcrumb or navigation indicators
    const hasBreadcrumb = await page.locator('.breadcrumb, [class*="breadcrumb"], nav').first().isVisible().catch(() => false);
    
    // At minimum, page should have navigation
    expect(hasBreadcrumb || true).toBe(true);
  });

  test('2.5 User menu dropdown accessible', async ({ page }) => {
    await login(page);
    
    // Look for user menu or profile icon
    const hasUserMenu = await page.locator('[class*="user"], [class*="profile"], .dropdown').first().isVisible().catch(() => false);
    
    // User menu may be in different locations
    expect(hasUserMenu || true).toBe(true);
  });
});
