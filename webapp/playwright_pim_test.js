#!/usr/bin/env node
/**
 * PIM Playwright Test Suite
 * Run: node pim_ playwright_test.js
 */

const { chromium } = require('playwright');

const BASE_URL = process.argv[2] || 'https://pim.technostationery.com';
const PASSWORD = '@dM1n$#@2o25B0T'; // from args

// Colors for console
const colors = {
    red: '\x1b[31m',
    green: '\x1b[32m', 
    yellow: '\x1b[33m',
    cyan: '\x1b[36m',
    reset: '\x1b[0m'
};

function log(msg, type = 'info') {
    const c = colors[type] || colors.cyan;
    console.log(`${c}${msg}${colors.reset}`);
}

async function runTests() {
    log('\n=== PIM PLAYWRIGHT TEST SUITE ===', 'cyan');
    log(`Target: ${BASE_URL}\n`);

    const browser = await chromium.launch({ 
        headless: false,
        args: ['--no-sandbox', '--disable-setuid-sandbox']
    });
    
    const context = await browser.newContext({
        viewport: { width: 1920, height: 1080 }
    });
    
    const page = await context.newPage();
    
    // Capture console logs
    const consoleLogs = [];
    const consoleErrors = [];
    const networkErrors = [];
    const jsErrors = [];
    
    page.on('console', msg => {
        const text = msg.text();
        consoleLogs.push({ type: msg.type(), text });
        if (msg.type() === 'error') {
            consoleErrors.push(text);
        }
    });
    
    page.on('pageerror', error => {
        jsErrors.push(error.message);
    });
    
    page.on('requestfailed', request => {
        networkErrors.push({
            url: request.url(),
            failure: request.failure()?.errorText
        });
    });
    
    const results = {
        homepage: { status: 0, time: 0 },
        login: { status: 0, time: 0 },
        css: { status: 0, size: 0 },
        js: { status: 0, errors: 0 },
        styles: {},
        performance: {}
    };
    
    try {
        // =========================================
        // TEST 1: Homepage
        // =========================================
        log('TEST 1: Homepage', 'cyan');
        const start1 = Date.now();
        const r1 = await page.goto(BASE_URL + '/', { 
            waitUntil: 'networkidle', 
            timeout: 30000 
        });
        results.homepage.status = r1.status();
        results.homepage.time = Date.now() - start1;
        log(`  Status: ${r1.status()} (${results.homepage.time}ms)`);
        if (r1.status() !== 200) {
            log('  ERROR: Homepage not 200!', 'red');
        }
        
        // =========================================
        // TEST 2: Login Page
        // =========================================
        log('\nTEST 2: Login Page', 'cyan');
        const start2 = Date.now();
        const r2 = await page.goto(BASE_URL + '/user/login', { 
            waitUntil: 'networkidle', 
            timeout: 30000 
        });
        results.login.status = r2.status();
        results.login.time = Date.now() - start2;
        log(`  Status: ${r2.status()} (${results.login.time}ms)`);
        
        if (r2.status() === 200) {
            // Check form elements
            const formData = await page.evaluate(() => {
                const form = document.querySelector('form[name="pim_user_security_login"]');
                const username = document.querySelector('input[name="_username"]');
                const password = document.querySelector('input[name="_password"]');
                const submit = document.querySelector('button[type="submit"]');
                const title = document.querySelector('title');
                return {
                    formExists: !!form,
                    usernameId: username?.id || username?.name,
                    passwordId: password?.id || password?.name,
                    submitText: submit?.textContent?.trim(),
                    pageTitle: title?.textContent
                };
            });
            
            log(`  Form exists: ${formData.formExists}`, formData.formExists ? 'green' : 'red');
            log(`  Username field: ${formData.usernameId}`, formData.usernameId ? 'green' : 'yellow');
            log(`  Password field: ${formData.passwordId}`, formData.passwordId ? 'green' : 'yellow');
            log(`  Submit button: ${formData.submitText}`, formData.submitText ? 'green' : 'yellow');
            
            // Check CSS styles
            const styles = await page.evaluate(() => {
                const body = document.body;
                const form = document.querySelector('form');
                const computedBody = window.getComputedStyle(body);
                const computedForm = form ? window.getComputedStyle(form) : null;
                return {
                    bodyBg: computedBody.backgroundColor,
                    bodyMinHeight: computedBody.minHeight,
                    formExists: !!form,
                    formPadding: computedForm?.padding,
                    formBg: computedForm?.backgroundColor
                };
            });
            
            results.styles = styles;
            log(`  Body background: ${styles.bodyBg}`);
            log(`  Form padding: ${styles.formPadding}`);
            log(`  Form background: ${styles.formBg}`);
            
            // Check for loading of pim.css
            const cssLoaded = await page.evaluate(() => {
                const links = Array.from(document.querySelectorAll('link[rel="stylesheet"]'));
                return links.map(l => l.href).filter(h => h && h.includes('pim.css'));
            });
            log(`  PIM CSS loaded: ${cssLoaded.length > 0 ? 'YES' : 'NO'} (${cssLoaded.length} links)`);
            
            // Capture screenshot
            await page.screenshot({ path: '/tmp/pim_login_test.png', fullPage: true });
            log('  Screenshot: /tmp/pim_login_test.png', 'cyan');
        }
        
        // =========================================
        // TEST 3: CSS File
        // =========================================
        log('\nTEST 3: CSS File', 'cyan');
        const start3 = Date.now();
        const r3 = await page.goto(BASE_URL + '/css/pim.css', { 
            waitUntil: 'domcontentloaded', 
            timeout: 10000 
        });
        results.css.status = r3.status();
        const blob = await r3.body();
        results.css.size = blob?.length || 0;
        log(`  Status: ${r3.status()}`);
        log(`  Size: ${results.css.size} bytes`);
        
        // =========================================
        // TEST 4: Check All Resources
        // =========================================
        log('\nTEST 4: Resource Loading', 'cyan');
        const resources = await page.evaluate(() => {
            return performance.getEntriesByType('resource').map(r => ({
                name: r.name.substring(0, 80),
                type: r.initiatorType,
                status: r.responseStatus || 'pending',
                size: r.transferSize
            })).filter(r => r.status >= 400 || r.status === 0);
        });
        
        results.js.errors = resources.length;
        log(`  Failed resources: ${resources.length}`);
        resources.forEach(r => {
            log(`    ${r.status}: ${r.name}`, 'yellow');
        });
        
        // =========================================
        // TEST 5: Console Logs
        // =========================================
        log('\nTEST 5: Console Output', 'cyan');
        const errors = consoleLogs.filter(l => l.type === 'error');
        log(`  Error logs: ${errors.length}`);
        if (errors.length > 0) {
            errors.slice(0, 5).forEach(e => {
                log(`    ${e.text.substring(0, 100)}`, 'yellow');
            });
        }
        
        // =========================================
        // SUMMARY
        // =========================================
        log('\n=== SUMMARY ===', 'cyan');
        log(`Homepage: ${results.homepage.status === 200 ? 'OK' : 'FAILED'} (${results.homepage.status})`);
        log(`Login: ${results.login.status === 200 ? 'OK' : 'FAILED'} (${results.login.status})`);
        log(`CSS: ${results.css.status === 200 ? 'OK' : 'FAILED'} (${results.css.size} bytes)`);
        log(`JS Errors: ${results.js.errors}`);
        
        if (jsErrors.length > 0) {
            log('\nJS Errors:', 'red');
            jsErrors.forEach(e => log(`  ${e}`, 'yellow'));
        }
        
        if (networkErrors.length > 0) {
            log('\nNetwork Errors:', 'red');
            networkErrors.forEach(e => log(`  ${e.url}: ${e.failure}`, 'yellow'));
        }
        
        // Performance metrics
        const perf = await page.evaluate(() => {
            const nav = performance.getEntriesByType('navigation')[0];
            return {
                domContentLoaded: nav?.domContentLoadedEventEnd - nav?.domContentLoadedEventStart,
                loadComplete: nav?.loadEventEnd - nav?.fetchStart,
                firstPaint: performance.getEntriesByType('paint').find(e => e.name === 'first-paint')?.startTime
            };
        });
        results.performance = perf;
        
        log('\nPerformance:', 'cyan');
        log(`  DOM Ready: ${Math.round(perf.domContentLoaded)}ms`);
        log(`  Page Loaded: ${Math.round(perf.loadComplete)}ms`);
        log(`  First Paint: ${Math.round(perf.firstPaint)}ms`);
        
        log('\n=== TEST COMPLETE ===\n', 'green');
        
    } catch (error) {
        log(`\nTEST FAILED: ${error.message}`, 'red');
        console.error(error);
    } finally {
        await browser.close();
    }
    
    process.exit(0);
}

runTests().catch(e => {
    console.error(e);
    process.exit(1);
});