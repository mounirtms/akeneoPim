#!/bin/bash

################################################################################
# Comprehensive PIM System Monitoring and Auto-Fix Script
# Monitors health, auto-fixes common issues, sends email alerts
# Run via cron: */15 * * * * /home/pim/public_html/webapp/monitor_and_fix.sh
################################################################################

set -e

# Configuration
PIM_ROOT="/home/pim/public_html"
WEBAPP_DIR="${PIM_ROOT}/webapp"
LOG_DIR="${PIM_ROOT}/var/logs"
ALERT_EMAIL="webmaster@techno-dz.com"
SITE_URL="https://pim.technostationery.com"

# Thresholds
MAX_LOG_SIZE_MB=100
MAX_CACHE_SIZE_MB=500
MIN_DISK_SPACE_GB=50
MAX_ERROR_COUNT=10

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Initialize
ISSUES_FOUND=0
FIXES_APPLIED=0
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
REPORT="/tmp/pim_monitor_report_$(date +%Y%m%d_%H%M%S).txt"

################################################################################
# Functions
################################################################################

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$REPORT"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$REPORT"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$REPORT"
    ((ISSUES_FOUND++))
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$REPORT"
    ((ISSUES_FOUND++))
}

send_alert_email() {
    local subject="$1"
    local message="$2"
    
    echo "$message" | mail -s "$subject" "$ALERT_EMAIL" 2>/dev/null || {
        log_warning "Could not send email alert"
    }
}

auto_fix() {
    local issue="$1"
    local fix_command="$2"
    
    log_info "Auto-fixing: $issue"
    if eval "$fix_command"; then
        log_success "Fixed: $issue"
        ((FIXES_APPLIED++))
        return 0
    else
        log_error "Failed to fix: $issue"
        return 1
    fi
}

################################################################################
# Monitoring Checks
################################################################################

echo "═══════════════════════════════════════════════════════════" | tee "$REPORT"
echo "PIM System Monitor - $TIMESTAMP" | tee -a "$REPORT"
echo "═══════════════════════════════════════════════════════════" | tee -a "$REPORT"
echo "" | tee -a "$REPORT"

# 1. Site Availability Check
log_info "Checking site availability..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "${SITE_URL}/user/login" 2>&1)

if [ "$HTTP_CODE" = "200" ]; then
    log_success "Site is ONLINE (HTTP 200)"
elif [ "$HTTP_CODE" = "500" ]; then
    log_error "Site is returning HTTP 500"
    auto_fix "Cache permissions" "cd ${WEBAPP_DIR} && ./fix_cache_permissions.sh >/dev/null 2>&1"
    
    # Recheck after fix
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "${SITE_URL}/user/login" 2>&1)
    if [ "$HTTP_CODE" = "200" ]; then
        log_success "Site recovered after cache fix"
    fi
else
    log_warning "Site returned HTTP $HTTP_CODE"
fi

# 2. Database Connection Check
log_info "Checking database connection..."
DB_CHECK=$(cd "$PIM_ROOT" && php bin/console doctrine:query:sql "SELECT 1 as test" --env=prod 2>&1 | grep -c "test" || echo "0")

if [ "$DB_CHECK" -gt 0 ]; then
    log_success "Database connection is healthy"
else
    log_error "Database connection failed"
fi

