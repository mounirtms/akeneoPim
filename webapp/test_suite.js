const { chromium } = require('playwright');

(async () => {
    console.log('╔════════════════════════════════════════════════════════════════════════════╗');
    console.log('║     AKENEO PIM COMPREHENSIVE TEST SUITE                              ║');
    console.log('╚════════════════════════════════════════════════════════════════════════════╝\n');
    
    const browser = await chromium.launch({
        headless: true,
        args: ['--no-sandbox', '--disable-setuid-sandbox']
    });
    
    const context = await browser.newContext({
        viewport: { width: 1920, height: 1080 },
        ignoreHTTPSErrors: true
    });
    
    const page = await context.newPage();
    const results = [];
    
    const log = (msg, pass = true) => {
        console.log((pass ? '✓ ' : '✗ ') + msg);
        results.push({ msg, pass });
    };
    
    try {
        // ============================================================
        // TEST 1: Login Page
        // ============================================================
        console.log('\n[TEST 1] Login Page');
        await page.goto('https://pim.technostationery.com/user/login', { waitUntil: 'domcontentloaded', timeout: 60000 });
        await page.waitForTimeout(3000);
        await page.screenshot({ path: '/tmp/akeneo_01_login.png' });
        
        const loginHtml = await page.content();
        log('Login page loads', loginHtml.includes('AknLogin'));
        log('Has Akeneo logo', loginHtml.includes('Logo.svg'));
        log('Has username input', loginHtml.includes('username'));
        log('Has password input', loginHtml.includes('password'));
        
        // ============================================================
        // TEST 2: Login
        // ============================================================
        console.log('\n[TEST 2] Login Submit');
        await page.fill('input[name="_username"]', 'admin');
        await page.fill('input[name="_password"]', 'admin');
        await page.click('button[type="submit"]');
        await page.waitForTimeout(8000);
        await page.screenshot({ path: '/tmp/akeneo_02_after_login.png' });
        
        const cookies = await context.cookies();
        const sessionCookie = cookies.find(c => c.name === 'BAPID');
        log('Session created', !!sessionCookie);
        
        const url = page.url();
        log('Logged in', url.includes('dashboard') || sessionCookie !== undefined);
        
        // ============================================================
        // TEST 3: Dashboard
        // ============================================================
        console.log('\n[TEST 3] Dashboard');
        await page.goto('https://pim.technostationery.com/dashboard', { waitUntil: 'domcontentloaded', timeout: 60000 });
        await page.waitForTimeout(3000);
        await page.screenshot({ path: '/tmp/akeneo_03_dashboard.png' });
        
        const dashHtml = await page.content();
        log('Dashboard loads', dashHtml.length > 500);
        log('Has menu', dashHtml.includes('menu') || dashHtml.includes('nav') || dashHtml.includes('Akn'));
        log('Has user', dashHtml.includes('admin'));
        
        // ============================================================
        // TEST 4: Root Route
        // ============================================================
        console.log('\n[TEST 4] Root (/)');
        await page.goto('https://pim.technostationery.com/', { waitUntil: 'domcontentloaded', timeout: 30000 });
        await page.waitForTimeout(2000);
        await page.screenshot({ path: '/tmp/akeneo_04_root.png' });
        log('Root loads', (await page.content()).length > 500);
        
        // ============================================================
        // TEST 5: Enrich Product
        // ============================================================
        console.log('\n[TEST 5] Enrich Product (/enrich/product)');
        await page.goto('https://pim.technostationery.com/enrich/product', { waitUntil: 'domcontentloaded', timeout: 30000 });
        await page.waitForTimeout(2000);
        await page.screenshot({ path: '/tmp/akeneo_05_enrich_product.png' });
        const enrichHtml = await page.content();
        log('Enrich product loads', enrichHtml.length > 500);
        log('Has datagrid', enrichHtml.includes('datagrid') || enrichHtml.includes('grid') || enrichHtml.includes('Akn'));
        
        // ============================================================
        // TEST 6: Settings
        // ============================================================
        console.log('\n[TEST 6] Settings (/settings)');
        await page.goto('https://pim.technostationery.com/settings', { waitUntil: 'domcontentloaded', timeout: 30000 });
        await page.waitForTimeout(2000);
        await page.screenshot({ path: '/tmp/akeneo_06_settings.png' });
        log('Settings loads', (await page.content()).length > 500);
        
        // ============================================================
        // TEST 7: CSS Check
        // ============================================================
        console.log('\n[TEST 7] CSS Assets');
        const cssResponse = await page.goto('https://pim.technostationery.com/css/pim.css');
        log('CSS accessible', cssResponse.status() === 200);
        const cssContent = await cssResponse.text();
        log('CSS has content', cssContent.length > 1000);
        
    } catch (err) {
        console.log('\n✗ Error:', err.message);
    }
    
    // ============================================================
    // SUMMARY
    // ============================================================
    console.log('\n' + '='.repeat(60));
    console.log('TEST RESULTS');
    console.log('='.repeat(60));
    
    const passed = results.filter(r => r.pass).length;
    const failed = results.filter(r => !r.pass).length;
    
    results.forEach(r => console.log((r.pass ? '✓' : '✗') + ' ' + r.msg));
    
    console.log('\n' + '='.repeat(60));
    console.log(`TOTAL: ${passed} Passed, ${failed} Failed`);
    console.log('='.repeat(60));
    
    await browser.close();
})();