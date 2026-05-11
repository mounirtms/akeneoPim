const { chromium } = require('playwright');

(async () => {
    const browser = await chromium.launch({ 
        headless: true,
        args: ['--no-sandbox', '--disable-setuid-sandbox']
    });
    
    const context = await browser.newContext({
        ignoreHTTPSErrors: true,
        viewport: { width: 1920, height: 1080 }
    });
    
    const page = await context.newPage();
    
    const consoleMessages = [];
    const errors = [];
    const warnings = [];
    const failedRequests = [];
    
    // Capture all console messages
    page.on('console', msg => {
        const type = msg.type();
        const text = msg.text();
        consoleMessages.push({ type, text });
        
        if (type === 'error') {
            errors.push(text);
        } else if (type === 'warning') {
            warnings.push(text);
        }
    });
    
    // Capture page errors
    page.on('pageerror', error => {
        errors.push(`PAGE ERROR: ${error.message}`);
    });
    
    // Capture failed requests
    page.on('requestfailed', request => {
        const url = request.url();
        const failure = request.failure();
        if (!url.includes('google-analytics') && !url.includes('clarity.ms')) {
            failedRequests.push(`${url} - ${failure.errorText}`);
        }
    });
    
    try {
        console.log('==========================================');
        console.log('   AKENEO PIM UI COMPREHENSIVE TEST');
        console.log('==========================================\n');
        
        // Step 1: Load login page
        console.log('📄 Step 1: Loading login page...');
        await page.goto('https://pim.technostationery.com/', { 
            timeout: 30000,
            waitUntil: 'networkidle'
        });
        console.log('✅ Login page loaded\n');
        
        // Step 2: Check login page CSS
        console.log('🎨 Step 2: Checking login page styles...');
        const loginStyles = await page.evaluate(() => {
            const body = document.body;
            const form = document.querySelector('form');
            const submitBtn = document.querySelector('button[type="submit"]');
            
            return {
                bodyBg: window.getComputedStyle(body).backgroundColor,
                formExists: !!form,
                buttonExists: !!submitBtn,
                buttonStyles: submitBtn ? {
                    bg: window.getComputedStyle(submitBtn).backgroundColor,
                    color: window.getComputedStyle(submitBtn).color,
                    display: window.getComputedStyle(submitBtn).display
                } : null
            };
        });
        console.log('Login page styles:', JSON.stringify(loginStyles, null, 2));
        console.log('');
        
        // Step 3: Login
        console.log('🔐 Step 3: Attempting login...');
        await page.fill('input[name="_username"]', 'admin');
        await page.fill('input[name="_password"]', 'admin');
        await page.click('button[type="submit"]');
        
        // Wait for navigation
        try {
            await page.waitForURL('**/dashboard', { timeout: 10000 });
            console.log('✅ Redirected to dashboard\n');
        } catch (e) {
            console.log('⚠️  Did not redirect to dashboard, checking current URL...');
            const currentUrl = page.url();
            console.log(`Current URL: ${currentUrl}\n`);
            
            // If still on login page, there might be an error
            if (currentUrl.includes('/user/login')) {
                const errorMsg = await page.$eval('.alert, .error, .flash-message', 
                    el => el.textContent).catch(() => null);
                if (errorMsg) {
                    console.log('❌ Login error:', errorMsg);
                }
            }
        }
        
        // Wait for page to settle
        await page.waitForTimeout(3000);
        
        // Step 4: Check if we're logged in and on dashboard
        const currentUrl = page.url();
        console.log('📍 Step 4: Current location check...');
        console.log(`URL: ${currentUrl}`);
        console.log(`Expected: /dashboard or /`);
        console.log('');
        
        // Step 5: Analyze page structure
        console.log('🏗️  Step 5: Analyzing page structure...');
        const pageStructure = await page.evaluate(() => {
            return {
                title: document.title,
                bodyClasses: document.body.className,
                hasApp: !!document.querySelector('.app, #app, [class*="App"]'),
                hasMenu: !!document.querySelector('.AknDefault-mainMenu, nav, [class*="menu"]'),
                hasHeader: !!document.querySelector('header, .header, [class*="Header"]'),
                hasContent: !!document.querySelector('.content, main, [class*="content"]'),
                loadingVisible: !!document.querySelector('.loading, [class*="loading"]')
            };
        });
        console.log('Page structure:', JSON.stringify(pageStructure, null, 2));
        console.log('');
        
        // Step 6: Check for menu specifically
        console.log('📋 Step 6: Menu inspection...');
        const menuAnalysis = await page.evaluate(() => {
            const selectors = [
                '.AknDefault-mainMenu',
                '.mainMenu',
                'nav',
                '[role="navigation"]',
                '[class*="Menu"]',
                '[class*="menu"]',
                '[class*="Navigation"]'
            ];
            
            const results = {};
            selectors.forEach(selector => {
                const el = document.querySelector(selector);
                if (el) {
                    const styles = window.getComputedStyle(el);
                    const rect = el.getBoundingClientRect();
                    results[selector] = {
                        exists: true,
                        display: styles.display,
                        visibility: styles.visibility,
                        opacity: styles.opacity,
                        position: styles.position,
                        zIndex: styles.zIndex,
                        width: rect.width,
                        height: rect.height,
                        top: rect.top,
                        left: rect.left,
                        className: el.className,
                        childrenCount: el.children.length
                    };
                }
            });
            
            return results;
        });
        console.log('Menu elements found:', Object.keys(menuAnalysis).length);
        if (Object.keys(menuAnalysis).length > 0) {
            console.log(JSON.stringify(menuAnalysis, null, 2));
        } else {
            console.log('❌ No menu elements found!');
        }
        console.log('');
        
        // Step 7: Check loaded resources
        console.log('📦 Step 7: Resource loading check...');
        const resources = await page.evaluate(() => {
            const links = Array.from(document.querySelectorAll('link[rel="stylesheet"]'));
            const scripts = Array.from(document.querySelectorAll('script[src]'));
            
            return {
                stylesheets: links.map(l => ({ href: l.href, loaded: l.sheet !== null })),
                scripts: scripts.map(s => ({ src: s.src }))
            };
        });
        console.log(`Stylesheets loaded: ${resources.stylesheets.filter(s => s.loaded).length}/${resources.stylesheets.length}`);
        console.log(`Scripts loaded: ${resources.scripts.length}`);
        
        // Check for critical CSS
        const hasPimCSS = resources.stylesheets.some(s => s.href.includes('pim.css'));
        console.log(`pim.css loaded: ${hasPimCSS ? '✅' : '❌'}`);
        console.log('');
        
        // Step 8: Screenshots
        console.log('📸 Step 8: Taking screenshots...');
        await page.screenshot({ 
            path: '/tmp/pim_ui_test_full.png', 
            fullPage: true 
        });
        console.log('✅ Full page screenshot: /tmp/pim_ui_test_full.png');
        
        await page.screenshot({ 
            path: '/tmp/pim_ui_test_viewport.png',
            fullPage: false
        });
        console.log('✅ Viewport screenshot: /tmp/pim_ui_test_viewport.png');
        console.log('');
        
        // Step 9: Summary
        console.log('==========================================');
        console.log('              TEST SUMMARY');
        console.log('==========================================\n');
        
        console.log('📊 Statistics:');
        console.log(`   Console Messages: ${consoleMessages.length}`);
        console.log(`   Errors: ${errors.length}`);
        console.log(`   Warnings: ${warnings.length}`);
        console.log(`   Failed Requests: ${failedRequests.length}`);
        console.log('');
        
        if (errors.length > 0) {
            console.log('❌ ERRORS FOUND:');
            errors.forEach((err, i) => {
                console.log(`   ${i + 1}. ${err}`);
            });
            console.log('');
        }
        
        if (failedRequests.length > 0) {
            console.log('🔴 FAILED REQUESTS:');
            failedRequests.forEach((req, i) => {
                console.log(`   ${i + 1}. ${req}`);
            });
            console.log('');
        }
        
        // Final verdict
        console.log('🎯 FINAL VERDICT:');
        const menuFound = Object.keys(menuAnalysis).length > 0;
        const cssLoaded = hasPimCSS;
        const noErrors = errors.length === 0;
        const onDashboard = currentUrl.includes('/dashboard') || currentUrl === 'https://pim.technostationery.com/';
        
        console.log(`   Login: ${onDashboard ? '✅' : '❌'}`);
        console.log(`   CSS Loaded: ${cssLoaded ? '✅' : '❌'}`);
        console.log(`   Menu Rendered: ${menuFound ? '✅' : '❌'}`);
        console.log(`   No JS Errors: ${noErrors ? '✅' : '⚠️'}`);
        console.log('');
        
        if (onDashboard && cssLoaded && menuFound && noErrors) {
            console.log('✅✅✅ ALL TESTS PASSED! ✅✅✅');
        } else {
            console.log('⚠️  SOME ISSUES FOUND - See details above');
        }
        
        console.log('\n==========================================\n');
        
    } catch (error) {
        console.error('❌ Test failed with error:', error.message);
        await page.screenshot({ path: '/tmp/pim_ui_test_error.png' });
        console.log('Error screenshot saved to: /tmp/pim_ui_test_error.png');
    } finally {
        await browser.close();
    }
})();
