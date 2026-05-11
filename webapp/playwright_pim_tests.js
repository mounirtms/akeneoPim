const { chromium } = require('playwright');
const fs = require('fs');

const BASE_URL = 'https://pim.technostationery.com';
const USERNAME = 'admin';
const PASSWORD = 'Admin123!';

// Test results storage
const testResults = {
    timestamp: new Date().toISOString(),
    url: BASE_URL,
    tests: [],
    screenshots: [],
    consoleLogs: [],
    networkLogs: []
};

async function runTests() {
    console.log('==========================================');
    console.log('PLAYWRIGHT - Akeneo PIM Test Suite');
    console.log('Date:', new Date().toISOString());
    console.log('==========================================\n');

    const browser = await chromium.launch({
        headless: true,
        args: ['--no-sandbox', '--disable-setuid-sandbox']
    });
    
    const context = await browser.newContext({
        viewport: { width: 1920, height: 1080 },
        ignoreHTTPSErrors: true,
        userAgent: 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
    });
    
    const page = await context.newPage();

    // Capture console logs
    page.on('console', msg => {
        const log = {
            type: msg.type(),
            text: msg.text(),
            timestamp: new Date().toISOString()
        };
        testResults.consoleLogs.push(log);
        console.log(`[CONSOLE ${msg.type()}] ${msg.text()}`);
    });

    // Capture network requests
    page.on('response', response => {
        const log = {
            url: response.url(),
            status: response.status(),
            statusText: response.statusText(),
            contentType: response.headers()['content-type'],
            timestamp: new Date().toISOString()
        };
        testResults.networkLogs.push(log);
    });

    // Capture page errors
    page.on('pageerror', error => {
        testResults.consoleLogs.push({
            type: 'pageerror',
            text: error.message,
            stack: error.stack,
            timestamp: new Date().toISOString()
        });
        console.log(`[PAGE ERROR] ${error.message}`);
    });

    try {
        // TEST 1: Homepage Load
        await test('Homepage Load', async () => {
            console.log('\n=== TEST 1: Homepage Load ===');
            const startTime = Date.now();
            await page.goto(BASE_URL, { waitUntil: 'networkidle', timeout: 30000 });
            const loadTime = Date.now() - startTime;
            
            await page.screenshot({ path: '/home/pim/public_html/webapp/screenshot_01_homepage.png', fullPage: true });
            testResults.screenshots.push('screenshot_01_homepage.png');
            
            const title = await page.title();
            console.log(`✓ Page loaded in ${loadTime}ms`);
            console.log(`✓ Title: ${title}`);
            
            return {
                success: true,
                loadTime,
                title,
                message: `Homepage loaded successfully in ${loadTime}ms`
            };
        });

        // TEST 2: Login Page Elements
        await test('Login Page Elements', async () => {
            console.log('\n=== TEST 2: Login Page Elements ===');
            
            // Check for login form elements
            const hasUsernameField = await page.locator('input[name="_username"], input#_username, input[type="text"]').count() > 0;
            const hasPasswordField = await page.locator('input[name="_password"], input#_password, input[type="password"]').count() > 0;
            const hasSubmitButton = await page.locator('button[type="submit"], input[type="submit"], .btn-primary').count() > 0;
            
            console.log(`✓ Username field: ${hasUsernameField ? 'Found' : 'Missing'}`);
            console.log(`✓ Password field: ${hasPasswordField ? 'Found' : 'Missing'}`);
            console.log(`✓ Submit button: ${hasSubmitButton ? 'Found' : 'Missing'}`);
            
            await page.screenshot({ path: '/home/pim/public_html/webapp/screenshot_02_login_page.png', fullPage: true });
            testResults.screenshots.push('screenshot_02_login_page.png');
            
            return {
                success: hasUsernameField && hasPasswordField && hasSubmitButton,
                elements: { hasUsernameField, hasPasswordField, hasSubmitButton },
                message: 'Login page elements validated'
            };
        });

        // TEST 3: Login Attempt
        await test('Login Functionality', async () => {
            console.log('\n=== TEST 3: Login Functionality ===');
            
            try {
                // Try multiple selector strategies
                const usernameSelectors = [
                    'input[name="_username"]',
                    'input#_username',
                    'input[type="text"]',
                    'input.form-control:first-of-type',
                    '[placeholder*="username" i]',
                    '[placeholder*="email" i]'
                ];
                
                const passwordSelectors = [
                    'input[name="_password"]',
                    'input#_password',
                    'input[type="password"]',
                    '[placeholder*="password" i]'
                ];
                
                const buttonSelectors = [
                    'button[type="submit"]',
                    'input[type="submit"]',
                    '.btn-primary',
                    'button:has-text("Log in")',
                    'button:has-text("Sign in")',
                    'button:has-text("Login")'
                ];
                
                // Fill username
                let usernameFilled = false;
                for (const selector of usernameSelectors) {
                    if (await page.locator(selector).count() > 0) {
                        await page.locator(selector).first().fill(USERNAME);
                        console.log(`✓ Username filled using selector: ${selector}`);
                        usernameFilled = true;
                        break;
                    }
                }
                
                // Fill password
                let passwordFilled = false;
                for (const selector of passwordSelectors) {
                    if (await page.locator(selector).count() > 0) {
                        await page.locator(selector).first().fill(PASSWORD);
                        console.log(`✓ Password filled using selector: ${selector}`);
                        passwordFilled = true;
                        break;
                    }
                }
                
                await page.screenshot({ path: '/home/pim/public_html/webapp/screenshot_03_credentials_filled.png', fullPage: true });
                testResults.screenshots.push('screenshot_03_credentials_filled.png');
                
                // Click submit button
                let buttonClicked = false;
                for (const selector of buttonSelectors) {
                    if (await page.locator(selector).count() > 0) {
                        await page.locator(selector).first().click();
                        console.log(`✓ Submit button clicked using selector: ${selector}`);
                        buttonClicked = true;
                        break;
                    }
                }
                
                // Wait for navigation or error message
                await page.waitForTimeout(3000);
                
                const currentUrl = page.url();
                console.log(`✓ Current URL after login: ${currentUrl}`);
                
                await page.screenshot({ path: '/home/pim/public_html/webapp/screenshot_04_after_login.png', fullPage: true });
                testResults.screenshots.push('screenshot_04_after_login.png');
                
                // Check if login was successful
                const isStillOnLogin = currentUrl.includes('/user/login') || currentUrl.includes('/login');
                const hasErrorMessage = await page.locator('.alert-error, .error, .invalid-feedback, [class*="error"]').count() > 0;
                
                if (hasErrorMessage) {
                    const errorText = await page.locator('.alert-error, .error, .invalid-feedback, [class*="error"]').first().textContent();
                    console.log(`✗ Error message: ${errorText}`);
                }
                
                return {
                    success: !isStillOnLogin && !hasErrorMessage,
                    usernameFilled,
                    passwordFilled,
                    buttonClicked,
                    currentUrl,
                    hasErrorMessage,
                    message: isStillOnLogin ? 'Login failed - still on login page' : 'Login successful'
                };
            } catch (error) {
                console.error(`✗ Login failed: ${error.message}`);
                return {
                    success: false,
                    error: error.message,
                    message: 'Login test encountered an error'
                };
            }
        });

        // TEST 4: Dashboard Elements
        await test('Dashboard Navigation', async () => {
            console.log('\n=== TEST 4: Dashboard Navigation ===');
            
            try {
                // Wait for dashboard to load
                await page.waitForTimeout(2000);
                
                const currentUrl = page.url();
                console.log(`✓ Current URL: ${currentUrl}`);
                
                // Check for common Akeneo dashboard elements
                const hasNavigation = await page.locator('nav, .navigation, #navigation, [role="navigation"]').count() > 0;
                const hasLogo = await page.locator('img[alt*="logo" i], .logo, #logo').count() > 0;
                const hasUserMenu = await page.locator('.user-menu, #user-menu, [class*="user"]').count() > 0;
                
                console.log(`✓ Navigation bar: ${hasNavigation ? 'Present' : 'Missing'}`);
                console.log(`✓ Logo: ${hasLogo ? 'Present' : 'Missing'}`);
                console.log(`✓ User menu: ${hasUserMenu ? 'Present' : 'Missing'}`);
                
                await page.screenshot({ path: '/home/pim/public_html/webapp/screenshot_05_dashboard.png', fullPage: true });
                testResults.screenshots.push('screenshot_05_dashboard.png');
                
                return {
                    success: hasNavigation || hasLogo,
                    elements: { hasNavigation, hasLogo, hasUserMenu },
                    currentUrl,
                    message: 'Dashboard elements checked'
                };
            } catch (error) {
                return {
                    success: false,
                    error: error.message,
                    message: 'Dashboard navigation test failed'
                };
            }
        });

        // TEST 5: Menu Items
        await test('Main Menu Items', async () => {
            console.log('\n=== TEST 5: Main Menu Items ===');
            
            try {
                // Look for common Akeneo menu items
                const menuItems = [
                    'Activity',
                    'Products',
                    'Enrich',
                    'Settings',
                    'System',
                    'Catalogs',
                    'Categories'
                ];
                
                const foundMenus = [];
                for (const item of menuItems) {
                    const exists = await page.locator(`text="${item}"`).count() > 0;
                    if (exists) {
                        foundMenus.push(item);
                        console.log(`✓ Menu item found: ${item}`);
                    }
                }
                
                await page.screenshot({ path: '/home/pim/public_html/webapp/screenshot_06_menu_items.png', fullPage: true });
                testResults.screenshots.push('screenshot_06_menu_items.png');
                
                return {
                    success: foundMenus.length > 0,
                    foundMenus,
                    totalChecked: menuItems.length,
                    message: `Found ${foundMenus.length} menu items`
                };
            } catch (error) {
                return {
                    success: false,
                    error: error.message,
                    message: 'Menu items test failed'
                };
            }
        });

        // TEST 6: CSS Loading
        await test('CSS and Styles Check', async () => {
            console.log('\n=== TEST 6: CSS and Styles Check ===');
            
            try {
                // Check for loaded stylesheets
                const stylesheets = await page.evaluate(() => {
                    return Array.from(document.styleSheets).map(sheet => {
                        try {
                            return {
                                href: sheet.href,
                                rules: sheet.cssRules ? sheet.cssRules.length : 0
                            };
                        } catch (e) {
                            return { href: sheet.href, error: e.message };
                        }
                    });
                });
                
                console.log(`✓ Total stylesheets loaded: ${stylesheets.length}`);
                stylesheets.forEach((sheet, i) => {
                    if (sheet.href) {
                        console.log(`  ${i + 1}. ${sheet.href.substring(sheet.href.lastIndexOf('/') + 1)} (${sheet.rules || 0} rules)`);
                    }
                });
                
                // Check computed styles of body
                const bodyStyles = await page.evaluate(() => {
                    const body = document.body;
                    const styles = window.getComputedStyle(body);
                    return {
                        backgroundColor: styles.backgroundColor,
                        fontFamily: styles.fontFamily,
                        fontSize: styles.fontSize,
                        color: styles.color
                    };
                });
                
                console.log('✓ Body styles:');
                console.log(`  Background: ${bodyStyles.backgroundColor}`);
                console.log(`  Font: ${bodyStyles.fontFamily}`);
                console.log(`  Size: ${bodyStyles.fontSize}`);
                console.log(`  Color: ${bodyStyles.color}`);
                
                return {
                    success: stylesheets.length > 0,
                    stylesheetsCount: stylesheets.length,
                    stylesheets: stylesheets.slice(0, 10), // First 10
                    bodyStyles,
                    message: `${stylesheets.length} stylesheets loaded`
                };
            } catch (error) {
                return {
                    success: false,
                    error: error.message,
                    message: 'CSS check failed'
                };
            }
        });

        // TEST 7: JavaScript Errors
        await test('JavaScript Error Check', async () => {
            console.log('\n=== TEST 7: JavaScript Error Check ===');
            
            const jsErrors = testResults.consoleLogs.filter(log => 
                log.type === 'error' || log.type === 'pageerror'
            );
            
            console.log(`✓ Total JS errors found: ${jsErrors.length}`);
            if (jsErrors.length > 0) {
                console.log('Errors:');
                jsErrors.forEach((error, i) => {
                    console.log(`  ${i + 1}. ${error.text}`);
                });
            }
            
            return {
                success: jsErrors.length === 0,
                errorCount: jsErrors.length,
                errors: jsErrors,
                message: jsErrors.length === 0 ? 'No JavaScript errors' : `${jsErrors.length} JavaScript errors found`
            };
        });

        // TEST 8: Performance Metrics
        await test('Performance Metrics', async () => {
            console.log('\n=== TEST 8: Performance Metrics ===');
            
            const metrics = await page.evaluate(() => {
                const perf = performance.getEntriesByType('navigation')[0];
                return {
                    domContentLoaded: perf.domContentLoadedEventEnd - perf.domContentLoadedEventStart,
                    loadComplete: perf.loadEventEnd - perf.loadEventStart,
                    domInteractive: perf.domInteractive,
                    responseTime: perf.responseEnd - perf.requestStart,
                    totalResources: performance.getEntriesByType('resource').length
                };
            });
            
            console.log('✓ Performance metrics:');
            console.log(`  DOM Content Loaded: ${metrics.domContentLoaded.toFixed(2)}ms`);
            console.log(`  Load Complete: ${metrics.loadComplete.toFixed(2)}ms`);
            console.log(`  Response Time: ${metrics.responseTime.toFixed(2)}ms`);
            console.log(`  Total Resources: ${metrics.totalResources}`);
            
            return {
                success: metrics.responseTime < 5000, // Less than 5 seconds
                metrics,
                message: 'Performance metrics captured'
            };
        });

    } catch (error) {
        console.error('Test suite error:', error);
        testResults.tests.push({
            name: 'Test Suite Error',
            success: false,
            error: error.message,
            stack: error.stack
        });
    } finally {
        // Close browser
        await browser.close();
    }

    // Helper function to run individual tests
    async function test(name, fn) {
        const result = {
            name,
            timestamp: new Date().toISOString(),
            success: false
        };
        
        try {
            const testResult = await fn();
            Object.assign(result, testResult);
        } catch (error) {
            result.success = false;
            result.error = error.message;
            result.stack = error.stack;
        }
        
        testResults.tests.push(result);
        console.log(result.success ? '✓ PASS' : '✗ FAIL');
    }

    // Generate report
    generateReport();
}

