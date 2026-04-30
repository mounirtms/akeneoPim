#!/usr/bin/env node
/**
 * Minimal resource PIM UI Check
 * Login and test all menu items, capture errors and issues
 */
const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');

const BASE_URL = 'https://pim.technostationery.com';
const ADMIN_USER = 'testadmin';
const ADMIN_PASS = 'testpass';
const resultsDir = '/home/pim/public_html/webapp/test-results-live';

if (!fs.existsSync(resultsDir)) {
    fs.mkdirSync(resultsDir, { recursive: true });
}

(async () => {
    console.log('🔍 Starting PIM UI Check...\n');
    
    const results = {
        timestamp: new Date().toISOString(),
        login: null,
        pages: [],
        errors: [],
        warnings: [],
        styles: { broken: [], missing: [] }
    };

    const browser = await chromium.launch({ 
        headless: true,
        args: ['--no-sandbox']
    });

    const page = await browser.newPage();

    // Capture all console messages
    const consoleLogs = [];
    page.on('console', msg => {
        consoleLogs.push({
            type: msg.type(),
            text: msg.text()
        });
        if (msg.type() === 'error') {
            results.errors.push(msg.text());
        }
    });

    // Capture failed requests
    page.on('response', async (response) => {
        if (response.status() >= 400) {
            results.warnings.push({
                url: response.url(),
                status: response.status()
            });
        }
    });

    try {
        // LOGIN
        console.log('1. Testing login...');
        await page.goto(`${BASE_URL}/user/login`, { 
            waitUntil: 'networkidle',
            timeout: 20000 
        });

        await page.fill('input[name="_username"]', ADMIN_USER);
        await page.fill('input[name="_password"]', ADMIN_PASS);
        await page.click('button[type="submit"]');
        await page.waitForLoadState('networkidle', { timeout: 20000 });
        await page.waitForTimeout(4000);

        results.login = {
            success: !page.url().includes('/user/login'),
            url: page.url()
        };

        await page.screenshot({ 
            path: path.join(resultsDir, '01-dashboard.png'),
            fullPage: true 
        });

        console.log(`   Login: ${results.login.success ? '✅' : '❌'}`);
        console.log(`   URL: ${results.login.url}`);

        // MENU ITEMS TO TEST
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

        // TEST EACH MENU ITEM
        for (let i = 0; i < menuItems.length; i++) {
            const item = menuItems[i];
            console.log(`\n${i + 2}. Testing ${item.name}...`);
            
            const errorsBefore = results.errors.length;
            const warningsBefore = results.warnings.length;

            await page.goto(`${BASE_URL}${item.url}`, { 
                waitUntil: 'networkidle',
                timeout: 15000 
            });
            await page.waitForTimeout(3000);

            await page.screenshot({ 
                path: path.join(resultsDir, `0${i + 2}-${item.name.toLowerCase().replace(/[^a-z]/g, '')}.png`),
                fullPage: false 
            });

            // Check for content
            const content = await page.evaluate(() => document.body.innerText);
            const hasLoading = content.includes('Loading...');
            const hasError = content.includes('Error') || content.includes('error');
            const pageErrors = results.errors.length - errorsBefore;
            const pageWarnings = results.warnings.length - warningsBefore;

            console.log(`   ${hasLoading ? '⏳ Still loading' : '✅ Loaded'}`);
            console.log(`   ${hasError ? '❌ Error found' : '✅ No errors'}`);
            console.log(`   Errors: ${pageErrors}, Warnings: ${pageWarnings}`);

            results.pages.push({
                name: item.name,
                url: item.url,
                loaded: !hasLoading,
                hasError: hasError,
                errors: pageErrors,
                warnings: pageWarnings
            });
        }

        // CHECK FOR BROKEN STYLES
        console.log('\n📋 Checking for broken styles...');
        const styleCheck = await page.evaluate(() => {
            const stylesheets = Array.from(document.querySelectorAll('link[rel="stylesheet"]'));
            const broken = [];
            const missing = [];

            stylesheets.forEach(link => {
                if (link.sheet) {
                    try {
                        link.sheet.cssRules;
                    } catch (e) {
                        broken.push(link.href);
                    }
                } else {
                    missing.push(link.href);
                }
            });

            return { broken, missing };
        });

        results.styles = styleCheck;
        console.log(`   Broken: ${styleCheck.broken.length}`);
        console.log(`   Missing: ${styleCheck.missing.length}`);

        // SUMMARY
        const loaded = results.pages.filter(p => p.loaded).length;
        const withErrors = results.pages.filter(p => p.hasError).length;
        const totalErrors = results.errors.length;
        const totalWarnings = results.warnings.length;

        console.log('\n' + '='.repeat(50));
        console.log('✅ PIM UI CHECK COMPLETE');
        console.log('='.repeat(50));
        console.log(`Pages loaded: ${loaded}/${results.pages.length}`);
        console.log(`Pages with errors: ${withErrors}`);
        console.log(`Total errors: ${totalErrors}`);
        console.log(`Total warnings: ${totalWarnings}`);
        console.log(`Broken styles: ${styleCheck.broken.length}`);
        console.log(`Missing styles: ${styleCheck.missing.length}`);

        // Save results
        fs.writeFileSync(
            path.join(resultsDir, 'results.json'),
            JSON.stringify(results, null, 2)
        );

    } catch (error) {
        console.error('❌ Error:', error.message);
    } finally {
        await browser.close();
    }
})();
