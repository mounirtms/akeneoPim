# Instructions

- Following Playwright test failed.
- Explain why, be concise, respect Playwright best practices.
- Provide a snippet of code with the fix, if possible.

# Test info

- Name: akeneo.spec.js >> Akeneo PIM - UI Rendering Tests >> should render app container
- Location: tests/akeneo.spec.js:146:3

# Error details

```
Error: expect(locator).toBeVisible() failed

Locator: locator('.app')
Expected: visible
Timeout: 5000ms
Error: element(s) not found

Call log:
  - Expect "toBeVisible" with timeout 5000ms
  - waiting for locator('.app')

```

# Page snapshot

```yaml
- generic [ref=e5]:
  - generic [ref=e6]:
    - img "Akeneo PIM" [ref=e8]
    - generic [ref=e9]:
      - generic [ref=e13]: Invalid credentials.
      - generic [ref=e14]:
        - generic [ref=e15]:
          - generic [ref=e16]:
            - generic [ref=e17]: Username or Email
            - textbox "Username or Email" [active] [ref=e19]: testadmin
          - generic [ref=e20]:
            - generic [ref=e21]: Password
            - textbox "Password" [ref=e23]
          - link "Forgot your password?" [ref=e25] [cursor=pointer]:
            - /url: /user/reset-request
          - generic [ref=e27] [cursor=pointer]:
            - checkbox "Remember me on this computer" [ref=e28]
            - text: Remember me on this computer
        - button "Login" [ref=e29] [cursor=pointer]
  - link "Powered by logo Akeneo Unlocking Growth Through Product Experiences" [ref=e30] [cursor=pointer]:
    - /url: https://www.akeneo.com/
    - generic [ref=e31]:
      - text: Powered by
      - img "logo Akeneo" [ref=e32]
    - generic [ref=e33]: Unlocking Growth Through Product Experiences
```

# Test source

```ts
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
> 148 |     await expect(appElement).toBeVisible();
      |                              ^ Error: expect(locator).toBeVisible() failed
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
  180 |       }
  181 |     });
  182 |     
  183 |     page.on('pageerror', error => {
  184 |       pageErrors.push(error.message);
  185 |     });
  186 |     
  187 |     await page.goto(`${BASE_URL}/user/login`);
  188 |     await page.fill('input[name="_username"]', TEST_USER.username);
  189 |     await page.fill('input[name="_password"]', TEST_USER.password);
  190 |     await page.click('button[type="submit"]');
  191 |     await page.waitForTimeout(5000);
  192 |     
  193 |     if (consoleErrors.length > 0) {
  194 |       console.log('Console errors:', consoleErrors);
  195 |     }
  196 |     if (pageErrors.length > 0) {
  197 |       console.log('Page errors:', pageErrors);
  198 |     }
  199 |     
  200 |     // We expect some errors due to the known AMD issue, but not many
  201 |     expect(pageErrors.length).toBeLessThan(5);
  202 |   });
  203 | });
  204 | 
  205 | test.describe('Akeneo PIM - Database Connectivity Tests', () => {
  206 |   
  207 |   test('should have working API endpoint', async ({ request }) => {
  208 |     // Test if API is reachable
  209 |     const response = await request.get(`${BASE_URL}/api/rest/v1`);
  210 |     // API requires auth, so 401 is expected but means it's working
  211 |     expect([200, 401, 403]).toContain(response.status());
  212 |   });
  213 | });
  214 | 
```