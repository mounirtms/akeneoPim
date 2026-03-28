const {chromium} = require('playwright');

(async () => {
  const browser = await chromium.launch({headless: true});
  const context = await browser.newContext({ignoreHTTPSErrors: true});
  const page = await context.newPage();
  
  const results = {passed: 0, failed: 0, tests: []};
  
  function test(name, passed, detail) {
    results.tests.push({name, passed, detail: detail || ''});
    if (passed) results.passed++;
    else results.failed++;
    console.log(`${passed ? '✅' : '❌'} ${name}${detail ? ' - ' + detail : ''}`);
  }

  const errors = [];
  page.on('pageerror', err => errors.push(err.message.substring(0, 200)));

  try {
    // ==========================================
    // SECTION 1: LOGIN & AUTHENTICATION
    // ==========================================
    console.log('\n🔐 === LOGIN & AUTHENTICATION ===');
    
    await page.goto('https://pim.technostationery.com/user/login', {waitUntil: 'networkidle', timeout: 30000});
    const loginPageTitle = await page.title();
    test('Login page loads (HTTP 200)', loginPageTitle === 'Login', `title: ${loginPageTitle}`);
    
    const hasLoginForm = !!(await page.$('input[name="_username"]'));
    test('Login form has username/password fields', hasLoginForm);
    
    await page.fill('input[name="_username"]', 'admin');
    await page.fill('input[name="_password"]', 'admin');
    await page.click('button[type="submit"]');
    await page.waitForNavigation({waitUntil: 'networkidle', timeout: 30000}).catch(() => {});
    
    const afterLoginUrl = page.url();
    test('Login redirects to SPA', !afterLoginUrl.includes('/user/login'), `URL: ${afterLoginUrl}`);
    
    // Wait for SPA to fully initialize
    await page.waitForTimeout(18000);
    
    // ==========================================
    // SECTION 2: SPA UI RENDERING
    // ==========================================
    console.log('\n🖥️  === SPA UI RENDERING ===');
    
    const spaState = await page.evaluate(() => {
      const app = document.querySelector('.app');
      const menu = document.querySelector('[data-drop-zone="menu"]');
      const container = document.querySelector('#container');
      const navItems = menu ? menu.querySelectorAll('a') : [];
      return {
        hasApp: !!app,
        hasMenu: !!menu,
        menuChildren: menu ? menu.children.length : 0,
        hasContainer: !!container,
        containerChildren: container ? container.children.length : 0,
        navItemCount: navItems.length,
        hasAknHeader: !!menu && menu.innerHTML.includes('AknHeader'),
        bodyText: document.body.innerText.substring(0, 500),
        pageTitle: document.title,
      };
    });
    
    test('SPA app element exists', spaState.hasApp);
    test('Menu zone renders with children', spaState.menuChildren > 0, `${spaState.menuChildren} children`);
    test('Container zone renders with children', spaState.containerChildren > 0, `${spaState.containerChildren} children`);
    test('Menu has navigation items (links)', spaState.navItemCount > 0, `${spaState.navItemCount} nav links`);
    test('Menu has AknHeader structure', spaState.hasAknHeader);
    test('Dashboard content visible', spaState.bodyText.length > 20, `body text: ${spaState.bodyText.substring(0, 60)}...`);
    
    // ==========================================
    // SECTION 3: ADMIN USER VERIFICATION
    // ==========================================
    console.log('\n📧 === ADMIN USER VERIFICATION ===');
    
    const userInfo = await page.evaluate(async () => {
      const resp = await fetch('/rest/user/', {credentials: 'same-origin'});
      return await resp.json();
    });
    test('Admin email is mounir.webdev.tms@gmail.com', userInfo.email === 'mounir.webdev.tms@gmail.com', `email: ${userInfo.email}`);
    test('Admin username is admin', userInfo.username === 'admin', `username: ${userInfo.username}`);
    test('Admin account is enabled', userInfo.enabled === true);
    
    // ==========================================
    // SECTION 4: REST API ENDPOINTS (Session-based)
    // ==========================================
    console.log('\n📡 === REST API ENDPOINTS (Session) ===');
    
    const sessionEndpoints = [
      {name: 'User Info', url: '/rest/user/', check: (d) => d.includes('"username":"admin"')},
      {name: 'Categories', url: '/enrich/category/rest', check: (d) => d.includes('"master"')},
      {name: 'Locales', url: '/configuration/locale/rest', check: (d) => d.includes('"en_US"')},
    ];
    
    for (const ep of sessionEndpoints) {
      const result = await page.evaluate(async (url) => {
        const resp = await fetch(url, {credentials: 'same-origin'});
        return {status: resp.status, body: await resp.text()};
      }, ep.url);
      test(`REST ${ep.name}`, result.status === 200 && ep.check(result.body), `HTTP ${result.status}`);
    }
    
    // ==========================================
    // SECTION 5: NAVIGATION ROUTES
    // ==========================================
    console.log('\n🧭 === NAVIGATION ROUTES ===');
    
    const routes = [
      {name: 'Products Grid', hash: '#/enrich/product/', titleCheck: 'Products'},
      {name: 'Channels', hash: '#/configuration/channel/', titleCheck: 'Channels'},
    ];
    
    for (const route of routes) {
      await page.evaluate(h => window.location.hash = h, route.hash);
      await page.waitForTimeout(5000);
      const title = await page.title();
      test(`Route: ${route.name}`, title === route.titleCheck, `title: ${title}`);
    }
    
    // ==========================================
    // SECTION 6: OAUTH API ENDPOINTS
    // ==========================================
    console.log('\n🔑 === OAUTH API ENDPOINTS ===');
    
    const tokenResult = await page.evaluate(async () => {
      const resp = await fetch('/api/oauth/v1/token', {
        method: 'POST',
        headers: {'Content-Type': 'application/json'},
        body: JSON.stringify({
          grant_type: 'password',
          client_id: '1_3yhbczkw7osgcw8wg44k84os4sc04w4wc80ks08sw8cc8c40sw',
          client_secret: '50vx3l4u4l4wwcsok4kcwkoo44oo0s0o8s0kcs0gc0c8g0oow4',
          username: 'admin',
          password: 'admin',
        }),
      });
      const data = await resp.json();
      return {status: resp.status, hasToken: !!data.access_token, token: data.access_token};
    });
    test('OAuth token endpoint', tokenResult.status === 200 && tokenResult.hasToken, `HTTP ${tokenResult.status}`);
    
    if (tokenResult.hasToken) {
      const bearerEndpoints = [
        {name: 'Products', url: '/api/rest/v1/products?limit=5', check: (d) => d.items && d.items.length > 0},
        {name: 'Categories', url: '/api/rest/v1/categories?limit=5', check: (d) => d.items && d.items.length > 0},
        {name: 'Channels', url: '/api/rest/v1/channels', check: (d) => d.items && d.items.length > 0},
        {name: 'Attributes', url: '/api/rest/v1/attributes?limit=5', check: (d) => d.items && d.items.length > 0},
        {name: 'Families', url: '/api/rest/v1/families?limit=5', check: (d) => d.items !== undefined},
        {name: 'Locales', url: '/api/rest/v1/locales?limit=5', check: (d) => d.items && d.items.length > 0},
        {name: 'Currencies', url: '/api/rest/v1/currencies?limit=5', check: (d) => d.items && d.items.length > 0},
        {name: 'Attribute Groups', url: '/api/rest/v1/attribute-groups?limit=5', check: (d) => d.items && d.items.length > 0},
      ];
      
      for (const ep of bearerEndpoints) {
        const result = await page.evaluate(async ({url, token}) => {
          const resp = await fetch(url, {headers: {'Authorization': 'Bearer ' + token}});
          if (resp.status !== 200) return {status: resp.status, data: null};
          const data = await resp.json();
          return {status: resp.status, data: {items: (data._embedded || {}).items || []}};
        }, {url: ep.url, token: tokenResult.token});
        const passed = result.status === 200 && ep.check(result.data);
        const itemCount = result.data ? result.data.items.length : 0;
        test(`API ${ep.name}`, passed, `HTTP ${result.status}, ${itemCount} items`);
      }
      
      // ==========================================
      // SECTION 7: PRODUCT CATALOG DATA
      // ==========================================
      console.log('\n📦 === PRODUCT CATALOG DATA ===');
      
      const productsResult = await page.evaluate(async (token) => {
        const resp = await fetch('/api/rest/v1/products?limit=10', {
          headers: {'Authorization': 'Bearer ' + token}
        });
        const data = await resp.json();
        return (data._embedded || {}).items || [];
      }, tokenResult.token);
      
      test('Products exist in catalog', productsResult.length >= 3, `${productsResult.length} products`);
      
      const productNames = productsResult.map(p => {
        const nameVals = (p.values || {}).name || [];
        return nameVals.length > 0 ? nameVals[0].data : 'N/A';
      });
      test('Products have names', productNames.every(n => n !== 'N/A'), productNames.join(', '));
      
      const hasPrices = productsResult.every(p => {
        const priceVals = (p.values || {}).price || [];
        return priceVals.length > 0;
      });
      test('Products have prices', hasPrices);
      
      const hasFamily = productsResult.every(p => p.family === 'stationery');
      test('Products belong to stationery family', hasFamily);
    }
    
    // ==========================================
    // SECTION 8: SESSION SECURITY
    // ==========================================
    console.log('\n🔒 === SESSION SECURITY ===');
    
    const cookies = await context.cookies('https://pim.technostationery.com');
    const sessionCookie = cookies.find(c => c.name === 'BAPID' || c.name === 'PHPSESSID');
    test('Session cookie exists (BAPID or PHPSESSID)', !!sessionCookie, sessionCookie ? `name: ${sessionCookie.name}` : '');
    if (sessionCookie) {
      test('Session cookie is HttpOnly', sessionCookie.httpOnly === true);
      test('Session cookie is Secure', sessionCookie.secure === true);
      test('Session cookie has SameSite=Lax', sessionCookie.sameSite === 'Lax');
    }
    
    // ==========================================
    // SUMMARY
    // ==========================================
    const themeErrors = errors.filter(e => e.includes('Cannot read properties of undefined'));
    const classErrors = errors.filter(e => e.includes('className is not defined'));
    
    console.log('\n' + '='.repeat(60));
    console.log(`📊 FINAL RESULTS: ${results.passed} passed, ${results.failed} failed out of ${results.tests.length} tests`);
    console.log(`🐛 Page errors: ${errors.length} (theme: ${themeErrors.length}, className: ${classErrors.length})`);
    if (errors.length > 0) {
      console.log('   Errors:');
      [...new Set(errors)].forEach(e => console.log(`   - ${e.substring(0, 120)}`));
    }
    console.log('='.repeat(60));
    
    if (results.failed === 0) {
      console.log('\n🎉 ALL TESTS PASSED! Platform is fully functional.\n');
    }
    
  } catch (e) {
    console.error('💥 FATAL:', e.message);
  }
  
  await browser.close();
})();
