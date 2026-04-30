#!/bin/bash
#
# Daily Monitoring Script for Akeneo PIM and Magento Integration
# Run this script daily to check system health
#

TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
LOG_FILE="/home/pim/public_html/webapp/logs/daily_monitor_$(date +%Y%m%d).log"
mkdir -p "$(dirname "$LOG_FILE")"

echo "=== DAILY SYSTEM MONITOR ===" | tee -a "$LOG_FILE"
echo "Timestamp: $TIMESTAMP" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

# Function to log with timestamp
log() {
    echo "$1" | tee -a "$LOG_FILE"
}

# 1. Check Akeneo PIM Accessibility
log "[1/8] Checking Akeneo PIM Accessibility..."
if curl -s -o /dev/null -w "%{http_code}" https://pim.technostationery.com/ | grep -q "200\|302"; then
    log "  ✅ Akeneo PIM accessible"
else
    log "  ❌ Akeneo PIM not accessible"
fi

# 2. Check Magento Accessibility
log ""
log "[2/8] Checking Magento Beta Accessibility..."
if curl -s -o /dev/null -w "%{http_code}" https://beta.technostationery.com/ | grep -q "200\|302"; then
    log "  ✅ Magento Beta accessible"
else
    log "  ❌ Magento Beta not accessible"
fi

# 3. Check Elasticsearch Health
log ""
log "[3/8] Checking Elasticsearch Health..."
ES_STATUS=$(curl -s http://localhost:9200/_cluster/health | jq -r '.status' 2>/dev/null)
if [ "$ES_STATUS" = "green" ] || [ "$ES_STATUS" = "yellow" ]; then
    log "  ✅ Elasticsearch status: $ES_STATUS"
else
    log "  ❌ Elasticsearch issue: $ES_STATUS"
fi

# 4. Check Akeneo Product Count
log ""
log "[4/8] Checking Akeneo Product Count..."
AKENEO_COUNT=$(mysql -h127.0.0.1 -P3307 -uakeneo_pim -pakeneo_pim --skip-ssl akeneo_pim -sN -e "SELECT COUNT(*) FROM pim_catalog_product WHERE is_enabled=1" 2>/dev/null | grep -v "Deprecated")
log "  Products: $AKENEO_COUNT"
if [ "$AKENEO_COUNT" = "9538" ]; then
    log "  ✅ Product count correct"
else
    log "  ⚠️  Product count mismatch"
fi

# 5. Check Elasticsearch Index Count
log ""
log "[5/8] Checking Elasticsearch Index..."
ES_COUNT=$(curl -s http://localhost:9200/akeneo_pim_product_and_product_model/_count | jq -r '.count' 2>/dev/null)
log "  Indexed: $ES_COUNT"
if [ "$ES_COUNT" = "9538" ]; then
    log "  ✅ Index count correct"
else
    log "  ⚠️  Index count mismatch"
fi

# 6. Check Magento Product Count
log ""
log "[6/8] Checking Magento Product Count..."
MAGENTO_COUNT=$(mysql -h127.0.0.1 -P3307 -ubeta_ntdbusr24 -p'the-correct-password' --skip-ssl beta_dBT8x12y22 -sN -e "SELECT COUNT(*) FROM catalog_product_entity_int WHERE attribute_id=97 AND value=1" 2>/dev/null | grep -v "Deprecated")
log "  Enabled Products: $MAGENTO_COUNT"
if [ "$MAGENTO_COUNT" = "9538" ]; then
    log "  ✅ Magento product count correct"
else
    log "  ⚠️  Magento product count mismatch"
fi

# 7. Check Disk Space
log ""
log "[7/8] Checking Disk Space..."
DISK_USAGE=$(df -h /home | tail -1 | awk '{print $5}' | sed 's/%//')
log "  Disk Usage: ${DISK_USAGE}%"
if [ "$DISK_USAGE" -lt 80 ]; then
    log "  ✅ Disk space OK"
elif [ "$DISK_USAGE" -lt 90 ]; then
    log "  ⚠️  Disk space warning"
else
    log "  ❌ Disk space critical"
fi

# 8. Check Recent Errors in Akeneo Logs
log ""
log "[8/8] Checking Recent Errors..."
ERROR_COUNT=$(grep -c "ERROR" /home/pim/public_html/var/logs/prod.log 2>/dev/null | tail -100 || echo "0")
log "  Recent errors in log: $ERROR_COUNT"
if [ "$ERROR_COUNT" -lt 10 ]; then
    log "  ✅ Error count acceptable"
else
    log "  ⚠️  High error count"
fi

# Summary
log ""
log "=== MONITORING COMPLETE ==="
log "Log saved to: $LOG_FILE"
log ""

# If critical issues found, could send email alert here
# mail -s "Akeneo PIM Daily Monitor Alert" webmaster@techno-dz.com < "$LOG_FILE"

