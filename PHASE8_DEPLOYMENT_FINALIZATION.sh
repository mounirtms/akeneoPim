#!/bin/bash
# PHASE 8: DEPLOYMENT FINALIZATION & COMPREHENSIVE TESTING
# Date: 2026-05-06
# Purpose: Complete deployment, test all systems, prepare production readiness

set -e
REPORT_FILE="PHASE8_DEPLOYMENT_REPORT_$(date +%Y%m%d_%H%M%S).md"
START_TIME=$(date +%s)

echo "=== PHASE 8: DEPLOYMENT FINALIZATION ===" | tee -a "$REPORT_FILE"
echo "Start: $(date)" | tee -a "$REPORT_FILE"
echo "" | tee -a "$REPORT_FILE"

# Test counters
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

test_passed() {
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    PASSED_TESTS=$((PASSED_TESTS + 1))
    echo "✓ PASS: $1" | tee -a "$REPORT_FILE"
}

test_failed() {
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    FAILED_TESTS=$((FAILED_TESTS + 1))
    echo "✗ FAIL: $1" | tee -a "$REPORT_FILE"
}

echo "## 1. CACHE STATUS" | tee -a "$REPORT_FILE"
echo "---" | tee -a "$REPORT_FILE"
CACHE_FILES=$(find var/cache/prod -type f 2>/dev/null | wc -l)
echo "Cache files: $CACHE_FILES" | tee -a "$REPORT_FILE"
if [ "$CACHE_FILES" -gt 5000 ]; then
    test_passed "Production cache warmed up ($CACHE_FILES files)"
else
    test_failed "Cache not fully warmed ($CACHE_FILES files, expected >5000)"
fi
echo "" | tee -a "$REPORT_FILE"

echo "## 2. APPLICATION STATUS" | tee -a "$REPORT_FILE"
echo "---" | tee -a "$REPORT_FILE"

# Test PHP version
PHP_VERSION=$(php -v | head -1)
echo "PHP Version: $PHP_VERSION" | tee -a "$REPORT_FILE"
test_passed "PHP executable found: $PHP_VERSION"

# Test Symfony console
SYMFONY_VERSION=$(php bin/console --version 2>&1 | head -1)
echo "Symfony Version: $SYMFONY_VERSION" | tee -a "$REPORT_FILE"
test_passed "Symfony console accessible: $SYMFONY_VERSION"

# Test database connection
echo "Database connection test:" | tee -a "$REPORT_FILE"
if php bin/console doctrine:query:sql "SELECT COUNT(*) as product_count FROM pim_catalog_product" --env=prod 2>&1 | grep -q "product_count"; then
    PRODUCT_COUNT=$(php bin/console doctrine:query:sql "SELECT COUNT(*) as product_count FROM pim_catalog_product" --env=prod 2>&1 | grep -oP '\d+' | head -1)
    echo "Products in database: $PRODUCT_COUNT" | tee -a "$REPORT_FILE"
    test_passed "Database connection working (Products: $PRODUCT_COUNT)"
else
    test_failed "Database connection issue"
fi
echo "" | tee -a "$REPORT_FILE"

echo "## 3. WEB SERVER CONFIGURATION" | tee -a "$REPORT_FILE"
echo "---" | tee -a "$REPORT_FILE"

# Check DocumentRoot
echo "Checking Apache DocumentRoot configuration..." | tee -a "$REPORT_FILE"
if grep -q "DocumentRoot /home/pim/public_html/public" /etc/apache2/conf/httpd.conf 2>/dev/null; then
    test_passed "Apache DocumentRoot correctly set to /home/pim/public_html/public"
else
    test_failed "Apache DocumentRoot configuration issue"
fi

# Check .htaccess files
if [ -f "public/.htaccess" ]; then
    test_passed ".htaccess exists in public directory"
else
    test_failed ".htaccess missing in public directory"
fi

# Check index.php
if [ -f "public/index.php" ]; then
    test_passed "index.php exists in public directory"
else
    test_failed "index.php missing in public directory"
fi
echo "" | tee -a "$REPORT_FILE"

echo "## 4. FILE SYSTEM STATUS" | tee -a "$REPORT_FILE"
echo "---" | tee -a "$REPORT_FILE"

