const { chromium } = require('playwright');
const fs = require('fs');

async function testMounirLogin() {
    console.log('🔐 Testing Login with mounir/2026');
    console.log('=' .repeat(60));
    
    const browser = await chromium.launch({
        headless: true,
        args: ['--no-sandbox', '--disable-setuid-sandbox']
    });
    
    const context = await browser.newContext({
        ignoreHTTPSErrors: true,
        viewport: { width: 1920, height: 1080 }
    });
    
    const page = await context.newPage();
    
    const consoleLogs = [];
    const errors = [];
    const networkErrors = [];
    
    // Capture all console messages
    page.on('console', msg => {
        const log = {
            type: msg.type(),
            text: msg.text(),
            location: msg.location()
        };
        consoleLogs.push(log);
        console.log(`📝 [${log.type.toUpperCase()}] ${log.text}`);
    });
    
    // Capture JavaScript errors
    page.on('pageerror', error => {
        errors.push({
            message: error.message,
            stack: error.stack
        });
        console.log(`❌ JS Error: ${error.message}`);
    });
    
    // Capture network failures
    page.on('response', response => {
        if (response.status() >= 400) {
            networkErrors.push({
                url: response.url(),
                status: response.status(),
                statusText: response.statusText()
            });
            console.log(`⚠️  HTTP ${response.status()}: ${response.url()}`);
        }
    });
    
    try {
        console.log('\n📋 Step 1: Navigate to login page');
        await page.goto('https://pim.technostationery.com/user/login', { 
            waitUntil: 'networkidle',
            timeout: 30000
        });
        await page.screenshot({ path: 'mounir_1_login_page.png', fullPage: true });
        console.log('✅ Login page loaded');
        
        console.log('\n📋 Step 2: Fill login form with mounir/2026');
        await page.fill('input[name="_username"]', 'mounir');
        await page.fill('input[name="_password"]', '2026');
        await page.screenshot({ path: 'mounir_2_form_filled.png', fullPage: true });
        console.log('✅ Form filled');
        
        console.log('\n📋 Step 3: Submit login form');
        await page.click('button[type="submit"]');
        
        // Wait for navigation or error message
        await page.waitForTimeout(5000);
        await page.screenshot({ path: 'mounir_3_after_submit.png', fullPage: true });
        
        const currentUrl = page.url();
        const pageTitle = await page.title();
        
        console.log(`\n📍 Current URL: ${currentUrl}`);
        console.log(`📄 Page Title: ${pageTitle}`);
        
        if (currentUrl.includes('/user/login')) {
            console.log('❌ Still on login page - checking for error message');
            const errorMsg = await page.$('.alert-danger, .alert-error, .error-message');
            if (errorMsg) {
                const errorText = await errorMsg.textContent();
                console.log(`❌ Error message: ${errorText}`);
            }
        } else {
            console.log('✅ Login successful - navigated away from login page');
            
            console.log('\n📋 Step 4: Wait for dashboard/PIM interface to load');
            await page.waitForTimeout(3000);
            await page.screenshot({ path: 'mounir_4_dashboard.png', fullPage: true });
            
            console.log('\n📋 Step 5: Check for loading screens');
            const loadingElements = await page.$$('[class*="loading"], [class*="spinner"], .loader');
            console.log(`🔄 Loading elements found: ${loadingElements.length}`);
            
            if (loadingElements.length > 0) {
                console.log('⏳ Waiting for loading to complete...');
                await page.waitForTimeout(5000);
                await page.screenshot({ path: 'mounir_5_after_loading.png', fullPage: true });
            }
            
            console.log('\n📋 Step 6: Check PIM menu');
            // Wait for any menu/navigation to appear
            await page.waitForTimeout(2000);
            
            // Try to find navigation menu
            const menuSelectors = [
                'nav',
                '.navigation',
                '.menu',
                '[role="navigation"]',
                '.AknHeader',
                '.AknMainMenu'
            ];
            
            let menuFound = false;
            for (const selector of menuSelectors) {
                const menu = await page.$(selector);
                if (menu) {
                    console.log(`✅ Found menu: ${selector}`);
                    menuFound = true;
                    
                    // Try to get menu items
                    const menuItems = await page.$$(`${selector} a, ${selector} button`);
                    console.log(`📊 Menu items count: ${menuItems.length}`);
                    
                    // Get first few menu item texts
                    for (let i = 0; i < Math.min(5, menuItems.length); i++) {
                        try {
                            const text = await menuItems[i].textContent();
                            console.log(`   ${i + 1}. ${text.trim()}`);
                        } catch (e) {}
                    }
                    break;
                }
            }
            
            if (!menuFound) {
                console.log('⚠️  No menu found with standard selectors');
            }
            
            console.log('\n📋 Step 7: Take final screenshot');
            await page.screenshot({ path: 'mounir_6_final_state.png', fullPage: true });
            
            console.log('\n📋 Step 8: Get page HTML structure');
            const bodyClasses = await page.evaluate(() => document.body.className);
            console.log(`Body classes: ${bodyClasses}`);
            
            // Check for common Akeneo/PIM elements
            const pimElements = await page.evaluate(() => {
                return {
                    hasAkeneoClasses: document.querySelector('[class*="Akn"]') !== null,
                    hasPimClasses: document.querySelector('[class*="pim"]') !== null,
                    hasReactRoot: document.querySelector('#root, [data-reactroot]') !== null,
                    mainHeading: document.querySelector('h1, h2')?.textContent || 'None'
                };
            });
            console.log('PIM Elements:', pimElements);
        }
        
    } catch (error) {
        console.error(`\n❌ Test Error: ${error.message}`);
        errors.push({
            message: error.message,
            stack: error.stack
        });
        await page.screenshot({ path: 'mounir_error.png', fullPage: true });
    } finally {
        await browser.close();
    }
    
    // Save detailed report
    const report = {
        timestamp: new Date().toISOString(),
        credentials: 'mounir/2026',
        consoleLogs,
        errors,
        networkErrors,
        screenshots: [
            'mounir_1_login_page.png',
            'mounir_2_form_filled.png',
            'mounir_3_after_submit.png',
            'mounir_4_dashboard.png',
            'mounir_5_after_loading.png',
            'mounir_6_final_state.png'
        ]
    };
    
    fs.writeFileSync('mounir_test_report.json', JSON.stringify(report, null, 2));
    
    console.log('\n' + '='.repeat(60));
    console.log('📊 TEST SUMMARY');
    console.log('='.repeat(60));
    console.log(`📝 Console Logs: ${consoleLogs.length}`);
    console.log(`❌ JavaScript Errors: ${errors.length}`);
    console.log(`⚠️  Network Errors: ${networkErrors.length}`);
    console.log(`\n📄 Detailed report: mounir_test_report.json`);
    console.log(`📸 Screenshots: mounir_*.png`);
    
    if (errors.length > 0) {
        console.log('\n❌ ERRORS FOUND:');
        errors.forEach((err, i) => {
            console.log(`${i + 1}. ${err.message}`);
        });
    }
    
    if (networkErrors.length > 0) {
        console.log('\n⚠️  NETWORK ERRORS:');
        networkErrors.slice(0, 10).forEach((err, i) => {
            console.log(`${i + 1}. ${err.status} ${err.url}`);
        });
    }
}

testMounirLogin().catch(error => {
    console.error('Fatal error:', error);
    process.exit(1);
});
