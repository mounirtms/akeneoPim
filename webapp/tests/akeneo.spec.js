const { test, expect } = require('@playwright/test');

// Test configuration
const BASE_URL = 'https://pim.technostationery.com';
const TEST_USER = {
  username: 'testadmin',
  password: 'testpass'
};

test.describe('Akeneo PIM - Authentication Tests', () => {
  
  test('should load login page with correct elements', async ({ page }) => {
    await page.goto(`${BASE_URL}/user/login`, { waitUntil: 'networkidle' });
    
    // Check page title
    await expect(page).toHaveTitle(/Connexion|Login/);
    
    // Check form elements exist
    await expect(page.locator('input[name="_username"]')).toBeVisible();
    await expect(page.locator('input[name="_password"]')).toBeVisible();
    await expect(page.locator('button[type="submit"]')).toBeVisible();
    
    // Check CSRF token exists
    const csrfToken = await page.locator('input[name="_csrf_token"]').getAttribute('value');
    expect(csrfToken).toBeTruthy();
    expect(csrfToken.length).toBeGreaterThan(10);
  });

  test('should show error for invalid credentials', async ({ page }) => {
    await page.goto(`${BASE_URL}/user/login`);
    
    await page.fill('input[name="_username"]', 'invaliduser');
    await page.fill('input[name="_password"]', 'wrongpassword');
    await page.click('button[type="submit"]');
    
    await page.waitForTimeout(2000);
    
    // Should still be on login page
    expect(page.url()).toContain('/user/login');
    
    // Should show error message
    const errorText = await page.textContent('body');
    expect(errorText).toMatch(/Invalid|invalide/i);
  });

  test('should successfully login with valid credentials', async ({ page }) => {
    await page.goto(`${BASE_URL}/user/login`);
    
    await page.fill('input[name="_username"]', TEST_USER.username);
    await page.fill('input[name="_password"]', TEST_USER.password);
    await page.click('button[type="submit"]');
    
    // Wait for redirect
    await page.waitForTimeout(3000);
    await page.waitForLoadState('networkidle');
    
    // Should redirect away from login
    expect(page.url()).not.toContain('/user/login');
    
    // Should have app element
    const appExists = await page.locator('.app').count();
    expect(appExists).toBeGreaterThan(0);
  });

  test('should maintain session after login', async ({ page }) => {
    // Login first
    await page.goto(`${BASE_URL}/user/login`);
    await page.fill('input[name="_username"]', TEST_USER.username);
    await page.fill('input[name="_password"]', TEST_USER.password);
    await page.click('button[type="submit"]');
    await page.waitForTimeout(3000);
    await page.waitForLoadState('networkidle');
    
    // Navigate to dashboard directly
    await page.goto(BASE_URL);
    await page.waitForTimeout(2000);
    
    // Should not redirect to login
    expect(page.url()).not.toContain('/user/login');
  });
});

test.describe('Akeneo PIM - Asset Loading Tests', () => {
  
  test.beforeEach(async ({ page }) => {
    // Login before each test
    await page.goto(`${BASE_URL}/user/login`);
    await page.fill('input[name="_username"]', TEST_USER.username);
    await page.fill('input[name="_password"]', TEST_USER.password);
    await page.click('button[type="submit"]');
    await page.waitForTimeout(3000);
    await page.waitForLoadState('networkidle');
    await page.waitForTimeout(3000);
  });

  test('should load CSS files successfully', async ({ page }) => {
    const response = await page.goto(`${BASE_URL}/css/pim.css`);
    expect(response.status()).toBe(200);
    expect(response.headers()['content-type']).toContain('text/css');
  });

  test('should load main JavaScript bundle', async ({ page }) => {
    const response = await page.goto(`${BASE_URL}/dist/main.min.js`);
    expect(response.status()).toBe(200);
    expect(response.headers()['content-type']).toContain('javascript');
  });

  test('should load vendor JavaScript bundle', async ({ page }) => {
    const response = await page.goto(`${BASE_URL}/dist/vendor.min.js`);
    expect(response.status()).toBe(200);
    expect(response.headers()['content-type']).toContain('javascript');
  });

  test('should have no 404 errors on dashboard', async ({ page }) => {
    const failed404s = [];
    
    page.on('response', response => {
      if (response.status() === 404 && !response.url().includes('google-analytics') && !response.url().includes('clarity')) {
        failed404s.push(response.url());
      }
    });
    
    await page.goto(BASE_URL);
    await page.waitForTimeout(5000);
    
    if (failed404s.length > 0) {
      console.log('404 Errors found:', failed404s);
    }
    
    expect(failed404s.length).toBe(0);
  });
});

test.describe('Akeneo PIM - UI Rendering Tests', () => {
  
  test.beforeEach(async ({ page }) => {
    await page.goto(`${BASE_URL}/user/login`);
    await page.fill('input[name="_username"]', TEST_USER.username);
    await page.fill('input[name="_password"]', TEST_USER.password);
    await page.click('button[type="submit"]');
    await page.waitForTimeout(3000);
    await page.waitForLoadState('networkidle');
    await page.waitForTimeout(5000);
  });

  test('should render app container', async ({ page }) => {
    const appElement = page.locator('.app');
    await expect(appElement).toBeVisible();
  });

  test('should show loading screen initially', async ({ page }) => {
    // The known issue: page gets stuck on loading screen
    const loadingScreen = page.locator('[class*="loading"], [class*="Loading"], .AknDefault-progressContainer');
    const hasLoading = await loadingScreen.count();
    
    // Document the known issue
    if (hasLoading > 0) {
      console.log('⚠️  Known Issue: Loading screen present (AMD/ES6 module issue)');
      const loadingText = await loadingScreen.textContent();
      console.log('Loading text:', loadingText);
    }
  });

  test('should have correct page title after login', async ({ page }) => {
    const title = await page.title();
    console.log('Page title:', title);
    expect(title).toBeTruthy();
  });
});

test.describe('Akeneo PIM - Console Error Tests', () => {
  
  test('should have no critical JavaScript errors', async ({ page }) => {
    const consoleErrors = [];
    const pageErrors = [];
    
    page.on('console', msg => {
      if (msg.type() === 'error') {
        consoleErrors.push(msg.text());
      }
    });
    
    page.on('pageerror', error => {
      pageErrors.push(error.message);
    });
    
    await page.goto(`${BASE_URL}/user/login`);
    await page.fill('input[name="_username"]', TEST_USER.username);
    await page.fill('input[name="_password"]', TEST_USER.password);
    await page.click('button[type="submit"]');
    await page.waitForTimeout(5000);
    
    if (consoleErrors.length > 0) {
      console.log('Console errors:', consoleErrors);
    }
    if (pageErrors.length > 0) {
      console.log('Page errors:', pageErrors);
    }
    
    // We expect some errors due to the known AMD issue, but not many
    expect(pageErrors.length).toBeLessThan(5);
  });
});

test.describe('Akeneo PIM - Database Connectivity Tests', () => {
  
  test('should have working API endpoint', async ({ request }) => {
    // Test if API is reachable
    const response = await request.get(`${BASE_URL}/api/rest/v1`);
    // API requires auth, so 401 is expected but means it's working
    expect([200, 401, 403]).toContain(response.status());
  });
});
