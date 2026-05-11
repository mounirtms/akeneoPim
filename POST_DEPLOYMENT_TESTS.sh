#!/bin/bash
# POST-DEPLOYMENT COMPREHENSIVE TESTS
# Date: 2026-05-06

set -e
REPORT_FILE="POST_DEPLOY_TEST_REPORT_$(date +%Y%m%d_%H%M%S).md"

echo "=== POST-DEPLOYMENT COMPREHENSIVE TESTS ===" | tee "$REPORT_FILE"
echo "Started: $(date)" | tee -a "$REPORT_FILE"
echo "" | tee -a "$REPORT_FILE"

PASSED=0
FAILED=0

test_pass() {
    PASSED=$((PASSED + 1))
    echo "✓ PASS: $1" | tee -a "$REPORT_FILE"
}

test_fail() {
    FAILED=$((FAILED + 1))
    echo "✗ FAIL: $1" | tee -a "$REPORT_FILE"
}

echo "## 1. WEB SERVER TESTS" | tee -a "$REPORT_FILE"
echo "---" | tee -a "$REPORT_FILE"

# Test 1: Apache running
APACHE_COUNT=$(ps aux | grep httpd | grep -v grep | wc -l)
if [ "$APACHE_COUNT" -gt 0 ]; then
    test_pass "Apache is running ($APACHE_COUNT processes)"
else
    test_fail "Apache is not running"
fi

# Test 2: Apache listening on ports
LISTENING=$(netstat -tlnp 2>/dev/null | grep -c ":80\|:443" || ss -tlnp 2>/dev/null | grep -c ":80\|:443" || echo "0")
if [ "$LISTENING" -gt 0 ]; then
    test_pass "Apache listening on ports 80/443"
else
    test_fail "Apache not listening on expected ports"
fi

echo "" | tee -a "$REPORT_FILE"

echo "## 2. APPLICATION TESTS" | tee -a "$REPORT_FILE"
echo "---" | tee -a "$REPORT_FILE"

