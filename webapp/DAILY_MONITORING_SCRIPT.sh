#!/bin/bash
# Daily Monitoring Script for Akeneo PIM Platform
# Tracks key metrics during optimization phase
# Date: 2026-04-29

LOG_DIR="/home/pim/public_html/webapp/logs/daily_monitoring"
mkdir -p "$LOG_DIR"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
REPORT="$LOG_DIR/daily_report_$TIMESTAMP.txt"

echo "========================================" > "$REPORT"
echo "DAILY MONITORING REPORT" >> "$REPORT"
echo "Generated: $(date)" >> "$REPORT"
echo "========================================" >> "$REPORT"
echo "" >> "$REPORT"

# 1. System Load
echo "=== SYSTEM LOAD ===" >> "$REPORT"
uptime >> "$REPORT"
LOAD_1MIN=$(uptime | awk -F'load average:' '{print $2}' | awk -F',' '{print $1}' | xargs)
echo "1-min load: $LOAD_1MIN" >> "$REPORT"
echo "" >> "$REPORT"

# 2. PHP-FPM Status
echo "=== PHP-FPM STATUS ===" >> "$REPORT"
if systemctl is-active --quiet php-fpm; then
    echo "✅ PHP-FPM: ACTIVE" >> "$REPORT"
    PHP_FPM_COUNT=$(ps aux | grep "php-fpm: pool" | grep -v grep | wc -l)
    echo "Worker count: $PHP_FPM_COUNT" >> "$REPORT"
else
    echo "❌ PHP-FPM: INACTIVE" >> "$REPORT"
fi
echo "" >> "$REPORT"

# 3. Varnish Cache Stats
echo "=== VARNISH CACHE ===" >> "$REPORT"
if command -v varnishstat &> /dev/null; then
    CACHE_HIT=$(varnishstat -1 -f MAIN.cache_hit | awk '{print $2}')
    CACHE_MISS=$(varnishstat -1 -f MAIN.cache_miss | awk '{print $2}')
    TOTAL=$((CACHE_HIT + CACHE_MISS))
    if [ $TOTAL -gt 0 ]; then
        HIT_RATE=$(echo "scale=2; $CACHE_HIT * 100 / $TOTAL" | bc)
        echo "Cache hits: $CACHE_HIT" >> "$REPORT"
        echo "Cache misses: $CACHE_MISS" >> "$REPORT"
        echo "Hit rate: ${HIT_RATE}%" >> "$REPORT"
    else
        echo "No cache data available yet" >> "$REPORT"
    fi
else
    echo "Varnishstat not available" >> "$REPORT"
fi
echo "" >> "$REPORT"

# 4. MariaDB Performance
echo "=== DATABASE METRICS ===" >> "$REPORT"
DB_QPS=$(/opt/mariadb10.6/mariadb/bin/mysql -u root -p'YourNewStrongPassword' -h 127.0.0.1 -P 3307 -e "SHOW GLOBAL STATUS LIKE 'Questions';" 2>/dev/null | grep Questions | awk '{print $2}')
DB_UPTIME=$(/opt/mariadb10.6/mariadb/bin/mysql -u root -p'YourNewStrongPassword' -h 127.0.0.1 -P 3307 -e "SHOW GLOBAL STATUS LIKE 'Uptime';" 2>/dev/null | grep Uptime | awk '{print $2}')
if [ ! -z "$DB_QPS" ] && [ ! -z "$DB_UPTIME" ] && [ $DB_UPTIME -gt 0 ]; then
    QPS=$(echo "scale=2; $DB_QPS / $DB_UPTIME" | bc)
    echo "Queries per second: $QPS" >> "$REPORT"
else
    echo "Unable to calculate QPS" >> "$REPORT"
fi

DB_THREADS=$(/opt/mariadb10.6/mariadb/bin/mysql -u root -p'YourNewStrongPassword' -h 127.0.0.1 -P 3307 -e "SHOW GLOBAL STATUS LIKE 'Threads_connected';" 2>/dev/null | grep Threads | awk '{print $2}')
echo "Active connections: $DB_THREADS/200" >> "$REPORT"

SLOW_QUERIES=$(/opt/mariadb10.6/mariadb/bin/mysql -u root -p'YourNewStrongPassword' -h 127.0.0.1 -P 3307 -e "SHOW GLOBAL STATUS LIKE 'Slow_queries';" 2>/dev/null | grep Slow | awk '{print $2}')
echo "Slow queries: $SLOW_QUERIES" >> "$REPORT"
echo "" >> "$REPORT"

