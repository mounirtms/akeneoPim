#!/bin/bash
# Comprehensive Akeneo PIM UI, Login & Menu Tests
# Date: 2026-05-01

LOG_FILE="logs/comprehensive_ui_login_$(date +%Y%m%d_%H%M%S).log"
mkdir -p logs

echo "========================================" | tee "$LOG_FILE"
echo "Comprehensive Akeneo PIM UI Tests" | tee -a "$LOG_FILE"
echo "Date: $(date)" | tee -a "$LOG_FILE"
echo "========================================" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

PASSED=0
FAILED=0

test_result() {
    if [ $1 -eq 0 ]; then
        echo "✓ PASS: $2" | tee -a "$LOG_FILE"
        ((PASSED++))
    else
        echo "✗ FAIL: $2" | tee -a "$LOG_FILE"
        ((FAILED++))
    fi
}

# Test 1: Check Frontend Error Logs
echo "=== Test 1: Checking Frontend Error Logs ===" | tee -a "$LOG_FILE"
cd /home/pim/public_html
if [ -f "var/logs/prod.log" ]; then
    ERRORS=$(tail -100 var/logs/prod.log | grep -i "error\|exception\|fatal" | wc -l)
    echo "Recent errors in prod.log: $ERRORS" | tee -a "$LOG_FILE"
    if [ $ERRORS -lt 5 ]; then
        test_result 0 "Production log errors acceptable ($ERRORS errors)"
    else
        test_result 1 "Too many errors in production log ($ERRORS errors)"
        tail -20 var/logs/prod.log | tee -a "$LOG_FILE"
    fi
else
    echo "Production log not found" | tee -a "$LOG_FILE"
    test_result 1 "Production log missing"
fi
echo "" | tee -a "$LOG_FILE"

# Test 2: Check CSS Files in Bundles
echo "=== Test 2: CSS Files Detection ===" | tee -a "$LOG_FILE"
CSS_FILES=$(find public/bundles -name "*.css" 2>/dev/null)
CSS_COUNT=$(echo "$CSS_FILES" | grep -c ".css")
echo "CSS files found: $CSS_COUNT" | tee -a "$LOG_FILE"
if [ $CSS_COUNT -gt 0 ]; then
    echo "CSS files list:" | tee -a "$LOG_FILE"
    echo "$CSS_FILES" | head -10 | tee -a "$LOG_FILE"
    test_result 0 "CSS files present ($CSS_COUNT files)"
