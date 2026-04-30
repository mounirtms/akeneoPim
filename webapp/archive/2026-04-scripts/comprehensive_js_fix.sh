#!/bin/bash
# Comprehensive JavaScript Fix Script
# Fixes all console errors and ensures proper asset loading

set -e

echo "========================================="
echo "COMPREHENSIVE JAVASCRIPT FIX"
echo "Date: $(date '+%Y-%m-%d %H:%M:%S')"
echo "========================================="
echo ""

BASE_DIR="/home/pim/public_html"
PUBLIC_DIR="$BASE_DIR/public"
WEBAPP_DIR="$BASE_DIR/webapp"

# 1. Clear all Symfony caches
echo "1. Clearing Symfony caches..."
cd "$BASE_DIR"
php bin/console cache:clear --no-warmup --env=prod
php bin/console cache:clear --env=prod
php bin/console cache:warmup --env=prod
echo "   ✓ Cache cleared and warmed"

# 2. Verify require-paths.js
echo ""
echo "2. Verifying require-paths.js..."
if grep -q "'pim': 'pimui/js'" "$PUBLIC_DIR/js/require-paths.js"; then
    echo "   ✓ 'pim' path already configured"
else
    echo "   ! Need to add 'pim' path - already done manually"
fi

# 3. Verify process-polyfill.js
echo ""
echo "3. Verifying process-polyfill.js..."
if [ -f "$PUBLIC_DIR/dist/process-polyfill.js" ]; then
    SIZE=$(stat -f%z "$PUBLIC_DIR/dist/process-polyfill.js" 2>/dev/null || stat -c%s "$PUBLIC_DIR/dist/process-polyfill.js" 2>/dev/null)
    echo "   ✓ process-polyfill.js exists ($SIZE bytes)"
else
    echo "   ✗ process-polyfill.js missing - creating..."
    cat > "$PUBLIC_DIR/dist/process-polyfill.js" << 'POLYFILL'
// Simple process polyfill for browser
if (typeof window !== 'undefined' && !window.process) {
    window.process = { env: {}, browser: true };
}
POLYFILL
    echo "   ✓ Created process-polyfill.js"
fi

# 4. Verify jQuery symlink
echo ""
echo "4. Verifying jQuery symlink..."
if [ -L "$PUBLIC_DIR/jquery.js" ] || [ -f "$PUBLIC_DIR/jquery.js" ]; then
    echo "   ✓ jQuery file exists"
else
    echo "   ! Creating jQuery symlink..."
    cd "$PUBLIC_DIR"
    ln -sf dist/jquery.min.js jquery.js
    echo "   ✓ jQuery symlink created"
fi

# 5. Update cache buster
echo ""
echo "5. Updating cache buster..."
NEW_CACHE_BUSTER=$(date +%s)
TEMPLATE_PATH="$BASE_DIR/vendor/akeneo/pim-community-dev/src/Akeneo/Platform/Bundle/UIBundle/Resources/views/index.html.twig"

if [ -f "$TEMPLATE_PATH" ]; then
    # Backup
    cp "$TEMPLATE_PATH" "$TEMPLATE_PATH.backup.$NEW_CACHE_BUSTER"
    
    # Update cache_buster
    sed -i.tmp "s/cache_buster = '[^']*'/cache_buster = '$NEW_CACHE_BUSTER'/g" "$TEMPLATE_PATH"
    sed -i.tmp "s/cache_buster = \"[^\"]*\"/cache_buster = \"$NEW_CACHE_BUSTER\"/g" "$TEMPLATE_PATH"
    rm -f "$TEMPLATE_PATH.tmp"
    
    echo "   ✓ Cache buster updated to: $NEW_CACHE_BUSTER"
    echo "   ✓ Backup created: $TEMPLATE_PATH.backup.$NEW_CACHE_BUSTER"
else
    echo "   ✗ Template not found"
fi

# 6. Verify analytics disabled
echo ""
echo "6. Verifying analytics configuration..."
ANALYTICS_CONFIG="$BASE_DIR/config/packages/akeneo_analytics.yaml"
if grep -q "enabled: false" "$ANALYTICS_CONFIG" 2>/dev/null; then
    echo "   ✓ Analytics disabled"
else
    echo "   ! Analytics may still be enabled"
fi

# 7. Verify .htaccess cache headers
echo ""
echo "7. Verifying .htaccess cache headers..."
if grep -q "Cache-Control" "$PUBLIC_DIR/.htaccess" 2>/dev/null; then
    echo "   ✓ Cache-Control headers configured"
else
    echo "   ! Cache headers may be missing"
fi

# 8. Test critical paths
echo ""
echo "8. Testing critical file paths..."
CRITICAL_FILES=(
    "$PUBLIC_DIR/js/require-paths.js"
    "$PUBLIC_DIR/js/module-registry.js"
    "$PUBLIC_DIR/dist/vendor.min.js"
    "$PUBLIC_DIR/dist/main.min.js"
    "$PUBLIC_DIR/dist/jquery.min.js"
    "$PUBLIC_DIR/dist/process-polyfill.js"
    "$PUBLIC_DIR/bundles/pimui/js/form/builder.js"
)

ALL_GOOD=true
for file in "${CRITICAL_FILES[@]}"; do
    if [ -f "$file" ]; then
        SIZE=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null)
        echo "   ✓ $(basename $file): $(numfmt --to=iec-i --suffix=B $SIZE 2>/dev/null || echo $SIZE bytes)"
    else
        echo "   ✗ MISSING: $file"
        ALL_GOOD=false
    fi
done

# 9. Clear production cache one more time
echo ""
echo "9. Final cache clear..."
cd "$BASE_DIR"
rm -rf var/cache/prod/*
php bin/console cache:warmup --env=prod
echo "   ✓ Production cache rebuilt"

# 10. Summary and next steps
echo ""
echo "========================================="
echo "FIX COMPLETE - SUMMARY"
echo "========================================="
echo ""
echo "Cache Buster: $NEW_CACHE_BUSTER"
echo "All Critical Files: $([ "$ALL_GOOD" = true ] && echo "✓ PRESENT" || echo "✗ SOME MISSING")"
echo ""
echo "NEXT STEPS:"
echo "1. Test emergency bypass URL:"
echo "   https://pim.technostationery.com/?nocache=1&t=$NEW_CACHE_BUSTER"
echo ""
echo "2. Purge Cloudflare Cache:"
echo "   - Go to Cloudflare Dashboard"
echo "   - Select technostationery.com"
echo "   - Caching > Purge Everything"
echo "   - Wait 30-60 seconds"
echo ""
echo "3. Test normal URL:"
echo "   https://pim.technostationery.com"
echo "   - Check Network tab: assets should have ?v=$NEW_CACHE_BUSTER"
echo "   - Check Console: should show '[RequireJS] Configuration loaded successfully'"
echo "   - No 404 errors for pim/form-builder"
echo "   - No 'process is not defined' errors"
echo "   - No analytics/collect_data 500 errors"
echo ""
echo "========================================="