# Test 3: Root path redirect
ROOT_TEST=$(php -r "
\$_SERVER['REQUEST_URI'] = '/';
\$_SERVER['SCRIPT_NAME'] = '/index.php';
\$_SERVER['HTTP_HOST'] = 'localhost';
\$_SERVER['REQUEST_METHOD'] = 'GET';
ob_start();
require 'public/index.php';
\$output = ob_get_clean();
echo (strpos(\$output, 'Redirecting') !== false) ? 'PASS' : 'FAIL';
" 2>/dev/null)
if [ "$ROOT_TEST" = "PASS" ]; then
    test_pass "Root path redirects correctly"
else
    test_fail "Root path redirect issue"
fi

# Test 4: Login page rendering
LOGIN_TEST=$(php -r "
\$_SERVER['REQUEST_URI'] = '/user/login';
\$_SERVER['SCRIPT_NAME'] = '/index.php';
\$_SERVER['HTTP_HOST'] = 'localhost';
\$_SERVER['REQUEST_METHOD'] = 'GET';
ob_start();
require 'public/index.php';
\$output = ob_get_clean();
\$hasAkeneo = strpos(\$output, 'Akeneo') !== false;
\$hasLogin = strpos(\$output, 'login') !== false;
echo (\$hasAkeneo && \$hasLogin) ? 'PASS' : 'FAIL';
" 2>/dev/null)
if [ "$LOGIN_TEST" = "PASS" ]; then
    test_pass "Login page renders correctly"
else
    test_fail "Login page rendering issue"
fi

# Test 5: Response time
RESPONSE_TIME=$(php -r "
\$start = microtime(true);
\$_SERVER['REQUEST_URI'] = '/user/login';
\$_SERVER['SCRIPT_NAME'] = '/index.php';
\$_SERVER['HTTP_HOST'] = 'localhost';
\$_SERVER['REQUEST_METHOD'] = 'GET';
ob_start();
require 'public/index.php';
ob_end_clean();
echo round((microtime(true) - \$start) * 1000);
" 2>/dev/null)
if [ "$RESPONSE_TIME" -lt 1000 ]; then
    test_pass "Response time: ${RESPONSE_TIME}ms (target <1000ms)"
else
    test_fail "Response time: ${RESPONSE_TIME}ms (exceeds 1000ms)"
fi

echo "" | tee -a "$REPORT_FILE"

echo "## 3. DATABASE TESTS" | tee -a "$REPORT_FILE"
echo "---" | tee -a "$REPORT_FILE"

# Test 6: Database connection
DB_TEST=$(php bin/console doctrine:query:sql "SELECT 1" --env=prod 2>&1 | grep -c "1" || echo "0")
if [ "$DB_TEST" -gt 0 ]; then
    test_pass "Database connection established"
else
    test_fail "Database connection failed"
fi

# Test 7: Product count
PRODUCT_COUNT=$(php bin/console doctrine:query:sql "SELECT COUNT(*) as count FROM pim_catalog_product" --env=prod 2>&1 | grep -oP '\d+' | head -1)
if [ "$PRODUCT_COUNT" -gt 9000 ]; then
    test_pass "Products verified: $PRODUCT_COUNT"
else
    test_fail "Product count low: $PRODUCT_COUNT (expected >9000)"
fi

echo "" | tee -a "$REPORT_FILE"

echo "## 4. FILE SYSTEM TESTS" | tee -a "$REPORT_FILE"
echo "---" | tee -a "$REPORT_FILE"

# Test 8: Cache files
CACHE_COUNT=$(find var/cache/prod -type f 2>/dev/null | wc -l)
if [ "$CACHE_COUNT" -gt 5000 ]; then
    test_pass "Cache optimized: $CACHE_COUNT files"
else
    test_fail "Cache files low: $CACHE_COUNT (expected >5000)"
fi

# Test 9: Log file writable
if [ -w "var/logs/prod.log" ]; then
    test_pass "Log file writable"
else
    test_fail "Log file not writable"
fi

# Test 10: Media directory
MEDIA_SIZE=$(du -sh public/media 2>/dev/null | cut -f1)
if [ -d "public/media" ]; then
    test_pass "Media directory accessible ($MEDIA_SIZE)"
else
    test_fail "Media directory not found"
fi

echo "" | tee -a "$REPORT_FILE"

echo "## 5. SYMFONY TESTS" | tee -a "$REPORT_FILE"
echo "---" | tee -a "$REPORT_FILE"

# Test 11: Symfony console
SYMFONY_VERSION=$(php bin/console --version --env=prod 2>&1 | head -1)
if echo "$SYMFONY_VERSION" | grep -q "Symfony"; then
    test_pass "Symfony console: $SYMFONY_VERSION"
else
    test_fail "Symfony console issue"
fi

# Test 12: Akeneo commands
COMMAND_COUNT=$(php bin/console list --env=prod 2>&1 | grep -c "pim:" || echo "0")
if [ "$COMMAND_COUNT" -gt 20 ]; then
    test_pass "Akeneo commands available: $COMMAND_COUNT"
else
    test_fail "Akeneo commands low: $COMMAND_COUNT (expected >20)"
fi

# Test 13: Router test
ROUTER_TEST=$(php bin/console debug:router pim_user_security_login --env=prod 2>&1 | grep -c "/user/login" || echo "0")
if [ "$ROUTER_TEST" -gt 0 ]; then
    test_pass "Routing system operational"
else
    test_fail "Routing system issue"
fi

echo "" | tee -a "$REPORT_FILE"

echo "## 6. SECURITY TESTS" | tee -a "$REPORT_FILE"
echo "---" | tee -a "$REPORT_FILE"

# Test 14: Security .htaccess files
SECURITY_COUNT=$(ls -1 var/.htaccess vendor/.htaccess config/.htaccess src/.htaccess 2>/dev/null | wc -l)
if [ "$SECURITY_COUNT" -eq 4 ]; then
    test_pass "Security .htaccess files: $SECURITY_COUNT/4"
else
    test_fail "Security .htaccess missing: $SECURITY_COUNT/4"
fi

# Test 15: File permissions
PERMISSION_ISSUES=0
for DIR in var/cache var/logs var/sessions public/media; do
    if [ ! -w "$DIR" ]; then
        PERMISSION_ISSUES=$((PERMISSION_ISSUES + 1))
    fi
done
if [ "$PERMISSION_ISSUES" -eq 0 ]; then
    test_pass "All critical directories writable"
else
    test_fail "$PERMISSION_ISSUES directories not writable"
fi

echo "" | tee -a "$REPORT_FILE"

echo "## 7. OPTIMIZATION VERIFICATION" | tee -a "$REPORT_FILE"
echo "---" | tee -a "$REPORT_FILE"

# Test 16: robots.txt
ROBOTS_SIZE=$(stat -c%s public/robots.txt 2>/dev/null || echo "0")
if [ "$ROBOTS_SIZE" -gt 500 ]; then
    test_pass "robots.txt optimized: $ROBOTS_SIZE bytes"
else
    test_fail "robots.txt basic: $ROBOTS_SIZE bytes"
fi

# Test 17: index.php ownership
INDEX_OWNER=$(stat -c'%U:%G' public/index.php)
if [ "$INDEX_OWNER" = "pim:pim" ]; then
    test_pass "index.php ownership: $INDEX_OWNER"
else
    test_fail "index.php ownership incorrect: $INDEX_OWNER"
fi

# Test 18: PHP handler
PHP_HANDLER=$(grep "AddHandler.*php" .htaccess 2>/dev/null | grep "ea-php" | tail -1)
if echo "$PHP_HANDLER" | grep -q "ea-php83"; then
    test_pass "PHP handler updated: ea-php83"
else
    test_fail "PHP handler not updated: $PHP_HANDLER"
fi

echo "" | tee -a "$REPORT_FILE"

echo "## 8. LOG ANALYSIS" | tee -a "$REPORT_FILE"
echo "---" | tee -a "$REPORT_FILE"

# Test 19: Recent errors
RECENT_ERRORS=$(tail -100 var/logs/prod.log 2>/dev/null | grep -c "CRITICAL\|ERROR" || echo "0")
if [ "$RECENT_ERRORS" -lt 10 ]; then
    test_pass "Recent errors acceptable: $RECENT_ERRORS"
else
    test_fail "High error count: $RECENT_ERRORS"
fi

# Test 20: No new critical errors post-deployment
NEW_CRITICAL=$(tail -20 var/logs/prod.log 2>/dev/null | grep -c "CRITICAL" || echo "0")
if [ "$NEW_CRITICAL" -eq 0 ]; then
    test_pass "No new critical errors post-deployment"
else
    echo "⚠ WARNING: $NEW_CRITICAL new critical errors detected" | tee -a "$REPORT_FILE"
    test_fail "New critical errors: $NEW_CRITICAL"
fi

echo "" | tee -a "$REPORT_FILE"

# SUMMARY
TOTAL=$((PASSED + FAILED))
SUCCESS_RATE=$((PASSED * 100 / TOTAL))

echo "## TEST SUMMARY" | tee -a "$REPORT_FILE"
echo "---" | tee -a "$REPORT_FILE"
echo "Total Tests: $TOTAL" | tee -a "$REPORT_FILE"
echo "Passed: $PASSED" | tee -a "$REPORT_FILE"
echo "Failed: $FAILED" | tee -a "$REPORT_FILE"
echo "Success Rate: $SUCCESS_RATE%" | tee -a "$REPORT_FILE"
echo "" | tee -a "$REPORT_FILE"

if [ "$SUCCESS_RATE" -ge 95 ]; then
    echo "## STATUS: ✅ EXCELLENT (${SUCCESS_RATE}%)" | tee -a "$REPORT_FILE"
elif [ "$SUCCESS_RATE" -ge 85 ]; then
    echo "## STATUS: ✓ GOOD (${SUCCESS_RATE}%)" | tee -a "$REPORT_FILE"
elif [ "$SUCCESS_RATE" -ge 75 ]; then
    echo "## STATUS: ⚠ ACCEPTABLE (${SUCCESS_RATE}%)" | tee -a "$REPORT_FILE"
else
    echo "## STATUS: ✗ NEEDS ATTENTION (${SUCCESS_RATE}%)" | tee -a "$REPORT_FILE"
fi

echo "" | tee -a "$REPORT_FILE"
echo "## PRODUCTION STATUS" | tee -a "$REPORT_FILE"
echo "---" | tee -a "$REPORT_FILE"
echo "🌐 Website: https://pim.technostationery.com/user/login" | tee -a "$REPORT_FILE"
echo "📊 Products: $PRODUCT_COUNT" | tee -a "$REPORT_FILE"
echo "⏱️ Response Time: ${RESPONSE_TIME}ms" | tee -a "$REPORT_FILE"
echo "💾 Cache Files: $CACHE_COUNT" | tee -a "$REPORT_FILE"
echo "🔒 Security: $SECURITY_COUNT/4 protections" | tee -a "$REPORT_FILE"
echo "" | tee -a "$REPORT_FILE"
echo "Testing completed: $(date)" | tee -a "$REPORT_FILE"
echo "Report saved: $REPORT_FILE" | tee -a "$REPORT_FILE"
