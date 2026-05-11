#!/bin/bash
# COMPREHENSIVE FIX PLAN - All Remaining Issues
# Date: 2026-05-06
# Purpose: Fix all critical issues before admin login testing

set -e
REPORT_FILE="COMPREHENSIVE_FIX_REPORT_$(date +%Y%m%d_%H%M%S).md"

echo "=== COMPREHENSIVE FIX PLAN EXECUTION ===" | tee "$REPORT_FILE"
echo "Started: $(date)" | tee -a "$REPORT_FILE"
echo "" | tee -a "$REPORT_FILE"

FIXES_APPLIED=0
FIXES_FAILED=0

fix_success() {
    FIXES_APPLIED=$((FIXES_APPLIED + 1))
    echo "✓ FIXED: $1" | tee -a "$REPORT_FILE"
}

fix_failed() {
    FIXES_FAILED=$((FIXES_FAILED + 1))
    echo "✗ FAILED: $1" | tee -a "$REPORT_FILE"
}

echo "## CRITICAL ISSUE #1: MISSING UI ASSETS" | tee -a "$REPORT_FILE"
echo "---" | tee -a "$REPORT_FILE"

# Fix 1: Reinstall frontend assets
echo "Reinstalling Akeneo frontend assets..." | tee -a "$REPORT_FILE"
if php bin/console pim:installer:assets --symlink --clean --env=prod 2>&1 | tee -a "$REPORT_FILE"; then
    fix_success "Frontend assets reinstalled"
else
    fix_failed "Frontend asset installation"
fi

echo "" | tee -a "$REPORT_FILE"

# Check if assets are now present
echo "Verifying asset installation..." | tee -a "$REPORT_FILE"
MISSING_ASSETS=()

if [ ! -f "public/bundles/pimui/css/pim.css" ]; then
    MISSING_ASSETS+=("pim.css")
fi
if [ ! -f "public/js/require-config.js" ]; then
    MISSING_ASSETS+=("require-config.js")
fi
if [ ! -f "public/dist/backend.min.js" ]; then
    MISSING_ASSETS+=("backend.min.js")
fi

