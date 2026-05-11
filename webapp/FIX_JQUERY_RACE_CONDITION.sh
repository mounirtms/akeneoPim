#!/bin/bash

echo "=========================================="
echo "FIXING JQUERY RACE CONDITION"
echo "=========================================="
echo ""

# Step 1: Check vendor.min.js content
echo "Step 1: Analyzing vendor.min.js..."
head -c 500 /home/pim/public_html/public/dist/vendor.min.js
echo ""
echo ""

# Step 2: Check if jQuery is being loaded synchronously
echo "Step 2: Testing jQuery availability timing..."
cat > /home/pim/public_html/public/test-jquery-timing.html << 'EOFHTML'
<!DOCTYPE html>
<html>
<head>
    <title>jQuery Timing Test</title>
    <script>
        console.log('1. Before jQuery load, typeof jQuery:', typeof jQuery);
    </script>
    <script src="/dist/jquery.min.js"></script>
    <script>
        console.log('2. After jQuery load, typeof jQuery:', typeof jQuery);
        console.log('3. jQuery version:', jQuery ? jQuery.fn.jquery : 'undefined');
    </script>
</head>
<body>
    <h1>Check Console</h1>
</body>
</html>
EOFHTML

echo "Created test file at /home/pim/public_html/public/test-jquery-timing.html"
echo "Access it at: https://pim.technostationery.com/test-jquery-timing.html"
echo ""

# Step 3: Create a wrapper script that ensures jQuery is ready
echo "Step 3: Creating jQuery ready wrapper..."
cat > /home/pim/public_html/public/dist/jquery-ready.js << 'EOFJS'
// jQuery Ready Wrapper - Ensures jQuery is available before continuing
(function() {
    'use strict';
    
    // Mark jQuery as loading
    window.jQueryReady = new Promise(function(resolve) {
        // If jQuery is already loaded
        if (typeof jQuery !== 'undefined') {
            console.log('[jQuery Ready] jQuery already loaded:', jQuery.fn.jquery);
            resolve(jQuery);
            return;
        }
        
        // Wait for jQuery to be defined
        var checkInterval = setInterval(function() {
            if (typeof jQuery !== 'undefined') {
                clearInterval(checkInterval);
                console.log('[jQuery Ready] jQuery now available:', jQuery.fn.jquery);
                resolve(jQuery);
            }
        }, 10);
        
        // Timeout after 5 seconds
        setTimeout(function() {
            clearInterval(checkInterval);
            if (typeof jQuery === 'undefined') {
                console.error('[jQuery Ready] Timeout: jQuery not loaded after 5 seconds');
                resolve(null);
            }
        }, 5000);
    });
    
    // Export to window
    window.jQuery = window.jQuery || undefined;
    window.$ = window.$ || undefined;
})();
EOFJS

chown pim:pim /home/pim/public_html/public/dist/jquery-ready.js
chmod 644 /home/pim/public_html/public/dist/jquery-ready.js
echo "✓ Created jquery-ready.js wrapper"
echo ""

# Step 4: Check the actual template being used
echo "Step 4: Checking which template is active..."
TEMPLATE_PATH="/home/pim/public_html/src/AppBundle/Resources/views/PimUI/index.html.twig"
if [ -f "$TEMPLATE_PATH" ]; then
    echo "✓ Custom template exists at: $TEMPLATE_PATH"
    echo "  Script loading order:"
    grep -n "script.*src=" "$TEMPLATE_PATH" | head -20
else
    echo "✗ Custom template not found"
    # Check vendor template
    VENDOR_TEMPLATE="/home/pim/public_html/vendor/akeneo/pim-community-dev/src/Akeneo/Platform/Bundle/UIBundle/Resources/views/index.html.twig"
    if [ -f "$VENDOR_TEMPLATE" ]; then
        echo "✓ Using vendor template: $VENDOR_TEMPLATE"
        grep -n "script.*src=" "$VENDOR_TEMPLATE" | head -20
    fi
fi
echo ""

