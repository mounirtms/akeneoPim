#!/usr/bin/env node
/**
 * Simple PIM UI Test using Playwright (global)
 */

const { chromium } = require('playwright');

const BASE_URL = 'https://pim.technostationery.com';
const ADMIN_USER = 'testadmin';
const ADMIN_PASS = 'testpass';
const fs = require('fs');
const path = require('path');

const resultsDir = '/home/pim/public_html/webapp/test-results';
if (!fs.existsSync(resultsDir)) {
    fs.mkdirSync(resultsDir, { recursive: true });
}

(async () => {
    console.log('🚀 Starting PIM UI Tests...\n');
    
    const results = {
        timestamp: new Date().toISOString(),
        tests: [],
        errors: [],
        console_errors: [],
        failed_requests: []
    };

    const browser = await chromium.launch({ 
        headless: true,
        args: ['--no-sandbox', '--disable-setuid-sandbox']
    });

    const page = await browser.newPage();

    // Capture console errors globally
    page.on('console', msg => {
        if (msg.type() === 'error') {
            results.console_errors.push(msg.text());
        }
    });

    // Capture failed requests
    page.on('response', async (response) => {
        if (response.status() >= 400) {
            results.failed_requests.push({
                url: response.url(),
                status: response.status()
            });
        }
    });

    try {
        // TEST 1: Login
        console.log('TEST 1: Login');
        await page.goto(`${BASE_URL}/user/login`, { 
            waitUntil: 'networkidle',
            timeout: 30000 
        });

        await page.screenshot({ 
            path: path.join(resultsDir, '01-login.png'),
            fullPage: true 
        });

        // Fill login form
        await page.fill('input[name="_username"]', ADMIN_USER);
        await page.fill('input[name="_password"]', ADMIN_PASS);
        await page.click('button[type="submit"]');

        await page.waitForLoadState('networkidle', { timeout: 30000 });
        await new Promise(r => setTimeout(r, 3000));

        await page.screenshot({ 
            path: path.join(resultsDir, '02-dashboard.png'),
            fullPage: true 
        });

        console.log(`  URL: ${page.url()}`);
        console.log(`  Title: ${await page.title()}\n`);

        results.tests.push({
            name: 'Login',
            status: 'PASSED',
            url: page.url()
        });

        // TEST 2: Check Dashboard Metrics
        console.log('TEST 2: Dashboard Metrics');
        const bodyText = await page.evaluate(() => document.body.innerText);
        
        const metrics = {
            image_rate: bodyText.match(/Produits avec une image.*?(\d+)%/) || 'Not found',
            enrichment_rate: bodyText.match(/taux d.enrichissement.*?(\d+)%/) || 'Not found',
            products_count: bodyText.match(/([0-9,]+)\s+produits/) || 'Not found'
        };

        console.log(`  Image Rate: ${metrics.image_rate}`);
        console.log(`  Enrichment Rate: ${metrics.enrichment_rate}\n`);

        results.dashboard_metrics = metrics;

        // TEST 3: Navigate to Products
        console.log('TEST 3: Products Grid');
        await page.goto(`${BASE_URL}/enrich/product/`, { 
            waitUntil: 'networkidle',
            timeout: 30000 
        });
        await new Promise(r => setTimeout(r, 5000));

        await page.screenshot({ 
            path: path.join(resultsDir, '03-products.png'),
            fullPage: true 
        });

        console.log(`  URL: ${page.url()}`);
        console.log(`  Console errors on page: ${results.console_errors.length}\n`);

        results.tests.push({
            name: 'Products Grid',
            status: 'PASSED',
            url: page.url(),
            console_errors: results.console_errors.length
        });

        // TEST 4: Navigate to Categories
        console.log('TEST 4: Categories');
        await page.goto(`${BASE_URL}/enrich/product-category-tree/`, { 
            waitUntil: 'networkidle',
            timeout: 30000 
        });
        await new Promise(r => setTimeout(r, 3000));

        await page.screenshot({ 
            path: path.join(resultsDir, '04-categories.png'),
            fullPage: true 
        });

        console.log(`  URL: ${page.url()}\n`);

        results.tests.push({
            name: 'Categories',
            status: 'PASSED',
            url: page.url()
        });

        // TEST 5: Extract all menu items
        console.log('TEST 5: Menu Items');
        const menuItems = await page.evaluate(() => {
            const links = Array.from(document.querySelectorAll('nav a, .menu a, aside a'));
            return links
                .map(link => ({
                    text: link.textContent.trim(),
                    href: link.getAttribute('href')
                }))
                .filter(item => item.text && item.text.length > 2);
        });

        console.log(`  Found ${menuItems.length} menu items:`);
        menuItems.slice(0, 20).forEach(item => {
            console.log(`    - ${item.text}`);
        });
        console.log('');

        results.menu_items = menuItems;

        // TEST 6: Check for errors on current page
        console.log('TEST 6: Error Scan');
        const pageErrors = await page.evaluate(() => {
            const errors = [];
            ['.alert-danger', '.alert-error', '.flash-error'].forEach(selector => {
                document.querySelectorAll(selector).forEach(el => {
                    errors.push(el.textContent.trim());
                });
            });
            return errors;
        });

        if (pageErrors.length > 0) {
            console.log(`  ❌ Found ${pageErrors.length} errors:`);
            pageErrors.forEach(err => console.log(`    ${err}`));
        } else {
            console.log('  ✅ No visible errors\n');
        }

        results.page_errors = pageErrors;

        // Save results
        fs.writeFileSync(
            path.join(resultsDir, 'results.json'),
            JSON.stringify(results, null, 2)
        );

        console.log('\n✅ All tests complete!');
        console.log(`📁 Results: ${resultsDir}`);

    } catch (error) {
        console.error('❌ Test error:', error.message);
        results.errors.push(error.message);
        
        // Screenshot on error
        await page.screenshot({ 
            path: path.join(resultsDir, 'error.png'),
            fullPage: true 
        });
    } finally {
        await browser.close();
    }
})();
