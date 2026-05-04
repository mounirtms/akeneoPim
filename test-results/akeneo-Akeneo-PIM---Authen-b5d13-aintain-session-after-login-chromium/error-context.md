# Instructions

- Following Playwright test failed.
- Explain why, be concise, respect Playwright best practices.
- Provide a snippet of code with the fix, if possible.

# Test info

- Name: akeneo.spec.js >> Akeneo PIM - Authentication Tests >> should maintain session after login
- Location: tests/akeneo.spec.js:65:3

# Error details

```
Error: expect(received).not.toContain(expected) // indexOf

Expected substring: not "/user/login"
Received string:        "https://pim.technostationery.com/user/login"
```

# Page snapshot

```yaml
- generic [ref=e5]:
  - generic [ref=e6]:
    - img "Akeneo PIM" [ref=e8]
    - generic [ref=e10]:
      - generic [ref=e11]:
        - generic [ref=e12]:
          - generic [ref=e13]: Username or Email
          - textbox "Username or Email" [active] [ref=e15]: testadmin
        - generic [ref=e16]:
          - generic [ref=e17]: Password
          - textbox "Password" [ref=e19]
        - link "Forgot your password?" [ref=e21] [cursor=pointer]:
          - /url: /user/reset-request
        - generic [ref=e23] [cursor=pointer]:
          - checkbox "Remember me on this computer" [ref=e24]
          - text: Remember me on this computer
      - button "Login" [ref=e25] [cursor=pointer]
  - link "Powered by logo Akeneo Unlocking Growth Through Product Experiences" [ref=e26] [cursor=pointer]:
    - /url: https://www.akeneo.com/
    - generic [ref=e27]:
      - text: Powered by
      - img "logo Akeneo" [ref=e28]
    - generic [ref=e29]: Unlocking Growth Through Product Experiences
```

# Test source

