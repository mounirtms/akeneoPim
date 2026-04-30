#!/bin/bash
# Production Monitoring Script for Akeneo PIM
# Monitors system health, performance, and potential issues
# Run this script regularly (e.g., via cron every hour)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="/home/pim/public_html"
LOG_DIR="$BASE_DIR/var/logs"
REPORT_DIR="$SCRIPT_DIR/monitoring_reports"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
REPORT_FILE="$REPORT_DIR/health_report_$TIMESTAMP.txt"

# Create reports directory
mkdir -p "$REPORT_DIR"

# Color codes for terminal output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "=========================================" | tee "$REPORT_FILE"
echo "AKENEO PIM PRODUCTION MONITORING REPORT" | tee -a "$REPORT_FILE"
echo "Date: $(date '+%Y-%m-%d %H:%M:%S')" | tee -a "$REPORT_FILE"
echo "=========================================" | tee -a "$REPORT_FILE"
echo "" | tee -a "$REPORT_FILE"

# Track overall health
CRITICAL_ISSUES=0
WARNINGS=0
PASSED_CHECKS=0

# Function to log results
log_check() {
    local status=$1
    local message=$2
    
    if [ "$status" == "PASS" ]; then
        echo -e "${GREEN}✓${NC} $message" | tee -a "$REPORT_FILE"
        ((PASSED_CHECKS++))
    elif [ "$status" == "WARN" ]; then
        echo -e "${YELLOW}⚠${NC} $message" | tee -a "$REPORT_FILE"
        ((WARNINGS++))
    else
        echo -e "${RED}✗${NC} $message" | tee -a "$REPORT_FILE"
        ((CRITICAL_ISSUES++))
    fi
}

# 1. System Resources
echo "1. SYSTEM RESOURCES" | tee -a "$REPORT_FILE"
echo "-------------------" | tee -a "$REPORT_FILE"

# Disk space
DISK_USAGE=$(df -h /home/pim | awk 'NR==2 {print $5}' | sed 's/%//')
if [ "$DISK_USAGE" -lt 80 ]; then
    log_check "PASS" "Disk Usage: ${DISK_USAGE}% (Healthy)"
elif [ "$DISK_USAGE" -lt 90 ]; then
    log_check "WARN" "Disk Usage: ${DISK_USAGE}% (Getting Full)"
else
    log_check "FAIL" "Disk Usage: ${DISK_USAGE}% (Critical - Cleanup Needed)"
fi

# Memory usage
MEM_TOTAL=$(free -m | awk 'NR==2{print $2}')
MEM_USED=$(free -m | awk 'NR==2{print $3}')
MEM_PERCENT=$((MEM_USED * 100 / MEM_TOTAL))
if [ "$MEM_PERCENT" -lt 80 ]; then
    log_check "PASS" "Memory Usage: ${MEM_PERCENT}% (${MEM_USED}/${MEM_TOTAL} MB)"
else
    log_check "WARN" "Memory Usage: ${MEM_PERCENT}% (${MEM_USED}/${MEM_TOTAL} MB - High)"
fi

# Load average
LOAD_AVG=$(uptime | awk -F'load average:' '{print $2}' | cut -d',' -f1 | xargs)
log_check "PASS" "Load Average: $LOAD_AVG"

echo "" | tee -a "$REPORT_FILE"

# 2. Elasticsearch Health
echo "2. ELASTICSEARCH" | tee -a "$REPORT_FILE"
echo "----------------" | tee -a "$REPORT_FILE"

ES_HOST=${AKENEO_ELASTICSEARCH_HOST:-localhost}
ES_PORT=${AKENEO_ELASTICSEARCH_PORT:-9200}

ES_HEALTH=$(curl -s "http://$ES_HOST:$ES_PORT/_cluster/health" 2>/dev/null || echo '{"status":"unavailable"}')
ES_STATUS=$(echo "$ES_HEALTH" | grep -o '"status":"[^"]*"' | cut -d':' -f2 | tr -d '"')

if [ "$ES_STATUS" == "green" ]; then
    log_check "PASS" "Elasticsearch Status: GREEN (Optimal)"