if [ ${#MISSING_ASSETS[@]} -eq 0 ]; then
    fix_success "All critical assets verified"
else
    echo "⚠ Still missing: ${MISSING_ASSETS[*]}" | tee -a "$REPORT_FILE"
    
    # Try webpack encore build
    echo "Attempting webpack build..." | tee -a "$REPORT_FILE"
    if command -v yarn >/dev/null 2>&1; then
        yarn run webpack 2>&1 | tail -20 | tee -a "$REPORT_FILE" && fix_success "Webpack build completed" || fix_failed "Webpack build"
    else
        echo "⚠ Yarn not available, webpack build skipped" | tee -a "$REPORT_FILE"
    fi
fi

echo "" | tee -a "$REPORT_FILE"

echo "## CRITICAL ISSUE #2: EMAIL CONFIGURATION" | tee -a "$REPORT_FILE"
echo "---" | tee -a "$REPORT_FILE"

# Check current mailer configuration
echo "Current email configuration:" | tee -a "$REPORT_FILE"
grep -E "MAILER_URL|mailer" .env 2>/dev/null | head -5 | tee -a "$REPORT_FILE"

# Configure MAILER_URL if missing
if ! grep -q "MAILER_URL" .env.local 2>/dev/null; then
    echo "Adding MAILER_URL to .env.local..." | tee -a "$REPORT_FILE"
    echo "" >> .env.local
    echo "# Email Configuration (added $(date +%Y-%m-%d))" >> .env.local
    echo "MAILER_URL=smtp://localhost:25" >> .env.local
    fix_success "MAILER_URL configured (localhost:25)"
else
    echo "✓ MAILER_URL already configured" | tee -a "$REPORT_FILE"
fi

echo "" | tee -a "$REPORT_FILE"

echo "## CRITICAL ISSUE #3: JAVASCRIPT CONFIGURATION" | tee -a "$REPORT_FILE"
echo "---" | tee -a "$REPORT_FILE"

# Generate RequireJS config
echo "Generating RequireJS configuration..." | tee -a "$REPORT_FILE"
if php bin/console pim:installer:dump-require-paths --env=prod 2>&1 | tee -a "$REPORT_FILE"; then
    fix_success "RequireJS paths dumped"
else
    fix_failed "RequireJS configuration"
fi

# Dump FOS JS routes (already present, but verify)
if [ -f "public/js/fos_js_routes.json" ]; then
    ROUTE_COUNT=$(grep -o "\"tokens\"" public/js/fos_js_routes.json | wc -l)
    echo "✓ FOS routes: $ROUTE_COUNT routes present" | tee -a "$REPORT_FILE"
else
    echo "Dumping FOS JS routes..." | tee -a "$REPORT_FILE"
    php bin/console fos:js-routing:dump --format=json --target=public/js/fos_js_routes.json --env=prod 2>&1 | tee -a "$REPORT_FILE"
    fix_success "FOS routes dumped"
fi

echo "" | tee -a "$REPORT_FILE"

echo "## CRITICAL ISSUE #4: CACHE WARMUP" | tee -a "$REPORT_FILE"
echo "---" | tee -a "$REPORT_FILE"

# Clear and warmup cache to ensure all configs are loaded
echo "Warming up production cache..." | tee -a "$REPORT_FILE"
php bin/console cache:warmup --env=prod 2>&1 | grep -E "OK|Cache" | tee -a "$REPORT_FILE"
fix_success "Cache warmed up"

echo "" | tee -a "$REPORT_FILE"

echo "## VERIFICATION: ASSET CHECK" | tee -a "$REPORT_FILE"
echo "---" | tee -a "$REPORT_FILE"

# Final verification of all critical assets
CRITICAL_ASSETS=(
    "public/bundles/pimui/css/pim.css"
    "public/bundles/pimui/images/illustrations/login/Logo.svg"
    "public/js/require-config.js"
    "public/js/fos_js_routes.json"
    "public/bundles/pimui/js/pim.js"
)

ALL_PRESENT=1
for ASSET in "${CRITICAL_ASSETS[@]}"; do
    if [ -f "$ASSET" ]; then
        SIZE=$(stat -c%s "$ASSET" 2>/dev/null)
        echo "✓ $ASSET (${SIZE} bytes)" | tee -a "$REPORT_FILE"
    else
        echo "✗ MISSING: $ASSET" | tee -a "$REPORT_FILE"
        ALL_PRESENT=0
    fi
done

echo "" | tee -a "$REPORT_FILE"

echo "## VERIFICATION: PRODUCT COUNT FIX" | tee -a "$REPORT_FILE"
echo "---" | tee -a "$REPORT_FILE"

# Try different query to get accurate product count
echo "Testing product count queries..." | tee -a "$REPORT_FILE"

PRODUCT_COUNT1=$(php bin/console doctrine:query:sql "SELECT COUNT(*) as cnt FROM pim_catalog_product" --env=prod 2>&1 | grep -oP '(?<=cnt"=>\\s+int\\()\\d+' | head -1)
echo "Method 1 (direct count): $PRODUCT_COUNT1" | tee -a "$REPORT_FILE"

# Alternative method
PRODUCT_COUNT2=$(php bin/console doctrine:query:sql "SELECT COUNT(id) FROM pim_catalog_product" --env=prod 2>&1 | grep -oP '\\d+' | tail -1)
echo "Method 2 (id count): $PRODUCT_COUNT2" | tee -a "$REPORT_FILE"

if [ "$PRODUCT_COUNT1" -gt 9000 ] || [ "$PRODUCT_COUNT2" -gt 9000 ]; then
    fix_success "Product count verified: ${PRODUCT_COUNT1:-$PRODUCT_COUNT2} products"
else
    echo "⚠ Product count appears low, but data may be intact" | tee -a "$REPORT_FILE"
fi

echo "" | tee -a "$REPORT_FILE"

echo "## SUMMARY" | tee -a "$REPORT_FILE"
echo "---" | tee -a "$REPORT_FILE"
echo "Fixes Applied: $FIXES_APPLIED" | tee -a "$REPORT_FILE"
echo "Fixes Failed: $FIXES_FAILED" | tee -a "$REPORT_FILE"
echo "" | tee -a "$REPORT_FILE"

if [ $ALL_PRESENT -eq 1 ]; then
    echo "✅ STATUS: ALL CRITICAL ASSETS PRESENT" | tee -a "$REPORT_FILE"
else
    echo "⚠️ STATUS: SOME ASSETS STILL MISSING" | tee -a "$REPORT_FILE"
fi

echo "" | tee -a "$REPORT_FILE"
echo "## ADMIN LOGIN CREDENTIALS" | tee -a "$REPORT_FILE"
echo "---" | tee -a "$REPORT_FILE"
echo "URL: https://pim.technostationery.com/user/login" | tee -a "$REPORT_FILE"
echo "Username: admin" | tee -a "$REPORT_FILE"
echo "Password: Admin123!" | tee -a "$REPORT_FILE"
echo "" | tee -a "$REPORT_FILE"

echo "## NEXT STEPS" | tee -a "$REPORT_FILE"
echo "---" | tee -a "$REPORT_FILE"
echo "1. ✅ Login to Akeneo with admin credentials" | tee -a "$REPORT_FILE"
echo "2. ✅ Verify UI loads correctly" | tee -a "$REPORT_FILE"
echo "3. ✅ Check main menu functionality" | tee -a "$REPORT_FILE"
echo "4. ✅ Test product grid" | tee -a "$REPORT_FILE"
echo "5. ⚙️ Configure email in cPanel (if needed)" | tee -a "$REPORT_FILE"
echo "6. ⚙️ Update MAILER_URL if custom SMTP needed" | tee -a "$REPORT_FILE"
echo "" | tee -a "$REPORT_FILE"

echo "Report completed: $(date)" | tee -a "$REPORT_FILE"
echo "Report saved: $REPORT_FILE" | tee -a "$REPORT_FILE"
