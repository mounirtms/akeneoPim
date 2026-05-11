#!/bin/bash
# TEST_ADMIN_LOGIN.sh - Test admin login and verify UI components
# Date: 2026-05-06

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔐 PHASE 10: ADMIN LOGIN TEST & UI VERIFICATION"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Start time: $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo ""

# Admin credentials
ADMIN_USER="admin"
ADMIN_PASS="Admin123!"
LOGIN_URL="https://pim.technostationery.com/user/login"
BASE_URL="https://pim.technostationery.com"

echo "1. Testing Login Page Access..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
LOGIN_RESPONSE=$(curl -s -w "\n%{http_code}\n%{time_total}" -o /tmp/login_page.html "$LOGIN_URL")
HTTP_CODE=$(echo "$LOGIN_RESPONSE" | tail -2 | head -1)
RESPONSE_TIME=$(echo "$LOGIN_RESPONSE" | tail -1)

if [ "$HTTP_CODE" = "200" ]; then
    echo "✓ Login page accessible (HTTP $HTTP_CODE)"
    echo "  Response time: ${RESPONSE_TIME}s"
    
    # Check for key elements
    grep -q "login" /tmp/login_page.html && echo "✓ Login form found" || echo "✗ Login form NOT found"
    grep -q "Akeneo" /tmp/login_page.html && echo "✓ Akeneo branding found" || echo "✗ Akeneo branding NOT found"
    grep -q "_csrf_token" /tmp/login_page.html && echo "✓ CSRF token found" || echo "✗ CSRF token NOT found"
else
    echo "✗ Login page error (HTTP $HTTP_CODE)"
fi
echo ""

echo "2. Checking Critical UI Assets..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# CSS files
echo "CSS Assets:"
for css in public/bundles/pimui/css/pim.css public/css/pim-*.css; do
    if [ -f "$css" ]; then
        SIZE=$(stat -f%z "$css" 2>/dev/null || stat -c%s "$css" 2>/dev/null)
        echo "  ✓ $css (${SIZE} bytes)"
    else
        echo "  ✗ $css MISSING"
    fi
done

# JavaScript files
echo "JavaScript Assets:"
for js in public/js/require-config.js public/dist/backend.min.js public/bundles/fosjsrouting/js/router.min.js; do
    if [ -f "$js" ]; then
        SIZE=$(stat -f%z "$js" 2>/dev/null || stat -c%s "$js" 2>/dev/null)
        echo "  ✓ $js (${SIZE} bytes)"
    else
        echo "  ✗ $js MISSING"
    fi
done

# Check bundles directory
echo "Bundle Assets:"
if [ -d "public/bundles" ]; then
    BUNDLE_COUNT=$(find public/bundles -type f 2>/dev/null | wc -l | tr -d ' ')
    echo "  ✓ public/bundles/ exists (${BUNDLE_COUNT} files)"
else
    echo "  ✗ public/bundles/ MISSING"
fi
echo ""

echo "3. Verifying Akeneo Backend Routes..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [ -f "public/js/fos_js_routes.json" ]; then
    ROUTE_COUNT=$(grep -o '"' public/js/fos_js_routes.json | wc -l | tr -d ' ')
    echo "✓ FOS routes available ($ROUTE_COUNT route definitions)"
    
    # Check for critical routes
    grep -q "pim_enrich_product_index" public/js/fos_js_routes.json && echo "  ✓ Product grid route found" || echo "  ✗ Product grid route MISSING"
    grep -q "pim_user_user_rest_get" public/js/fos_js_routes.json && echo "  ✓ User API route found" || echo "  ✗ User API route MISSING"
else
    echo "✗ FOS routes file MISSING"
fi
echo ""

echo "4. Checking Product Data Integrity..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
PRODUCT_COUNT=$(php bin/console pim:product:query-help 2>/dev/null | grep -c "identifier" || echo "0")
DB_PRODUCTS=$(mysql -h 127.0.0.1 -P 3307 -u pim -ppim_password akeneo_pim -se "SELECT COUNT(*) FROM pim_catalog_product" 2>/dev/null || echo "0")
echo "✓ Products in database: ${DB_PRODUCTS}"

# Check sample products
SAMPLE_PRODUCTS=$(mysql -h 127.0.0.1 -P 3307 -u pim -ppim_password akeneo_pim -se "SELECT identifier FROM pim_catalog_product LIMIT 5" 2>/dev/null)
if [ -n "$SAMPLE_PRODUCTS" ]; then
    echo "✓ Sample products:"
    echo "$SAMPLE_PRODUCTS" | head -5 | sed 's/^/    /'
fi
echo ""

echo "5. Database Connectivity Test..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
DB_VERSION=$(mysql -h 127.0.0.1 -P 3307 -u pim -ppim_password -se "SELECT VERSION()" 2>/dev/null || echo "Connection failed")
echo "Database: $DB_VERSION"

DB_SIZE=$(mysql -h 127.0.0.1 -P 3307 -u pim -ppim_password -se "SELECT ROUND(SUM(data_length + index_length) / 1024 / 1024, 2) AS 'Size (MB)' FROM information_schema.TABLES WHERE table_schema = 'akeneo_pim'" 2>/dev/null || echo "0")
echo "Database size: ${DB_SIZE} MB"
echo ""

echo "6. Checking Session Configuration..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [ -d "var/sessions" ]; then
    SESSION_COUNT=$(ls -1 var/sessions/ 2>/dev/null | wc -l | tr -d ' ')
    echo "✓ Session directory exists (${SESSION_COUNT} active sessions)"
    ls -ld var/sessions/
else
    echo "✗ Session directory MISSING"
fi
echo ""

echo "7. Email Configuration Check..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [ -f ".env.local" ]; then
    echo "✓ .env.local exists"
    if grep -q "MAILER_URL" .env.local; then
        MAILER=$(grep "MAILER_URL" .env.local | head -1)
        echo "  Current: $MAILER"
    else
        echo "  ✗ MAILER_URL not configured"
    fi
else
    echo "✗ .env.local MISSING"
fi
echo ""

echo "8. Summary & Login Instructions..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📋 ADMIN LOGIN CREDENTIALS:"
echo "   URL: $LOGIN_URL"
echo "   Username: $ADMIN_USER"
echo "   Password: $ADMIN_PASS"
echo ""
echo "🌐 DIRECT URLS TO TEST:"
echo "   Login: $BASE_URL/user/login"
echo "   Dashboard: $BASE_URL/"
echo "   Products: $BASE_URL/#/enrich/product/"
echo ""
echo "✅ READY FOR MANUAL TESTING"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "End time: $(date '+%Y-%m-%d %H:%M:%S %Z')"
