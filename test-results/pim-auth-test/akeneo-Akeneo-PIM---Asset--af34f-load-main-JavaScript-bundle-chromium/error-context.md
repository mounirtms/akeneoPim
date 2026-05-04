# Instructions

- Following Playwright test failed.
- Explain why, be concise, respect Playwright best practices.
- Provide a snippet of code with the fix, if possible.

# Test info

- Name: akeneo.spec.js >> Akeneo PIM - Asset Loading Tests >> should load main JavaScript bundle
- Location: tests/akeneo.spec.js:102:3

# Error details

```
Error: expect(received).toBe(expected) // Object.is equality

Expected: 200
Received: 404
```

# Page snapshot

```yaml
- generic [active] [ref=e1]:
  - banner [ref=e2]:
    - generic [ref=e3]:
      - heading "Symfony Exception" [level=1] [ref=e4]:
        - img [ref=e5]
        - text: Symfony Exception
      - link "Symfony Docs" [ref=e8] [cursor=pointer]:
        - /url: https://symfony.com/doc/5.4.48/index.html
        - img [ref=e10]
        - text: Symfony Docs
  - generic [ref=e12]:
    - generic [ref=e14]:
      - heading "ResourceNotFoundException NotFoundHttpException" [level=2] [ref=e15]:
        - link "ResourceNotFoundException" [ref=e16] [cursor=pointer]:
          - /url: "#trace-box-2"
        - img [ref=e18]
        - link "NotFoundHttpException" [ref=e20] [cursor=pointer]:
          - /url: "#trace-box-1"
      - heading "HTTP 404 Not Found" [level=2] [ref=e21]
    - generic [ref=e23]:
      - heading "No route found for \"GET https://pim.technostationery.com/dist/main.min.js\"" [level=1] [ref=e24]
      - img [ref=e26]
  - generic [ref=e29]:
    - list [ref=e30]:
      - listitem [ref=e31] [cursor=pointer]:
        - text: Exceptions
        - generic [ref=e32]: "2"
      - listitem [ref=e33] [cursor=pointer]: Logs
      - listitem [ref=e34] [cursor=pointer]:
        - text: Stack Traces
        - generic [ref=e35]: "2"
    - generic [ref=e37]:
      - generic [ref=e39]:
        - generic [ref=e41] [cursor=pointer]:
          - img [ref=e43]
          - heading "Symfony\\Component\\HttpKernel\\Exception\\ NotFoundHttpException" [level=3] [ref=e45]:
            - generic [ref=e46]: Symfony\Component\HttpKernel\Exception\
            - text: NotFoundHttpException
        - generic [ref=e47]:
          - generic [ref=e49] [cursor=pointer]:
            - img [ref=e51]
            - generic [ref=e53]:
              - text: in
              - link "vendor/symfony/http-kernel/EventListener/RouterListener.php" [ref=e54]:
                - /url: ""
                - text: vendor/symfony/http-kernel/EventListener/
                - strong [ref=e55]: RouterListener.php
              - text: (line 135)
          - generic [ref=e57] [cursor=pointer]:
            - img [ref=e59]
            - generic [ref=e61]:
              - text: in
              - link "vendor/symfony/event-dispatcher/Debug/WrappedListener.php" [ref=e62]:
                - /url: ""
                - text: vendor/symfony/event-dispatcher/Debug/
                - strong [ref=e63]: WrappedListener.php
              - text: "-> onKernelRequest (line 118)"
          - generic [ref=e65] [cursor=pointer]:
            - img [ref=e67]
            - generic [ref=e69]:
              - text: in
              - link "vendor/symfony/event-dispatcher/EventDispatcher.php" [ref=e70]:
                - /url: ""
                - text: vendor/symfony/event-dispatcher/
                - strong [ref=e71]: EventDispatcher.php
              - text: "-> __invoke (line 230)"
          - generic [ref=e73] [cursor=pointer]:
            - img [ref=e75]
            - generic [ref=e77]:
              - text: in
              - link "vendor/symfony/event-dispatcher/EventDispatcher.php" [ref=e78]:
                - /url: ""
                - text: vendor/symfony/event-dispatcher/
                - strong [ref=e79]: EventDispatcher.php
              - text: "-> callListeners (line 59)"
              - img [ref=e81]
          - generic [ref=e85] [cursor=pointer]:
            - img [ref=e87]
            - generic [ref=e89]:
              - text: in
              - link "vendor/symfony/event-dispatcher/Debug/TraceableEventDispatcher.php" [ref=e90]:
                - /url: ""
                - text: vendor/symfony/event-dispatcher/Debug/
                - strong [ref=e91]: TraceableEventDispatcher.php
              - text: "-> dispatch (line 154)"
          - generic [ref=e93] [cursor=pointer]:
            - img [ref=e95]
            - generic [ref=e97]:
              - text: in
              - link "vendor/symfony/http-kernel/HttpKernel.php" [ref=e98]:
                - /url: ""
                - text: vendor/symfony/http-kernel/
                - strong [ref=e99]: HttpKernel.php
              - text: "-> dispatch (line 139)"
          - generic [ref=e101] [cursor=pointer]:
            - img [ref=e103]
            - generic [ref=e105]:
              - text: in
              - link "vendor/symfony/http-kernel/HttpKernel.php" [ref=e106]:
                - /url: ""
                - text: vendor/symfony/http-kernel/
                - strong [ref=e107]: HttpKernel.php
              - text: "-> handleRaw (line 75)"
          - generic [ref=e109] [cursor=pointer]:
            - img [ref=e111]
            - generic [ref=e113]:
              - text: in
              - link "vendor/symfony/http-kernel/Kernel.php" [ref=e114]:
                - /url: ""
                - text: vendor/symfony/http-kernel/
                - strong [ref=e115]: Kernel.php
              - text: "-> handle (line 202)"
          - generic [ref=e116]:
            - generic [ref=e117] [cursor=pointer]:
              - img [ref=e119]
              - generic [ref=e121]: Kernel
              - text: "->handle"
              - generic [ref=e122]:
                - text: (
                - emphasis [ref=e123]: object
                - text: (Request))
              - generic [ref=e124]:
                - text: in
                - link "public/index.php" [ref=e125]:
                  - /url: ""
                  - text: public/
                  - strong [ref=e126]: index.php
                - text: (line 62)
            - generic [ref=e127]:
              - list
      - generic [ref=e131] [cursor=pointer]:
        - img [ref=e133]
        - heading "Symfony\\Component\\Routing\\Exception\\ ResourceNotFoundException" [level=3] [ref=e135]:
          - generic [ref=e136]: Symfony\Component\Routing\Exception\
          - text: ResourceNotFoundException
        - paragraph [ref=e137]: No routes found for "/dist/main.min.js/".
```

# Test source

```ts
  4   | const BASE_URL = 'https://pim.technostationery.com';
  5   | const TEST_USER = {
  6   |   username: 'admin',
  7   |   password: 'admin'
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
> 104 |     expect(response.status()).toBe(200);
      |                               ^ Error: expect(received).toBe(expected) // Object.is equality
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
```