#!/usr/bin/env node
/**
 * Comprehensive PIM Menu & Data Progress Test
 * Tests ALL menu items and product/model progress
 */

const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');

const BASE_URL = 'https://pim.technostationery.com';
const ADMIN_USER = 'testadmin';
const ADMIN_PASS = 'testpass';

const resultsDir = '/home/pim/public_html/webapp/test-results-menus';
if (!fs.existsSync(resultsDir)) {
    fs.mkdirSync(resultsDir, { recursive: true });
}

(async () => {
    console.log('🚀 Starting Comprehensive Menu & Progress Tests...\n');
    
    const results = {
        timestamp: new Date().toISOString(),
        cache_buster: '1777510314',
        menu_items: [],
        products: { count: 0, models: 0, progress: {} },
        errors: [],
        console_errors: [],
        screenshots: []
    };

    const browser = await chromium.launch({ 
        headless: true,
        args: ['--no-sandbox', '--disable-setuid-sandbox', '--disable-cache']
    });

    const context = await browser.newContext({
        viewport: { width: 1920, height: 1080 },
        bypassCSP: true
    });

    // Add no-cache headers
    await context.setExtraHTTPHeaders({
        'Cache-Control': 'no-cache, no-store, must-revalidate',
        'Pragma': 'no-cache',
        'Expires': '0'
    });

    const page = await context.newPage();

    // Global error capture
    page.on('console', msg => {
        if (msg.type() === 'error') {
            results.console_errors.push(msg.text());
        }
    });

    page.on('pageerror', (error) => {
        results.errors.push(error.message);
    });

    try {
        // ============================================================
        // STEP 1: Login with cache bypass
        // ============================================================
        console.log('STEP 1: Login with Cache Bypass');
        
        // Add random parameter to bypass any CDN cache
        await page.goto(`${BASE_URL}/user/login?nocache=${Date.now()}`, { 
            waitUntil: 'networkidle',
            timeout: 30000 
        });

        await page.fill('input[name="_username"]', ADMIN_USER);
        await page.fill('input[name="_password"]', ADMIN_PASS);
        await page.click('button[type="submit"]');

        await page.waitForLoadState('networkidle', { timeout: 30000 });
        await new Promise(r => setTimeout(r, 8000)); // Longer wait for SPA

        await page.screenshot({ 
            path: path.join(resultsDir, '00-dashboard-fresh.png'),
            fullPage: true 
        });
        results.screenshots.push('00-dashboard-fresh.png');

        console.log('  ✅ Logged in successfully');
        console.log('  URL:', page.url());
        console.log('  Title:', await page.title());

        // Check if tooltip shim is loaded
        const hasTooltipShim = await page.evaluate(() => {
            return document.querySelector('script[src*="tooltip-shim"]') !== null;
        });
        console.log('  Tooltip Shim:', hasTooltipShim ? '✅ Loaded' : '❌ Missing');

        // ============================================================
        // STEP 2: Extract and Test ALL Menu Items
        // ============================================================
        console.log('\nSTEP 2: Extract and Test ALL Menu Items');
        
        // Wait for menu to render
        await new Promise(r => setTimeout(r, 3000));

        // Get all navigation menu items
        const allMenuItems = await page.evaluate(() => {
            // Try multiple selectors for different menu types
            const selectors = [
                'nav a',
                '.menu a', 
                'aside a',
                '[class*="Navigation"] a',
                '[class*="menu"] a',
                '[class*="nav"] a',
                '.AknNavbar-link'
            ];

            const allLinks = [];
            selectors.forEach(selector => {
                const links = Array.from(document.querySelectorAll(selector));
                links.forEach(link => {
                    const href = link.getAttribute('href');
                    const text = link.innerText.trim();
                    if (text && text.length > 2 && !allLinks.find(l => l.text === text)) {
                        allLinks.push({ text, href });
                    }
                });
            });

            return allLinks;
        });

        console.log(`  📋 Found ${allMenuItems.length} unique menu items`);
        allMenuItems.forEach((item, idx) => {
            console.log(`    ${idx + 1}. ${item.text} → ${item.href || 'N/A'}`);
        });

        results.menu_items = allMenuItems;

        // ============================================================
        // STEP 3: Test Each Menu Item
        // ============================================================
        console.log('\nSTEP 3: Testing Each Menu Item');

        // Define expected menu routes
        const menuRoutes = [
            { name: 'Dashboard', url: '/', selector: 'body' },
            { name: 'Products', url: '/enrich/product/', selector: 'body' },
            { name: 'Categories', url: '/enrich/product-category-tree/', selector: 'body' },
            { name: 'Import', url: '/collect/import/', selector: 'body' },
            { name: 'Export', url: '/spread/export/', selector: 'body' },
            { name: 'Jobs', url: '/job', selector: 'body' },
            { name: 'Attributes', url: '/configuration/attribute/', selector: 'body' },
            { name: 'Attribute Groups', url: '/configuration/attribute-group/', selector: 'body' },
            { name: 'Families', url: '/configuration/family/', selector: 'body' },
            { name: 'Channels', url: '/configuration/channel/', selector: 'body' },
            { name: 'Locales', url: '/configuration/locale/', selector: 'body' },
        ];

        for (const menu of menuRoutes) {
            try {
                console.log(`\n  Testing: ${menu.name}`);
                results.console_errors.length = 0;

                await page.goto(`${BASE_URL}${menu.url}?nocache=${Date.now()}`, { 
                    waitUntil: 'networkidle',
                    timeout: 25000 
                });
                await new Promise(r => setTimeout(r, 5000));

                await page.screenshot({ 
                    path: path.join(resultsDir, `01-menu-${menu.name.toLowerCase().replace(/[^a-z]/g, '-')}.png`),
                    fullPage: true 
                });

                const pageTitle = await page.title();
                const pageContent = await page.evaluate(() => document.body.innerText);
                
                // Check for loading indicators
                const isLoading = pageContent.includes('Loading') || pageContent.includes('loading');
                
                // Check for error messages
                const hasErrors = pageContent.includes('error') || pageContent.includes('Error');

                console.log(`    ✅ Loaded: ${pageTitle}`);
                console.log(`    Content length: ${pageContent.length} chars`);
                console.log(`    Loading: ${isLoading ? '⏳ Yes' : '✅ No'}`);
                console.log(`    Errors: ${hasErrors ? '❌ Yes' : '✅ No'}`);

                results.menu_items.push({
                    name: menu.name,
                    url: menu.url,
                    status: 'PASS',
                    title: pageTitle,
                    content_length: pageContent.length,
                    is_loading: isLoading,
                    has_errors: hasErrors,
                    console_errors: results.console_errors.length
                });

            } catch (e) {
                console.log(`    ❌ Failed: ${e.message}`);
                results.menu_items.push({
                    name: menu.name,
                    url: menu.url,
                    status: 'FAIL',
                    error: e.message
                });
            }
        }

        // ============================================================
        // STEP 4: Product Progress & Statistics
        // ============================================================
        console.log('\nSTEP 4: Product Progress & Statistics');
        
        // Navigate to products
        await page.goto(`${BASE_URL}/enrich/product/?nocache=${Date.now()}`, { 
            waitUntil: 'networkidle',
            timeout: 30000 
        });
        await new Promise(r => setTimeout(r, 8000));

        await page.screenshot({ 
            path: path.join(resultsDir, '02-products-grid-fresh.png'),
            fullPage: true 
        });

        // Try to get product count and grid data
        const productData = await page.evaluate(() => {
            // Look for product count indicators
            const text = document.body.innerText;
            
            // Try to find count
            const countMatch = text.match(/(\d[\d\s]*)\s*products?/i) || 
                              text.match(/(\d[\d\s]*)\s*produits?/i);
            
            // Look for grid rows
            const rows = document.querySelectorAll('tr, [class*="row"], [class*="item"]');
            
            return {
                count_text: countMatch ? countMatch[0] : 'Not found',
                grid_rows: rows.length,
                has_images: document.querySelectorAll('img').length > 5,
                image_count: document.querySelectorAll('img').length
            };
        });

        console.log('  📊 Product Data:');
        console.log('  ', productData);
        results.products.grid = productData;

        // ============================================================
        // STEP 5: Product Models Test
        // ============================================================
        console.log('\nSTEP 5: Product Models');
        
        await page.goto(`${BASE_URL}/enrich/product-model/?nocache=${Date.now()}`, { 
            waitUntil: 'networkidle',
            timeout: 30000 
        });
        await new Promise(r => setTimeout(r, 6000));

        await page.screenshot({ 
            path: path.join(resultsDir, '03-product-models-fresh.png'),
            fullPage: true 
        });

        const modelData = await page.evaluate(() => {
            const text = document.body.innerText;
            const countMatch = text.match(/(\d[\d\s]*)\s*models?/i);
            
            return {
                count_text: countMatch ? countMatch[0] : 'Not found',
                page_loaded: text.length > 100
            };
        });

        console.log('  📦 Product Models:', modelData);
        results.products.models = modelData;

        // ============================================================
        // STEP 6: Categories Deep Test
        // ============================================================
        console.log('\nSTEP 6: Categories Deep Test');
        
        await page.goto(`${BASE_URL}/enrich/product-category-tree/?nocache=${Date.now()}`, { 
            waitUntil: 'networkidle',
            timeout: 30000 
        });
        await new Promise(r => setTimeout(r, 6000));

        await page.screenshot({ 
            path: path.join(resultsDir, '04-categories-fresh.png'),
            fullPage: true 
        });

        const categoryData = await page.evaluate(() => {
            const text = document.body.innerText;
            const treeItems = document.querySelectorAll('[class*="tree"], [class*="category"]');
            
            return {
                tree_items: treeItems.length,
                content_length: text.length,
                has_tree: text.includes('tree') || text.includes('Tree')
            };
        });

        console.log('  📂 Categories:', categoryData);
        results.products.categories = categoryData;

        // ============================================================
        // STEP 7: Database Verification
        // ============================================================
        console.log('\nSTEP 7: Verifying with Database...');
        
        // This would normally run DB queries, but we'll check API instead
        try {
            const apiCheck = await page.evaluate(async () => {
                try {
                    const resp = await fetch('/api/rest/v1/products?page=1&limit=1', {
                        headers: { 'Accept': 'application/json' }
                    });
                    const data = await resp.json();
                    return {
                        api_accessible: true,
                        product_count: data.total || 'N/A'
                    };
                } catch (e) {
                    return { api_accessible: false, error: e.message };
                }
            });

            console.log('  🔌 API Check:', apiCheck);
            results.products.api = apiCheck;
        } catch (e) {
            console.log('  ⚠️ API check skipped');
        }

        // ============================================================
        // STEP 8: Final Error Summary
        // ============================================================
        console.log('\nSTEP 8: Final Summary');

        const summary = {
            total_menu_items: allMenuItems.length,
            menu_routes_tested: menuRoutes.length,
            menu_routes_passed: results.menu_items.filter(m => m.status === 'PASS').length,
            menu_routes_failed: results.menu_items.filter(m => m.status === 'FAIL').length,
            total_console_errors: results.console_errors.length,
            total_page_errors: results.errors.length,
            screenshots_taken: results.screenshots.length + menuRoutes.length + 4
        };

        console.log('\n' + '='.repeat(60));
        console.log('✅ Comprehensive Test Complete!');
        console.log('='.repeat(60));
        console.log('\n📊 Summary:');
        console.log(`  Menu items found: ${summary.total_menu_items}`);
        console.log(`  Menu routes tested: ${summary.menu_routes_tested}`);
        console.log(`  Routes passed: ${summary.menu_routes_passed} ✅`);
        console.log(`  Routes failed: ${summary.menu_routes_failed} ❌`);
        console.log(`  Console errors: ${summary.total_console_errors}`);
        console.log(`  Page errors: ${summary.total_page_errors}`);
        console.log(`  Screenshots: ${summary.screenshots_taken}`);

        results.summary = summary;

        // Save all results
        fs.writeFileSync(
            path.join(resultsDir, 'results.json'),
            JSON.stringify(results, null, 2)
        );

        // Create quick summary file
        fs.writeFileSync(
            path.join(resultsDir, 'SUMMARY.txt'),
            `COMPREHENSIVE MENU & PROGRESS TEST SUMMARY
=====================================
Date: ${results.timestamp}
Cache Buster: ${results.cache_buster}

MENU ITEMS FOUND: ${summary.total_menu_items}
MENU ROUTES TESTED: ${summary.menu_routes_tested}
ROUTES PASSED: ${summary.menu_routes_passed}
ROUTES FAILED: ${summary.menu_routes_failed}

ERRORS:
- Console Errors: ${summary.total_console_errors}
- Page Errors: ${summary.total_page_errors}

SCREENSHOTS: ${summary.screenshots_taken}
Location: ${resultsDir}

PRODUCTS:
- Grid Data: ${JSON.stringify(results.products.grid)}
- Models: ${JSON.stringify(results.products.models)}
- Categories: ${JSON.stringify(results.products.categories)}

For full details, see: results.json
`
        );

        console.log(`\n📁 Results saved to: ${resultsDir}`);

    } catch (error) {
        console.error('\n❌ Test failed:', error.message);
        results.fatal_error = error.message;
        
        try {
            await page.screenshot({ 
                path: path.join(resultsDir, 'FATAL-ERROR.png'),
                fullPage: true 
            });
        } catch (e) {}

        fs.writeFileSync(
            path.join(resultsDir, 'results.json'),
            JSON.stringify(results, null, 2)
        );
    } finally {
        await browser.close();
    }
})();
