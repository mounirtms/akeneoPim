#!/bin/bash
# PIM Akeneo - Quick Health Check Script
# Usage: ./health_check.sh

set -e

WORK_DIR="/home/pim/public_html"
cd "$WORK_DIR"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "================================================================="
echo "         PIM AKENEO HEALTH CHECK - $(date '+%Y-%m-%d %H:%M:%S')"
echo "================================================================="
echo ""

# 1. Site Availability Check
echo "📊 1. SITE AVAILABILITY CHECK"
echo "-----------------------------------------------------------------"
HTTP_STATUS=$(curl -I -s -k https://pim.technostationery.com/user/login | grep "HTTP/" | head -1 | awk '{print $2}')
if [ "$HTTP_STATUS" = "200" ]; then
    echo -e "${GREEN}✅ Site is ONLINE (HTTP $HTTP_STATUS)${NC}"
else
    echo -e "${RED}❌ Site issue detected (HTTP $HTTP_STATUS)${NC}"
fi
echo ""

# 2. Database Connection Check
echo "🗄️  2. DATABASE CONNECTION CHECK"
echo "-----------------------------------------------------------------"
if php bin/console doctrine:query:sql "SELECT 1 as test" --env=prod > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Database connection is HEALTHY${NC}"
else
    echo -e "${RED}❌ Database connection FAILED${NC}"
fi
echo ""

# 3. Cache Directory Permissions
echo "📂 3. CACHE DIRECTORY PERMISSIONS"
echo "-----------------------------------------------------------------"
CACHE_OWNER=$(stat -c '%U:%G' var/cache/prod/oro_acl_annotations 2>/dev/null || echo "N/A")
CACHE_PERMS=$(stat -c '%a' var/cache/prod/oro_acl_annotations 2>/dev/null || echo "N/A")
if [ "$CACHE_OWNER" = "pim:pim" ] && [ "$CACHE_PERMS" = "777" ]; then
    echo -e "${GREEN}✅ Cache permissions are CORRECT ($CACHE_OWNER, $CACHE_PERMS)${NC}"
else
    echo -e "${YELLOW}⚠️  Cache permissions: $CACHE_OWNER, $CACHE_PERMS${NC}"
fi
echo ""

# 4. Recent Critical Errors (excluding deprecations)
echo "🔍 4. RECENT CRITICAL ERRORS (Last 24 hours)"
echo "-----------------------------------------------------------------"
ERROR_COUNT=$(tail -1000 var/logs/prod.log 2>/dev/null | grep -i "request.CRITICAL" | grep -v "deprecated" | wc -l || echo "0")
if [ "$ERROR_COUNT" = "0" ]; then
    echo -e "${GREEN}✅ No critical errors detected${NC}"
else
    echo -e "${YELLOW}⚠️  Found $ERROR_COUNT critical errors (review recommended)${NC}"
    tail -1000 var/logs/prod.log | grep -i "request.CRITICAL" | grep -v "deprecated" | tail -3
fi
echo ""

# 5. Log File Sizes
echo "📝 5. LOG FILE SIZES"
echo "-----------------------------------------------------------------"
ERROR_LOG_SIZE=$(du -h error_log 2>/dev/null | awk '{print $1}' || echo "0")
PROD_LOG_SIZE=$(du -h var/logs/prod.log 2>/dev/null | awk '{print $1}' || echo "0")
echo "   error_log: $ERROR_LOG_SIZE"
echo "   prod.log:  $PROD_LOG_SIZE"

# Check if logs are too large
ERROR_LOG_MB=$(du -m error_log 2>/dev/null | awk '{print $1}' || echo "0")
PROD_LOG_MB=$(du -m var/logs/prod.log 2>/dev/null | awk '{print $1}' || echo "0")
if [ "$ERROR_LOG_MB" -gt 50 ] || [ "$PROD_LOG_MB" -gt 50 ]; then
    echo -e "${YELLOW}⚠️  Logs are large (consider archiving)${NC}"
else
    echo -e "${GREEN}✅ Log sizes are healthy${NC}"
fi
echo ""

# 6. Disk Space
echo "💾 6. DISK SPACE"
echo "-----------------------------------------------------------------"
DISK_USAGE=$(df -h /home/pim | tail -1 | awk '{print $5}' | sed 's/%//')
DISK_AVAIL=$(df -h /home/pim | tail -1 | awk '{print $4}')
echo "   Usage: ${DISK_USAGE}% (Available: $DISK_AVAIL)"
if [ "$DISK_USAGE" -lt 80 ]; then
    echo -e "${GREEN}✅ Disk space is healthy${NC}"
elif [ "$DISK_USAGE" -lt 90 ]; then
    echo -e "${YELLOW}⚠️  Disk space is getting low${NC}"
else
    echo -e "${RED}❌ CRITICAL: Disk space critically low${NC}"
fi
echo ""

# 7. PHP Extensions Check
echo "🔌 7. PHP EXTENSIONS"
echo "-----------------------------------------------------------------"
OPCACHE_STATUS=$(php -m | grep -i "Zend OPcache" > /dev/null 2>&1 && echo "✅ Installed" || echo "❌ Missing")
APCU_STATUS=$(php -m | grep -i "apcu" > /dev/null 2>&1 && echo "✅ Installed" || echo "❌ Missing")
echo "   OPcache: $OPCACHE_STATUS"
echo "   APCu:    $APCU_STATUS"
if [[ "$OPCACHE_STATUS" == *"Missing"* ]] || [[ "$APCU_STATUS" == *"Missing"* ]]; then
    echo -e "${YELLOW}⚠️  Performance extensions missing (contact admin)${NC}"
fi
echo ""

# 8. Elasticsearch Connection
echo "🔍 8. ELASTICSEARCH CONNECTION"
echo "-----------------------------------------------------------------"
ES_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:9200/_cluster/health 2>/dev/null || echo "000")
if [ "$ES_STATUS" = "200" ]; then
    echo -e "${GREEN}✅ Elasticsearch is HEALTHY${NC}"