```ts
  1   | const { test, expect } = require('@playwright/test');
  2   | 
  3   | // Test configuration
  4   | const BASE_URL = 'https://pim.technostationery.com';
  5   | const TEST_USER = {
  6   |   username: 'testadmin',
  7   |   password: 'testpass'
  8   | };
  9   | 
  10  | test.describe('Akeneo PIM - Authentication Tests', () => {
  11  |   
  12  |   test('should load login page with correct elements', async ({ page }) => {
  13  |     await page.goto(`${BASE_URL}/user/login`, { waitUntil: 'networkidle' });
  14  |     
  15  |     // Check page title
  16  |     await expect(page).toHaveTitle(/Connexion|Login/);
  17  |     
  18  |     // Check form elements exist
  19  |     await expect(page.locator('input[name="_username"]')).toBeVisible();
  20  |     await expect(page.locator('input[name="_password"]')).toBeVisible();
  21  |     await expect(page.locator('button[type="submit"]')).toBeVisible();
  22  |     
  23  |     // Check CSRF token exists
  24  |     const csrfToken = await page.locator('input[name="_csrf_token"]').getAttribute('value');
  25  |     expect(csrfToken).toBeTruthy();
  26  |     expect(csrfToken.length).toBeGreaterThan(10);
  27  |   });
  28  | 
  29  |   test('should show error for invalid credentials', async ({ page }) => {
  30  |     await page.goto(`${BASE_URL}/user/login`);
  31  |     
  32  |     await page.fill('input[name="_username"]', 'invaliduser');
  33  |     await page.fill('input[name="_password"]', 'wrongpassword');
  34  |     await page.click('button[type="submit"]');
  35  |     
  36  |     await page.waitForTimeout(2000);
  37  |     
  38  |     // Should still be on login page
  39  |     expect(page.url()).toContain('/user/login');
  40  |     
  41  |     // Should show error message
  42  |     const errorText = await page.textContent('body');
  43  |     expect(errorText).toMatch(/Invalid|invalide/i);
  44  |   });
  45  | 
  46  |   test('should successfully login with valid credentials', async ({ page }) => {
  47  |     await page.goto(`${BASE_URL}/user/login`);
  48  |     
  49  |     await page.fill('input[name="_username"]', TEST_USER.username);
  50  |     await page.fill('input[name="_password"]', TEST_USER.password);
  51  |     await page.click('button[type="submit"]');
  52  |     
  53  |     // Wait for redirect
  54  |     await page.waitForTimeout(3000);
  55  |     await page.waitForLoadState('networkidle');
  56  |     
  57  |     // Should redirect away from login
  58  |     expect(page.url()).not.toContain('/user/login');
  59  |     
  60  |     // Should have app element
  61  |     const appExists = await page.locator('.app').count();
  62  |     expect(appExists).toBeGreaterThan(0);
  63  |   });
  64  | 
  65  |   test('should maintain session after login', async ({ page }) => {
  66  |     // Login first
  67  |     await page.goto(`${BASE_URL}/user/login`);
  68  |     await page.fill('input[name="_username"]', TEST_USER.username);
  69  |     await page.fill('input[name="_password"]', TEST_USER.password);
  70  |     await page.click('button[type="submit"]');
  71  |     await page.waitForTimeout(3000);
  72  |     await page.waitForLoadState('networkidle');
  73  |     
  74  |     // Navigate to dashboard directly
  75  |     await page.goto(BASE_URL);
  76  |     await page.waitForTimeout(2000);
  77  |     
  78  |     // Should not redirect to login
> 79  |     expect(page.url()).not.toContain('/user/login');
      |                            ^ Error: expect(received).not.toContain(expected) // indexOf
  80  |   });
  81  | });
  82  | 
  83  | test.describe('Akeneo PIM - Asset Loading Tests', () => {
  84  |   
  85  |   test.beforeEach(async ({ page }) => {
  86  |     // Login before each test
  87  |     await page.goto(`${BASE_URL}/user/login`);
  88  |     await page.fill('input[name="_username"]', TEST_USER.username);
  89  |     await page.fill('input[name="_password"]', TEST_USER.password);
  90  |     await page.click('button[type="submit"]');
  91  |     await page.waitForTimeout(3000);
  92  |     await page.waitForLoadState('networkidle');
  93  |     await page.waitForTimeout(3000);
  94  |   });
  95  | 
  96  |   test('should load CSS files successfully', async ({ page }) => {
  97  |     const response = await page.goto(`${BASE_URL}/css/pim.css`);
  98  |     expect(response.status()).toBe(200);
  99  |     expect(response.headers()['content-type']).toContain('text/css');
  100 |   });
  101 | 
  102 |   test('should load main JavaScript bundle', async ({ page }) => {
  103 |     const response = await page.goto(`${BASE_URL}/dist/main.min.js`);
  104 |     expect(response.status()).toBe(200);
  105 |     expect(response.headers()['content-type']).toContain('javascript');
  106 |   });
  107 | 
  108 |   test('should load vendor JavaScript bundle', async ({ page }) => {
  109 |     const response = await page.goto(`${BASE_URL}/dist/vendor.min.js`);
  110 |     expect(response.status()).toBe(200);
  111 |     expect(response.headers()['content-type']).toContain('javascript');
  112 |   });
  113 | 
  114 |   test('should have no 404 errors on dashboard', async ({ page }) => {
  115 |     const failed404s = [];
  116 |     
  117 |     page.on('response', response => {
  118 |       if (response.status() === 404 && !response.url().includes('google-analytics') && !response.url().includes('clarity')) {
  119 |         failed404s.push(response.url());
  120 |       }
  121 |     });
  122 |     
  123 |     await page.goto(BASE_URL);
  124 |     await page.waitForTimeout(5000);
  125 |     
  126 |     if (failed404s.length > 0) {
  127 |       console.log('404 Errors found:', failed404s);
  128 |     }
  129 |     
  130 |     expect(failed404s.length).toBe(0);
  131 |   });
  132 | });
  133 | 
  134 | test.describe('Akeneo PIM - UI Rendering Tests', () => {
  135 |   
  136 |   test.beforeEach(async ({ page }) => {
  137 |     await page.goto(`${BASE_URL}/user/login`);
  138 |     await page.fill('input[name="_username"]', TEST_USER.username);
  139 |     await page.fill('input[name="_password"]', TEST_USER.password);
  140 |     await page.click('button[type="submit"]');
  141 |     await page.waitForTimeout(3000);
  142 |     await page.waitForLoadState('networkidle');
  143 |     await page.waitForTimeout(5000);
  144 |   });
  145 | 
  146 |   test('should render app container', async ({ page }) => {
  147 |     const appElement = page.locator('.app');
  148 |     await expect(appElement).toBeVisible();
  149 |   });
  150 | 
  151 |   test('should show loading screen initially', async ({ page }) => {
  152 |     // The known issue: page gets stuck on loading screen
  153 |     const loadingScreen = page.locator('[class*="loading"], [class*="Loading"], .AknDefault-progressContainer');
  154 |     const hasLoading = await loadingScreen.count();
  155 |     
  156 |     // Document the known issue
  157 |     if (hasLoading > 0) {
  158 |       console.log('⚠️  Known Issue: Loading screen present (AMD/ES6 module issue)');
  159 |       const loadingText = await loadingScreen.textContent();
  160 |       console.log('Loading text:', loadingText);
  161 |     }
  162 |   });
  163 | 
  164 |   test('should have correct page title after login', async ({ page }) => {
  165 |     const title = await page.title();
  166 |     console.log('Page title:', title);
  167 |     expect(title).toBeTruthy();
  168 |   });
  169 | });
  170 | 
  171 | test.describe('Akeneo PIM - Console Error Tests', () => {
  172 |   
  173 |   test('should have no critical JavaScript errors', async ({ page }) => {
  174 |     const consoleErrors = [];
  175 |     const pageErrors = [];
  176 |     
  177 |     page.on('console', msg => {
  178 |       if (msg.type() === 'error') {
  179 |         consoleErrors.push(msg.text());
```