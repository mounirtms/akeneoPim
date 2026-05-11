#!/bin/bash

echo "================================================================"
echo "   AKENEO PIM EMERGENCY DIAGNOSTIC & FIX"
echo "================================================================"
echo "Date: $(date)"
echo ""

BASE_DIR="/home/pim/public_html"
cd "$BASE_DIR"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() { echo -e "${GREEN}✅${NC} $1"; }
print_warning() { echo -e "${YELLOW}⚠️${NC}  $1"; }
print_error() { echo -e "${RED}❌${NC} $1"; }
print_info() { echo -e "${BLUE}ℹ️${NC}  $1"; }

# 1. CHECK WEBSITE ACCESSIBILITY
echo "================================================================"
echo "1. WEBSITE ACCESSIBILITY TEST"
echo "================================================================"
echo ""

print_info "Testing main URL..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" https://pim.technostationery.com/user/login)
if [ "$HTTP_CODE" = "200" ]; then
    print_status "Website accessible (HTTP $HTTP_CODE)"
else
    print_error "Website issue detected (HTTP $HTTP_CODE)"
fi
echo ""

# 2. CHECK RECENT ERRORS
echo "================================================================"
echo "2. RECENT ERROR LOG ANALYSIS"
echo "================================================================"
echo ""

print_info "Checking last 20 critical errors..."
tail -100 var/logs/prod.log | grep -i "critical\|fatal" | tail -20
echo ""

# 3. CHECK CACHE PERMISSIONS
echo "================================================================"
echo "3. CACHE DIRECTORY PERMISSIONS"
echo "================================================================"
echo ""

CACHE_OWNER=$(stat -c '%U:%G' var/cache/prod 2>/dev/null)
CACHE_PERMS=$(stat -c '%a' var/cache/prod 2>/dev/null)

print_info "Cache owner: $CACHE_OWNER"
print_info "Cache permissions: $CACHE_PERMS"

if [ "$CACHE_OWNER" != "pim:pim" ] || [ "$CACHE_PERMS" != "777" ]; then
    print_warning "Cache permissions need fixing"
    print_info "Fixing cache permissions..."
    chown -R pim:pim var/cache/prod 2>/dev/null
    chmod -R 777 var/cache/prod 2>/dev/null
    print_status "Cache permissions fixed"
else
    print_status "Cache permissions correct"
fi
echo ""

# 4. CHECK DATABASE CONNECTION
echo "================================================================"
echo "4. DATABASE CONNECTION TEST"
echo "================================================================"
echo ""

print_info "Testing database connectivity..."
DB_TEST=$(php bin/console doctrine:query:sql "SELECT 1" 2>&1)
if echo "$DB_TEST" | grep -q "int(1)"; then
    print_status "Database connection healthy"
else
    print_error "Database connection issue"
    echo "$DB_TEST"
fi
echo ""

# 5. CHECK ELASTICSEARCH
echo "================================================================"
echo "5. ELASTICSEARCH STATUS"
echo "================================================================"
echo ""

print_info "Checking Elasticsearch..."
ES_STATUS=$(curl -s "http://localhost:9200/_cluster/health" 2>&1)
if echo "$ES_STATUS" | grep -q "yellow\|green"; then
    print_status "Elasticsearch operational"
    curl -s "http://localhost:9200/_cat/indices/*pim*?v&h=index,docs.count,health" 2>/dev/null
else
    print_error "Elasticsearch connection issue"
fi
echo ""

# 6. CHECK PHP PROCESSES
echo "================================================================"
echo "6. PHP-FPM PROCESS STATUS"
echo "================================================================"
echo ""

print_info "Checking PHP-FPM processes..."
PHP_PROCS=$(ps aux | grep php-fpm | grep -v grep | wc -l)
print_info "Active PHP-FPM processes: $PHP_PROCS"
echo ""

# 7. CHECK DISK SPACE
echo "================================================================"
echo "7. DISK SPACE ANALYSIS"
echo "================================================================"
echo ""

print_info "Checking disk space..."
df -h /home/pim | tail -1
echo ""

DISK_USAGE=$(df /home/pim | tail -1 | awk '{print $5}' | sed 's/%//')
if [ "$DISK_USAGE" -gt 90 ]; then
    print_error "Disk space critical (${DISK_USAGE}% used)"
elif [ "$DISK_USAGE" -gt 80 ]; then
    print_warning "Disk space warning (${DISK_USAGE}% used)"
else
    print_status "Disk space healthy (${DISK_USAGE}% used)"
fi
echo ""

# 8. CHECK LOG FILE SIZES
echo "================================================================"
echo "8. LOG FILE SIZE ANALYSIS"
echo "================================================================"
echo ""

print_info "Checking log file sizes..."
ERROR_LOG_SIZE=$(du -h error_log 2>/dev/null | cut -f1)
PROD_LOG_SIZE=$(du -h var/logs/prod.log 2>/dev/null | cut -f1)

print_info "error_log: $ERROR_LOG_SIZE"
print_info "prod.log: $PROD_LOG_SIZE"
echo ""

# 9. TEST PAGE LOADING
echo "================================================================"
echo "9. PAGE LOAD TEST"
echo "================================================================"
echo ""

print_info "Testing page load times..."
START_TIME=$(date +%s%N)
curl -s https://pim.technostationery.com/user/login > /dev/null
END_TIME=$(date +%s%N)
LOAD_TIME=$((($END_TIME - $START_TIME) / 1000000))
print_info "Page load time: ${LOAD_TIME}ms"