function generateReport() {
    console.log('\n==========================================');
    console.log('TEST RESULTS SUMMARY');
    console.log('==========================================\n');
    
    const passed = testResults.tests.filter(t => t.success).length;
    const failed = testResults.tests.length - passed;
    const passRate = ((passed / testResults.tests.length) * 100).toFixed(1);
    
    console.log(`Total Tests: ${testResults.tests.length}`);
    console.log(`Passed: ${passed}`);
    console.log(`Failed: ${failed}`);
    console.log(`Pass Rate: ${passRate}%\n`);
    
    console.log('Test Details:');
    testResults.tests.forEach((test, i) => {
        console.log(`${i + 1}. ${test.name}: ${test.success ? '✓ PASS' : '✗ FAIL'}`);
        if (test.message) console.log(`   ${test.message}`);
        if (test.error) console.log(`   Error: ${test.error}`);
    });
    
    console.log(`\nScreenshots: ${testResults.screenshots.length} saved`);
    console.log(`Console Logs: ${testResults.consoleLogs.length} captured`);
    console.log(`Network Requests: ${testResults.networkLogs.length} logged`);
    
    // Save detailed report to JSON
    const reportPath = '/home/pim/public_html/webapp/playwright_test_report.json';
    fs.writeFileSync(reportPath, JSON.stringify(testResults, null, 2));
    console.log(`\nDetailed report saved to: ${reportPath}`);
    
    console.log('\n==========================================');
}

// Run tests
runTests().catch(console.error);

