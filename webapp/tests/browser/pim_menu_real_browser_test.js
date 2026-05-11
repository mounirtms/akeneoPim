#!/usr/bin/env node
/**
 * PIM Menu Real Browser Test
 * Tests navigation, menu functionality, and dashboard features
 */

const { chromium } = require('playwright');
const fs = require('fs');

const BASE_URL = 'https://pim.technostationery.com';
const credentials = {
    username: 'admin',
    password: 'Admin@2024'
};

// Real browser user agent to bypass bot detection
const REAL_USER_AGENT = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

async function runPIMMenuTest() {
    console.log('================================================================================');
    console.log('PIM MENU REAL BROWSER TEST');
    console.log('================================================================================\n');

    const browser = await chromium.launch({
        headless: true,
        args: [
            '--disable-blink-features=AutomationControlled',
            '--disable-web-security',
            '--no-sandbox'
        ]
    });

    const context = await browser.newContext({
        userAgent: REAL_USER_AGENT,
        viewport: { width: 1920, height: 1080 },
        locale: 'en-US',
        extraHTTPHeaders: {
            'Accept-Language': 'en-US,en;q=0.9'
        }
    });

    const page = await context.newPage();

    // Logging arrays
    const logs = {
        console: [],
        errors: [],
        requests: [],
        responses: [],
        navigation: [],
        menuItems: [],
        dashboardElements: []
    };

    // Console monitoring
    page.on('console', msg => {
        const entry = `[${msg.type()}] ${msg.text()}`;
        logs.console.push(entry);
        if (msg.type() === 'error') {
            console.log(`❌ CONSOLE ERROR: ${msg.text()}`);
        }
    });

    // Error monitoring
    page.on('pageerror', error => {
        logs.errors.push(error.message);
        console.log(`❌ JS ERROR: ${error.message}`);
    });

    // Network monitoring
    page.on('request', req => {
        logs.requests.push({
            url: req.url(),
            method: req.method(),
            timestamp: new Date().toISOString()
        });
    });

    page.on('response', resp => {
        logs.responses.push({
            url: resp.url(),
            status: resp.status(),
            timestamp: new Date().toISOString()
        });
    });

    try {
        // ============================================================================
        // STEP 1: LOAD LOGIN PAGE
        // ============================================================================
        console.log('📍 Step 1: Loading login page...\n');
        await page.goto(`${BASE_URL}/user/login`, { 
            waitUntil: 'networkidle',
            timeout: 30000 
        });
        
        logs.navigation.push({ step: 'Login page loaded', url: page.url() });
        
        // Wait for CloudFlare challenges
        await page.waitForTimeout(3000);
        
        await page.screenshot({ 
            path: 'tests/browser/screenshots/menu_01_login_page.png',
            fullPage: true 
        });

        // ============================================================================
        // STEP 2: FILL AND SUBMIT LOGIN FORM
        // ============================================================================
        console.log('📍 Step 2: Attempting login...\n');
        
        // Check if login form exists
        const hasLoginForm = await page.evaluate(() => {
            return !!document.querySelector('input[name="_username"]');
        });

        if (!hasLoginForm) {
            throw new Error('Login form not found');
        }

        // Fill form with delay to simulate human behavior
        await page.waitForSelector('input[name="_username"]', { state: 'visible', timeout: 5000 });
        await page.click('input[name="_username"]');
        await page.type('input[name="_username"]', credentials.username, { delay: 100 });
        
        await page.click('input[name="_password"]');
        await page.type('input[name="_password"]', credentials.password, { delay: 100 });
        
        await page.waitForTimeout(1000);
        
        await page.screenshot({ 
            path: 'tests/browser/screenshots/menu_02_form_filled.png',
            fullPage: true 
        });

        // Submit form and wait for navigation
        console.log('Submitting login form...\n');
        
        const submitPromise = page.waitForNavigation({ 
            timeout: 15000,
            waitUntil: 'networkidle'
        }).catch(() => null);

        await page.click('button[type="submit"]');
        await submitPromise;
        
        // Wait for page to settle
        await page.waitForTimeout(3000);
        
        const currentUrl = page.url();
        logs.navigation.push({ step: 'After login', url: currentUrl });
        
        console.log(`Current URL: ${currentUrl}\n`);
        
        await page.screenshot({ 
            path: 'tests/browser/screenshots/menu_03_after_login.png',
            fullPage: true 
        });

        // ============================================================================
        // STEP 3: CHECK IF LOGIN WAS SUCCESSFUL
        // ============================================================================
        console.log('📍 Step 3: Verifying authentication...\n');
        
        const isLoggedIn = !currentUrl.includes('/user/login');
        
        if (!isLoggedIn) {
            console.log('⚠️  Still on login page - authentication may have failed');
            console.log('   This could be due to incorrect credentials or bot detection\n');
            
            // Check for error messages
            const errorMessages = await page.evaluate(() => {
                const errors = [];
                document.querySelectorAll('.alert-error, .alert-danger, .error, .alert').forEach(el => {
                    const text = el.textContent.trim();
                    if (text) errors.push(text);
                });
                return errors;
            });
            
            if (errorMessages.length > 0) {
                console.log('Error messages found:');
                errorMessages.forEach(msg => console.log(`   - ${msg}`));
            }
        } else {
            console.log('✅ Login successful! Redirected to:', currentUrl);
        }

        // ============================================================================
        // STEP 4: ANALYZE DASHBOARD/PIM UI
        // ============================================================================
        console.log('\n📍 Step 4: Analyzing PIM interface...\n');
        
        const pageAnalysis = await page.evaluate(() => {
            const analysis = {
                title: document.title,
                hasPimApp: false,
                hasDashboard: false,
                hasNavigation: false,
                menuItems: [],
                mainContent: null,
                requireJSLoaded: false,
                backboneLoaded: false,
                bodyClasses: document.body.className
            };

            // Check for PIM application container
            const pimApp = document.querySelector('#pim-app, [data-app="pim"], .AknDefault');
            analysis.hasPimApp = !!pimApp;

            // Check for dashboard elements
            const dashboard = document.querySelector('.dashboard, #dashboard, .content-main');
            analysis.hasDashboard = !!dashboard;

            // Check for navigation
            const nav = document.querySelector('nav, .navigation, .AknDefault-mainMenu, .main-menu');
            analysis.hasNavigation = !!nav;

            // Extract menu items
            const menuSelectors = [
                'nav a',
                '.navigation a',
                '.main-menu a',
                '.AknDefault-mainMenu a',
                '[data-navigation] a'
            ];

            menuSelectors.forEach(selector => {
                try {
                    document.querySelectorAll(selector).forEach(link => {
                        const text = link.textContent.trim();
                        const href = link.href;
                        if (text && href && !analysis.menuItems.some(m => m.href === href)) {
                            analysis.menuItems.push({
                                text: text,
                                href: href
                            });
                        }
                    });
                } catch (e) {}
            });

            // Check main content
            const mainContent = document.querySelector('main, .content-main, #content, .main-content');
            if (mainContent) {
                analysis.mainContent = {
                    exists: true,
                    innerHTML: mainContent.innerHTML.substring(0, 500)
                };
            }

            // Check if RequireJS and Backbone are loaded
            analysis.requireJSLoaded = typeof window.require !== 'undefined' && typeof window.requirejs !== 'undefined';
            analysis.backboneLoaded = typeof window.Backbone !== 'undefined';

            return analysis;
        });

        logs.dashboardElements = pageAnalysis;

        console.log('Dashboard Analysis:');
        console.log(`  Title: ${pageAnalysis.title}`);
        console.log(`  PIM App Container: ${pageAnalysis.hasPimApp ? '✅ Found' : '❌ Not found'}`);
        console.log(`  Dashboard: ${pageAnalysis.hasDashboard ? '✅ Found' : '❌ Not found'}`);
        console.log(`  Navigation: ${pageAnalysis.hasNavigation ? '✅ Found' : '❌ Not found'}`);
        console.log(`  Menu Items: ${pageAnalysis.menuItems.length} found`);
        console.log(`  RequireJS: ${pageAnalysis.requireJSLoaded ? '✅ Loaded' : '❌ Not loaded'}`);
        console.log(`  Backbone: ${pageAnalysis.backboneLoaded ? '✅ Loaded' : '❌ Not loaded'}`);

        if (pageAnalysis.menuItems.length > 0) {
            console.log('\nMenu Items Found:');
            pageAnalysis.menuItems.slice(0, 10).forEach((item, idx) => {
                console.log(`  ${idx + 1}. ${item.text}`);
            });
            if (pageAnalysis.menuItems.length > 10) {
                console.log(`  ... and ${pageAnalysis.menuItems.length - 10} more`);
            }
        }

        logs.menuItems = pageAnalysis.menuItems;

        // ============================================================================
        // STEP 5: TEST MENU NAVIGATION (if logged in)
        // ============================================================================
        if (isLoggedIn && pageAnalysis.menuItems.length > 0) {
            console.log('\n📍 Step 5: Testing menu navigation...\n');
            
            // Try to click first few menu items
            const menuToTest = pageAnalysis.menuItems.slice(0, 3);
            
            for (const [idx, menuItem] of menuToTest.entries()) {
                try {
                    console.log(`Testing menu item ${idx + 1}: ${menuItem.text}`);
                    
                    // Find and click the menu item
                    const clicked = await page.evaluate((href) => {
                        const link = Array.from(document.querySelectorAll('a')).find(a => a.href === href);
                        if (link) {
                            link.click();
                            return true;
                        }
                        return false;
                    }, menuItem.href);

                    if (clicked) {
                        await page.waitForTimeout(2000);
                        const newUrl = page.url();
                        logs.navigation.push({ 
                            step: `Menu click: ${menuItem.text}`, 
                            url: newUrl 
                        });
                        console.log(`  ✅ Navigated to: ${newUrl}`);
                        
                        await page.screenshot({ 
                            path: `tests/browser/screenshots/menu_04_nav_${idx + 1}.png`,
                            fullPage: true 
                        });
                        
                        // Go back to dashboard
                        await page.goBack();
                        await page.waitForTimeout(1000);
                    } else {
                        console.log(`  ⚠️  Could not click menu item`);
                    }
                } catch (error) {
                    console.log(`  ❌ Error testing menu item: ${error.message}`);
                }
            }
        }

        // ============================================================================
        // STEP 6: CAPTURE FINAL STATE
        // ============================================================================
        console.log('\n📍 Step 6: Capturing final state...\n');
        
        await page.screenshot({ 
            path: 'tests/browser/screenshots/menu_05_final_state.png',
            fullPage: true 
        });

        // Get final page state
        const finalState = await page.evaluate(() => {
            return {
                url: window.location.href,
                title: document.title,
                readyState: document.readyState,
                hasErrors: document.querySelectorAll('.error, .alert-danger').length > 0,
                scriptCount: document.querySelectorAll('script').length,
                linkCount: document.querySelectorAll('a').length
            };
        });

        console.log('Final State:');
        console.log(`  URL: ${finalState.url}`);
        console.log(`  Title: ${finalState.title}`);
        console.log(`  Scripts: ${finalState.scriptCount}`);
        console.log(`  Links: ${finalState.linkCount}`);
        console.log(`  Errors on page: ${finalState.hasErrors ? 'Yes' : 'No'}`);

    } catch (error) {
        console.log(`\n❌ TEST ERROR: ${error.message}`);
        logs.errors.push(error.message);
        
        // Take error screenshot
        try {
            await page.screenshot({ 
                path: 'tests/browser/screenshots/menu_error.png',
                fullPage: true 
            });
        } catch (e) {}
    }

    // ============================================================================
    // GENERATE REPORT
    // ============================================================================
    const report = {
        timestamp: new Date().toISOString(),
        testName: 'PIM Menu Real Browser Test',
        userAgent: REAL_USER_AGENT,
        credentials: { username: credentials.username, password: '***' },
        summary: {
            consoleLogs: logs.console.length,
            errors: logs.errors.length,
            requests: logs.requests.length,
            responses: logs.responses.length,
            navigationSteps: logs.navigation.length,
            menuItems: logs.menuItems.length
        },
        logs: logs
    };

    fs.writeFileSync(
        'tests/browser/reports/pim_menu_test_report.json',
        JSON.stringify(report, null, 2)
    );

    console.log('\n================================================================================');
    console.log('TEST COMPLETE');
    console.log('================================================================================');
    console.log(`Console Logs: ${logs.console.length}`);
    console.log(`Errors: ${logs.errors.length}`);
    console.log(`HTTP Requests: ${logs.requests.length}`);
    console.log(`Navigation Steps: ${logs.navigation.length}`);
    console.log(`Menu Items Found: ${logs.menuItems.length}`);
    console.log('\n✓ Report: tests/browser/reports/pim_menu_test_report.json');
    console.log('✓ Screenshots: tests/browser/screenshots/menu_*.png');
    console.log('================================================================================\n');

    await browser.close();
}

// Run the test
runPIMMenuTest().catch(console.error);
