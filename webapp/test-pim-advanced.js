#!/usr/bin/env node
/**
 * Advanced PIM UI Test Suite
 * Tests product interactions, category navigation, data quality, and configurations
 */

const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');

const BASE_URL = 'https://pim.technostationery.com';
const ADMIN_USER = 'testadmin';
const ADMIN_PASS = 'testpass';

const resultsDir = '/home/pim/public_html/webapp/test-results-advanced';
if (!fs.existsSync(resultsDir)) {
    fs.mkdirSync(resultsDir, { recursive: true });
}

(async () => {
    console.log('🚀 Starting Advanced PIM UI Tests...\n');
    
    const results = {
        timestamp: new Date().toISOString(),
        tests: [],
        errors: [],
        console_errors: [],
        failed_requests: [],
        products_tested: [],
        categories_tested: [],
        data_quality: {},
        configurations: {}
    };

    const browser = await chromium.launch({ 
        headless: true,
        args: ['--no-sandbox', '--disable-setuid-sandbox']
    });

    const context = await browser.newContext({
        viewport: { width: 1920, height: 1080 }
    });

    const page = await context.newPage();

    // Global error capture
    page.on('console', msg => {
        if (msg.type() === 'error') {
            results.console_errors.push({
                text: msg.text(),
                location: msg.location()
            });
        }
    });

    page.on('response', async (response) => {
        if (response.status() >= 400) {
            results.failed_requests.push({
                url: response.url(),
                status: response.status(),
                statusText: response.statusText()
            });
        }
    });

    page.on('pageerror', (error) => {
        results.errors.push({
            message: error.message,
            stack: error.stack
        });
    });

    try {
        // ============================================================
        // TEST 1: Login and Dashboard Analysis
        // ============================================================
        console.log('TEST 1: Login & Dashboard Deep Analysis');
        await page.goto(`${BASE_URL}/user/login`, { 
            waitUntil: 'networkidle',
            timeout: 30000 
        });

        await page.fill('input[name="_username"]', ADMIN_USER);
        await page.fill('input[name="_password"]', ADMIN_PASS);
        await page.click('button[type="submit"]');

        await page.waitForLoadState('networkidle', { timeout: 30000 });
        await new Promise(r => setTimeout(r, 5000)); // Wait for SPA to load

        await page.screenshot({ 
            path: path.join(resultsDir, '01-dashboard-loaded.png'),
            fullPage: true 
        });

        // Extract all text content to find metrics
        const dashboardContent = await page.evaluate(() => document.body.innerText);
        
        // Look for various metrics
        const metrics = {
            product_count: dashboardContent.match(/(\d[\d\s]*)produits/gi),
            image_percentage: dashboardContent.match(/image.*?(\d+)%/gi),
            enrichment_data: dashboardContent.match(/enrichissement.*?(\d+)%/gi),
            completeness: dashboardContent.match(/compl[eè]tude.*?(\d+)%/gi),
            quality_scores: dashboardContent.match(/qualit[eé].*?(\d+)/gi)
        };

        console.log('  📊 Dashboard Metrics Found:');
        console.log('  ', metrics);

        results.dashboard_metrics = metrics;

        // Check for configuration warnings
        const configWarnings = await page.evaluate(() => {
            const warnings = [];
            const text = document.body.innerText;
            if (text.includes('configuration')) warnings.push('configuration issue');
            if (text.includes('installation')) warnings.push('installation issue');
            if (text.includes('setup')) warnings.push('setup issue');
            return warnings;
        });

        results.config_warnings = configWarnings;

        // ============================================================
        // TEST 2: Products Grid - Detailed Testing
        // ============================================================
        console.log('\nTEST 2: Products Grid Deep Testing');
        results.console_errors.length = 0;

        await page.goto(`${BASE_URL}/enrich/product/`, { 
            waitUntil: 'networkidle',
            timeout: 30000 
        });
        await new Promise(r => setTimeout(r, 6000));

        await page.screenshot({ 
            path: path.join(resultsDir, '02-products-grid.png'),
            fullPage: true 
        });

        // Get product grid data
        const productGridData = await page.evaluate(() => {
            const rows = document.querySelectorAll('table tr, .datagrid-row, [class*="row"]');
            const products = [];
            
            rows.forEach((row, idx) => {
                if (idx < 20) { // Get first 20 rows
                    const cells = row.querySelectorAll('td, [class*="cell"]');
                    const rowData = [];
                    cells.forEach(cell => {
                        rowData.push(cell.innerText.trim());
                    });
                    if (rowData.length > 0) {
                        products.push(rowData);
                    }
                }
            });

            return products;
        });

        console.log(`  📦 Found ${productGridData.length} product rows`);

        // Check for images in grid
        const imageCount = await page.evaluate(() => {
            return document.querySelectorAll('img').length;
        });

        console.log(`  🖼️  Images on page: ${imageCount}`);

        // Check for loading spinners (indicates incomplete loading)
        const loadingSpinners = await page.evaluate(() => {
            return document.querySelectorAll('.loader, .spinner, [class*="loading"]').length;
        });

        console.log(`  ⏳ Loading spinners: ${loadingSpinners}`);

        results.products_grid = {
            rows: productGridData.length,
            images: imageCount,
            loading_spinners: loadingSpinners,
            console_errors: results.console_errors.length
        };

        // ============================================================
        // TEST 3: Click on Individual Products
        // ============================================================
        console.log('\nTEST 3: Product Detail Testing');
        
        // Try to click on first few products
        const productLinks = await page.evaluate(() => {
            const links = Array.from(document.querySelectorAll('a[href*="product/view"], a[href*="enrich/product"]'));
            return links.slice(0, 5).map(link => ({
                href: link.getAttribute('href'),
                text: link.innerText.trim()
            }));
        });

        console.log(`  🔗 Found ${productLinks.length} product links`);

        for (let i = 0; i < Math.min(3, productLinks.length); i++) {
            try {
                console.log(`  Testing product ${i + 1}...`);
                await page.goto(`${BASE_URL}${productLinks[i].href}`, { 
                    waitUntil: 'networkidle',
                    timeout: 20000 
                });
                await new Promise(r => setTimeout(r, 3000));

                await page.screenshot({ 
                    path: path.join(resultsDir, `03-product-${i + 1}.png`),
                    fullPage: true 
                });

                // Get product details
                const productDetails = await page.evaluate(() => {
                    const text = document.body.innerText;
                    return {
                        has_name: text.includes('name') || text.includes('Name'),
                        has_description: text.includes('description') || text.includes('Description'),
                        has_image: document.querySelectorAll('img').length > 5,
                        has_price: text.includes('price') || text.includes('Price'),
                        has_categories: text.includes('category') || text.includes('Category')
                    };
                });

                console.log(`    ✅ Product ${i + 1} loaded:`, productDetails);

                results.products_tested.push({
                    index: i + 1,
                    url: page.url(),
                    details: productDetails,
                    console_errors: results.console_errors.length
                });
            } catch (e) {
                console.log(`    ❌ Product ${i + 1} failed:`, e.message);
            }
        }

        // ============================================================
        // TEST 4: Category Tree Navigation
        // ============================================================
        console.log('\nTEST 4: Category Tree Navigation');
        results.console_errors.length = 0;

        await page.goto(`${BASE_URL}/enrich/product-category-tree/`, { 
            waitUntil: 'networkidle',
            timeout: 30000 
        });
        await new Promise(r => setTimeout(r, 4000));

        await page.screenshot({ 
            path: path.join(resultsDir, '04-category-tree.png'),
            fullPage: true 
        });

        // Get category tree structure
        const categoryTree = await page.evaluate(() => {
            const items = document.querySelectorAll('.tree-item, .category-node, [class*="category"]');
            const categories = [];
            
            items.forEach((item, idx) => {
                if (idx < 30) {
                    categories.push({
                        text: item.innerText.trim(),
                        has_children: item.querySelectorAll('.children').length > 0
                    });
                }
            });

            return categories;
        });

        console.log(`  📂 Found ${categoryTree.length} category items`);

        // Try clicking on a category
        if (categoryTree.length > 0) {
            try {
                const firstCategory = await page.locator('.tree-item, .category-node').first();
                if (await firstCategory.isVisible()) {
                    await firstCategory.click();
                    await new Promise(r => setTimeout(r, 2000));

                    await page.screenshot({ 
                        path: path.join(resultsDir, '04-category-selected.png'),
                        fullPage: true 
                    });

                    console.log('  ✅ Category click successful');
                }
            } catch (e) {
                console.log('  ⚠️ Category click failed:', e.message);
            }
        }

        results.categories_tested = {
            items_found: categoryTree.length,
            categories: categoryTree.slice(0, 10),
            console_errors: results.console_errors.length
        };

        // ============================================================
        // TEST 5: Data Quality Insights
        // ============================================================
        console.log('\nTEST 5: Data Quality Insights');
        results.console_errors.length = 0;

        // Try accessing data quality page
        try {
            await page.goto(`${BASE_URL}/data-quality-insights/`, { 
                waitUntil: 'networkidle',
                timeout: 20000 
            });
            await new Promise(r => setTimeout(r, 4000));

            await page.screenshot({ 
                path: path.join(resultsDir, '05-data-quality.png'),
                fullPage: true 
            });

            const dqContent = await page.evaluate(() => {
                const text = document.body.innerText;
                return {
                    has_scores: text.includes('score') || text.includes('Score'),
                    has_recommendations: text.includes('recommend') || text.includes('Recommend'),
                    has_progress: text.includes('progress') || text.includes('Progress')
                };
            });

            console.log('  📊 Data Quality:', dqContent);

            results.data_quality = dqContent;
        } catch (e) {
            console.log('  ⚠️ Data quality page not accessible:', e.message);
        }

        // ============================================================
        // TEST 6: System Configuration Check
        // ============================================================
        console.log('\nTEST 6: System Configuration');
        results.console_errors.length = 0;

        // Try accessing settings/system page
        try {
            await page.goto(`${BASE_URL}/settings/`, { 
                waitUntil: 'networkidle',
                timeout: 20000 
            });
            await new Promise(r => setTimeout(r, 3000));

            await page.screenshot({ 
                path: path.join(resultsDir, '06-settings.png'),
                fullPage: true 
            });

            console.log('  ⚙️ Settings page loaded');
        } catch (e) {
            console.log('  ⚠️ Settings page not accessible');
        }

        // ============================================================
        // TEST 7: Import/Export Functionality
        // ============================================================
        console.log('\nTEST 7: Import/Export Pages');

        const pagesToTest = [
            { name: 'Import', url: '/import/' },
            { name: 'Export', url: '/export/' },
            { name: 'Jobs', url: '/job/' }
        ];

        for (const pg of pagesToTest) {
            try {
                await page.goto(`${BASE_URL}${pg.url}`, { 
                    waitUntil: 'networkidle',
                    timeout: 15000 
                });
                await new Promise(r => setTimeout(r, 2000));

                console.log(`  ✅ ${pg.name} page loaded`);
            } catch (e) {
                console.log(`  ❌ ${pg.name} page failed: ${e.message}`);
            }
        }

        // ============================================================
        // TEST 8: Comprehensive Log Analysis
        // ============================================================
        console.log('\nTEST 8: Comprehensive Log Analysis');

        // Categorize all errors
        const errorCategories = {
            not_found_404: results.failed_requests.filter(r => r.status === 404).length,
            server_errors_500: results.failed_requests.filter(r => r.status >= 500).length,
            auth_errors_401: results.failed_requests.filter(r => r.status === 401).length,
            js_errors: results.console_errors.filter(e => e.text.includes('TypeError') || e.text.includes('ReferenceError')).length,
            network_errors: results.console_errors.filter(e => e.text.includes('Failed to load')).length
        };

        console.log('  📋 Error Summary:');
        console.log('  ', errorCategories);

        results.error_summary = errorCategories;

        // ============================================================
        // FINAL: Save Results
        // ============================================================
        console.log('\n' + '='.repeat(60));
        console.log('✅ All Tests Complete!');
        console.log('='.repeat(60));

        console.log(`\n📁 Results saved to: ${resultsDir}`);
        console.log(`📊 Screenshots: ${resultsDir}/*.png`);
        console.log(`📄 Full results: ${resultsDir}/results.json`);

        console.log('\n📈 Summary:');
        console.log(`  Products tested: ${results.products_tested.length}`);
        console.log(`  Categories tested: ${results.categories_tested.items_found}`);
        console.log(`  Console errors: ${results.console_errors.length}`);
        console.log(`  Failed requests: ${results.failed_requests.length}`);
        console.log(`  JS errors: ${results.errors.length}`);

        // Save detailed results
        fs.writeFileSync(
            path.join(resultsDir, 'results.json'),
            JSON.stringify(results, null, 2)
        );

        // Create summary file
        const summary = {
            timestamp: results.timestamp,
            total_tests: 8,
            products_tested: results.products_tested.length,
            categories_found: results.categories_tested.items_found,
            total_errors: results.errors.length,
            total_console_errors: results.console_errors.length,
            total_failed_requests: results.failed_requests.length,
            error_summary: results.error_summary,
            dashboard_metrics: results.dashboard_metrics,
            critical_issues: results.errors.filter(e => 
                e.message.includes('TypeError') || 
                e.message.includes('ReferenceError')
            ),
            recommendations: []
        };

        // Generate recommendations
        if (errorCategories.not_found_404 > 5) {
            summary.recommendations.push('Investigate 404 errors - missing resources or routes');
        }
        if (errorCategories.js_errors > 0) {
            summary.recommendations.push('Fix JavaScript errors in bundles');
        }
        if (results.products_tested.some(p => !p.details.has_image)) {
            summary.recommendations.push('Some products missing images');
        }
        if (results.products_tested.some(p => !p.details.has_description)) {
            summary.recommendations.push('Many products missing descriptions');
        }

        fs.writeFileSync(
            path.join(resultsDir, 'summary.json'),
            JSON.stringify(summary, null, 2)
        );

        console.log('\n🎯 Recommendations:');
        summary.recommendations.forEach(rec => console.log(`  - ${rec}`));

    } catch (error) {
        console.error('\n❌ Test suite failed:', error.message);
        results.fatal_error = error.message;
        
        // Screenshot on fatal error
        try {
            await page.screenshot({ 
                path: path.join(resultsDir, 'fatal-error.png'),
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