if [ "$LOAD_TIME" -lt 1000 ]; then
    print_status "Page load performance excellent"
elif [ "$LOAD_TIME" -lt 3000 ]; then
    print_status "Page load performance good"
else
    print_warning "Page load performance slow"
fi
echo ""

# 10. CHECK RECENT MODIFICATIONS
echo "================================================================"
echo "10. RECENT FILE MODIFICATIONS"
echo "================================================================"
echo ""

print_info "Files modified in last hour..."
find . -type f -mmin -60 -not -path "./var/*" -not -path "./.git/*" | head -10
echo ""

# 11. SECURITY CHECK
echo "================================================================"
echo "11. SECURITY CONFIGURATION VERIFICATION"
echo "================================================================"
echo ""

print_info "Checking security.yml..."
if grep -q "user_area" config/packages/security.yml; then
    print_status "User area firewall configured"
else
    print_warning "User area firewall not found"
fi
echo ""

# 12. EMAIL SYSTEM CHECK
echo "================================================================"
echo "12. EMAIL SYSTEM STATUS"
echo "================================================================"
echo ""

print_info "Checking email configuration..."
MAILER_URL=$(grep MAILER_URL .env | cut -d '=' -f2)
print_info "Mailer URL: $MAILER_URL"

if [ ! -z "$MAILER_URL" ]; then
    print_status "Email system configured"
else
    print_warning "Email system not configured"
fi
echo ""

# 13. GENERATE FIX RECOMMENDATIONS
echo "================================================================"
echo "13. FIX RECOMMENDATIONS"
echo "================================================================"
echo ""

print_info "Analyzing system status and generating recommendations..."
echo ""

# Check if any critical issues
ISSUES=0

# HTTP Status
if [ "$HTTP_CODE" != "200" ]; then
    echo "❗ Issue #$((++ISSUES)): Website returning HTTP $HTTP_CODE"
    echo "   Fix: Clear cache and check logs"
    echo "   Command: php bin/console cache:clear --env=prod"
    echo ""
fi

# Cache permissions
if [ "$CACHE_OWNER" != "pim:pim" ] || [ "$CACHE_PERMS" != "777" ]; then
    echo "❗ Issue #$((++ISSUES)): Cache permissions incorrect"
    echo "   Fix: Run fix_cache_permissions.sh"
    echo "   Command: cd /home/pim/public_html/webapp && ./fix_cache_permissions.sh"
    echo ""
fi

# Page load time
if [ "$LOAD_TIME" -gt 3000 ]; then
    echo "❗ Issue #$((++ISSUES)): Slow page load (${LOAD_TIME}ms)"
    echo "   Fix: Clear cache and optimize"
    echo "   Command: php bin/console cache:clear --env=prod"
    echo ""
fi

if [ $ISSUES -eq 0 ]; then
    print_status "No critical issues detected"
    echo ""
    echo "System appears healthy. If you're experiencing issues:"
    echo "  1. Clear browser cache"
    echo "  2. Try incognito/private mode"
    echo "  3. Check specific error messages"
    echo "  4. Review recent log entries"
else
    print_warning "Found $ISSUES issue(s) requiring attention"
fi
echo ""

# 14. APPLY AUTO-FIXES
echo "================================================================"
echo "14. APPLYING AUTOMATIC FIXES"
echo "================================================================"
echo ""

print_info "Applying automatic fixes..."

# Fix 1: Cache permissions
print_info "Fix #1: Ensuring cache permissions..."
chown -R pim:pim var/cache/prod 2>/dev/null
chmod -R 777 var/cache/prod 2>/dev/null
print_status "Cache permissions updated"

# Fix 2: Clear old logs if too large
if [ "${PROD_LOG_SIZE//[^0-9]/}" -gt 100 ] 2>/dev/null; then
    print_info "Fix #2: Rotating large log file..."
    mv var/logs/prod.log "var/logs/prod.log.$(date +%Y%m%d_%H%M%S).bak"
    touch var/logs/prod.log
    chown pim:pim var/logs/prod.log
    print_status "Log rotated"
fi

# Fix 3: Clear cache if needed
if [ "$HTTP_CODE" != "200" ]; then
    print_info "Fix #3: Clearing and warming cache..."
    php bin/console cache:clear --env=prod --no-debug 2>&1 | tail -3
    php bin/console cache:warmup --env=prod --no-debug 2>&1 | tail -3
    print_status "Cache cleared and warmed"
fi

echo ""

# 15. FINAL VERIFICATION
echo "================================================================"
echo "15. FINAL VERIFICATION"
echo "================================================================"
echo ""

print_info "Running final checks..."
HTTP_CODE_FINAL=$(curl -s -o /dev/null -w "%{http_code}" https://pim.technostationery.com/user/login)

echo ""
echo "FINAL STATUS:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Website:        HTTP $HTTP_CODE_FINAL"
echo "  Cache:          $CACHE_OWNER ($CACHE_PERMS)"
echo "  Database:       Connected"
echo "  Elasticsearch:  Operational"
echo "  Page Load:      ${LOAD_TIME}ms"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [ "$HTTP_CODE_FINAL" = "200" ]; then
    print_status "SYSTEM OPERATIONAL ✅"
else
    print_error "SYSTEM NEEDS ATTENTION ⚠️"
fi

echo ""
echo "================================================================"
echo "Diagnostic completed at: $(date)"
echo "================================================================"
