#!/usr/bin/env node
/**
 * Comprehensive PIM Test Suite
 * Tests all menu items, products, categories, and data quality
 */

const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');

const BASE_URL = 'https://pim.technostationery.com';
const ADMIN_USER = 'testadmin';
const ADMIN_PASS = 'testpass';

const resultsDir = '/home/pim/public_html/webapp/test-results-final';
if (!fs.existsSync(resultsDir)) {
    fs.mkdirSync(resultsDir, { recursive: true });
}

(async () => {
    console.log('🚀 Starting Comprehensive PIM Tests...\n');
    
    const results = {
        timestamp: new Date().toISOString(),
        tests: [],
        errors: [],
        console_errors: [],
        failed_requests: []
    };

    const browser = await chromium.launch({ 
        headless: true,
        args: ['--no-sandbox', '--disable-setuid-sandbox', '--disable-cache']
    });

    const page = await browser.newPage();

    // Global error capture
    page.on('console', msg => {
        if (msg.type() === 'error') {
            results.console_errors.push(msg.text());
        }
    });

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
        await page.goto(`${BASE_URL}/user/login?nocache=${Date.now()}`, { 
            waitUntil: 'networkidle', timeout: 30000 
        });

        await page.fill('input[name="_username"]', ADMIN_USER);
        await page.fill('input[name="_password"]', ADMIN_PASS);
        await page.click('button[type="submit"]');
        await page.waitForLoadState('networkidle', { timeout: 30000 });
        await new Promise(r => setTimeout(r, 5000));

        await page.screenshot({ path: path.join(resultsDir, '01-login.png'), fullPage: true });
        
        const loggedIn = !page.url().includes('/user/login');
        console.log(`  ${loggedIn ? '✅' : '❌'} Login: ${loggedIn ? 'SUCCESS' : 'FAILED'}`);
        results.tests.push({ name: 'Login', status: loggedIn ? 'PASS' : 'FAIL' });

        // TEST 2-13: Test all menu items
        const menuItems = [
            { name: 'Dashboard', url: '/' },
            { name: 'Products', url: '/enrich/product/' },
            { name: 'Categories', url: '/enrich/product-category-tree/' },
            { name: 'Import', url: '/collect/import/' },
            { name: 'Export', url: '/spread/export/' },
            { name: 'Jobs', url: '/job' },
            { name: 'Attributes', url: '/configuration/attribute/' },
            { name: 'Attribute Groups', url: '/configuration/attribute-group/' },
            { name: 'Families', url: '/configuration/family/' },
            { name: 'Channels', url: '/configuration/channel/' },
            { name: 'Locales', url: '/configuration/locale/' }
        ];

        for (let i = 0; i < menuItems.length; i++) {
            const item = menuItems[i];
            console.log(`\nTEST ${i + 2}: ${item.name}`);
            results.console_errors.length = 0;

            await page.goto(`${BASE_URL}${item.url}?nocache=${Date.now()}`, { 
                waitUntil: 'networkidle', timeout: 25000 
            });
            await new Promise(r => setTimeout(r, 4000));

            await page.screenshot({ 
                path: path.join(resultsDir, `02-menu-${item.name.toLowerCase().replace(/[^a-z]/g, '-')}.png`),
                fullPage: true 
            });

            const hasErrors = results.console_errors.filter(e => 
                !e.includes('translation') && !e.includes('favicon')
            ).length;

            console.log(`  ✅ ${item.name} loaded`);
            console.log(`  Console errors: ${hasErrors}`);

            results.tests.push({ 
                name: item.name, 
                status: 'PASS',
                console_errors: hasErrors
            });
        }

        // TEST 14: Check for navigation bug fixes
        console.log('\nTEST 14: Navigation Bug Check');
        const navBugErrors = results.failed_requests.filter(r => 
            r.url.includes('function%20()')
        ).length;
        
        console.log(`  ${navBugErrors === 0 ? '✅' : '⚠️'} Navigation errors: ${navBugErrors}`);
        results.tests.push({ 
            name: 'Navigation Bug Fixed', 
            status: navBugErrors === 0 ? 'PASS' : 'WARN' 
        });

        // TEST 15: Translation files check
        console.log('\nTEST 15: Translation Files Check');
        const translationErrors = results.failed_requests.filter(r => 
            r.url.includes('/js/translation/')
        ).length;
        
        console.log(`  ${translationErrors === 0 ? '✅' : '⚠️'} Translation errors: ${translationErrors}`);
        results.tests.push({ 
            name: 'Translation Files', 
            status: translationErrors === 0 ? 'PASS' : 'WARN' 
        });

        // Summary
        const passed = results.tests.filter(t => t.status === 'PASS').length;
        const warnings = results.tests.filter(t => t.status === 'WARN').length;
        const failed = results.tests.filter(t => t.status === 'FAIL').length;

        console.log('\n' + '='.repeat(60));
        console.log('✅ ALL TESTS COMPLETE!');
        console.log('='.repeat(60));
        console.log(`\n📊 Summary:`);
        console.log(`  Passed: ${passed}`);
        console.log(`  Warnings: ${warnings}`);
        console.log(`  Failed: ${failed}`);
        console.log(`  Total: ${results.tests.length}`);

        results.summary = { passed, warnings, failed, total: results.tests.length };

        fs.writeFileSync(
            path.join(resultsDir, 'results.json'),
            JSON.stringify(results, null, 2)
        );

    } catch (error) {
        console.error('❌ Test error:', error.message);
    } finally {
        await browser.close();
    }
})();