else
    echo -e "${YELLOW}⚠️  Elasticsearch status: HTTP $ES_STATUS${NC}"
fi
echo ""

# 9. Messenger Queue Status
echo "📬 9. MESSENGER QUEUE STATUS"
echo "-----------------------------------------------------------------"
QUEUE_ERRORS=$(tail -100 var/logs/prod.log | grep "messenger:consume" | grep -i "error\|gone away" | wc -l || echo "0")
if [ "$QUEUE_ERRORS" = "0" ]; then
    echo -e "${GREEN}✅ Messenger queues are processing normally${NC}"
else
    echo -e "${YELLOW}⚠️  Found $QUEUE_ERRORS messenger errors (non-critical)${NC}"
fi
echo ""

# 10. Summary
echo "================================================================="
echo "                         SUMMARY                                 "
echo "================================================================="
if [ "$HTTP_STATUS" = "200" ] && [ "$ERROR_COUNT" = "0" ] && [ "$DISK_USAGE" -lt 80 ]; then
    echo -e "${GREEN}✅ ALL SYSTEMS OPERATIONAL${NC}"
    echo ""
    echo "Next Actions:"
    echo "  • Continue monitoring"
    echo "  • Consider Phase 2 optimizations (see NEXT_STEPS_ROADMAP.md)"
else
    echo -e "${YELLOW}⚠️  ATTENTION REQUIRED${NC}"
    echo ""
    echo "Recommended Actions:"
    if [ "$HTTP_STATUS" != "200" ]; then
        echo "  • Investigate site availability issue"
    fi
    if [ "$ERROR_COUNT" != "0" ]; then
        echo "  • Review recent critical errors in logs"
    fi
    if [ "$DISK_USAGE" -gt 80 ]; then
        echo "  • Free up disk space (archive logs)"
    fi
fi
echo ""
echo "================================================================="
echo "Report generated: $(date '+%Y-%m-%d %H:%M:%S')"
echo "================================================================="
