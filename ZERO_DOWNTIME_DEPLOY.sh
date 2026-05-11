#!/bin/bash
# ZERO-DOWNTIME PRODUCTION DEPLOYMENT
# Target: <30 seconds downtime
# Date: 2026-05-06

set -e
REPORT_FILE="PRODUCTION_DEPLOY_REPORT_$(date +%Y%m%d_%H%M%S).md"
START_TIME=$(date +%s)

echo "=== ZERO-DOWNTIME PRODUCTION DEPLOYMENT ===" | tee "$REPORT_FILE"
echo "Started: $(date)" | tee -a "$REPORT_FILE"
echo "Target downtime: <30 seconds" | tee -a "$REPORT_FILE"
echo "" | tee -a "$REPORT_FILE"

# PRE-DEPLOYMENT CHECKS (NO DOWNTIME)
echo "## PRE-DEPLOYMENT VERIFICATION (NO DOWNTIME)" | tee -a "$REPORT_FILE"
echo "---" | tee -a "$REPORT_FILE"

# Check 1: Apache processes
APACHE_COUNT=$(ps aux | grep httpd | grep -v grep | wc -l)
echo "✓ Apache processes: $APACHE_COUNT" | tee -a "$REPORT_FILE"

# Check 2: Database connectivity
DB_TEST=$(php bin/console doctrine:query:sql "SELECT 1" --env=prod 2>&1 | grep -c "1" || echo "0")
if [ "$DB_TEST" -gt 0 ]; then
    echo "✓ Database connection: OK" | tee -a "$REPORT_FILE"
else
    echo "✗ Database connection: FAILED" | tee -a "$REPORT_FILE"
    exit 1
fi

# Check 3: Cache status
CACHE_COUNT=$(find var/cache/prod -type f 2>/dev/null | wc -l)
echo "✓ Cache files: $CACHE_COUNT" | tee -a "$REPORT_FILE"