elif [ "$ES_STATUS" == "yellow" ]; then
    log_check "WARN" "Elasticsearch Status: YELLOW (Acceptable)"
elif [ "$ES_STATUS" == "unavailable" ]; then
    log_check "FAIL" "Elasticsearch Status: UNAVAILABLE"
else
    log_check "FAIL" "Elasticsearch Status: RED (Critical)"
fi

# Check product index count
ES_COUNT=$(curl -s "http://$ES_HOST:$ES_PORT/akeneo_pim_product_and_product_model*/_count" 2>/dev/null | grep -o '"count":[0-9]*' | cut -d':' -f2)
if [ ! -z "$ES_COUNT" ] && [ "$ES_COUNT" -gt 9000 ]; then
    log_check "PASS" "Indexed Products: $ES_COUNT"
elif [ ! -z "$ES_COUNT" ]; then
    log_check "WARN" "Indexed Products: $ES_COUNT (Expected ~9,538)"
else
    log_check "FAIL" "Could not retrieve product count"
fi

echo "" | tee -a "$REPORT_FILE"

# 3. Application Logs
echo "3. APPLICATION LOGS" | tee -a "$REPORT_FILE"
echo "-------------------" | tee -a "$REPORT_FILE"

# Check for recent errors in production log
if [ -f "$LOG_DIR/prod.log" ]; then
    RECENT_ERRORS=$(tail -1000 "$LOG_DIR/prod.log" | grep -i "ERROR\|CRITICAL" | wc -l)
    if [ "$RECENT_ERRORS" -eq 0 ]; then
        log_check "PASS" "Production Log: No recent errors"
    elif [ "$RECENT_ERRORS" -lt 10 ]; then
        log_check "WARN" "Production Log: $RECENT_ERRORS errors in last 1000 lines"
    else
        log_check "FAIL" "Production Log: $RECENT_ERRORS errors in last 1000 lines (High)"
    fi
    
    # Log size
    LOG_SIZE=$(du -h "$LOG_DIR/prod.log" | cut -f1)
    log_check "PASS" "Production Log Size: $LOG_SIZE"
else
    log_check "WARN" "Production log not found"
fi

echo "" | tee -a "$REPORT_FILE"

# 4. Cache Status
echo "4. CACHE STATUS" | tee -a "$REPORT_FILE"
echo "---------------" | tee -a "$REPORT_FILE"

CACHE_SIZE=$(du -sh "$BASE_DIR/var/cache/prod" 2>/dev/null | cut -f1)
if [ ! -z "$CACHE_SIZE" ]; then
    log_check "PASS" "Production Cache Size: $CACHE_SIZE"
else
    log_check "WARN" "Could not determine cache size"
fi

# Check if cache is fresh (modified in last 24 hours)
CACHE_AGE=$(find "$BASE_DIR/var/cache/prod" -type f -mmin -1440 2>/dev/null | wc -l)
if [ "$CACHE_AGE" -gt 0 ]; then
    log_check "PASS" "Cache freshness: Recently updated"
else
    log_check "WARN" "Cache may be stale (no files modified in 24h)"
fi

echo "" | tee -a "$REPORT_FILE"

# 5. Web Server Status
echo "5. WEB SERVER" | tee -a "$REPORT_FILE"
echo "-------------" | tee -a "$REPORT_FILE"

# Check if site is accessible
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" https://pim.technostationery.com/ 2>/dev/null || echo "000")
if [ "$HTTP_CODE" == "200" ]; then
    log_check "PASS" "Website Status: HTTP $HTTP_CODE (OK)"
elif [ "$HTTP_CODE" == "000" ]; then
    log_check "FAIL" "Website Status: Unreachable"
else
    log_check "WARN" "Website Status: HTTP $HTTP_CODE"
fi