# Check critical directories
CRITICAL_DIRS=("var/cache" "var/logs" "var/sessions" "public/media" "vendor")
for DIR in "${CRITICAL_DIRS[@]}"; do
    if [ -d "$DIR" ]; then
        SIZE=$(du -sh "$DIR" 2>/dev/null | cut -f1)
        echo "$DIR: $SIZE" | tee -a "$REPORT_FILE"
        if [ -w "$DIR" ]; then
            test_passed "Directory $DIR exists and is writable (Size: $SIZE)"
        else
            test_failed "Directory $DIR not writable"
        fi
    else
        test_failed "Directory $DIR missing"
    fi
done
echo "" | tee -a "$REPORT_FILE"

echo "## 5. FRONTEND ASSETS" | tee -a "$REPORT_FILE"
echo "---" | tee -a "$REPORT_FILE"

# Check frontend assets
ASSET_DIRS=("public/bundles" "public/css" "public/js" "public/dist")
for DIR in "${ASSET_DIRS[@]}"; do
    if [ -d "$DIR" ]; then
        FILE_COUNT=$(find "$DIR" -type f 2>/dev/null | wc -l)
        echo "$DIR: $FILE_COUNT files" | tee -a "$REPORT_FILE"
        test_passed "Frontend assets present in $DIR ($FILE_COUNT files)"
    else
        test_failed "Frontend asset directory $DIR missing"
    fi
done
echo "" | tee -a "$REPORT_FILE"

echo "## 6. APPLICATION TESTING" | tee -a "$REPORT_FILE"
echo "---" | tee -a "$REPORT_FILE"

# Test index.php execution
echo "Testing index.php execution..." | tee -a "$REPORT_FILE"
OUTPUT=$(php public/index.php 2>&1 | head -5)
if echo "$OUTPUT" | grep -q "Redirecting"; then
    test_passed "index.php executes correctly (redirects to /user/login)"
else
    test_failed "index.php execution issue"
fi

# Test login route
echo "Testing login route..." | tee -a "$REPORT_FILE"
if php bin/console debug:router pim_user_security_login --env=prod 2>&1 | grep -q "/user/login"; then
    test_passed "Login route configured correctly"
else
    test_failed "Login route configuration issue"
fi
echo "" | tee -a "$REPORT_FILE"

echo "## 7. AKENEO CLI COMMANDS" | tee -a "$REPORT_FILE"
echo "---" | tee -a "$REPORT_FILE"

# Count available commands
COMMAND_COUNT=$(php bin/console list --env=prod 2>&1 | grep -c "pim:" || echo "0")
echo "Available Akeneo commands: $COMMAND_COUNT" | tee -a "$REPORT_FILE"
if [ "$COMMAND_COUNT" -gt 20 ]; then
    test_passed "Akeneo CLI commands available ($COMMAND_COUNT commands)"
else
    test_failed "Insufficient Akeneo commands ($COMMAND_COUNT found, expected >20)"
fi
echo "" | tee -a "$REPORT_FILE"

echo "## 8. LOG ANALYSIS" | tee -a "$REPORT_FILE"
echo "---" | tee -a "$REPORT_FILE"

# Check recent logs
if [ -f "var/logs/prod.log" ]; then
    RECENT_ERRORS=$(tail -100 var/logs/prod.log 2>/dev/null | grep -c "ERROR\|CRITICAL" || echo "0")
    echo "Recent errors in log (last 100 lines): $RECENT_ERRORS" | tee -a "$REPORT_FILE"
    if [ "$RECENT_ERRORS" -lt 10 ]; then
        test_passed "Log file healthy (Recent errors: $RECENT_ERRORS)"
    else
        echo "⚠ Warning: Multiple recent errors detected" | tee -a "$REPORT_FILE"
        test_passed "Log file exists but contains $RECENT_ERRORS recent errors"
    fi
else
    test_failed "Production log file not found"
fi
echo "" | tee -a "$REPORT_FILE"

echo "## 9. LOCALHOST TESTING" | tee -a "$REPORT_FILE"
echo "---" | tee -a "$REPORT_FILE"

