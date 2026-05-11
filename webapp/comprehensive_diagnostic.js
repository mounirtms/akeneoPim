/**
 * Comprehensive Diagnostic with Console Log Capture
 * Captures all console messages, network errors, and page state
 */

const playwright = require('playwright');
const fs = require('fs');

async function comprehensiveDiagnostic() {
    console.log('='.repeat(80));
    console.log('COMPREHENSIVE DIAGNOSTIC - Console Log Capture');
    console.log('='.repeat(80));
    
    const browser = await playwright.chromium.launch({ 
        headless: true,
        args: ['--no-sandbox', '--disable-setuid-sandbox']
    });
    
    const context = await browser.newContext({ ignoreHTTPSErrors: true });
    const page = await context.newPage();
    
    const diagnosticData = {
        timestamp: new Date().toISOString(),
        consoleLogs: [],
        consoleErrors: [],
        networkErrors: [],
        jsErrors: [],
        cssErrors: [],
        mimeTypeErrors: [],
        corsErrors: []
    };
    
    // Capture all console messages
    page.on('console', msg => {
        const type = msg.type();
        const text = msg.text();
        const log = { type, text, timestamp: new Date().toISOString() };
        
        diagnosticData.consoleLogs.push(log);
        
        if (type === 'error') {
            diagnosticData.consoleErrors.push(log);
            console.log(`[CONSOLE ERROR] ${text}`);
        }
    });
    
    // Capture JavaScript errors
    page.on('pageerror', error => {
        const errorMsg = error.toString();
        diagnosticData.jsErrors.push({
            error: errorMsg,
            stack: error.stack,
            timestamp: new Date().toISOString()
        });
        console.log(`[JS ERROR] ${errorMsg}`);
    });
    
    // Capture network failures
    page.on('response', response => {
        const url = response.url();
        const status = response.status();
        const headers = response.headers();
        
        // Check for 404 errors
        if (status === 404) {
            diagnosticData.networkErrors.push({
                url,
                status,
                type: '404 Not Found',
                timestamp: new Date().toISOString()
            });
            console.log(`[404 ERROR] ${url}`);
        }
        
        // Check for 403 errors
        if (status === 403) {
            diagnosticData.networkErrors.push({
                url,
                status,
                type: '403 Forbidden',
                timestamp: new Date().toISOString()
            });
            console.log(`[403 ERROR] ${url}`);
        }
        
        // Check for CSS MIME type errors
        if (url.includes('.css') && headers['content-type'] && 
            !headers['content-type'].includes('text/css')) {
            diagnosticData.mimeTypeErrors.push({
                url,
                expectedType: 'text/css',
                actualType: headers['content-type'],
                timestamp: new Date().toISOString()
            });
            console.log(`[MIME ERROR] CSS file ${url} has wrong MIME type: ${headers['content-type']}`);
        }
        
        // Check for JS MIME type errors
        if (url.includes('.js') && headers['content-type'] && 
            !headers['content-type'].includes('javascript') &&
            !headers['content-type'].includes('json')) {
            diagnosticData.mimeTypeErrors.push({
                url,
                expectedType: 'application/javascript',
                actualType: headers['content-type'],
                timestamp: new Date().toISOString()
            });
            console.log(`[MIME ERROR] JS file ${url} has wrong MIME type: ${headers['content-type']}`);
        }
    });
    
    page.on('requestfailed', request => {
        const url = request.url();
        const failure = request.failure();
        diagnosticData.networkErrors.push({
            url,
            failure: failure ? failure.errorText : 'unknown',
            timestamp: new Date().toISOString()
        });
        console.log(`[REQUEST FAILED] ${url} - ${failure ? failure.errorText : 'unknown'}`);
    });
    
    try {
        console.log('\nLoading login page...');
        await page.goto('https://pim.technostationery.com/user/login', {
            waitUntil: 'networkidle',
            timeout: 30000
        });
        
        console.log('Page loaded, waiting for additional resources...');
        await page.waitForTimeout(5000);
        
        // Check critical files
        console.log('\nChecking critical files:');
        
        const criticalFiles = [
            '/css/pim.css',
            '/js/requirejs-config.js',
            '/js/extensions.json',
            '/bundles/pimui/js/index.js'
        ];
        
        for (const file of criticalFiles) {
            const response = await page.goto(`https://pim.technostationery.com${file}`, {
                waitUntil: 'networkidle',
                timeout: 10000
            }).catch(e => null);
            
            if (response) {
                const status = response.status();
                const contentType = response.headers()['content-type'];
                console.log(`  ${file}: ${status} (${contentType})`);
                
                if (status === 404) {
                    console.log(`    ✗ FILE NOT FOUND`);
                } else if (status === 200 && contentType && contentType.includes('text/html')) {
                    console.log(`    ✗ WRONG MIME TYPE - Returns HTML instead of expected type`);
                } else if (status === 200) {
                    console.log(`    ✓ OK`);
                }
            } else {
                console.log(`  ${file}: ✗ FAILED TO LOAD`);
            }
        }
        
        await page.screenshot({ 
            path: '/home/pim/public_html/webapp/diagnostic_screenshot.png',
            fullPage: true 
        });
        
    } catch (error) {
        console.error(`\nERROR: ${error.message}`);
        diagnosticData.fatalError = error.message;
    }
    
    await browser.close();
    
    // Analyze errors
    console.log('\n' + '='.repeat(80));
    console.log('DIAGNOSTIC SUMMARY');
    console.log('='.repeat(80));
    
    console.log(`\nConsole Errors: ${diagnosticData.consoleErrors.length}`);
    console.log(`JavaScript Errors: ${diagnosticData.jsErrors.length}`);
    console.log(`Network Errors (404/403): ${diagnosticData.networkErrors.length}`);
    console.log(`MIME Type Errors: ${diagnosticData.mimeTypeErrors.length}`);
    
    // Group errors by type
    console.log('\n--- CRITICAL ISSUES ---');
    
    // CSS MIME type issues
    const cssMimeErrors = diagnosticData.mimeTypeErrors.filter(e => e.url.includes('.css'));
    if (cssMimeErrors.length > 0) {
        console.log('\n🔴 CSS MIME TYPE ERRORS:');
        cssMimeErrors.forEach(e => {
            console.log(`  - ${e.url}`);
            console.log(`    Expected: text/css`);
            console.log(`    Got: ${e.actualType}`);
        });
    }
    
    // 404 errors
    const notFoundErrors = diagnosticData.networkErrors.filter(e => e.status === 404);
    if (notFoundErrors.length > 0) {
        console.log('\n🔴 404 NOT FOUND ERRORS:');
        notFoundErrors.forEach(e => {
            console.log(`  - ${e.url}`);
        });
    }
    
    // JS errors containing specific keywords
    const criticalJsErrors = diagnosticData.jsErrors.filter(e => 
        e.error.includes('extensions.filter') ||
        e.error.includes('mod_rewrite') ||
        e.error.includes('pimui/js/index')
    );
    
    if (criticalJsErrors.length > 0) {
        console.log('\n🔴 CRITICAL JAVASCRIPT ERRORS:');
        criticalJsErrors.forEach(e => {
            console.log(`  - ${e.error}`);
        });
    }
    
    // Save detailed report
    const reportPath = '/home/pim/public_html/webapp/diagnostic_full_report.json';
    fs.writeFileSync(reportPath, JSON.stringify(diagnosticData, null, 2));
    console.log(`\nFull diagnostic report saved: ${reportPath}`);
    
    console.log('\n' + '='.repeat(80));
    
    return diagnosticData;
}

// Run diagnostic
comprehensiveDiagnostic()
    .then(() => {
        console.log('\nDiagnostic complete!');
        process.exit(0);
    })
    .catch(error => {
        console.error('Diagnostic failed:', error);
        process.exit(1);
    });
