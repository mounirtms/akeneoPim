#!/bin/bash
# 2-Day Database Monitoring Script
# Tracks database changes, performance, and integrity

AKENEO_DB="akeneo_pim"
MAGENTO_DB="beta_dBT8x12y22"
MYSQL_CMD="/opt/mariadb10.6/mariadb/bin/mysql -u root -pYourNewStrongPassword -h 127.0.0.1 -P 3307"
LOG_DIR="/home/pim/public_html/webapp/logs/db_monitor"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

mkdir -p "$LOG_DIR"

# Baseline snapshot function
take_snapshot() {
    local db=$1
    local snapshot_file="$LOG_DIR/${db}_snapshot_$TIMESTAMP.txt"
    
    echo "=== DATABASE SNAPSHOT: $db - $(date) ===" > "$snapshot_file"
    
    # Table row counts
    echo -e "\n--- TABLE ROW COUNTS ---" >> "$snapshot_file"
    $MYSQL_CMD -e "
        SELECT 
            TABLE_NAME, 
            TABLE_ROWS,
            ROUND((DATA_LENGTH + INDEX_LENGTH) / 1024 / 1024, 2) AS size_mb
        FROM information_schema.TABLES 
        WHERE TABLE_SCHEMA = '$db' 
        ORDER BY TABLE_ROWS DESC
        LIMIT 50;
    " >> "$snapshot_file"
    
    # Database size
    echo -e "\n--- DATABASE SIZE ---" >> "$snapshot_file"
    $MYSQL_CMD -e "
        SELECT 
            ROUND(SUM(DATA_LENGTH + INDEX_LENGTH) / 1024 / 1024, 2) AS total_size_mb
        FROM information_schema.TABLES 
        WHERE TABLE_SCHEMA = '$db';
    " >> "$snapshot_file"
    
    # Performance metrics
    echo -e "\n--- PERFORMANCE METRICS ---" >> "$snapshot_file"
    $MYSQL_CMD -e "SHOW GLOBAL STATUS WHERE Variable_name IN ('Questions', 'Slow_queries', 'Connections', 'Threads_connected');" >> "$snapshot_file"
    
    # Akeneo-specific metrics
    if [ "$db" = "$AKENEO_DB" ]; then
        echo -e "\n--- AKENEO METRICS ---" >> "$snapshot_file"
        $MYSQL_CMD "$db" -e "
            SELECT 
                (SELECT COUNT(*) FROM pim_catalog_product) as products,
                (SELECT COUNT(*) FROM pim_catalog_attribute) as attributes,
                (SELECT COUNT(*) FROM pim_catalog_attribute_option) as options,
                (SELECT COUNT(*) FROM pim_catalog_category) as categories,
                (SELECT COUNT(DISTINCT product_id) FROM pim_catalog_completeness) as completeness_tracked;
        " >> "$snapshot_file"
    fi
    
    # Magento-specific metrics
    if [ "$db" = "$MAGENTO_DB" ]; then
        echo -e "\n--- MAGENTO METRICS ---" >> "$snapshot_file"
        $MYSQL_CMD "$db" -e "
            SELECT 
                (SELECT COUNT(*) FROM catalog_product_entity) as products,
                (SELECT COUNT(*) FROM catalog_category_product) as category_links,
                (SELECT COUNT(*) FROM cataloginventory_stock_status WHERE stock_status = 1) as in_stock,
                (SELECT COUNT(*) FROM sales_order WHERE created_at > DATE_SUB(NOW(), INTERVAL 24 HOUR)) as orders_24h;
        " >> "$snapshot_file"
    fi
    
    echo "Snapshot saved: $snapshot_file"
}

# Continuous monitoring function
monitor_changes() {
    local interval=$1  # in seconds
    local duration=$2  # in hours
    local monitor_log="$LOG_DIR/monitor_log_$TIMESTAMP.txt"
    
    echo "=== STARTING 2-DAY MONITORING - $(date) ===" > "$monitor_log"
    echo "Interval: ${interval}s, Duration: ${duration}h" >> "$monitor_log"
    
    local iterations=$((duration * 3600 / interval))
    
    for ((i=1; i<=iterations; i++)); do
        echo -e "\n--- Check #$i - $(date) ---" >> "$monitor_log"
        
        # Quick health check
        echo "System Load: $(uptime | awk -F'load average:' '{print $2}')" >> "$monitor_log"
        
        # Akeneo product count
        local akeneo_products=$($MYSQL_CMD "$AKENEO_DB" -sN -e "SELECT COUNT(*) FROM pim_catalog_product;")
        echo "Akeneo Products: $akeneo_products" >> "$monitor_log"
        
        # Magento product count
        local magento_products=$($MYSQL_CMD "$MAGENTO_DB" -sN -e "SELECT COUNT(*) FROM catalog_product_entity;")
        echo "Magento Products: $magento_products" >> "$monitor_log"
        
        # Database connections
        local connections=$($MYSQL_CMD -sN -e "SHOW STATUS LIKE 'Threads_connected';" | awk '{print $2}')
        echo "DB Connections: $connections" >> "$monitor_log"
        
        # Slow queries
        local slow_queries=$($MYSQL_CMD -sN -e "SHOW STATUS LIKE 'Slow_queries';" | awk '{print $2}')
        echo "Slow Queries: $slow_queries" >> "$monitor_log"
        
        # Check for errors in production log
        local recent_errors=$(tail -100 /home/pim/public_html/var/logs/prod.log 2>/dev/null | grep -c '\[ERROR\]')
        echo "Recent Errors (last 100 lines): $recent_errors" >> "$monitor_log"
        
        sleep "$interval"
    done
    
    echo -e "\n=== MONITORING COMPLETE - $(date) ===" >> "$monitor_log"
}

# Main execution
echo "Starting 2-Day Database Monitoring..."
echo "Taking initial snapshots..."

# Take baseline snapshots
take_snapshot "$AKENEO_DB"
take_snapshot "$MAGENTO_DB"

echo ""
echo "Snapshots complete. Starting continuous monitoring..."
echo "Monitoring will run for 48 hours, checking every 2 hours"
echo "Logs will be saved to: $LOG_DIR"
echo ""
echo "To stop monitoring: kill -9 $(echo $$)"
echo ""

# Monitor every 2 hours for 48 hours
monitor_changes 7200 48 &

echo "Monitoring started in background (PID: $!)"
echo "Check progress: tail -f $LOG_DIR/monitor_log_$TIMESTAMP.txt"
