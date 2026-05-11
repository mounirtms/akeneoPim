#!/bin/bash
# Platform Stability and Performance Check
# Session: 2026-04-23 - Continued
# Focus: Prepare for Magento sync

echo "=========================================="
echo "PLATFORM STABILITY CHECK"
echo "=========================================="
echo "Date: $(date)"
echo ""

# 1. Website Health
echo "=== 1. Website Health Check ==="
HTTP_CODE=$(curl -I https://pim.technostationery.com/ 2>&1 | grep "HTTP/" | awk '{print $2}')
echo "Website Status: HTTP $HTTP_CODE"
if [ "$HTTP_CODE" = "302" ] || [ "$HTTP_CODE" = "200" ]; then
    echo "✓ Website responding correctly"
else
    echo "✗ Warning: HTTP $HTTP_CODE"
fi
echo ""

# 2. Database Connection
echo "=== 2. Database Connection Test ==="
DB_VERSION=$(/opt/mariadb10.6/mariadb/bin/mysql -u root -p'YourNewStrongPassword' -h 127.0.0.1 -P 3307 -e "SELECT VERSION();" 2>&1 | tail -1)
if [ $? -eq 0 ]; then
    echo "✓ MariaDB Connected: $DB_VERSION"
else
    echo "✗ Database connection failed"
    exit 1
fi
echo ""

# 3. Product Data Integrity
echo "=== 3. Product Data Integrity ==="
/opt/mariadb10.6/mariadb/bin/mysql -u root -p'YourNewStrongPassword' -h 127.0.0.1 -P 3307 akeneo_pim << 'SQL'
SELECT 
    'Total Products' as metric,
    COUNT(*) as count
FROM pim_catalog_product
UNION ALL
SELECT 'Enabled Products', SUM(is_enabled)
FROM pim_catalog_product
UNION ALL
SELECT 'Products with Family', COUNT(*) 
FROM pim_catalog_product WHERE family_id IS NOT NULL
UNION ALL
SELECT 'Products without Family', COUNT(*) 
FROM pim_catalog_product WHERE family_id IS NULL;
SQL
echo ""

# 4. Image Storage Analysis
echo "=== 4. Image Storage Analysis ==="
CATALOG_FILES=$(find /home/pim/public_html/var/file_storage/catalog -type f 2>/dev/null | wc -l)
DB_FILE_RECORDS=$(/opt/mariadb10.6/mariadb/bin/mysql -u root -p'YourNewStrongPassword' -h 127.0.0.1 -P 3307 akeneo_pim -e "SELECT COUNT(*) FROM akeneo_file_storage_file_info;" 2>&1 | tail -1)

echo "Physical files in catalog: $CATALOG_FILES"
echo "Database file records: $DB_FILE_RECORDS"
echo "Gap (files not in DB): $((CATALOG_FILES - DB_FILE_RECORDS))"
if [ $CATALOG_FILES -gt $((DB_FILE_RECORDS * 10)) ]; then
    echo "⚠ CRITICAL: Large gap between files and DB records"
    echo "   Action required: Import images to database"
else
    echo "✓ File-DB ratio acceptable"
fi
echo ""

# 5. Magento Connector Check
echo "=== 5. Magento Connector Status ==="
if [ -f "/home/pim/public_html/vendor/akeneo/magento-connector-bundle/composer.json" ]; then
    echo "✓ Magento Connector bundle installed"
    CONNECTOR_VERSION=$(grep '"version"' /home/pim/public_html/vendor/akeneo/magento-connector-bundle/composer.json | head -1 | awk -F'"' '{print $4}')
    echo "  Version: $CONNECTOR_VERSION"
else
    echo "⚠ Magento Connector bundle not found"
    echo "  Check: composer show | grep magento"
fi
echo ""

# 6. Recent Errors
echo "=== 6. Recent Error Analysis ==="
ERROR_COUNT=$(tail -100 /home/pim/public_html/var/logs/prod.log 2>/dev/null | grep -E "CRITICAL|ERROR" | wc -l)
echo "Errors in last 100 log lines: $ERROR_COUNT"
if [ $ERROR_COUNT -lt 5 ]; then
    echo "✓ Error rate acceptable"
else
    echo "⚠ Warning: High error rate"
    echo "Recent errors:"
    tail -100 /home/pim/public_html/var/logs/prod.log | grep -E "CRITICAL|ERROR" | tail -5
fi
echo ""

# 7. Cache Status
echo "=== 7. Cache Status ==="
CACHE_SIZE=$(du -sh /home/pim/public_html/var/cache 2>/dev/null | awk '{print $1}')
echo "Cache size: $CACHE_SIZE"
ROOT_FILES=$(find /home/pim/public_html/var/cache -user root 2>/dev/null | wc -l)
if [ $ROOT_FILES -gt 0 ]; then
    echo "⚠ Warning: $ROOT_FILES root-owned files in cache"
    echo "  Action: bash webapp/fix_cache_permissions.sh"
else
    echo "✓ No root-owned cache files"
fi
echo ""

# 8. Backup Status
echo "=== 8. Backup Status ==="
BACKUP_COUNT=$(ls -1 /home/pim/backups/*.gz 2>/dev/null | wc -l)
LATEST_BACKUP=$(ls -t /home/pim/backups/akeneo_backup_*.sql.gz 2>/dev/null | head -1)
if [ -n "$LATEST_BACKUP" ]; then
    BACKUP_AGE=$(stat -c %Y "$LATEST_BACKUP")
    CURRENT_TIME=$(date +%s)
    AGE_HOURS=$(( (CURRENT_TIME - BACKUP_AGE) / 3600 ))
    echo "Latest backup: $(basename $LATEST_BACKUP)"
    echo "Backup age: ${AGE_HOURS} hours"
    echo "Total backups: $BACKUP_COUNT"
    if [ $AGE_HOURS -lt 24 ]; then
        echo "✓ Recent backup available"
    else
        echo "⚠ Warning: Backup older than 24 hours"
    fi
else
    echo "✗ No backups found"
fi
echo ""

# 9. Performance Metrics
echo "=== 9. Performance Metrics ==="
/opt/mariadb10.6/mariadb/bin/mysql -u root -p'YourNewStrongPassword' -h 127.0.0.1 -P 3307 akeneo_pim << 'SQL'
SELECT 
    TABLE_NAME,
    ROUND((DATA_LENGTH + INDEX_LENGTH) / 1024 / 1024, 2) AS 'Size_MB',
    TABLE_ROWS
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = 'akeneo_pim'
    AND TABLE_NAME IN ('pim_catalog_product', 'pim_catalog_category_product', 'akeneo_file_storage_file_info')
ORDER BY (DATA_LENGTH + INDEX_LENGTH) DESC;
SQL
echo ""

# 10. Channel Configuration
echo "=== 10. Channel Configuration ==="
/opt/mariadb10.6/mariadb/bin/mysql -u root -p'YourNewStrongPassword' -h 127.0.0.1 -P 3307 akeneo_pim << 'SQL'
SELECT 
    c.code,
    COUNT(DISTINCT cl.locale_id) as locales,
    COUNT(DISTINCT cc.currency_id) as currencies
FROM pim_catalog_channel c
LEFT JOIN pim_catalog_channel_locale cl ON c.id = cl.channel_id
LEFT JOIN pim_catalog_channel_currency cc ON c.id = cc.channel_id
GROUP BY c.code;
SQL
echo ""

echo "=========================================="
echo "STABILITY CHECK COMPLETE"
echo "=========================================="
echo ""
echo "Next Steps:"
echo "1. Fix monitoring dashboard access (move to public)"
echo "2. Import product images to database"
echo "3. Test Magento connector"
echo "4. Validate product sync workflow"
echo ""