# Check response time
RESPONSE_TIME=$(curl -s -o /dev/null -w "%{time_total}" https://pim.technostationery.com/ 2>/dev/null || echo "0")
RESPONSE_MS=$(echo "$RESPONSE_TIME * 1000" | bc | cut -d'.' -f1)
if [ "$RESPONSE_MS" -lt 3000 ]; then
    log_check "PASS" "Response Time: ${RESPONSE_MS}ms (Fast)"
elif [ "$RESPONSE_MS" -lt 5000 ]; then
    log_check "WARN" "Response Time: ${RESPONSE_MS}ms (Acceptable)"
else
    log_check "FAIL" "Response Time: ${RESPONSE_MS}ms (Slow)"
fi

echo "" | tee -a "$REPORT_FILE"

# 6. Database Status
echo "6. DATABASE" | tee -a "$REPORT_FILE"
echo "-----------" | tee -a "$REPORT_FILE"

# Try to connect via Symfony console
cd "$BASE_DIR"
DB_CHECK=$(php bin/console doctrine:query:sql "SELECT 1" --env=prod 2>&1)
if echo "$DB_CHECK" | grep -q "1"; then
    log_check "PASS" "Database Connection: OK"
else
    log_check "FAIL" "Database Connection: Failed"
fi

echo "" | tee -a "$REPORT_FILE"

# 7. Critical Files
echo "7. CRITICAL FILES" | tee -a "$REPORT_FILE"
echo "-----------------" | tee -a "$REPORT_FILE"

CRITICAL_FILES=(
    "$BASE_DIR/public/js/require-paths.js"
    "$BASE_DIR/public/dist/vendor.min.js"
    "$BASE_DIR/public/dist/main.min.js"
    "$BASE_DIR/public/dist/jquery.min.js"
    "$BASE_DIR/public/dist/process-polyfill.js"
)

for file in "${CRITICAL_FILES[@]}"; do
    if [ -f "$file" ]; then
        log_check "PASS" "$(basename $file): Present"
    else
        log_check "FAIL" "$(basename $file): Missing"
    fi
done

echo "" | tee -a "$REPORT_FILE"

# 8. Summary
echo "=========================================" | tee -a "$REPORT_FILE"
echo "SUMMARY" | tee -a "$REPORT_FILE"
echo "=========================================" | tee -a "$REPORT_FILE"
echo "Passed Checks: $PASSED_CHECKS" | tee -a "$REPORT_FILE"
echo "Warnings: $WARNINGS" | tee -a "$REPORT_FILE"
echo "Critical Issues: $CRITICAL_ISSUES" | tee -a "$REPORT_FILE"
echo "" | tee -a "$REPORT_FILE"

# Overall health score
TOTAL_CHECKS=$((PASSED_CHECKS + WARNINGS + CRITICAL_ISSUES))
if [ "$TOTAL_CHECKS" -gt 0 ]; then
    HEALTH_SCORE=$((PASSED_CHECKS * 100 / TOTAL_CHECKS))
else
    HEALTH_SCORE=0
fi

if [ "$CRITICAL_ISSUES" -eq 0 ] && [ "$WARNINGS" -eq 0 ]; then
    echo -e "${GREEN}Overall Status: EXCELLENT (${HEALTH_SCORE}%)${NC}" | tee -a "$REPORT_FILE"
elif [ "$CRITICAL_ISSUES" -eq 0 ]; then
    echo -e "${YELLOW}Overall Status: GOOD (${HEALTH_SCORE}%) - Minor Warnings${NC}" | tee -a "$REPORT_FILE"
else
    echo -e "${RED}Overall Status: NEEDS ATTENTION (${HEALTH_SCORE}%)${NC}" | tee -a "$REPORT_FILE"
fi

echo "" | tee -a "$REPORT_FILE"
echo "Report saved to: $REPORT_FILE" | tee -a "$REPORT_FILE"
echo "=========================================" | tee -a "$REPORT_FILE"

# Clean up old reports (keep last 30)
cd "$REPORT_DIR"
ls -t health_report_*.txt 2>/dev/null | tail -n +31 | xargs rm -f 2>/dev/null || true

# Exit with appropriate code
if [ "$CRITICAL_ISSUES" -gt 0 ]; then
    exit 1
elif [ "$WARNINGS" -gt 0 ]; then
    exit 2
else
    exit 0
fi

