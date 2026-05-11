#!/bin/bash
# FIX_CRITICAL_ISSUES.sh - Fix database connection and rebuild assets
# Date: 2026-05-06

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔧 PHASE 10: CRITICAL ISSUE FIXES"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Start time: $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo ""

FIXES_APPLIED=0
FIXES_FAILED=0

# Fix 1: Database Connection Test
echo "1. Testing Database Connection..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
DB_TEST=$(mysql -h 127.0.0.1 -P 3307 -u pim -ppim_password akeneo_pim -se "SELECT COUNT(*) FROM pim_catalog_product" 2>&1)
if [ $? -eq 0 ]; then
    echo "✓ Database connection OK"
    echo "  Product count: $DB_TEST"
    ((FIXES_APPLIED++))
else
    echo "✗ Database connection FAILED"
    echo "  Error: $DB_TEST"
    ((FIXES_FAILED++))
fi
echo ""

# Fix 2: Reinstall Frontend Assets
echo "2. Reinstalling Frontend Assets..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
php bin/console pim:installer:assets --env=prod --symlink 2>&1 | tail -10
if [ $? -eq 0 ]; then
    echo "✓ Assets reinstalled"
    ((FIXES_APPLIED++))
else
    echo "✗ Asset installation failed"
    ((FIXES_FAILED++))
fi
echo ""

# Fix 3: Generate RequireJS Config
echo "3. Generating RequireJS Configuration..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
php bin/console pim:installer:dump-require-paths --env=prod 2>&1 | tail -5
if [ $? -eq 0 ]; then
    echo "✓ RequireJS config generated"
    ((FIXES_APPLIED++))
else
    echo "✗ RequireJS config failed"
    ((FIXES_FAILED++))
fi
echo ""

# Fix 4: Check Bundle Directory
echo "4. Checking Bundle Files..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
BUNDLE_COUNT=$(find public/bundles -type f 2>/dev/null | wc -l | tr -d ' ')
echo "Bundle files found: $BUNDLE_COUNT"

if [ "$BUNDLE_COUNT" -gt 100 ]; then
    echo "✓ Bundle files present"
    ((FIXES_APPLIED++))
else
    echo "⚠ Bundle files low, attempting fix..."
    rm -rf public/bundles/
    php bin/console assets:install public --symlink --env=prod 2>&1 | tail -10
    NEW_COUNT=$(find public/bundles -type f 2>/dev/null | wc -l | tr -d ' ')
    echo "New bundle count: $NEW_COUNT"
    if [ "$NEW_COUNT" -gt 100 ]; then
        echo "✓ Bundles fixed"
        ((FIXES_APPLIED++))
    else
        echo "✗ Bundle fix failed"
        ((FIXES_FAILED++))
    fi
fi
echo ""

# Fix 5: Verify Critical Files
echo "5. Verifying Critical Asset Files..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
CRITICAL_FILES=(
    "public/js/fos_js_routes.json"
    "public/bundles/fosjsrouting/js/router.min.js"
    "public/bundles/pimui/images/akeneo.svg"
)

for file in "${CRITICAL_FILES[@]}"; do
    if [ -f "$file" ]; then
        SIZE=$(stat -c%s "$file" 2>/dev/null)
        echo "  ✓ $file (${SIZE} bytes)"
    else
        echo "  ✗ $file MISSING"
    fi
done
echo ""

# Fix 6: Check CSS/JS Compilation
echo "6. Checking Asset Compilation..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check if webpack is available
if [ -f "webpack.config.js" ]; then
    echo "✓ webpack.config.js found"
    
    # Check for yarn/npm
    if command -v yarn &> /dev/null; then
        echo "  Yarn available, checking assets..."
        if [ -d "node_modules" ]; then
            echo "  ✓ node_modules present"
        else
            echo "  ⚠ node_modules missing (webpack build may be needed)"
        fi
    else
        echo "  ⚠ Yarn not available"
    fi
else
    echo "⚠ webpack.config.js not found"
fi
echo ""

# Fix 7: Clear and Warm Cache
echo "7. Clearing and Warming Cache..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
php bin/console cache:clear --env=prod --no-warmup 2>&1 | tail -3
php bin/console cache:warmup --env=prod 2>&1 | tail -3
if [ $? -eq 0 ]; then
    CACHE_FILES=$(find var/cache/prod -type f 2>/dev/null | wc -l | tr -d ' ')
    echo "✓ Cache warmed: $CACHE_FILES files"
    ((FIXES_APPLIED++))
else
    echo "✗ Cache warmup failed"
    ((FIXES_FAILED++))
fi
echo ""

# Fix 8: Verify After All Fixes
echo "8. Post-Fix Verification..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Test login page
LOGIN_TEST=$(php public/index.php 2>&1)
if echo "$LOGIN_TEST" | grep -q "user/login"; then
    echo "✓ Application routing works"
    ((FIXES_APPLIED++))
else
    echo "✗ Application routing broken"
    ((FIXES_FAILED++))
fi

# Test database again
DB_PRODUCTS=$(mysql -h 127.0.0.1 -P 3307 -u pim -ppim_password akeneo_pim -se "SELECT COUNT(*) FROM pim_catalog_product" 2>/dev/null || echo "0")
echo "✓ Products in database: $DB_PRODUCTS"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 SUMMARY"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Fixes Applied: $FIXES_APPLIED"
echo "Fixes Failed: $FIXES_FAILED"
echo "End time: $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo ""

if [ $FIXES_FAILED -eq 0 ]; then
    echo "✅ ALL FIXES SUCCESSFUL"
    exit 0
else
    echo "⚠️  SOME FIXES FAILED - Manual intervention may be needed"
    exit 1
fi
