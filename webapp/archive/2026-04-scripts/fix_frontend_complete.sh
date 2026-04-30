#!/bin/bash
# Comprehensive Frontend Fix Script
# Date: 2026-04-27

echo "=============================================="
echo "COMPREHENSIVE FRONTEND FIX - 2026-04-27"
echo "=============================================="

# Set proper environment
export NODE_ENV=production
export APP_ENV=prod

echo ""
echo "Step 1: Checking current state..."
ls -lh public/js/require-paths.js 2>/dev/null || echo "require-paths.js missing!"
head -3 public/js/require-paths.js 2>/dev/null || echo "Cannot read require-paths.js"

echo ""
echo "Step 2: Backing up problematic files..."
mkdir -p webapp/backups/frontend_$(date +%Y%m%d)
cp public/js/require-paths.js webapp/backups/frontend_$(date +%Y%m%d)/ 2>/dev/null || echo "No backup needed"

echo ""
echo "Step 3: Removing Node.js-style require-paths.js..."
# This file should be browser-compatible JavaScript, not Node.js module
if [ -f "public/js/require-paths.js" ]; then
    if grep -q "module.exports" public/js/require-paths.js; then
        echo "⚠️  Found Node.js syntax in require-paths.js - regenerating..."
        rm -f public/js/require-paths.js
    fi
fi

echo ""
echo "Step 4: Regenerating RequireJS configuration properly..."
php bin/console pim:installer:dump-require-paths --env=prod 2>&1

echo ""
echo "Step 5: Checking require-paths.js after regeneration..."
if [ -f "public/js/require-paths.js" ]; then
    echo "File exists, size: $(stat -f%z public/js/require-paths.js 2>/dev/null || stat -c%s public/js/require-paths.js 2>/dev/null) bytes"
    echo "First 5 lines:"
    head -5 public/js/require-paths.js
    
    # Check if still has module.exports
    if grep -q "module.exports" public/js/require-paths.js; then
        echo "❌ Still contains Node.js syntax! Manual fix needed."
        
        # Create proper RequireJS config
        echo "Creating proper RequireJS configuration..."
        cat > public/js/require-paths.js << 'REQUIREJS_CONFIG'
/**
 * RequireJS configuration for Akeneo PIM
 * Generated: 2026-04-27
 */
require.config({
    baseUrl: '/bundles',
    paths: {
        'jquery': 'pimui/lib/jquery-1.11.0.min',
        'underscore': 'pimui/lib/underscore-min',
        'backbone': 'pimui/lib/backbone-min',
        'oro/translator': 'orotranslation/js/translator',
        'routing': 'fosjsrouting/js/router',
        'pim/form-builder': 'pimenrichment/js/form/builder',
        'pim/form': 'pimenrichment/js/form',
        'pim/router': 'pimui/js/router'
    },
    shim: {
        'underscore': {
            exports: '_'
        },
        'backbone': {
            deps: ['underscore', 'jquery'],
            exports: 'Backbone'
        }
    },
    config: {
        'pim/form-builder': {
            'root': '/bundles/pimenrichment'
        }
    },
    waitSeconds: 30
});
REQUIREJS_CONFIG
        echo "✅ Created browser-compatible RequireJS config"
    else
        echo "✅ require-paths.js looks good"
    fi
else
    echo "❌ require-paths.js not generated!"
fi

echo ""
echo "Step 6: Checking for jQuery in bundles..."
find public/bundles -name "*jquery*.js" -type f | head -10

echo ""
echo "Step 7: Creating symlinks for missing files..."
# jQuery
if [ ! -f "public/jquery.js" ]; then
    JQUERY_SOURCE=$(find public/bundles -name "jquery*.min.js" -o -name "jquery-1.*.js" | grep -v "ui" | head -1)
    if [ -n "$JQUERY_SOURCE" ]; then
        ln -sf "$JQUERY_SOURCE" public/jquery.js
        echo "✅ Created jquery.js symlink to $JQUERY_SOURCE"
    else
        echo "⚠️  jQuery not found in bundles"
    fi
fi

echo ""
echo "Step 8: Checking webpack bundles..."
ls -lh public/dist/*.js 2>/dev/null | head -5

echo ""
echo "Step 9: Clearing ALL caches..."
# Symfony cache
rm -rf var/cache/prod/*
php bin/console cache:clear --env=prod --no-warmup
php bin/console cache:warmup --env=prod

# Browser cache busting - update version
CURRENT_VERSION=$(date +%Y%m%d%H%M)
echo "Cache version: $CURRENT_VERSION"

# Asset version config
if [ -f "config/packages/framework.yaml" ]; then
    if grep -q "assets:" config/packages/framework.yaml; then
        echo "Assets config found"
    fi
fi

echo ""
echo "Step 10: Reinstalling Akeneo assets..."
php bin/console pim:installer:assets --env=prod --symlink

echo ""
echo "Step 11: Checking analytics configuration..."
if [ -f "config/packages/akeneo_analytics.yaml" ]; then
    echo "Analytics config exists:"
    cat config/packages/akeneo_analytics.yaml
else
    echo "Creating analytics config to disable collection..."
    mkdir -p config/packages
    cat > config/packages/akeneo_analytics.yaml << 'ANALYTICS_CONFIG'
akeneo_analytics:
    is_enabled: false
ANALYTICS_CONFIG
    echo "✅ Analytics disabled"
fi

echo ""
echo "Step 12: Checking production webpack build..."
if [ -f "public/dist/vendor.min.js" ]; then
    SIZE=$(stat -f%z public/dist/vendor.min.js 2>/dev/null || stat -c%s public/dist/vendor.min.js 2>/dev/null)
    echo "vendor.min.js exists, size: $SIZE bytes"
    
    # Check for process polyfill
    if grep -q "process is not defined" public/dist/vendor.min.js 2>/dev/null; then
        echo "⚠️  vendor.min.js needs process polyfill"
    fi
else
    echo "⚠️  vendor.min.js not found - webpack build may be incomplete"
fi

echo ""
echo "Step 13: Final verification..."
echo "=== Public JS files ==="
ls -lh public/js/*.js 2>/dev/null

echo ""
echo "=== Translation files ==="
ls -lh public/js/translation/*.js 2>/dev/null | head -5

echo ""
echo "=== Bundle directories ==="
ls -d public/bundles/*/ 2>/dev/null | head -10

echo ""
echo "=============================================="
echo "Frontend fix completed!"
echo "=============================================="
echo ""
echo "Next steps:"
echo "1. Clear browser cache (Ctrl+Shift+Delete)"
echo "2. Test: https://pim.technostationery.com"
echo "3. Check browser console for remaining errors"
echo ""