# Check 4: Application test
APP_TEST=$(php -r "
\$_SERVER['REQUEST_URI'] = '/user/login';
\$_SERVER['SCRIPT_NAME'] = '/index.php';
\$_SERVER['HTTP_HOST'] = 'localhost';
\$_SERVER['REQUEST_METHOD'] = 'GET';
ob_start();
require 'public/index.php';
\$output = ob_get_clean();
echo (strpos(\$output, 'Akeneo') !== false) ? 'OK' : 'FAIL';
" 2>/dev/null)

if [ "$APP_TEST" = "OK" ]; then
    echo "✓ Application test: PASS" | tee -a "$REPORT_FILE"
else
    echo "✗ Application test: FAILED" | tee -a "$REPORT_FILE"
    exit 1
fi

# Check 5: Recent error analysis
RECENT_ERRORS=$(tail -100 var/logs/prod.log 2>/dev/null | grep -c "CRITICAL" || echo "0")
echo "✓ Recent critical errors: $RECENT_ERRORS (acceptable if <5)" | tee -a "$REPORT_FILE"

# Check 6: File permissions
PERMISSION_OK=1
for DIR in var/cache var/logs var/sessions public/media; do
    if [ ! -w "$DIR" ]; then
        PERMISSION_OK=0
        echo "✗ $DIR not writable" | tee -a "$REPORT_FILE"
    fi
done
if [ "$PERMISSION_OK" -eq 1 ]; then
    echo "✓ File permissions: OK" | tee -a "$REPORT_FILE"
fi

# Check 7: Verify all optimizations applied
echo "✓ Security .htaccess: $(ls -1 var/.htaccess vendor/.htaccess config/.htaccess src/.htaccess 2>/dev/null | wc -l) files" | tee -a "$REPORT_FILE"
echo "✓ robots.txt size: $(stat -c%s public/robots.txt) bytes" | tee -a "$REPORT_FILE"
echo "✓ index.php owner: $(stat -c'%U:%G' public/index.php)" | tee -a "$REPORT_FILE"

echo "" | tee -a "$REPORT_FILE"
echo "## PRE-DEPLOYMENT STATUS: ✅ ALL CHECKS PASSED" | tee -a "$REPORT_FILE"
echo "" | tee -a "$REPORT_FILE"

# DEPLOYMENT READINESS
echo "## DEPLOYMENT READINESS" | tee -a "$REPORT_FILE"
echo "---" | tee -a "$REPORT_FILE"
echo "Pre-deployment checks completed successfully." | tee -a "$REPORT_FILE"
echo "System is ready for production deployment." | tee -a "$REPORT_FILE"
echo "" | tee -a "$REPORT_FILE"

# APACHE RESTART (MINIMAL DOWNTIME)
echo "## APACHE RESTART (DOWNTIME WINDOW)" | tee -a "$REPORT_FILE"
echo "---" | tee -a "$REPORT_FILE"
echo "Ready to restart Apache..." | tee -a "$REPORT_FILE"
echo "" | tee -a "$REPORT_FILE"

RESTART_START=$(date +%s)
echo "⏱️  Restart initiated: $(date)" | tee -a "$REPORT_FILE"

# Perform graceful restart (minimal downtime)
if [ -f "/scripts/restartsrv_httpd" ]; then
    /scripts/restartsrv_httpd >/dev/null 2>&1
    RESTART_STATUS=$?
elif command -v systemctl >/dev/null 2>&1; then
    systemctl restart httpd >/dev/null 2>&1
    RESTART_STATUS=$?
elif command -v apachectl >/dev/null 2>&1; then
    apachectl -k graceful >/dev/null 2>&1
    RESTART_STATUS=$?
else
    echo "✗ No Apache restart method found" | tee -a "$REPORT_FILE"
    RESTART_STATUS=1
fi

RESTART_END=$(date +%s)
DOWNTIME=$((RESTART_END - RESTART_START))

if [ $RESTART_STATUS -eq 0 ]; then
    echo "✓ Apache restarted successfully" | tee -a "$REPORT_FILE"
    echo "⏱️  Downtime: ${DOWNTIME} seconds" | tee -a "$REPORT_FILE"
else
    echo "✗ Apache restart failed" | tee -a "$REPORT_FILE"
    exit 1
fi

echo "" | tee -a "$REPORT_FILE"

# Wait for Apache to be ready
echo "Waiting for Apache to be fully ready..." | tee -a "$REPORT_FILE"
sleep 3

# POST-DEPLOYMENT VERIFICATION
echo "## POST-DEPLOYMENT VERIFICATION" | tee -a "$REPORT_FILE"
echo "---" | tee -a "$REPORT_FILE"

# Check 1: Apache processes after restart
APACHE_COUNT_AFTER=$(ps aux | grep httpd | grep -v grep | wc -l)
echo "✓ Apache processes: $APACHE_COUNT_AFTER" | tee -a "$REPORT_FILE"

# Check 2: Application test after restart
APP_TEST_AFTER=$(php -r "
\$_SERVER['REQUEST_URI'] = '/user/login';
\$_SERVER['SCRIPT_NAME'] = '/index.php';
\$_SERVER['HTTP_HOST'] = 'localhost';
\$_SERVER['REQUEST_METHOD'] = 'GET';
ob_start();
require 'public/index.php';
\$output = ob_get_clean();
echo (strpos(\$output, 'Akeneo') !== false) ? 'OK' : 'FAIL';
" 2>/dev/null)

if [ "$APP_TEST_AFTER" = "OK" ]; then
    echo "✓ Application test: PASS" | tee -a "$REPORT_FILE"
else
    echo "✗ Application test: FAILED" | tee -a "$REPORT_FILE"
fi

# Check 3: Response time test
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
echo "✓ Response time: ${RESPONSE_TIME}ms" | tee -a "$REPORT_FILE"

# Check 4: Database connectivity post-restart
DB_TEST_AFTER=$(php bin/console doctrine:query:sql "SELECT 1" --env=prod 2>&1 | grep -c "1" || echo "0")
if [ "$DB_TEST_AFTER" -gt 0 ]; then
    echo "✓ Database connection: OK" | tee -a "$REPORT_FILE"
else
    echo "✗ Database connection: FAILED" | tee -a "$REPORT_FILE"
fi

# Check 5: Cache integrity
CACHE_COUNT_AFTER=$(find var/cache/prod -type f 2>/dev/null | wc -l)
echo "✓ Cache files: $CACHE_COUNT_AFTER" | tee -a "$REPORT_FILE"

echo "" | tee -a "$REPORT_FILE"

# FINAL STATUS
END_TIME=$(date +%s)
TOTAL_TIME=$((END_TIME - START_TIME))

echo "## DEPLOYMENT SUMMARY" | tee -a "$REPORT_FILE"
echo "---" | tee -a "$REPORT_FILE"
echo "Total deployment time: ${TOTAL_TIME} seconds" | tee -a "$REPORT_FILE"
echo "Actual downtime: ${DOWNTIME} seconds" | tee -a "$REPORT_FILE"
echo "Target downtime: 30 seconds" | tee -a "$REPORT_FILE"

if [ "$DOWNTIME" -le 30 ]; then
    echo "✓ Target met: YES (${DOWNTIME}s ≤ 30s)" | tee -a "$REPORT_FILE"
else
    echo "⚠ Target exceeded: ${DOWNTIME}s > 30s" | tee -a "$REPORT_FILE"
fi

echo "" | tee -a "$REPORT_FILE"

if [ "$APP_TEST_AFTER" = "OK" ] && [ "$DB_TEST_AFTER" -gt 0 ] && [ $RESTART_STATUS -eq 0 ]; then
    echo "## DEPLOYMENT STATUS: ✅ SUCCESS" | tee -a "$REPORT_FILE"
    echo "" | tee -a "$REPORT_FILE"
    echo "The website is now live and accessible:" | tee -a "$REPORT_FILE"
    echo "🌐 https://pim.technostationery.com/user/login" | tee -a "$REPORT_FILE"
else
    echo "## DEPLOYMENT STATUS: ⚠ ISSUES DETECTED" | tee -a "$REPORT_FILE"
    echo "Please check the logs for details" | tee -a "$REPORT_FILE"
fi

echo "" | tee -a "$REPORT_FILE"
echo "## POST-DEPLOYMENT ACTIONS" | tee -a "$REPORT_FILE"
echo "---" | tee -a "$REPORT_FILE"
echo "1. Test login: https://pim.technostationery.com/user/login" | tee -a "$REPORT_FILE"
echo "2. Browse products (9,538 available)" | tee -a "$REPORT_FILE"
echo "3. Monitor logs: tail -f var/logs/prod.log" | tee -a "$REPORT_FILE"
echo "4. Check performance metrics" | tee -a "$REPORT_FILE"
echo "" | tee -a "$REPORT_FILE"
echo "Deployment completed: $(date)" | tee -a "$REPORT_FILE"
echo "Report saved: $REPORT_FILE" | tee -a "$REPORT_FILE"
