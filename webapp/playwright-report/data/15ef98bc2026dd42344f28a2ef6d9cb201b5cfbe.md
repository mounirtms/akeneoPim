# Instructions

- Following Playwright test failed.
- Explain why, be concise, respect Playwright best practices.
- Provide a snippet of code with the fix, if possible.

# Test info

- Name: akeneo.spec.js >> Akeneo PIM - Authentication Tests >> should load login page with correct elements
- Location: tests/akeneo.spec.js:12:3

# Error details

```
Error: expect(page).toHaveTitle(expected) failed

Expected pattern: /Connexion|Login/
Received string:  ""
Timeout: 5000ms

Call log:
  - Expect "toHaveTitle" with timeout 5000ms
    9 × unexpected value ""

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
          - textbox "Username or Email" [active] [ref=e15]
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
> 16  |     await expect(page).toHaveTitle(/Connexion|Login/);
      |                        ^ Error: expect(page).toHaveTitle(expected) failed
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
  79  |     expect(page.url()).not.toContain('/user/login');
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
```