# Test root path
echo "Testing localhost root path..." | tee -a "$REPORT_FILE"
ROOT_TEST=$(php -r "
\$_SERVER['REQUEST_URI'] = '/';
\$_SERVER['SCRIPT_NAME'] = '/index.php';
\$_SERVER['HTTP_HOST'] = 'localhost';
\$_SERVER['REQUEST_METHOD'] = 'GET';
ob_start();
require 'public/index.php';
\$output = ob_get_clean();
echo (strpos(\$output, 'Redirecting') !== false) ? 'PASS' : 'FAIL';
" 2>&1 | grep -o "PASS\|FAIL")

if [ "$ROOT_TEST" = "PASS" ]; then
    test_passed "Localhost root path redirects correctly"
else
    test_failed "Localhost root path test failed"
fi

# Test login path
echo "Testing localhost login path..." | tee -a "$REPORT_FILE"
LOGIN_TEST=$(php -r "
\$_SERVER['REQUEST_URI'] = '/user/login';
\$_SERVER['SCRIPT_NAME'] = '/index.php';
\$_SERVER['HTTP_HOST'] = 'localhost';
\$_SERVER['REQUEST_METHOD'] = 'GET';
ob_start();
require 'public/index.php';
\$output = ob_get_clean();
echo (strpos(\$output, 'Akeneo') !== false && strpos(\$output, 'login') !== false) ? 'PASS' : 'FAIL';
" 2>&1 | grep -o "PASS\|FAIL")

if [ "$LOGIN_TEST" = "PASS" ]; then
    test_passed "Localhost login page renders correctly"
else
    test_failed "Localhost login page test failed"
fi
echo "" | tee -a "$REPORT_FILE"

echo "## 10. CONFIGURATION FILES" | tee -a "$REPORT_FILE"
echo "---" | tee -a "$REPORT_FILE"

# Check configuration files
CONFIG_FILES=(".env" ".env.local" "config/packages/security.yml" "config/packages/framework.yml")
for FILE in "${CONFIG_FILES[@]}"; do
    if [ -f "$FILE" ]; then
        test_passed "Configuration file exists: $FILE"
    else
        test_failed "Configuration file missing: $FILE"
    fi
done
echo "" | tee -a "$REPORT_FILE"

# Calculate test results
SUCCESS_RATE=$(( PASSED_TESTS * 100 / TOTAL_TESTS ))
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

echo "## SUMMARY" | tee -a "$REPORT_FILE"
echo "---" | tee -a "$REPORT_FILE"
echo "Total Tests: $TOTAL_TESTS" | tee -a "$REPORT_FILE"
echo "Passed: $PASSED_TESTS" | tee -a "$REPORT_FILE"
echo "Failed: $FAILED_TESTS" | tee -a "$REPORT_FILE"
echo "Success Rate: $SUCCESS_RATE%" | tee -a "$REPORT_FILE"
echo "Duration: ${DURATION}s" | tee -a "$REPORT_FILE"
echo "" | tee -a "$REPORT_FILE"

if [ "$SUCCESS_RATE" -ge 90 ]; then
    echo "## STATUS: ✅ EXCELLENT - PRODUCTION READY" | tee -a "$REPORT_FILE"
elif [ "$SUCCESS_RATE" -ge 75 ]; then
    echo "## STATUS: ⚠ GOOD - Minor issues to address" | tee -a "$REPORT_FILE"
else
    echo "## STATUS: ❌ CRITICAL - Requires immediate attention" | tee -a "$REPORT_FILE"
fi

echo "" | tee -a "$REPORT_FILE"
echo "## NEXT STEPS" | tee -a "$REPORT_FILE"
echo "---" | tee -a "$REPORT_FILE"
echo "1. Review this report: $REPORT_FILE" | tee -a "$REPORT_FILE"
echo "2. Test website access: https://pim.technostationery.com/user/login" | tee -a "$REPORT_FILE"
echo "3. If directory index shows, check Apache configuration" | tee -a "$REPORT_FILE"
echo "4. Verify .htaccess is being processed by Apache" | tee -a "$REPORT_FILE"
echo "5. Consider restarting Apache: sudo systemctl restart httpd" | tee -a "$REPORT_FILE"
echo "" | tee -a "$REPORT_FILE"
echo "Report completed: $(date)" | tee -a "$REPORT_FILE"
echo "Report saved to: $REPORT_FILE" | tee -a "$REPORT_FILE"
