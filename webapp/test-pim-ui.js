#!/usr/bin/env node
/**
 * Akeneo PIM UI Test Script
 * Uses Puppeteer to login, check menus, and capture errors
 */

const puppeteer = require('puppeteer');
const fs = require('fs');
const path = require('path');

const BASE_URL = 'https://pim.technostationery.com';
const ADMIN_USER = 'admin';
const ADMIN_PASS = 'admin';

const screenshotDir = path.join(__dirname, 'test-results');
if (!fs.existsSync(screenshotDir)) {
    fs.mkdirSync(screenshotDir, { recursive: true });
}

async function main() {
    console.log('🚀 Starting Akeneo PIM UI Test...\n');
    
    const results = {
        timestamp: new Date().toISOString(),
        errors: [],
        warnings: [],
        pages: [],
        menus: []
    };

    const browser = await puppeteer.launch({
        headless: 'new',
        args: ['--no-sandbox', '--disable-setuid-sandbox', '--ignore-certificate-errors']
    });

    try {
        const page = await browser.newPage();
        await page.setViewport({ width: 1920, height: 1080 });

        // Capture console errors
        const consoleErrors = [];
        page.on('console', msg => {
            if (msg.type() === 'error') {
                consoleErrors.push(msg.text());
            }
        });

        // Capture failed requests
        const failedRequests = [];
        page.on('response', async (response) => {
            if (response.status() >= 400) {
                failedRequests.push({
                    url: response.url(),
                    status: response.status()
                });
            }
        });

        // 1. Login
        console.log('1️⃣  Testing Login...');
        await page.goto(`${BASE_URL}/user/login`, { 
            waitUntil: 'networkidle0',
            timeout: 30000 
        });
        
        await page.screenshot({ 
            path: path.join(screenshotDir, '01-login-page.png'),
            fullPage: true 
        });

        await page.type('input[name="username"]', ADMIN_USER);
        await page.type('input[name="password"]', ADMIN_PASS);
        
        await Promise.all([
            page.click('button[type="submit"]'),
            page.waitForNavigation({ waitUntil: 'networkidle0', timeout: 30000 })
        ]);

        await page.waitForTimeout(3000);
        
        await page.screenshot({ 
            path: path.join(screenshotDir, '02-dashboard.png'),
            fullPage: true 
        });

        const dashboardUrl = page.url();
        console.log(`   ✓ Logged in: ${dashboardUrl}`);
        console.log(`   ✓ Title: ${await page.title()}\n`);

        results.pages.push({
            name: 'Dashboard',
            url: dashboardUrl,
            title: await page.title(),
            consoleErrors: consoleErrors.length,
            failedRequests: failedRequests.length
        });

        // 2. Check Dashboard Indicators
        console.log('2️⃣  Checking Dashboard Metrics...');
        const dashboardContent = await page.evaluate(() => document.body.innerText);
        
        const imageMatch = dashboardContent.match(/Produits avec une image.*?(\d+)%/);
        const enrichmentMatch = dashboardContent.match(/taux d.enrichissement.*?(\d+)%/);
        
        console.log(`   📊 Image rate: ${imageMatch ? imageMatch[1] + '%' : 'Not found'}`);
        console.log(`   📊 Enrichment rate: ${enrichmentMatch ? enrichmentMatch[1] + '%' : 'Not found'}\n`);

        results.metrics = {
            imageRate: imageMatch ? imageMatch[1] + '%' : 'Not found',
            enrichmentRate: enrichmentMatch ? enrichmentMatch[1] + '%' : 'Not found'
        };

        // 3. Navigate to Products
        console.log('3️⃣  Testing Products Grid...');
        consoleErrors.length = 0;
        failedRequests.length = 0;

        try {
            await page.goto(`${BASE_URL}/enrich/product/`, { 
                waitUntil: 'networkidle0',
                timeout: 30000 
            });
            await page.waitForTimeout(5000);
            
            await page.screenshot({ 
                path: path.join(screenshotDir, '03-products-grid.png'),
                fullPage: true 
            });

            const productContent = await page.evaluate(() => document.body.innerText);
            const productCount = productContent.match(/[0-9,]+ products?/i);
            
            console.log(`   ✓ Products page loaded`);
            console.log(`   📦 Product count: ${productCount ? productCount[0] : 'Unknown'}\n`);

            results.pages.push({
                name: 'Products',
                url: page.url(),
                productCount: productCount ? productCount[0] : 'Unknown',
                consoleErrors: consoleErrors.slice(0, 20),
                failedRequests: failedRequests.slice(0, 20)
            });
        } catch (e) {
            console.log(`   ❌ Error loading products: ${e.message}\n`);
            results.errors.push({ page: 'Products', error: e.message });
        }

        // 4. Navigate to Categories
        console.log('4️⃣  Testing Categories...');
        consoleErrors.length = 0;
        failedRequests.length = 0;

        try {
            await page.goto(`${BASE_URL}/enrich/category/tree/`, { 
                waitUntil: 'networkidle0',
                timeout: 30000 
            });
            await page.waitForTimeout(3000);
            
            await page.screenshot({ 
                path: path.join(screenshotDir, '04-categories.png'),
                fullPage: true 
            });

            console.log(`   ✓ Categories page loaded`);
            console.log(`   📍 URL: ${page.url()}\n`);

            results.pages.push({
                name: 'Categories',
                url: page.url(),
                consoleErrors: consoleErrors.slice(0, 20),
                failedRequests: failedRequests.slice(0, 20)
            });
        } catch (e) {
            console.log(`   ❌ Error loading categories: ${e.message}\n`);
            results.errors.push({ page: 'Categories', error: e.message });
        }

        // 5. Check Navigation Menu
        console.log('5️⃣  Checking Navigation Menu...');
        const menuItems = await page.evaluate(() => {
            const links = Array.from(document.querySelectorAll('nav a, .menu a, [class*="nav"] a'));
            return links.map(link => ({
                text: link.innerText.trim(),
                href: link.getAttribute('href')
            })).filter(item => item.text && item.text.length > 0);
        });

        console.log(`   📋 Found ${menuItems.length} menu items:`);
        menuItems.slice(0, 15).forEach(item => {
            console.log(`      - ${item.text}`);
        });
        console.log('');

        results.menus = menuItems.slice(0, 30);

        // 6. Check for UI Errors
        console.log('6️⃣  Scanning for UI Errors...');
        const uiErrors = await page.evaluate(() => {
            const errors = [];
            const selectors = ['.alert-danger', '.alert-error', '.flash-error', '.error'];
            selectors.forEach(selector => {
                const elements = document.querySelectorAll(selector);
                elements.forEach(el => {
                    errors.push(el.innerText.trim());
                });
            });
            return errors;
        });

        if (uiErrors.length > 0) {
            console.log(`   ❌ Found ${uiErrors.length} UI errors:`);
            uiErrors.forEach(err => console.log(`      - ${err}`));
        } else {
            console.log('   ✓ No visible UI errors\n');
        }

        results.uiErrors = uiErrors;

        // Save results
        fs.writeFileSync(
            path.join(screenshotDir, 'test-results.json'),
            JSON.stringify(results, null, 2)
        );

        console.log('\n✅ Test Complete!');
        console.log(`📁 Results saved to: ${screenshotDir}`);
        console.log(`📄 Summary: ${results.pages.length} pages tested, ${results.errors.length} errors, ${uiErrors.length} UI errors`);

    } catch (error) {
        console.error('❌ Test failed:', error.message);
        results.fatalError = error.message;
        
        fs.writeFileSync(
            path.join(screenshotDir, 'test-results.json'),
            JSON.stringify(results, null, 2)
        );
    } finally {
        await browser.close();
    }
}

main().catch(console.error);