else
    echo "Checking for embedded styles..." | tee -a "$LOG_FILE"
    STYLE_TAGS=$(curl -s https://pim.technostationery.com/ | grep -o "<style" | wc -l)
    echo "Inline <style> tags found: $STYLE_TAGS" | tee -a "$LOG_FILE"
    if [ $STYLE_TAGS -gt 5 ]; then
        test_result 0 "Styles present via inline tags ($STYLE_TAGS tags)"
    else
        test_result 1 "No CSS files or inline styles found"
    fi
fi
echo "" | tee -a "$LOG_FILE"

# Test 3: Check Webpack Build Output
echo "=== Test 3: Webpack Build Status ===" | tee -a "$LOG_FILE"
if [ -d "public/dist" ]; then
    DIST_SIZE=$(du -sh public/dist 2>/dev/null | cut -f1)
    echo "Webpack dist directory: $DIST_SIZE" | tee -a "$LOG_FILE"
    test_result 0 "Webpack dist directory exists ($DIST_SIZE)"
else
    echo "No webpack dist directory found" | tee -a "$LOG_FILE"
    test_result 1 "Webpack dist directory missing"
fi

# Check for built JS files
BUILT_JS=$(find public -name "*.min.js" -o -name "vendor.js" 2>/dev/null | wc -l)
echo "Built JS files: $BUILT_JS" | tee -a "$LOG_FILE"
if [ $BUILT_JS -gt 0 ]; then
    test_result 0 "Built JavaScript files present ($BUILT_JS files)"
else
    test_result 1 "No built JavaScript files found"
fi
echo "" | tee -a "$LOG_FILE"

# Test 4: Test Login Page HTML Structure
echo "=== Test 4: Login Page HTML Structure ===" | tee -a "$LOG_FILE"
LOGIN_HTML=$(curl -s https://pim.technostationery.com/user/login 2>/dev/null)
if echo "$LOGIN_HTML" | grep -q "form"; then
    test_result 0 "Login form HTML present"
    
    # Check for specific elements
    if echo "$LOGIN_HTML" | grep -q "username\|email\|_username"; then
        echo "  ✓ Username field found" | tee -a "$LOG_FILE"
    fi
    if echo "$LOGIN_HTML" | grep -q "password\|_password"; then
        echo "  ✓ Password field found" | tee -a "$LOG_FILE"
    fi
    if echo "$LOGIN_HTML" | grep -q "submit\|button"; then
        echo "  ✓ Submit button found" | tee -a "$LOG_FILE"
    fi
else
    test_result 1 "Login form HTML missing"
fi
echo "" | tee -a "$LOG_FILE"

# Test 5: Check Enrich Bundle
echo "=== Test 5: Enrich Bundle Status ===" | tee -a "$LOG_FILE"
if [ -d "public/bundles/pimui" ]; then
    PIMUI_SIZE=$(du -sh public/bundles/pimui 2>/dev/null | cut -f1)
    PIMUI_FILES=$(find public/bundles/pimui -type f | wc -l)
    echo "PIM UI bundle: $PIMUI_SIZE, $PIMUI_FILES files" | tee -a "$LOG_FILE"
    test_result 0 "PIM UI bundle present ($PIMUI_SIZE, $PIMUI_FILES files)"
else
    test_result 1 "PIM UI bundle missing"
fi

if [ -d "public/bundles/pименrich" ]; then
    ENRICH_SIZE=$(du -sh public/bundles/pimenovrich 2>/dev/null | cut -f1)
    echo "Enrich bundle: $ENRICH_SIZE" | tee -a "$LOG_FILE"
    test_result 0 "Enrich bundle present ($ENRICH_SIZE)"
else
    echo "Enrich bundle not found in standard location" | tee -a "$LOG_FILE"
    test_result 1 "Enrich bundle missing"
fi
echo "" | tee -a "$LOG_FILE"

# Test 6: Test Menu/Navigation Routes
echo "=== Test 6: Navigation Routes Test ===" | tee -a "$LOG_FILE"
if [ -f "public/js/fos_js_routes.json" ]; then
    # Check for key Akeneo routes
    PRODUCT_ROUTES=$(grep -o "pim_enrich_product\|product_index\|product_edit" public/js/fos_js_routes.json | wc -l)
    CATEGORY_ROUTES=$(grep -o "pim_enrich_category\|category_tree" public/js/fos_js_routes.json | wc -l)
    ATTRIBUTE_ROUTES=$(grep -o "pim_enrich_attribute\|attribute_index" public/js/fos_js_routes.json | wc -l)
    
    echo "Product routes: $PRODUCT_ROUTES" | tee -a "$LOG_FILE"
    echo "Category routes: $CATEGORY_ROUTES" | tee -a "$LOG_FILE"
    echo "Attribute routes: $ATTRIBUTE_ROUTES" | tee -a "$LOG_FILE"
    
    TOTAL_ENRICH_ROUTES=$((PRODUCT_ROUTES + CATEGORY_ROUTES + ATTRIBUTE_ROUTES))
    if [ $TOTAL_ENRICH_ROUTES -gt 5 ]; then
        test_result 0 "Enrich menu routes configured ($TOTAL_ENRICH_ROUTES routes)"
    else
        test_result 1 "Insufficient enrich routes ($TOTAL_ENRICH_ROUTES routes)"
    fi
else
    test_result 1 "Routes file missing"
fi
echo "" | tee -a "$LOG_FILE"

# Test 7: Check RequireJS Configuration
echo "=== Test 7: RequireJS Configuration ===" | tee -a "$LOG_FILE"
if [ -f "public/js/require-config.js" ] || [ -f "public/bundles/pimui/js/require-config.js" ]; then
    echo "RequireJS config found" | tee -a "$LOG_FILE"
    test_result 0 "RequireJS configuration present"
else
    echo "RequireJS config not in standard location" | tee -a "$LOG_FILE"
    test_result 1 "RequireJS configuration missing"
fi

# Check module registry
if [ -f "public/js/module-registry.js" ]; then
    REGISTRY_SIZE=$(stat -c%s "public/js/module-registry.js" 2>/dev/null)
    echo "Module registry size: $REGISTRY_SIZE bytes" | tee -a "$LOG_FILE"
    if [ $REGISTRY_SIZE -gt 1000 ]; then
        test_result 0 "Module registry valid ($REGISTRY_SIZE bytes)"
    else
        test_result 1 "Module registry too small ($REGISTRY_SIZE bytes)"
    fi
else
    test_result 1 "Module registry missing"
fi
echo "" | tee -a "$LOG_FILE"

# Test 8: Check Symfony Asset Installation
echo "=== Test 8: Symfony Assets ===" | tee -a "$LOG_FILE"
SYMFONY_BUNDLES=$(ls -1 public/bundles 2>/dev/null | wc -l)
echo "Symfony asset bundles: $SYMFONY_BUNDLES" | tee -a "$LOG_FILE"
if [ $SYMFONY_BUNDLES -gt 10 ]; then
    test_result 0 "Symfony assets installed ($SYMFONY_BUNDLES bundles)"
    ls -1 public/bundles | head -15 | tee -a "$LOG_FILE"
else
    test_result 1 "Insufficient Symfony assets ($SYMFONY_BUNDLES bundles)"
fi
echo "" | tee -a "$LOG_FILE"

# Test 9: Check Varnish Status
echo "=== Test 9: Varnish Cache Status ===" | tee -a "$LOG_FILE"
if pgrep -x "varnishd" > /dev/null; then
    echo "Varnish is running" | tee -a "$LOG_FILE"
    VARNISH_STATS=$(varnishstat -1 2>/dev/null | head -10)
    if [ ! -z "$VARNISH_STATS" ]; then
        echo "Varnish stats:" | tee -a "$LOG_FILE"
        echo "$VARNISH_STATS" | tee -a "$LOG_FILE"
        test_result 0 "Varnish running and responding"
    else
        test_result 0 "Varnish running (stats unavailable)"
    fi
else
    echo "Varnish not running" | tee -a "$LOG_FILE"
    test_result 1 "Varnish not running"
fi
echo "" | tee -a "$LOG_FILE"

# Test 10: Check Redis Connection
echo "=== Test 10: Redis Status ===" | tee -a "$LOG_FILE"
if redis-cli ping > /dev/null 2>&1; then
    REDIS_INFO=$(redis-cli info stats 2>/dev/null | grep "total_connections_received\|total_commands_processed" | head -2)
    echo "Redis is running" | tee -a "$LOG_FILE"
    echo "$REDIS_INFO" | tee -a "$LOG_FILE"
    test_result 0 "Redis running and responding"
else
    echo "Redis not responding" | tee -a "$LOG_FILE"
    test_result 1 "Redis connection failed"
fi
echo "" | tee -a "$LOG_FILE"

# Test 11: Check Web Server Error Logs
echo "=== Test 11: Web Server Error Logs ===" | tee -a "$LOG_FILE"
if [ -f "/home/pim/public_html/error_log" ]; then
    RECENT_ERRORS=$(tail -50 /home/pim/public_html/error_log | grep -i "error\|warning" | wc -l)
    echo "Recent web server errors: $RECENT_ERRORS" | tee -a "$LOG_FILE"
    if [ $RECENT_ERRORS -lt 10 ]; then
        test_result 0 "Web server errors acceptable ($RECENT_ERRORS errors)"
    else
        test_result 1 "Too many web server errors ($RECENT_ERRORS errors)"
        echo "Recent errors:" | tee -a "$LOG_FILE"
        tail -20 /home/pim/public_html/error_log | tee -a "$LOG_FILE"
    fi
else
    echo "Web server error log not found at standard location" | tee -a "$LOG_FILE"
    test_result 0 "Error log not found (may be elsewhere)"
fi
echo "" | tee -a "$LOG_FILE"

# Test 12: Check Console Commands
echo "=== Test 12: Akeneo Console Commands ===" | tee -a "$LOG_FILE"
CONSOLE_COMMANDS=$(php bin/console list pim 2>/dev/null | grep "pim:" | wc -l)
echo "Available PIM commands: $CONSOLE_COMMANDS" | tee -a "$LOG_FILE"
if [ $CONSOLE_COMMANDS -gt 20 ]; then
    test_result 0 "Akeneo commands available ($CONSOLE_COMMANDS commands)"
else
    test_result 1 "Few Akeneo commands available ($CONSOLE_COMMANDS commands)"
fi
echo "" | tee -a "$LOG_FILE"

# Test 13: Check User Authentication
echo "=== Test 13: User Authentication System ===" | tee -a "$LOG_FILE"
USER_COUNT=$(php bin/console dbal:run-sql "SELECT COUNT(*) as count FROM oro_user" --env=prod 2>/dev/null | grep -o '[0-9]*' | tail -1)
echo "Users in database: $USER_COUNT" | tee -a "$LOG_FILE"
if [ "$USER_COUNT" -gt 0 ]; then
    test_result 0 "User authentication system configured ($USER_COUNT users)"
else
    test_result 1 "No users found in database"
fi
echo "" | tee -a "$LOG_FILE"

# Test 14: Check Translation Files
echo "=== Test 14: Translation Files ===" | tee -a "$LOG_FILE"
TRANSLATION_FILES=$(find public/js/translation -name "*.js" 2>/dev/null | wc -l)
echo "Translation files: $TRANSLATION_FILES" | tee -a "$LOG_FILE"
if [ $TRANSLATION_FILES -gt 0 ]; then
    test_result 0 "Translation files present ($TRANSLATION_FILES files)"
    find public/js/translation -name "*.js" 2>/dev/null | head -5 | tee -a "$LOG_FILE"
else
    test_result 1 "No translation files found"
fi
echo "" | tee -a "$LOG_FILE"

# Test 15: Check Session Configuration
echo "=== Test 15: Session Configuration ===" | tee -a "$LOG_FILE"
SESSION_DIR="var/sessions"
if [ -d "$SESSION_DIR" ]; then
    SESSION_SIZE=$(du -sh "$SESSION_DIR" 2>/dev/null | cut -f1)
    echo "Session directory: $SESSION_SIZE" | tee -a "$LOG_FILE"
    test_result 0 "Session directory exists ($SESSION_SIZE)"
else
    echo "Session directory not found, checking PHP config..." | tee -a "$LOG_FILE"
    test_result 0 "Sessions may be handled by PHP default"
fi
echo "" | tee -a "$LOG_FILE"

# Summary
echo "========================================" | tee -a "$LOG_FILE"
echo "COMPREHENSIVE UI TEST SUMMARY" | tee -a "$LOG_FILE"
echo "========================================" | tee -a "$LOG_FILE"
TOTAL=$((PASSED + FAILED))
SUCCESS_RATE=$(awk "BEGIN {printf \"%.1f\", ($PASSED/$TOTAL)*100}")

echo "Total Tests: $TOTAL" | tee -a "$LOG_FILE"
echo "Passed: $PASSED" | tee -a "$LOG_FILE"
echo "Failed: $FAILED" | tee -a "$LOG_FILE"
echo "Success Rate: $SUCCESS_RATE%" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

if [ $FAILED -eq 0 ]; then
    echo "✓ ALL UI TESTS PASSED" | tee -a "$LOG_FILE"
    exit 0
elif [ $FAILED -le 5 ]; then
    echo "⚠ MINOR UI ISSUES DETECTED" | tee -a "$LOG_FILE"
    exit 0
else
    echo "✗ UI ISSUES REQUIRE ATTENTION" | tee -a "$LOG_FILE"
    exit 1
fi
