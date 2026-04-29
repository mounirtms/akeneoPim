#!/bin/bash
# Emergency Frontend Fix for Akeneo PIM
# Fixes missing require.min.js and webpack build issues

echo "=== EMERGENCY FRONTEND FIX ==="
echo "Date: $(date)"
echo ""

# Step 1: Find and copy require.min.js from vendor
echo "Step 1: Locating require.min.js..."
REQUIRE_SRC=$(find vendor -name "require.min.js" 2>/dev/null | head -1)
if [ -n "$REQUIRE_SRC" ]; then
    echo "  Found: $REQUIRE_SRC"
    mkdir -p public/js
    cp "$REQUIRE_SRC" public/js/require.min.js
    chmod 644 public/js/require.min.js
    echo "  ✅ Copied to public/js/require.min.js"
else
    echo "  ⚠️  Not found in vendor, downloading from CDN..."
    curl -s https://cdnjs.cloudflare.com/ajax/libs/require.js/2.3.6/require.min.js -o public/js/require.min.js
    echo "  ✅ Downloaded from CDN"
fi

# Step 2: Find and copy require.js config
echo ""
echo "Step 2: Setting up require.js configuration..."
REQUIRE_CONFIG=$(find vendor -name "require.config.js" 2>/dev/null | head -1)
if [ -n "$REQUIRE_CONFIG" ]; then
    cp "$REQUIRE_CONFIG" public/js/require-config.js
    echo "  ✅ Config copied"
else
    echo "  ⚠️  Creating minimal config..."
    cat > public/js/require-config.js << 'REQCONFIG'
requirejs.config({
    baseUrl: '/bundles',
    paths: {
        'jquery': 'jquery/jquery.min',
        'underscore': 'underscore/underscore-min',
        'backbone': 'backbone/backbone-min',
        'routing': '../js/fos_js_routes',
        'routes': 'fosjsrouting/js/router.min'
    }
});
REQCONFIG
    echo "  ✅ Minimal config created"
fi

# Step 3: Clear webpack cache to fix chunk conflict
echo ""
echo "Step 3: Clearing webpack cache..."
rm -rf node_modules/.cache 2>/dev/null
rm -rf var/cache/webpack 2>/dev/null
echo "  ✅ Cache cleared"

# Step 4: Verify critical files
echo ""
echo "Step 4: Verifying critical files..."
CRITICAL_FILES=(
    "public/js/require.min.js"
    "public/js/fos_js_routes.json"
    "public/bundles/fosjsrouting/js/router.min.js"
)

ALL_GOOD=true
for file in "${CRITICAL_FILES[@]}"; do
    if [ -f "$file" ]; then
        echo "  ✅ $file"
    else
        echo "  ❌ $file (missing)"
        ALL_GOOD=false
    fi
done

# Step 5: Check and fix router.min.js if missing
if [ ! -f "public/bundles/fosjsrouting/js/router.min.js" ]; then
    echo ""
    echo "Step 5: Fixing missing FOS router..."
    ROUTER_SRC=$(find vendor -name "router.min.js" 2>/dev/null | head -1)
    if [ -n "$ROUTER_SRC" ]; then
        mkdir -p public/bundles/fosjsrouting/js
        cp "$ROUTER_SRC" public/bundles/fosjsrouting/js/router.min.js
        echo "  ✅ Router copied"
    fi
fi

# Step 6: Fix permissions
echo ""
echo "Step 6: Fixing permissions..."
chmod -R 755 public/js public/bundles 2>/dev/null
chown -R pim:pim public/js public/bundles 2>/dev/null
echo "  ✅ Permissions fixed"

# Step 7: Summary
echo ""
echo "=== SUMMARY ==="
if [ "$ALL_GOOD" = true ]; then
    echo "✅ All critical files in place"
    echo ""
    echo "NEXT STEPS:"
    echo "1. Clear browser cache (Ctrl+Shift+Delete)"
    echo "2. Hard reload (Ctrl+Shift+R)"
    echo "3. If errors persist, the webpack build needs manual intervention"
else
    echo "⚠️  Some files still missing"
    echo ""
    echo "ALTERNATIVE: Use pre-built assets"
    echo "  The webpack build has conflicts. Consider:"
    echo "  1. Contact Akeneo support for pre-built assets"
    echo "  2. Or run: composer install --no-dev --optimize-autoloader"
fi

echo ""
echo "Fix completed: $(date)"
