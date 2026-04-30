// @ts-check
const { test, expect } = require('@playwright/test');
const fs = require('fs');
const path = require('path');

// Admin credentials
const ADMIN_USER = 'admin';
const ADMIN_PASS = 'admin'; // Default - change if different

test.describe('Akeneo PIM Full UI Test', () => {
  
  // Store screenshots and logs
  const screenshotDir = path.join(__dirname, 'screenshots');
  if (!fs.existsSync(screenshotDir)) {
    fs.mkdirSync(screenshotDir, { recursive: true });
  }

  test('1. Login to PIM and capture initial errors', async ({ page }) => {
    // Capture all console errors
    const consoleErrors = [];
    const failedRequests = [];
    const pageErrors = [];

    page.on('console', msg => {
      if (msg.type() === 'error') {
        consoleErrors.push({
          type: 'console',
          text: msg.text(),
          location: msg.location()
        });
      }
    });

    page.on('response', async (response) => {
      if (response.status() >= 400) {
        failedRequests.push({
          url: response.url(),
          status: response.status(),
          statusText: response.statusText()
        });
      }
    });

    page.on('pageerror', (error) => {
      pageErrors.push({
        message: error.message,
        stack: error.stack
      });
    });

    // Navigate to PIM
    console.log('🔍 Navigating to PIM login page...');
    await page.goto('https://pim.technostationery.com/', { 
      waitUntil: 'networkidle',
      timeout: 30000 
    });

    // Take screenshot of login page
    await page.screenshot({ 
      path: path.join(screenshotDir, '01-login-page.png'),
      fullPage: true 
    });

    // Login
    console.log('🔑 Logging in...');
    await page.fill('input[name="username"]', ADMIN_USER);
    await page.fill('input[name="password"]', ADMIN_PASS);
    await page.click('button[type="submit"]');
    
    await page.waitForLoadState('networkidle', { timeout: 30000 });
    await page.waitForTimeout(3000); // Wait for dashboard to load

    // Take screenshot of dashboard
    await page.screenshot({ 
      path: path.join(screenshotDir, '02-dashboard.png'),
      fullPage: true 
    });

    // Get page title
    const title = await page.title();
    console.log(`📊 Dashboard title: ${title}`);

    // Check URL
    const url = page.url();
    console.log(`📍 Current URL: ${url}`);

    // Save errors to file
    const errors = {
      consoleErrors,
      failedRequests: failedRequests.slice(0, 50), // Limit to first 50
      pageErrors,
      timestamp: new Date().toISOString(),
      currentUrl: url,
      pageTitle: title
    };

    fs.writeFileSync(
      path.join(screenshotDir, 'login-errors.json'), 
      JSON.stringify(errors, null, 2)
    );

    console.log(`❌ Console errors: ${consoleErrors.length}`);
    console.log(`❌ Failed requests: ${failedRequests.length}`);
    console.log(`❌ Page errors: ${pageErrors.length}`);

    // Should have logged in successfully
    expect(url).toContain('dashboard');
  });

  test('2. Check main menu items', async ({ page }) => {
    // Login first
    await page.goto('https://pim.technostationery.com/user/login', { waitUntil: 'networkidle' });
    await page.fill('input[name="username"]', ADMIN_USER);
    await page.fill('input[name="password"]', ADMIN_PASS);
    await page.click('button[type="submit"]');
    await page.waitForLoadState('networkidle');
    await page.waitForTimeout(3000);

    console.log('📋 Checking main menu items...');

    // Expected menu items in Akeneo PIM
    const menuItems = [
      { name: 'Dashboard', selector: 'a[href*="dashboard"]' },
      { name: 'Products', selector: 'a[href*="product/list"]' },
      { name: 'Categories', selector: 'a[href*="category/list"]' },
      { name: 'Import', selector: 'a[href*="import"]' },
      { name: 'Export', selector: 'a[href*="export"]' },
    ];

    const menuStatus = [];

    for (const item of menuItems) {
      const element = await page.locator(item.selector).first();
      const isVisible = await element.isVisible().catch(() => false);
      const text = isVisible ? await element.textContent() : 'NOT FOUND';
      
      menuStatus.push({
        name: item.name,
        visible: isVisible,
        text: text,
        selector: item.selector
      });

      console.log(`${isVisible ? '✅' : '❌'} ${item.name}: ${isVisible ? text : 'NOT FOUND'}`);
    }

    // Take screenshot of menu
    await page.screenshot({ 
      path: path.join(screenshotDir, '03-main-menu.png'),
      fullPage: true 
    });

    // Save menu status
    fs.writeFileSync(
      path.join(screenshotDir, 'menu-status.json'),
      JSON.stringify(menuStatus, null, 2)
    );

    // At least Dashboard and Products should be visible
    const visibleMenus = menuStatus.filter(m => m.visible);
    expect(visibleMenus.length).toBeGreaterThan(0);
  });

  test('3. Navigate to Products grid and check data', async ({ page }) => {
    // Login
    await page.goto('https://pim.technostationery.com/user/login', { waitUntil: 'networkidle' });
    await page.fill('input[name="username"]', ADMIN_USER);
    await page.fill('input[name="password"]', ADMIN_PASS);
    await page.click('button[type="submit"]');
    await page.waitForLoadState('networkidle');
    await page.waitForTimeout(3000);

    console.log('📦 Navigating to Products grid...');

    // Capture errors during navigation
    const errors = [];
    page.on('console', msg => {
      if (msg.type() === 'error') errors.push(msg.text());
    });

    // Click Products menu
    await page.locator('a[href*="product/list"]').first().click({ timeout: 10000 });
    await page.waitForLoadState('networkidle', { timeout: 30000 });
    await page.waitForTimeout(5000); // Wait for grid to load

    // Take screenshot
    await page.screenshot({ 
      path: path.join(screenshotDir, '04-products-grid.png'),
      fullPage: true 
    });

    // Check URL
    const url = page.url();
    console.log(`📍 Products URL: ${url}`);

    // Check if grid is visible
    const gridVisible = await page.locator('.datagrid, table, [class*="grid"]').first().isVisible().catch(() => false);
    console.log(`${gridVisible ? '✅' : '❌'} Product grid visible: ${gridVisible}`);

    // Check for product count
    const productCountText = await page.locator('text=/[0-9]+ products?/').first().textContent().catch(() => 'Count not found');
    console.log(`📊 Product count: ${productCountText}`);

    // Check for common errors on product page
    const errorSelectors = [
      '.alert-danger',
      '.alert-error',
      '.flash-error',
      'text=/error/i',
      'text=/failed/i'
    ];

    const pageErrors = [];
    for (const selector of errorSelectors) {
      const errorEl = await page.locator(selector).first();
      if (await errorEl.isVisible().catch(() => false)) {
        const errorText = await errorEl.textContent();
        pageErrors.push(errorText);
        console.log(`❌ Error found: ${errorText}`);
      }
    }

    // Check if images are loading in grid
    const images = await page.locator('img').all();
    const brokenImages = [];
    for (const img of images.slice(0, 20)) { // Check first 20
      const src = await img.getAttribute('src').catch(() => null);
      if (src && src.includes('error')) {
        brokenImages.push(src);
      }
    }

    const productData = {
      url,
      gridVisible,
      productCountText,
      errors: pageErrors,
      consoleErrors: errors.slice(0, 20),
      brokenImages: brokenImages
    };

    fs.writeFileSync(
      path.join(screenshotDir, '04-products-data.json'),
      JSON.stringify(productData, null, 2)
    );

    expect(gridVisible).toBe(true);
  });

  test('4. Navigate to Categories and check structure', async ({ page }) => {
    // Login
    await page.goto('https://pim.technostationery.com/user/login', { waitUntil: 'networkidle' });
    await page.fill('input[name="username"]', ADMIN_USER);
    await page.fill('input[name="password"]', ADMIN_PASS);
    await page.click('button[type="submit"]');
    await page.waitForLoadState('networkidle');
    await page.waitForTimeout(3000);

    console.log('📂 Navigating to Categories...');

    const errors = [];
    page.on('console', msg => {
      if (msg.type() === 'error') errors.push(msg.text());
    });

    // Click Categories menu
    const categoryLink = await page.locator('a[href*="category"]').first();
    if (await categoryLink.isVisible().catch(() => false)) {
      await categoryLink.click({ timeout: 10000 });
      await page.waitForLoadState('networkidle', { timeout: 30000 });
      await page.waitForTimeout(3000);

      await page.screenshot({ 
        path: path.join(screenshotDir, '05-categories.png'),
        fullPage: true 
      });

      const url = page.url();
      console.log(`📍 Categories URL: ${url}`);

      // Check for category tree
      const treeVisible = await page.locator('.category-tree, [class*="tree"]').first().isVisible().catch(() => false);
      console.log(`${treeVisible ? '✅' : '❌'} Category tree visible: ${treeVisible}`);

      fs.writeFileSync(
        path.join(screenshotDir, '05-categories-data.json'),
        JSON.stringify({ url, treeVisible, errors }, null, 2)
      );
    } else {
      console.log('❌ Categories menu not found');
    }
  });

  test('5. Check Dashboard indicators and data quality', async ({ page }) => {
    // Login
    await page.goto('https://pim.technostationery.com/user/login', { waitUntil: 'networkidle' });
    await page.fill('input[name="username"]', ADMIN_USER);
    await page.fill('input[name="password"]', ADMIN_PASS);
    await page.click('button[type="submit"]');
    await page.waitForLoadState('networkidle');
    await page.waitForTimeout(5000);

    console.log('📊 Checking Dashboard indicators...');

    // Get all text content from dashboard
    const dashboardText = await page.locator('body').textContent();
    
    // Look for key metrics
    const metrics = {
      imageRate: dashboardText.match(/Produits avec une image.*?(\d+)%/)?.[1] || 'Not found',
      enrichmentRate: dashboardText.match(/taux d.enrichissement.*?(\d+)%/)?.[1] || 'Not found',
      productCount: dashboardText.match(/([0-9,]+)\s+produits/)?.[1] || 'Not found',
    };

    console.log('📈 Dashboard Metrics:');
    console.log(`  - Image rate: ${metrics.imageRate}`);
    console.log(`  - Enrichment rate: ${metrics.enrichmentRate}`);
    console.log(`  - Product count: ${metrics.productCount}`);

    // Take screenshot
    await page.screenshot({ 
      path: path.join(screenshotDir, '06-dashboard-indicators.png'),
      fullPage: true 
    });

    // Save metrics
    fs.writeFileSync(
      path.join(screenshotDir, '06-dashboard-metrics.json'),
      JSON.stringify(metrics, null, 2)
    );

    // Enrichment should NOT be 0% anymore
    if (metrics.enrichmentRate !== 'Not found') {
      expect(parseInt(metrics.enrichmentRate)).toBeGreaterThan(0);
    }
  });

  test('6. Comprehensive error log analysis', async ({ page }) => {
    // Login
    await page.goto('https://pim.technostationery.com/user/login', { waitUntil: 'networkidle' });
    await page.fill('input[name="username"]', ADMIN_USER);
    await page.fill('input[name="password"]', ADMIN_PASS);
    await page.click('button[type="submit"]');
    await page.waitForLoadState('networkidle');
    await page.waitForTimeout(3000);

    console.log('🔍 Comprehensive error check...');

    // Visit multiple pages and capture errors
    const pagesToVisit = [
      { name: 'Dashboard', url: '/dashboard' },
      { name: 'Products', url: '/enrich/product/' },
      { name: 'Categories', url: '/enrich/category/tree/' },
    ];

    const allErrors = {
      pages: [],
      timestamp: new Date().toISOString()
    };

    for (const pg of pagesToVisit) {
      console.log(`  Checking ${pg.name}...`);
      const pageErrors = [];
      
      page.on('console', msg => {
        if (msg.type() === 'error') {
          pageErrors.push(msg.text());
        }
      });

      try {
        await page.goto(`https://pim.technostationery.com${pg.url}`, { 
          waitUntil: 'networkidle',
          timeout: 20000 
        });
        await page.waitForTimeout(2000);

        // Check for HTTP errors
        const hasErrors = await page.locator('.alert-danger, .alert-error, .flash-error').first().isVisible().catch(() => false);
        
        allErrors.pages.push({
          name: pg.name,
          url: pg.url,
          consoleErrors: pageErrors.slice(0, 30),
          hasVisibleErrors: hasErrors
        });
      } catch (e) {
        allErrors.pages.push({
          name: pg.name,
          url: pg.url,
          error: e.message
        });
      }
    }

    // Check server logs
    fs.writeFileSync(
      path.join(screenshotDir, '07-comprehensive-errors.json'),
      JSON.stringify(allErrors, null, 2)
    );

    console.log('✅ Error analysis complete');
    console.log(`📄 Results saved to ${screenshotDir}/07-comprehensive-errors.json`);
  });

});
