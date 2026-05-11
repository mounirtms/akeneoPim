#!/usr/bin/env node
/**
 * PIM Menu Real Browser Test - With Correct Credentials
 * Tests navigation, menu functionality, and dashboard features
 */

const { chromium } = require('playwright');
const fs = require('fs');

const BASE_URL = 'https://pim.technostationery.com';
const credentials = {
    username: 'Mounir',
    password: '2026'
};

const REAL_USER_AGENT = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

async function runPIMMenuTest() {
    console.log('================================================================================');
    console.log('PIM MENU TEST - With Credentials: Mounir/2026');
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
        locale: 'en-US'
    });

    const page = await context.newPage();

    const logs = {
        console: [],
        errors: [],
        menuItems: [],
        navigation: [],
        dashboardElements: null
    };

    page.on('console', msg => {
        logs.console.push(`[${msg.type()}] ${msg.text()}`);
        if (msg.type() === 'error') {
            console.log(`❌ CONSOLE: ${msg.text()}`);
        }
    });

    page.on('pageerror', error => {
        logs.errors.push(error.message);
        console.log(`❌ JS ERROR: ${error.message}`);
    });

    try {
        // STEP 1: LOGIN
        console.log('📍 Step 1: Loading login page...');
        await page.goto(`${BASE_URL}/user/login`, { 
            waitUntil: 'networkidle',
            timeout: 30000 
        });
        
        await page.waitForTimeout(3000);
        await page.screenshot({ path: 'tests/browser/screenshots/pim_01_login.png', fullPage: true });

        console.log('📍 Step 2: Logging in with Mounir/2026...');
        await page.waitForSelector('input[name="_username"]', { state: 'visible', timeout: 5000 });
        
        await page.click('input[name="_username"]');
        await page.type('input[name="_username"]', credentials.username, { delay: 100 });
        
        await page.click('input[name="_password"]');
        await page.type('input[name="_password"]', credentials.password, { delay: 100 });
        
        await page.waitForTimeout(1000);
        await page.screenshot({ path: 'tests/browser/screenshots/pim_02_filled.png', fullPage: true });

        console.log('📍 Step 3: Submitting form...');
        const submitPromise = page.waitForNavigation({ 
            timeout: 15000,
            waitUntil: 'networkidle'
        }).catch(() => null);

        await page.click('button[type="submit"]');
        await submitPromise;
        await page.waitForTimeout(5000);
        
        const currentUrl = page.url();
        logs.navigation.push({ step: 'After login', url: currentUrl });
        
        console.log(`Current URL: ${currentUrl}`);
        await page.screenshot({ path: 'tests/browser/screenshots/pim_03_after_login.png', fullPage: true });

        const isLoggedIn = !currentUrl.includes('/user/login');
        
        if (!isLoggedIn) {
            console.log('\n⚠️  Still on login page - checking for errors...');
            const errorMessages = await page.evaluate(() => {
                const errors = [];
                document.querySelectorAll('.alert-error, .alert-danger, .error, .alert').forEach(el => {
                    errors.push(el.textContent.trim());
                });
                return errors;
            });
            
            if (errorMessages.length > 0) {
                console.log('Error messages:');
                errorMessages.forEach(msg => console.log(`   ${msg}`));
            } else {
                console.log('   No error messages found - credentials may be rejected silently');
            }
        } else {
            console.log('✅ LOGIN SUCCESSFUL!');
            
            // STEP 4: ANALYZE DASHBOARD
            console.log('\n📍 Step 4: Analyzing dashboard...');
            
            // Wait for dashboard to load
            await page.waitForTimeout(5000);
            
            const pageAnalysis = await page.evaluate(() => {
                const analysis = {
                    title: document.title,
                    url: window.location.href,
                    hasPimApp: false,
                    hasDashboard: false,
                    hasNavigation: false,
                    menuItems: [],
                    requireJSLoaded: false,
                    backboneLoaded: false
                };

                // Check for PIM containers
                analysis.hasPimApp = !!(
                    document.querySelector('#pim-app') ||
                    document.querySelector('[data-app="pim"]') ||
                    document.querySelector('.AknDefault')
                );

                analysis.hasDashboard = !!(
                    document.querySelector('.dashboard') ||
                    document.querySelector('#dashboard') ||
                    document.querySelector('.content-main')
                );

                analysis.hasNavigation = !!(
                    document.querySelector('nav') ||
                    document.querySelector('.navigation') ||
                    document.querySelector('.AknDefault-mainMenu') ||
                    document.querySelector('.main-menu')
                );

                // Extract menu items
                const selectors = [
                    'nav a',
                    '.navigation a',
                    '.AknDefault-mainMenu a',
                    '.main-menu a',
                    '[role="navigation"] a',
                    '.menu a'
                ];

                selectors.forEach(selector => {
                    try {
                        document.querySelectorAll(selector).forEach(link => {
                            const text = link.textContent.trim();
                            const href = link.href;
                            if (text && href && !analysis.menuItems.some(m => m.href === href)) {
                                analysis.menuItems.push({ text, href });
                            }
                        });
                    } catch (e) {}
                });

                analysis.requireJSLoaded = typeof window.require !== 'undefined';
                analysis.backboneLoaded = typeof window.Backbone !== 'undefined';

                return analysis;
            });

            logs.dashboardElements = pageAnalysis;

            console.log(`\nDashboard Analysis:`);
            console.log(`  Title: ${pageAnalysis.title}`);
            console.log(`  URL: ${pageAnalysis.url}`);
            console.log(`  PIM App: ${pageAnalysis.hasPimApp ? '✅' : '❌'}`);
            console.log(`  Dashboard: ${pageAnalysis.hasDashboard ? '✅' : '❌'}`);
            console.log(`  Navigation: ${pageAnalysis.hasNavigation ? '✅' : '❌'}`);
            console.log(`  Menu Items: ${pageAnalysis.menuItems.length}`);
            console.log(`  RequireJS: ${pageAnalysis.requireJSLoaded ? '✅' : '❌'}`);
            console.log(`  Backbone: ${pageAnalysis.backboneLoaded ? '✅' : '❌'}`);

            if (pageAnalysis.menuItems.length > 0) {
                console.log(`\nMenu Items Found:`);
                pageAnalysis.menuItems.forEach((item, idx) => {
                    console.log(`  ${idx + 1}. ${item.text}`);
                });
                logs.menuItems = pageAnalysis.menuItems;
            }

            await page.screenshot({ path: 'tests/browser/screenshots/pim_04_dashboard.png', fullPage: true });

            // STEP 5: TEST MENU NAVIGATION
            if (pageAnalysis.menuItems.length > 0) {
                console.log(`\n📍 Step 5: Testing menu navigation...`);
                
                const menuToTest = pageAnalysis.menuItems.slice(0, Math.min(5, pageAnalysis.menuItems.length));
                
                for (const [idx, menuItem] of menuToTest.entries()) {
                    try {
                        console.log(`\n  Testing ${idx + 1}/${menuToTest.length}: ${menuItem.text}`);
                        
                        const clicked = await page.evaluate((href) => {
                            const link = Array.from(document.querySelectorAll('a')).find(a => a.href === href);
                            if (link) {
                                link.click();
                                return true;
                            }
                            return false;
                        }, menuItem.href);

                        if (clicked) {
                            await page.waitForTimeout(3000);
                            const newUrl = page.url();
                            logs.navigation.push({ 
                                step: `Menu: ${menuItem.text}`, 
                                url: newUrl 
                            });
                            console.log(`    ✅ Navigated to: ${newUrl}`);
                            
                            await page.screenshot({ 
                                path: `tests/browser/screenshots/pim_05_menu_${idx + 1}.png`,
                                fullPage: true 
                            });
                            
                            await page.goBack();
                            await page.waitForTimeout(2000);
                        } else {
                            console.log(`    ⚠️  Could not click`);
                        }
                    } catch (error) {
                        console.log(`    ❌ Error: ${error.message}`);
                    }
                }
            }

            // FINAL STATE
            console.log(`\n📍 Step 6: Capturing final state...`);
            await page.screenshot({ path: 'tests/browser/screenshots/pim_06_final.png', fullPage: true });
        }

    } catch (error) {
        console.log(`\n❌ TEST ERROR: ${error.message}`);
        logs.errors.push(error.message);
        try {
            await page.screenshot({ path: 'tests/browser/screenshots/pim_error.png', fullPage: true });
        } catch (e) {}
    }

    // GENERATE REPORT
    const report = {
        timestamp: new Date().toISOString(),
        credentials: { username: credentials.username, password: '***' },
        summary: {
            consoleLogs: logs.console.length,
            errors: logs.errors.length,
            navigationSteps: logs.navigation.length,
            menuItems: logs.menuItems.length
        },
        logs: logs
    };

    fs.writeFileSync(
        'tests/browser/reports/pim_menu_final_report.json',
        JSON.stringify(report, null, 2)
    );

    console.log('\n================================================================================');
    console.log('TEST COMPLETE');
    console.log('================================================================================');
    console.log(`Console Logs: ${logs.console.length}`);
    console.log(`Errors: ${logs.errors.length}`);
    console.log(`Navigation Steps: ${logs.navigation.length}`);
    console.log(`Menu Items: ${logs.menuItems.length}`);
    console.log('\n✓ Report: tests/browser/reports/pim_menu_final_report.json');
    console.log('✓ Screenshots: tests/browser/screenshots/pim_*.png');
    console.log('================================================================================\n');

    await browser.close();
}

runPIMMenuTest().catch(console.error);
