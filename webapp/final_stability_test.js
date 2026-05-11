const playwright = require('playwright');
const fs = require('fs');

(async () => {
    console.log('\n╔════════════════════════════════════════════════════════════╗');
    console.log('║      FINAL STABILITY TEST - POST CACHE CLEAR              ║');
    console.log('╚════════════════════════════════════════════════════════════╝\n');
    
    const browser = await playwright.chromium.launch({ 
        headless: true,
        args: ['--no-sandbox', '--disable-setuid-sandbox']
    });
    
    const context = await browser.newContext({ 
        ignoreHTTPSErrors: true,
        viewport: { width: 1920, height: 1080 }
    });
    
    const page = await context.newPage();
    
    const logs = [];
    const errors = [];
    
    page.on('console', msg => {
        const text = msg.text();
        logs.push({ type: msg.type(), text });
        
        if (text.includes('Akeneo') || text.includes('jQuery') || text.includes('loaded')) {
            console.log(`📝 ${msg.type().toUpperCase()}: ${text}`);
        }
    });
    
    page.on('pageerror', err => {
        errors.push(err.message);
        console.log(`❌ ERROR: ${err.message}`);
    });
    
    try {
        console.log('═══ Testing jQuery Direct Load ═══\n');
        
        await page.goto('https://pim.technostationery.com/test-jquery-direct.html?nocache=' + Date.now(), { 
            waitUntil: 'load',
            timeout: 20000 
        });
        
        await page.waitForTimeout(2000);
        
        const directTest = await page.evaluate(() => {
            return {
                jQueryLoaded: typeof jQuery !== 'undefined',
                version: typeof jQuery !== 'undefined' ? jQuery.fn.jquery : null,
                bodyText: document.body.innerText
            };
        });
        
        console.log('Direct test results:');
        console.log(`  jQuery loaded: ${directTest.jQueryLoaded ? '✅' : '❌'}`);
        console.log(`  Version: ${directTest.version || 'N/A'}`);
        console.log(`\nPage output:\n${directTest.bodyText}\n`);
        
        await page.screenshot({ path: 'final_test_1_direct.png' });
        
        console.log('═══ Testing Login Page ═══\n');
        
        await page.goto('https://pim.technostationery.com/user/login?nocache=' + Date.now(), { 
            waitUntil: 'load',
            timeout: 20000 
        });
        
        await page.waitForTimeout(3000);
        
        const loginPageCheck = await page.evaluate(() => {
            return {
                jQueryLoaded: typeof jQuery !== 'undefined',
                version: typeof jQuery !== 'undefined' ? jQuery.fn.jquery : null,
                hasUsername: document.querySelector('input[name="_username"]') !== null,
                hasPassword: document.querySelector('input[name="_password"]') !== null
            };
        });
        
        console.log('Login page:');
        console.log(`  jQuery loaded: ${loginPageCheck.jQueryLoaded ? '✅' : '❌'}`);
        console.log(`  Version: ${loginPageCheck.version || 'N/A'}`);
        console.log(`  Login form present: ${loginPageCheck.hasUsername && loginPageCheck.hasPassword ? '✅' : '❌'}`);
        
        await page.screenshot({ path: 'final_test_2_login.png' });
        
        if (!loginPageCheck.jQueryLoaded) {
            console.log('\n⚠️  jQuery still not loading - cache may need more time');
            console.log('   Recommendation: Test in browser with hard refresh (Ctrl+Shift+R)');
        } else {
            console.log('\n═══ Testing Login Submission ═══\n');
            
            await page.fill('input[name="_username"]', 'mounir');
            await page.fill('input[name="_password"]', '2026');
            await page.click('button[type="submit"]');
            
            console.log('Waiting for navigation...');
            
            try {
                await page.waitForURL(/dashboard|#\//, { timeout: 15000 });
                console.log('✅ Dashboard reached!');
            } catch (e) {
                console.log('⏱️  Navigation timeout - checking current URL...');
            }
            
            await page.waitForTimeout(5000);
            
            const finalUrl = page.url();
            const finalTitle = await page.title();
            
            console.log(`\nFinal URL: ${finalUrl}`);
            console.log(`Page title: ${finalTitle}`);
            
            const dashboardState = await page.evaluate(() => {
                return {
                    jQueryLoaded: typeof jQuery !== 'undefined',
                    backboneLoaded: typeof Backbone !== 'undefined',
                    hasMenu: document.querySelector('.AknDefault-mainMenu') !== null ||
                            document.querySelector('nav') !== null,
                    bodyText: document.body.innerText.substring(0, 300),
                    loadingVisible: document.querySelector('.AknDefault-progressContainer') !== null &&
                                  document.querySelector('.AknDefault-progressContainer').offsetWidth > 0
                };
            });
            
            console.log('\nDashboard state:');
            console.log(`  jQuery: ${dashboardState.jQueryLoaded ? '✅' : '❌'}`);
            console.log(`  Backbone: ${dashboardState.backboneLoaded ? '✅' : '❌'}`);
            console.log(`  Menu visible: ${dashboardState.hasMenu ? '✅' : '❌'}`);
            console.log(`  Loading screen: ${dashboardState.loadingVisible ? '⚠️ Still visible' : '✅ Cleared'}`);
            
            await page.screenshot({ path: 'final_test_3_dashboard.png', fullPage: true });
        }
        
        console.log('\n═══ SUMMARY ═══');
        console.log(`Console logs captured: ${logs.length}`);
        console.log(`JavaScript errors: ${errors.length}`);
        
        if (errors.length > 0) {
            console.log('\nErrors found:');
            errors.forEach((err, i) => {
                console.log(`  ${i + 1}. ${err}`);
            });
        }
        
        const jQuerySuccess = logs.some(log => log.text.includes('jQuery loaded successfully'));
        console.log(`\n"jQuery loaded successfully" message: ${jQuerySuccess ? '✅ Found' : '❌ Not found'}`);
        
        const report = {
            timestamp: new Date().toISOString(),
            cacheBuster: '20260508_154531',
            directTest,
            loginPageCheck,
            errors,
            logsCount: logs.length,
            jQuerySuccessMessage: jQuerySuccess
        };
        
        fs.writeFileSync('final_stability_report.json', JSON.stringify(report, null, 2));
        console.log('\n📄 Report saved: final_stability_report.json');
        
    } catch (err) {
        console.error('\n❌ Test error:', err.message);
    } finally {
        await browser.close();
    }
})();