# 5. Redis Status
echo "=== REDIS STATUS ===" >> "$REPORT"
if systemctl is-active --quiet redis; then
    echo "✅ Redis: ACTIVE" >> "$REPORT"
    if command -v redis-cli &> /dev/null; then
        REDIS_MEM=$(redis-cli info memory 2>/dev/null | grep used_memory_human | cut -d: -f2 | tr -d '\r')
        REDIS_KEYS=$(redis-cli dbsize 2>/dev/null | awk '{print $2}')
        echo "Memory used: $REDIS_MEM" >> "$REPORT"
        echo "Total keys: $REDIS_KEYS" >> "$REPORT"
    fi
else
    echo "❌ Redis: INACTIVE" >> "$REPORT"
fi
echo "" >> "$REPORT"

# 6. Elasticsearch Health
echo "=== ELASTICSEARCH ===" >> "$REPORT"
if curl -s http://localhost:9200/_cluster/health?pretty 2>/dev/null | grep -q "status"; then
    ES_STATUS=$(curl -s http://localhost:9200/_cluster/health?pretty 2>/dev/null | grep "status" | head -1 | awk -F'"' '{print $4}')
    echo "Cluster status: $ES_STATUS" >> "$REPORT"
else
    echo "❌ Elasticsearch: Not responding" >> "$REPORT"
fi
echo "" >> "$REPORT"

# 7. Memory Usage
echo "=== MEMORY USAGE ===" >> "$REPORT"
free -h | grep -E "Mem:|Swap:" >> "$REPORT"
echo "" >> "$REPORT"

# 8. Disk Usage
echo "=== DISK USAGE ===" >> "$REPORT"
df -h /home | tail -1 >> "$REPORT"
echo "" >> "$REPORT"

# 9. Error Log Summary
echo "=== ERROR LOG (Last 1 hour) ===" >> "$REPORT"
if [ -f /var/log/httpd/error_log ]; then
    ERROR_COUNT=$(grep -c "$(date -d '1 hour ago' '+%d/%b/%Y')" /var/log/httpd/error_log 2>/dev/null || echo "0")
    echo "Error count: $ERROR_COUNT" >> "$REPORT"
else
    echo "Error log not found" >> "$REPORT"
fi
echo "" >> "$REPORT"

# 10. Product Sync Status
echo "=== PRODUCT SYNC STATUS ===" >> "$REPORT"
cd /home/pim/public_html/webapp
AKENEO_COUNT=$(bin/console pim:product:count --env=prod 2>/dev/null | grep -oE '[0-9]+' | head -1)
echo "Akeneo products: ${AKENEO_COUNT:-N/A}" >> "$REPORT"
echo "" >> "$REPORT"

# Summary Status
echo "========================================" >> "$REPORT"
echo "STATUS SUMMARY" >> "$REPORT"
echo "========================================" >> "$REPORT"

# Determine overall status based on metrics
STATUS="🟢 HEALTHY"
ISSUES=0

# Check load
LOAD_CHECK=$(echo "$LOAD_1MIN < 4.0" | bc -l 2>/dev/null || echo "0")
if [ "$LOAD_CHECK" != "1" ]; then
    STATUS="🟡 WARNING"
    ISSUES=$((ISSUES + 1))
    echo "⚠️  High system load: $LOAD_1MIN (target: <4.0)" >> "$REPORT"
fi

# Check PHP-FPM
if ! systemctl is-active --quiet php-fpm; then
    STATUS="🔴 CRITICAL"
    ISSUES=$((ISSUES + 1))
    echo "❌ PHP-FPM inactive" >> "$REPORT"
fi

# Check Varnish hit rate
if [ ! -z "$HIT_RATE" ]; then
    HIT_CHECK=$(echo "$HIT_RATE < 70" | bc -l 2>/dev/null || echo "0")
    if [ "$HIT_CHECK" = "1" ]; then
        if [ "$STATUS" = "🟢 HEALTHY" ]; then
            STATUS="🟡 WARNING"
        fi
        ISSUES=$((ISSUES + 1))
        echo "⚠️  Low cache hit rate: ${HIT_RATE}% (target: >70%)" >> "$REPORT"
    fi
fi

if [ $ISSUES -eq 0 ]; then
    echo "✅ All systems operating within target parameters" >> "$REPORT"
fi

echo "" >> "$REPORT"
echo "Overall Status: $STATUS" >> "$REPORT"
echo "Issues detected: $ISSUES" >> "$REPORT"
echo "" >> "$REPORT"
echo "Report saved to: $REPORT" >> "$REPORT"

# Output to console
cat "$REPORT"

# Keep only last 30 days of reports
find "$LOG_DIR" -name "daily_report_*.txt" -mtime +30 -delete 2>/dev/null

exit 0
