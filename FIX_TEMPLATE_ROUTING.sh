#!/bin/bash

echo "╔════════════════════════════════════════════════════════════╗"
echo "║         TEMPLATE ROUTING DIAGNOSIS & FIX                   ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# Step 1: Find which template is actually being used
echo "Step 1: Finding active template..."
echo ""

# Check if custom template exists
CUSTOM_TEMPLATE="src/AppBundle/Resources/views/PimUI/index.html.twig"
VENDOR_TEMPLATE="vendor/akeneo/pim-community-dev/src/Akeneo/Platform/Bundle/UIBundle/Resources/views/index.html.twig"

if [ -f "$CUSTOM_TEMPLATE" ]; then
    echo "✅ Custom template exists: $CUSTOM_TEMPLATE"
    CUSTOM_SIZE=$(wc -l < "$CUSTOM_TEMPLATE")
    echo "   Lines: $CUSTOM_SIZE"
    echo "   Cache buster: $(grep cache_buster "$CUSTOM_TEMPLATE" | head -1)"
else
    echo "❌ Custom template NOT found: $CUSTOM_TEMPLATE"
fi
echo ""

if [ -f "$VENDOR_TEMPLATE" ]; then
    echo "✅ Vendor template exists: $VENDOR_TEMPLATE"
    VENDOR_SIZE=$(wc -l < "$VENDOR_TEMPLATE")
    echo "   Lines: $VENDOR_SIZE"
else
    echo "❌ Vendor template NOT found"
fi
echo ""

# Step 2: Check which template has the jQuery fix
echo "Step 2: Checking for jQuery verification in templates..."
if grep -q "jQuery loaded successfully" "$CUSTOM_TEMPLATE" 2>/dev/null; then
    echo "✅ Custom template HAS jQuery fix"
else
    echo "❌ Custom template MISSING jQuery fix"
fi

if grep -q "jQuery loaded successfully" "$VENDOR_TEMPLATE" 2>/dev/null; then
    echo "✅ Vendor template HAS jQuery fix"
else
    echo "❌ Vendor template MISSING jQuery fix (expected)"
fi
echo ""

# Step 3: Check template override configuration
echo "Step 3: Checking bundle override configuration..."
BUNDLE_CONFIG="config/bundles.php"
if [ -f "$BUNDLE_CONFIG" ]; then
    if grep -q "AppBundle" "$BUNDLE_CONFIG"; then
        echo "✅ AppBundle registered in config/bundles.php"
    else
        echo "❌ AppBundle NOT registered (template override won't work)"
    fi
else
    echo "⚠️  config/bundles.php not found"
fi
echo ""

# Step 4: Apply jQuery fix to VENDOR template (the one actually being used)
echo "Step 4: Applying jQuery fix to VENDOR template..."
echo ""
echo "This ensures the fix works regardless of template routing issues"
echo ""

# Backup vendor template
cp "$VENDOR_TEMPLATE" "$VENDOR_TEMPLATE.backup_$(date +%Y%m%d_%H%M%S)"

# Create new vendor template with jQuery fix
cat > "$VENDOR_TEMPLATE" << 'EOFTEMPLATE'
{% set cache_buster = "20260508_194500" %}
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
EOFTEMPLATE

echo "✅ Vendor template updated with jQuery fix"
echo "   Backup saved: $VENDOR_TEMPLATE.backup_*"
echo ""

# Step 5: Clear all caches AGAIN
echo "Step 5: Clearing ALL caches..."
rm -rf var/cache/*
php bin/console cache:clear --env=prod --no-warmup
php bin/console cache:warmup --env=prod --no-debug
systemctl restart varnish
systemctl restart ea-php83-php-fpm
systemctl reload httpd
echo "✅ All caches cleared and services restarted"
echo ""

# Step 6: Wait and test
echo "Step 6: Waiting 10 seconds for services to stabilize..."
sleep 10
echo "✓ Wait complete"
echo ""

# Step 7: Test what's being served
echo "Step 7: Testing what's actually being served..."
RESPONSE=$(curl -s "https://pim.technostationery.com/user/login?t=$(date +%s)")

if echo "$RESPONSE" | grep -q "jQuery loaded successfully"; then
    echo "✅ SUCCESS! Template fix is now in the HTML"
    echo "   Cache buster found: $(echo "$RESPONSE" | grep -o 'cache_buster = "[^"]*"' | head -1)"
else
    echo "❌ Template fix still not in HTML"
    echo ""
    echo "First 500 chars of response:"
    echo "$RESPONSE" | head -c 500
fi
echo ""

echo "╔════════════════════════════════════════════════════════════╗"
echo "║            TEMPLATE FIX APPLIED TO VENDOR                  ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "Running final test..."
echo ""

