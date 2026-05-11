#!/usr/bin/env node
/**
 * Enhanced Real Browser Login Test
 * 
 * This test addresses the authentication failure by:
 * 1. Using a realistic user agent (not HeadlessChrome)
 * 2. Handling CloudFlare challenges properly
 * 3. Waiting for redirects and dynamic content
 * 4. Capturing detailed authentication flow
 */

const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');

// Configuration
const BASE_URL = 'https://pim.technostationery.com';
const LOGIN_URL = `${BASE_URL}/user/login`;
const DASHBOARD_URL = `${BASE_URL}/`;

const credentials = {
    username: 'admin',
    password: 'Admin@2024'
};

// Real browser user agent (Chrome on Windows)
const REAL_USER_AGENT = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

async function runEnhancedLoginTest() {
    console.log('================================================================================');
    console.log('ENHANCED LOGIN TEST - Real User Agent & CloudFlare Handling');
    console.log('================================================================================\n');

    const browser = await chromium.launch({
        headless: true, // Must use headless in sandbox environment
        args: [
            '--disable-blink-features=AutomationControlled', // Hide automation
            '--disable-web-security',
            '--no-sandbox'
        ]
    });

    const context = await browser.newContext({
        userAgent: REAL_USER_AGENT,
        viewport: { width: 1920, height: 1080 },
        locale: 'en-US',
        timezoneId: 'America/New_York',
        // Add realistic browser features
        extraHTTPHeaders: {
            'Accept-Language': 'en-US,en;q=0.9',
            'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8'
        }
    });

    const page = await context.newPage();

    // Tracking arrays
    const consoleLogs = [];
    const jsErrors = [];
    const networkRequests = [];
    const networkResponses = [];

    // Console monitoring
    page.on('console', msg => {
        const logEntry = {
            type: msg.type(),
            text: msg.text(),
            timestamp: new Date().toISOString()
        };
        consoleLogs.push(logEntry);
        if (msg.type() === 'error') {
            console.log(`❌ CONSOLE ERROR: ${msg.text()}`);
        }
    });

    // JavaScript error capture
    page.on('pageerror', error => {
        jsErrors.push({
            message: error.message,
            stack: error.stack,
            timestamp: new Date().toISOString()
        });
        console.log(`❌ JS ERROR: ${error.message}`);
    });

    // Network monitoring
    page.on('request', request => {
        networkRequests.push({
            url: request.url(),
            method: request.method(),
            timestamp: new Date().toISOString()
        });
        
        // Log authentication-related requests
        if (request.url().includes('login-check')) {
            console.log(`📤 POST to login-check`);
        }
    });

    page.on('response', response => {
        networkResponses.push({
            url: response.url(),
            status: response.status(),
            timestamp: new Date().toISOString()
        });

        // Log authentication responses
        if (response.url().includes('login-check')) {
            console.log(`📥 Response from login-check: ${response.status()}`);
        }
    });

    try {
        // Step 1: Navigate to login page
        console.log('📍 Step 1: Loading login page...');
        console.log('────────────────────────────────────────────────────────────────────────────────');
        
        await page.goto(LOGIN_URL, { 
            waitUntil: 'networkidle',
            timeout: 30000 
        });
        
        console.log(`✓ Login page loaded`);
        console.log(`  Current URL: ${page.url()}`);
        console.log(`  User Agent: ${await page.evaluate(() => navigator.userAgent)}\n`);

        // Wait for CloudFlare challenges to complete
        console.log('⏳ Waiting for CloudFlare challenges...');
        await page.waitForTimeout(3000);

        // Screenshot: Initial page
        await page.screenshot({ 
            path: 'tests/browser/screenshots/enhanced_01_initial.png',
            fullPage: true 
        });

        // Step 2: Analyze form
        console.log('📍 Step 2: Analyzing login form...');
        console.log('────────────────────────────────────────────────────────────────────────────────');

        const formData = await page.evaluate(() => {
            const usernameField = document.querySelector('input[name="_username"]');
            const passwordField = document.querySelector('input[name="_password"]');
            const csrfField = document.querySelector('input[name="_csrf_token"]');
            const form = document.querySelector('form');

            return {
                hasUsernameField: !!usernameField,
                hasPasswordField: !!passwordField,
                hasCsrfField: !!csrfField,
                csrfToken: csrfField ? csrfField.value : null,
                formAction: form ? form.action : null,
                formMethod: form ? form.method : null,
                usernameFieldVisible: usernameField ? usernameField.offsetWidth > 0 : false,
                passwordFieldVisible: passwordField ? passwordField.offsetWidth > 0 : false
            };
        });

        console.log(`Form Analysis:`);
        console.log(`  Username field: ${formData.hasUsernameField ? '✓' : '✗'} (visible: ${formData.usernameFieldVisible})`);
        console.log(`  Password field: ${formData.hasPasswordField ? '✓' : '✗'} (visible: ${formData.passwordFieldVisible})`);
        console.log(`  CSRF token: ${formData.hasCsrfField ? '✓' : '✗'} (${formData.csrfToken ? formData.csrfToken.substring(0, 20) + '...' : 'none'})`);
        console.log(`  Form action: ${formData.formAction}`);
        console.log(`  Form method: ${formData.formMethod}\n`);

        // Step 3: Fill form using Playwright's fill() method
        console.log('📍 Step 3: Filling login form...');
        console.log('────────────────────────────────────────────────────────────────────────────────');

        // Wait for form to be ready
        await page.waitForSelector('input[name="_username"]', { state: 'visible' });
        await page.waitForSelector('input[name="_password"]', { state: 'visible' });

        // Clear and fill username
        await page.click('input[name="_username"]');
        await page.fill('input[name="_username"]', '');
        await page.type('input[name="_username"]', credentials.username, { delay: 100 });
        console.log(`✓ Username entered: ${credentials.username}`);

        // Clear and fill password
        await page.click('input[name="_password"]');
        await page.fill('input[name="_password"]', '');
        await page.type('input[name="_password"]', credentials.password, { delay: 100 });
        console.log(`✓ Password entered: ${'*'.repeat(credentials.password.length)}`);

        await page.waitForTimeout(1000);

        // Verify values are set
        const fieldValues = await page.evaluate(() => {
            return {
                username: document.querySelector('input[name="_username"]').value,
                password: document.querySelector('input[name="_password"]').value
            };
        });

        console.log(`\nField Verification:`);
        console.log(`  Username value: "${fieldValues.username}"`);
        console.log(`  Password length: ${fieldValues.password.length} chars`);

        // Screenshot: Form filled
        await page.screenshot({ 
            path: 'tests/browser/screenshots/enhanced_02_form_filled.png',
            fullPage: true 
        });

        // Step 4: Submit form and wait for navigation
        console.log('\n📍 Step 4: Submitting form...');
        console.log('────────────────────────────────────────────────────────────────────────────────');

        // Click submit button and wait for navigation
        const submitButton = await page.$('button[type="submit"]');
        
        console.log('Clicking submit button...');
        
        // Use Promise.race to handle both successful redirect and failed redirect
        const navigationPromise = page.waitForNavigation({ 
            timeout: 10000,
            waitUntil: 'networkidle'
        }).catch(() => null);

        await submitButton.click();
        await navigationPromise;

        // Wait for any pending requests
        await page.waitForTimeout(3000);

        // Screenshot: After submit
        await page.screenshot({ 
            path: 'tests/browser/screenshots/enhanced_03_after_submit.png',
            fullPage: true 
        });

        // Step 5: Analyze authentication result
        console.log('\n📍 Step 5: Analyzing authentication result...');
        console.log('────────────────────────────────────────────────────────────────────────────────');

        const currentUrl = page.url();
        console.log(`Current URL: ${currentUrl}`);

        const pageAnalysis = await page.evaluate(() => {
            return {
                title: document.title,
                hasErrorMessage: !!document.querySelector('.alert-error, .error-message, .alert-danger'),
                errorText: document.querySelector('.alert-error, .error-message, .alert-danger')?.textContent?.trim(),
                hasPimApp: !!document.querySelector('#pim-app, [data-app="pim"]'),
                hasMainContent: !!document.querySelector('#container, main'),
                url: window.location.href,
                bodyClasses: document.body.className,
                navLinks: Array.from(document.querySelectorAll('nav a, .navigation a')).map(a => a.textContent.trim()).filter(t => t)
            };
        });

        console.log(`\nPage Analysis:`);
        console.log(`  Title: ${pageAnalysis.title}`);
        console.log(`  Has error message: ${pageAnalysis.hasErrorMessage}`);
        if (pageAnalysis.errorText) {
            console.log(`  Error message: ${pageAnalysis.errorText}`);
        }
        console.log(`  Has PIM app: ${pageAnalysis.hasPimApp}`);
        console.log(`  Has main content: ${pageAnalysis.hasMainContent}`);
        console.log(`  Body classes: ${pageAnalysis.bodyClasses}`);
        console.log(`  Navigation links: ${pageAnalysis.navLinks.length}`);

        // Check authentication status
        const isAuthenticated = !currentUrl.includes('/login') && (
            pageAnalysis.hasPimApp || 
            pageAnalysis.navLinks.length > 5 ||
            currentUrl === BASE_URL + '/' ||
            currentUrl === BASE_URL
        );

        console.log('\n────────────────────────────────────────────────────────────────────────────────');
        if (isAuthenticated) {
            console.log('✅ SUCCESS: User authenticated successfully!');
            console.log(`   Redirected to: ${currentUrl}`);
        } else {
            console.log('❌ FAIL: Authentication failed - still on login page');
            console.log(`   Current URL: ${currentUrl}`);
            
            // Log recent network activity around login-check
            const loginCheckRequests = networkRequests.filter(r => r.url.includes('login-check'));
            const loginCheckResponses = networkResponses.filter(r => r.url.includes('login-check'));
            
            console.log('\n🔍 Authentication Request Analysis:');
            loginCheckRequests.forEach(req => {
                console.log(`  ${req.method} ${req.url}`);
            });
            
            console.log('\n🔍 Authentication Response Analysis:');
            loginCheckResponses.forEach(res => {
                console.log(`  Status ${res.status} for ${res.url}`);
            });
        }

        // Wait a bit for user to see the result
        await page.waitForTimeout(3000);

    } catch (error) {
        console.log(`\n❌ ERROR: ${error.message}`);
        console.log(error.stack);
    } finally {
        // Generate report
        const report = {
            timestamp: new Date().toISOString(),
            testName: 'Enhanced Login Test with Real User Agent',
            userAgent: REAL_USER_AGENT,
            result: {
                finalUrl: await page.url().catch(() => 'unknown'),
                consoleLogs: consoleLogs.length,
                jsErrors: jsErrors.length,
                networkRequests: networkRequests.length,
                networkResponses: networkResponses.length
            },
            consoleLogs,
            jsErrors,
            authenticationFlow: {
                loginCheckRequests: networkRequests.filter(r => r.url.includes('login-check')),
                loginCheckResponses: networkResponses.filter(r => r.url.includes('login-check')),
                redirects: networkResponses.filter(r => r.status >= 300 && r.status < 400)
            }
        };

        fs.writeFileSync(
            'tests/browser/reports/enhanced_login_test_report.json',
            JSON.stringify(report, null, 2)
        );

        console.log('\n================================================================================');
        console.log('TEST SUMMARY');
        console.log('================================================================================');
        console.log(`Console logs: ${consoleLogs.length}`);
        console.log(`JS errors: ${jsErrors.length}`);
        console.log(`Network requests: ${networkRequests.length}`);
        console.log(`Network responses: ${networkResponses.length}`);
        console.log('\n✓ Report saved: tests/browser/reports/enhanced_login_test_report.json');
        console.log('✓ Screenshots: tests/browser/screenshots/enhanced_*.png');
        console.log('================================================================================\n');

        await browser.close();
    }
}

// Run test
runEnhancedLoginTest().catch(console.error);