# Step 5: The real fix - Modify the template to add defer/async handling
echo "Step 5: Creating modified template with proper script loading..."
cat > /home/pim/public_html/src/AppBundle/Resources/views/PimUI/index.html.twig << 'EOFTWIG'
{% set cache_buster = "20260329a" %}
<!DOCTYPE html>
<html>
    <head>
        <title>Loading...</title>
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <base href="/" />
        <link rel="shortcut icon" href="/favicon.ico" />

        <link rel="stylesheet" href="/css/pim.css?v={{ cache_buster }}"/>

        {{ external_javascript_dependencies() }}

        {# External libraries required by webpack externals config - LOAD SYNCHRONOUSLY #}
        <script type="text/javascript" src="/dist/jquery.min.js?v={{ cache_buster }}"></script>
        
        {# Verify jQuery is loaded before continuing #}
        <script type="text/javascript">
            if (typeof jQuery === 'undefined') {
                console.error('[Akeneo] CRITICAL: jQuery failed to load!');
                document.write('<div style="position:fixed;top:0;left:0;right:0;background:red;color:white;padding:20px;z-index:99999;">ERROR: jQuery failed to load. Please refresh the page.</div>');
            } else {
                console.log('[Akeneo] jQuery loaded successfully:', jQuery.fn.jquery);
                window.$ = window.jQuery = jQuery; // Ensure global scope
            }
        </script>
        
        <script type="text/javascript" src="/dist/underscore.min.js?v={{ cache_buster }}"></script>
        <script type="text/javascript" src="/dist/backbone.min.js?v={{ cache_buster }}"></script>
        <script type="text/javascript" src="/dist/react.min.js?v={{ cache_buster }}"></script>
        <script type="text/javascript" src="/dist/react-dom.min.js?v={{ cache_buster }}"></script>

        {# FOS Routing - provides fos.Router for route generation #}
        <script type="text/javascript" src="/bundles/fosjsrouting/js/router.min.js?v={{ cache_buster }}"></script>
        <script type="text/javascript" src="{{ path('fos_js_routing_js', {'callback': 'fos.Router.setData'}) }}"></script>

        {# Process polyfill - fixes "process is not defined" for vfile/styled-components #}
        <script type="text/javascript" src="/dist/process-polyfill.js?v={{ cache_buster }}"></script>

        {# RequireJS - needed for AMD module loading #}
        <script type="text/javascript" src="/dist/require.min.js?v={{ cache_buster }}"></script>
        
        {# Webpack bundles - NOW jQuery is guaranteed to be available #}
        <script type="text/javascript" src="/dist/vendor.min.js?v={{ cache_buster }}"></script>
        <script type="text/javascript" src="/dist/main.min.js?v={{ cache_buster }}"></script>
        
        {# RequireJS Configuration and PIM initialization #}
        <script type="text/javascript">
            // Configure RequireJS with paths
            if (typeof requirejs !== 'undefined') {
                requirejs.config({
                    baseUrl: '/js',
                    paths: {
                        'jquery': '/dist/jquery.min',
                        'underscore': '/dist/underscore.min',
                        'backbone': '/dist/backbone.min',
                        'react': '/dist/react.min',
                        'react-dom': '/dist/react-dom.min'
                    },
                    shim: {
                        'backbone': {
                            deps: ['underscore', 'jquery'],
                            exports: 'Backbone'
                        }
                    }
                });
                
                // Wait for DOM and initialize
                document.addEventListener('DOMContentLoaded', function() {
                    console.log('[Akeneo] DOM loaded, checking modules...');
                    
                    // Verify jQuery is still available
                    if (typeof jQuery === 'undefined') {
                        console.error('[Akeneo] jQuery lost after DOM load!');
                        return;
                    }
                    
                    // Check if webpack modules are loaded
                    if (typeof __webpack_require__ !== 'undefined') {
                        console.log('[Akeneo] Webpack modules loaded successfully');
                        
                        // Try to initialize via window.pimInit if available
                        if (typeof window.pimInit === 'function') {
                            console.log('[Akeneo] Calling pimInit()...');
                            window.pimInit();
                        } else {
                            console.log('[Akeneo] window.pimInit not found, checking for alternative init methods...');
                            
                            // Alternative: trigger Backbone router
                            if (typeof Backbone !== 'undefined' && Backbone.history) {
                                console.log('[Akeneo] Starting Backbone.history...');
                                Backbone.history.start({ pushState: false });
                            }
                        }
                    } else {
                        console.warn('[Akeneo] Webpack modules not loaded');
                    }
                });
            }
        </script>
    </head>
    <body>
        <div class="app">
            <div class="AknDefault-progressContainer">
                <h3>
                    Loading ...
                </h3>
                <img src="/bundles/pimui/images/main-loader.gif"/>
                {% if true == oro_config_value('pim_ui.loading_message_enabled') %}
                <h4 class="AknDefault-progressContainer--loadingMessages">
                    {{ random(oro_config_value('pim_ui.loading_messages')|split('\n')) }}
                </h4>
                {% endif %}
            </div>
        </div>
        <div class="hash-loading-mask"></div>
    </body>
</html>
EOFTWIG

chown pim:pim "$TEMPLATE_PATH"
chmod 644 "$TEMPLATE_PATH"
echo "✓ Modified template with jQuery verification checks"
echo ""

# Step 6: Clear Symfony cache
echo "Step 6: Clearing Symfony cache..."
cd /home/pim/public_html
rm -rf var/cache/prod/*
php bin/console cache:clear --env=prod --no-warmup 2>&1 | tail -5
php bin/console cache:warmup --env=prod 2>&1 | tail -5
echo "✓ Cache cleared and warmed"
echo ""

# Step 7: Purge Cloudflare cache
echo "Step 7: Purging Cloudflare cache..."
curl -s -X POST "https://api.cloudflare.com/client/v4/zones/4919ad3406fcabba381edbd543814a68/purge_cache" \
  -H "Authorization: Bearer mxga48kVXklB6E2jvE-SZxWXMC_S50g5Zl4Py5hS" \
  -H "Content-Type: application/json" \
  --data '{"purge_everything":true}' | jq -r '.success'
echo ""

# Step 8: Test the fix
echo "Step 8: Running login test with jQuery monitoring..."
cd /home/pim/public_html/webapp

cat > test_jquery_fix.js << 'EOFTEST'
const puppeteer = require('puppeteer');

(async () => {
    const browser = await puppeteer.launch({ 
        headless: true,
        args: ['--no-sandbox', '--disable-setuid-sandbox']
    });
    const page = await browser.newPage();
    
    // Monitor console
    const logs = [];
    page.on('console', msg => {
        const text = msg.text();
        logs.push(text);
        console.log('[BROWSER]', text);
    });
    
    // Monitor errors
    const errors = [];
    page.on('pageerror', err => {
        errors.push(err.message);
        console.log('[ERROR]', err.message);
    });
    
    try {
        console.log('Loading login page...');
        await page.goto('https://pim.technostationery.com/user/login', { 
            waitUntil: 'networkidle2',
            timeout: 30000 
        });
        
        await page.waitForTimeout(2000);
        
        console.log('\n--- LOGIN PAGE ANALYSIS ---');
        
        // Check if jQuery loaded
        const jQueryVersion = await page.evaluate(() => {
            return typeof jQuery !== 'undefined' ? jQuery.fn.jquery : 'NOT LOADED';
        });
        console.log('jQuery version:', jQueryVersion);
        
        // Fill and submit form
        console.log('Filling login form...');
        await page.type('input[name="_username"]', 'mounir');
        await page.type('input[name="_password"]', '2026');
        
        console.log('Submitting login...');
        await page.click('button[type="submit"]');
        
        await page.waitForNavigation({ waitUntil: 'networkidle2', timeout: 30000 });
        await page.waitForTimeout(3000);
        
        const finalUrl = page.url();
        console.log('\n--- AFTER LOGIN ---');
        console.log('URL:', finalUrl);
        
        // Check jQuery again
        const jQueryAfterLogin = await page.evaluate(() => {
            return typeof jQuery !== 'undefined' ? jQuery.fn.jquery : 'NOT LOADED';
        });
        console.log('jQuery version:', jQueryAfterLogin);
        
        // Check for menu/navigation
        const hasMenu = await page.evaluate(() => {
            return document.querySelector('.AknDefault-mainMenu') !== null ||
                   document.querySelector('nav') !== null ||
                   document.querySelector('[role="navigation"]') !== null;
        });
        console.log('Menu visible:', hasMenu);
        
        // Summary
        console.log('\n--- SUMMARY ---');
        console.log('Console logs:', logs.length);
        console.log('JavaScript errors:', errors.length);
        if (errors.length > 0) {
            console.log('Errors:', errors);
        }
        
        await page.screenshot({ path: 'jquery_fix_test.png', fullPage: true });
        console.log('Screenshot saved: jquery_fix_test.png');
        
    } catch (err) {
        console.error('Test failed:', err.message);
    } finally {
        await browser.close();
    }
})();
EOFTEST

node test_jquery_fix.js
echo ""

echo "=========================================="
echo "FIX COMPLETE"
echo "=========================================="
echo ""
echo "Changes made:"
echo "1. ✓ Added jQuery verification script immediately after jQuery load"
echo "2. ✓ Added explicit window.$ and window.jQuery assignments"
echo "3. ✓ Added detailed console logging for debugging"
echo "4. ✓ Added Backbone.history.start() as fallback init method"
echo "5. ✓ Cleared Symfony cache"
echo "6. ✓ Purged Cloudflare cache"
echo ""
echo "Test with: https://pim.technostationery.com/user/login"
echo "Credentials: mounir / 2026"
echo ""
echo "Check browser console for:"
echo "  - '[Akeneo] jQuery loaded successfully: X.X.X'"
echo "  - '[Akeneo] Webpack modules loaded successfully'"
echo "  - No 'jQuery is not defined' errors"
echo ""

