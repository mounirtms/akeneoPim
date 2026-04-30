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
    // ========== 1. LOGIN PAGE ==========
    console.log('\n🔐 === LOGIN TEST ===');
    await page.goto('https://pim.technostationery.com/user/login', {waitUntil: 'networkidle', timeout: 30000});
    const loginPageTitle = await page.title();
    test('Login page loads', loginPageTitle === 'Login', `title: ${loginPageTitle}`);
    
    const hasLoginForm = !!(await page.$('input[name="_username"]'));
    test('Login form present', hasLoginForm);
    
    // ========== 2. AUTHENTICATE ==========
    await page.fill('input[name="_username"]', 'admin');
    await page.fill('input[name="_password"]', 'admin');
    await page.click('button[type="submit"]');
    await page.waitForNavigation({waitUntil: 'networkidle', timeout: 30000}).catch(() => {});
    
    const afterLoginUrl = page.url();
    test('Login redirects to SPA', !afterLoginUrl.includes('/user/login'), `URL: ${afterLoginUrl}`);
    
    // ========== 3. SPA INITIALIZATION ==========
    console.log('\n🖥️  === SPA TEST ===');
    await page.waitForTimeout(15000);
    
    const spaState = await page.evaluate(() => {
      const app = document.querySelector('.app');
      const menu = document.querySelector('[data-drop-zone="menu"]');
      const container = document.querySelector('#container');
      return {
        hasApp: !!app,
        hasMenu: !!menu,
        menuChildren: menu ? menu.children.length : 0,
        hasContainer: !!container,
        containerChildren: container ? container.children.length : 0,
        bodyText: document.body.innerText.substring(0, 300),
      };
    });
    
    test('SPA app element exists', spaState.hasApp);
    test('Menu zone renders', spaState.menuChildren > 0, `${spaState.menuChildren} children`);
    test('Container zone renders', spaState.containerChildren > 0, `${spaState.containerChildren} children`);
    test('Dashboard content visible', spaState.bodyText.includes('ANNOUNCEMENTS') || spaState.bodyText.length > 20);
    
    // Check menu navigation items
    const menuState = await page.evaluate(() => {
      const menu = document.querySelector('[data-drop-zone="menu"]');
      const navItems = menu ? menu.querySelectorAll('a') : [];
      const menuHtml = menu ? menu.innerHTML.substring(0, 500) : '';
      return {
        navItemCount: navItems.length,
        menuHtml: menuHtml,
        hasAknHeader: !!menu && menu.innerHTML.includes('AknHeader'),
      };
    });
    test('Menu has navigation items', menuState.navItemCount > 0, `${menuState.navItemCount} nav items`);
    test('Menu has AknHeader structure', menuState.hasAknHeader);
    
    // ========== 4. REST API (authenticated session) ==========
    console.log('\n📡 === REST API TEST ===');
    const apiEndpoints = [
      {name: 'User Info', url: '/rest/user/', check: (d) => d.includes('"username":"admin"')},
      {name: 'Categories', url: '/enrich/category/rest', check: (d) => d.includes('"master"')},
      {name: 'Locales', url: '/configuration/locale/rest', check: (d) => d.includes('"en_US"')},
    ];
    
    for (const ep of apiEndpoints) {
      const result = await page.evaluate(async (url) => {
        const resp = await fetch(url, {credentials: 'same-origin'});
        return {status: resp.status, body: await resp.text()};
      }, ep.url);
      test(`REST ${ep.name}`, result.status === 200 && ep.check(result.body), `HTTP ${result.status}`);
    }
    
    // ========== 5. NAVIGATION ROUTES ==========
    console.log('\n🧭 === NAVIGATION TEST ===');
    const routes = [
      {name: 'Products Grid', hash: '#/enrich/product/', titleCheck: 'Products'},
      {name: 'Channels', hash: '#/configuration/channel/', titleCheck: 'Channels'},
    ];
    
    for (const route of routes) {
      await page.evaluate(h => window.location.hash = h, route.hash);
      await page.waitForTimeout(5000);
      const title = await page.title();
      const containerHtml = await page.evaluate(() => {
        const c = document.querySelector('#container');
        return c ? c.innerHTML.substring(0, 100) : '';
      });
      test(`Route: ${route.name}`, title === route.titleCheck && containerHtml.length > 10, `title: ${title}`);
    }
    
    // ========== 6. OAUTH API TEST ==========
    console.log('\n🔑 === OAUTH API TEST ===');
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
      // Test API endpoints with bearer token
      const bearerEndpoints = [
        {name: 'Products', url: '/api/rest/v1/products?limit=1'},
        {name: 'Categories', url: '/api/rest/v1/categories?limit=1'},
        {name: 'Channels', url: '/api/rest/v1/channels'},
        {name: 'Attributes', url: '/api/rest/v1/attributes?limit=1'},
        {name: 'Families', url: '/api/rest/v1/families?limit=1'},
        {name: 'Locales', url: '/api/rest/v1/locales?limit=1'},
        {name: 'Currencies', url: '/api/rest/v1/currencies?limit=1'},
        {name: 'Attribute Groups', url: '/api/rest/v1/attribute-groups?limit=1'},
      ];
      
      for (const ep of bearerEndpoints) {
        const result = await page.evaluate(async ({url, token}) => {
          const resp = await fetch(url, {headers: {'Authorization': 'Bearer ' + token}});
          return {status: resp.status};
        }, {url: ep.url, token: tokenResult.token});
        test(`API ${ep.name}`, result.status === 200, `HTTP ${result.status}`);
      }
    }
    
    // ========== 7. ADMIN EMAIL CHECK ==========
    console.log('\n📧 === ADMIN EMAIL TEST ===');
    const userInfo = await page.evaluate(async () => {
      const resp = await fetch('/rest/user/', {credentials: 'same-origin'});
      return await resp.json();
    });
    test('Admin email correct', userInfo.email === 'mounir.webdev.tms@gmail.com', `email: ${userInfo.email}`);
    test('Admin username correct', userInfo.username === 'admin', `username: ${userInfo.username}`);
    
    // ========== SUMMARY ==========
    const themeErrors = errors.filter(e => e.includes('Cannot read properties of undefined'));
    console.log('\n' + '='.repeat(50));
    console.log(`📊 RESULTS: ${results.passed} passed, ${results.failed} failed out of ${results.tests.length} tests`);
    console.log(`🐛 Page errors: ${errors.length} (theme-related: ${themeErrors.length})`);
    if (errors.length > 0) {
      console.log('   First 5 errors:');
      errors.slice(0, 5).forEach(e => console.log(`   - ${e.substring(0, 150)}`));
    }
    console.log('='.repeat(50));
    
  } catch (e) {
    console.error('💥 FATAL:', e.message);
  }
  
  await browser.close();
})();
