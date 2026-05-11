#!/usr/bin/env node
/**
 * Comprehensive Audit Test - Post CloudFlare Development Mode
 * Captures detailed logs, screenshots, and diagnostics
 */

const { chromium } = require('playwright');
const fs = require('fs');

const BASE_URL = 'https://pim.technostationery.com';
const credentials = { username: 'admin', password: 'Admin@2024' };

async function runAudit() {
    console.log('================================================================================');
    console.log('COMPREHENSIVE AUDIT TEST - CloudFlare Development Mode Active');
    console.log('================================================================================\n');

    const browser = await chromium.launch({ headless: true });
    const context = await browser.newContext({
        userAgent: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/120.0.0.0',
        viewport: { width: 1920, height: 1080 }
    });
    const page = await context.newPage();

    const logs = {
        console: [],
        errors: [],
        requests: [],
        responses: [],
        headers: [],
        cookies: []
    };

    // Capture console
    page.on('console', msg => {
        const entry = `[${msg.type()}] ${msg.text()}`;
        logs.console.push(entry);
        console.log(`📝 ${entry}`);
    });

    // Capture errors
    page.on('pageerror', error => {
        logs.errors.push(error.message);
        console.log(`❌ ERROR: ${error.message}`);
    });

    // Capture network
    page.on('request', req => {
        logs.requests.push({
            url: req.url(),
            method: req.method(),
            headers: req.headers()
        });
    });

    page.on('response', async resp => {
        const headers = await resp.allHeaders();
        logs.responses.push({
            url: resp.url(),
            status: resp.status(),
            headers: headers
        });
        
        // Log caching headers
        if (resp.url().includes('pim.technostationery.com')) {
            console.log(`\n🌐 ${resp.status()} ${resp.url()}`);
            console.log(`   Cache-Control: ${headers['cache-control'] || 'none'}`);
            console.log(`   CF-Cache-Status: ${headers['cf-cache-status'] || 'none'}`);
            console.log(`   X-Varnish: ${headers['x-varnish'] || 'none'}`);
        }
    });

    try {
        console.log('📍 Step 1: Loading login page...\n');
        await page.goto(`${BASE_URL}/user/login`, { waitUntil: 'networkidle', timeout: 30000 });
        
        // Capture cookies
        const cookies = await context.cookies();
        logs.cookies = cookies;
        console.log(`\n🍪 Cookies: ${cookies.length} cookies received`);
        cookies.forEach(c => console.log(`   ${c.name}: ${c.value.substring(0, 20)}...`));

        await page.screenshot({ path: 'tests/browser/screenshots/audit_01_login.png', fullPage: true });

        // Check security headers
        const securityHeaders = await page.evaluate(() => {
            const meta = {};
            document.querySelectorAll('meta').forEach(m => {
                if (m.getAttribute('http-equiv')) {
                    meta[m.getAttribute('http-equiv')] = m.getAttribute('content');
                }
            });
            return meta;
        });

        console.log('\n🔒 Security Headers:');
        console.log(JSON.stringify(securityHeaders, null, 2));

        // Check assets loading
        console.log('\n📦 Asset Loading Check:');
        const assetCheck = await page.evaluate(() => {
            const checks = {
                cssLoaded: !!document.querySelector('link[href*="pim.css"]'),
                jsLoaded: !!document.querySelector('script[src*="require"]'),
                imagesLoaded: document.querySelectorAll('img').length,
                hasForm: !!document.querySelector('form'),
                hasCsrfToken: !!document.querySelector('input[name="_csrf_token"]')
            };
            return checks;
        });
        console.log(JSON.stringify(assetCheck, null, 2));

        // Try login
        console.log('\n📍 Step 2: Attempting login...\n');
        await page.waitForSelector('input[name="_username"]', { timeout: 5000 });
        await page.fill('input[name="_username"]', credentials.username);
        await page.fill('input[name="_password"]', credentials.password);
        
        await page.screenshot({ path: 'tests/browser/screenshots/audit_02_filled.png', fullPage: true });

        // Submit and wait
        await Promise.all([
            page.waitForNavigation({ timeout: 10000 }).catch(() => null),
            page.click('button[type="submit"]')
        ]);

        await page.waitForTimeout(2000);
        await page.screenshot({ path: 'tests/browser/screenshots/audit_03_result.png', fullPage: true });

        const finalUrl = page.url();
        console.log(`\n🎯 Final URL: ${finalUrl}`);
        console.log(`   Login Success: ${!finalUrl.includes('/login')}`);

        // Check for error messages
        const pageErrors = await page.evaluate(() => {
            const errors = [];
            document.querySelectorAll('.alert-error, .alert-danger, .error').forEach(el => {
                errors.push(el.textContent.trim());
            });
            return errors;
        });

        if (pageErrors.length > 0) {
            console.log('\n⚠️  Page Errors:');
            pageErrors.forEach(e => console.log(`   ${e}`));
        }

    } catch (error) {
        console.log(`\n❌ Test Error: ${error.message}`);
        logs.errors.push(error.message);
    }

    // Save report
    const report = {
        timestamp: new Date().toISOString(),
        logs: logs,
        summary: {
            consoleMessages: logs.console.length,
            errors: logs.errors.length,
            requests: logs.requests.length,
            responses: logs.responses.length,
            cookies: logs.cookies.length
        }
    };

    fs.writeFileSync('tests/browser/reports/audit_report.json', JSON.stringify(report, null, 2));
    
    console.log('\n================================================================================');
    console.log('AUDIT COMPLETE');
    console.log('================================================================================');
    console.log(`Console Messages: ${logs.console.length}`);
    console.log(`Errors: ${logs.errors.length}`);
    console.log(`HTTP Requests: ${logs.requests.length}`);
    console.log(`HTTP Responses: ${logs.responses.length}`);
    console.log(`\n✓ Report: tests/browser/reports/audit_report.json`);
    console.log('✓ Screenshots: tests/browser/screenshots/audit_*.png\n');

    await browser.close();
}

runAudit().catch(console.error);