# 3. Elasticsearch Health Check
log_info "Checking Elasticsearch..."
ES_HEALTH=$(curl -s http://localhost:9200/_cluster/health 2>&1 | grep -o '"status":"[^"]*"' | cut -d'"' -f4)

if [ "$ES_HEALTH" = "green" ] || [ "$ES_HEALTH" = "yellow" ]; then
    log_success "Elasticsearch status: $ES_HEALTH"
    
    # Check product count
    ES_COUNT=$(curl -s "http://localhost:9200/akeneo_pim_product_and_product_model*/_count" 2>&1 | grep -o '"count":[0-9]*' | cut -d':' -f2)
    log_info "Elasticsearch indexed items: $ES_COUNT"
else
    log_error "Elasticsearch status: $ES_HEALTH"
fi

# 4. Cache Directory Permissions
log_info "Checking cache permissions..."
CACHE_OWNER=$(stat -c '%U:%G' "${PIM_ROOT}/var/cache" 2>/dev/null || echo "unknown")
CACHE_PERMS=$(stat -c '%a' "${PIM_ROOT}/var/cache" 2>/dev/null || echo "000")

if [ "$CACHE_OWNER" = "pim:pim" ] && [ "$CACHE_PERMS" = "777" ]; then
    log_success "Cache permissions correct (pim:pim, 777)"
else
    log_warning "Cache permissions incorrect: $CACHE_OWNER, $CACHE_PERMS"
    auto_fix "Cache permissions" "cd ${PIM_ROOT} && chown -R pim:pim var/cache var/logs && chmod -R 777 var/cache var/logs"
fi

# 5. Log File Size Check
log_info "Checking log file sizes..."
PROD_LOG_SIZE=$(du -m "${LOG_DIR}/prod.log" 2>/dev/null | cut -f1)
ERROR_LOG_SIZE=$(du -m "${PIM_ROOT}/error_log" 2>/dev/null | cut -f1)

if [ "$PROD_LOG_SIZE" -gt "$MAX_LOG_SIZE_MB" ]; then
    log_warning "prod.log is large (${PROD_LOG_SIZE}MB)"
    auto_fix "Large prod.log" "cd ${PIM_ROOT} && > var/logs/prod.log"
fi

if [ "$ERROR_LOG_SIZE" -gt "$MAX_LOG_SIZE_MB" ]; then
    log_warning "error_log is large (${ERROR_LOG_SIZE}MB)"
    auto_fix "Large error_log" "cd ${PIM_ROOT} && > error_log"
fi

# 6. Disk Space Check
log_info "Checking disk space..."
DISK_FREE_GB=$(df -BG "${PIM_ROOT}" | tail -1 | awk '{print $4}' | sed 's/G//')

if [ "$DISK_FREE_GB" -lt "$MIN_DISK_SPACE_GB" ]; then
    log_warning "Low disk space: ${DISK_FREE_GB}GB free"
else
    log_success "Disk space healthy: ${DISK_FREE_GB}GB free"
fi

# 7. Recent Error Check
log_info "Checking for recent errors..."
if [ -f "${LOG_DIR}/prod.log" ]; then
    RECENT_ERRORS=$(grep -c "CRITICAL\|ERROR" "${LOG_DIR}/prod.log" 2>/dev/null || echo "0")
    if [ "$RECENT_ERRORS" -gt "$MAX_ERROR_COUNT" ]; then
        log_warning "Found $RECENT_ERRORS recent errors in logs"
    else
        log_success "Error count acceptable: $RECENT_ERRORS"
    fi
fi

# 8. PHP OPcache Check
log_info "Checking PHP OPcache..."
if php -m | grep -q "Zend OPcache"; then
    log_success "OPcache is installed"
else
    log_warning "OPcache is not installed (performance impact)"
fi

# 9. Email System Check
log_info "Checking email configuration..."
MAILER_URL=$(grep "^MAILER_URL=" "${PIM_ROOT}/.env" 2>/dev/null | cut -d'=' -f2-)
if [[ "$MAILER_URL" == *"sendmail"* ]]; then
    log_success "Email system configured (sendmail)"
elif [[ "$MAILER_URL" == *"null"* ]]; then
    log_warning "Email system using null transport (emails won't send)"
else
    log_success "Email system configured"
fi

# 10. Cron Job Check
log_info "Checking cron jobs..."
CRON_COUNT=$(crontab -u pim -l 2>/dev/null | grep -cv "^#" || echo "0")
log_info "Active cron jobs: $CRON_COUNT"

################################################################################
# Summary
################################################################################

echo "" | tee -a "$REPORT"
echo "═══════════════════════════════════════════════════════════" | tee -a "$REPORT"
echo "SUMMARY" | tee -a "$REPORT"
echo "═══════════════════════════════════════════════════════════" | tee -a "$REPORT"
echo "Issues Found: $ISSUES_FOUND" | tee -a "$REPORT"
echo "Fixes Applied: $FIXES_APPLIED" | tee -a "$REPORT"
echo "Timestamp: $TIMESTAMP" | tee -a "$REPORT"
echo "═══════════════════════════════════════════════════════════" | tee -a "$REPORT"

# Send email if critical issues found
if [ "$ISSUES_FOUND" -gt 5 ]; then
    ALERT_MESSAGE=$(cat "$REPORT")
    send_alert_email "⚠️ PIM Monitor Alert - $ISSUES_FOUND Issues Found" "$ALERT_MESSAGE"
fi

# Cleanup old reports (keep last 7 days)
find /tmp -name "pim_monitor_report_*.txt" -mtime +7 -delete 2>/dev/null || true

# Exit with appropriate code
if [ "$ISSUES_FOUND" -eq 0 ]; then
    echo ""
    log_success "All systems operational! ✅"
    exit 0
elif [ "$FIXES_APPLIED" -gt 0 ]; then
    echo ""
    log_success "Issues found and auto-fixed ✅"
    exit 0
else
    echo ""
    log_warning "Issues found requiring manual attention ⚠️"
    exit 1
fi
