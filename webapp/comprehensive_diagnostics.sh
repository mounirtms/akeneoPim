#!/bin/bash
# Comprehensive System Diagnostics and Fix Plan
# Date: 2026-04-23

echo "=========================================="
echo "AKENEO PIM COMPREHENSIVE DIAGNOSTICS"
echo "=========================================="
echo ""

REPORT_FILE="/home/pim/public_html/webapp/diagnostic_report_$(date +%Y%m%d_%H%M%S).txt"

{
echo "=== SYSTEM OVERVIEW ==="
echo "Date: $(date)"
echo "Hostname: $(hostname)"
echo "Uptime: $(uptime)"
echo ""

echo "=== MARIADB 10.6 STATUS (PORT 3307) ==="
/opt/mariadb10.6/mariadb/bin/mysql -u root -p'YourNewStrongPassword' -h 127.0.0.1 -P 3307 -e "SELECT VERSION();"
/opt/mariadb10.6/mariadb/bin/mysql -u root -p'YourNewStrongPassword' -h 127.0.0.1 -P 3307 -e "SHOW PROCESSLIST;"
echo ""

echo "=== DATABASE METRICS ==="
/opt/mariadb10.6/mariadb/bin/mysql -u root -p'YourNewStrongPassword' -h 127.0.0.1 -P 3307 akeneo_pim -e "
SELECT 'Total Products' as metric, COUNT(*) as value FROM pim_catalog_product
UNION ALL SELECT 'Enabled Products', COUNT(*) FROM pim_catalog_product WHERE is_enabled = 1
UNION ALL SELECT 'Disabled Products', COUNT(*) FROM pim_catalog_product WHERE is_enabled = 0
UNION ALL SELECT 'Total Categories', COUNT(*) FROM pim_catalog_category
UNION ALL SELECT 'Total Families', COUNT(*) FROM pim_catalog_family
UNION ALL SELECT 'Total Attributes', COUNT(*) FROM pim_catalog_attribute
UNION ALL SELECT 'Active Channels', COUNT(*) FROM pim_catalog_channel
UNION ALL SELECT 'File Storage Records', COUNT(*) FROM akeneo_file_storage_file_info;
"
echo ""

echo "=== CRITICAL ERRORS IN LOGS (LAST 100 LINES) ==="
cd /home/pim/public_html
tail -100 var/logs/prod.log | grep -E "CRITICAL|ERROR" | tail -20
echo ""

echo "=== DISK USAGE ==="
du -sh /home/pim/public_html/var/file_storage/catalog/
du -sh /home/pim/public_html/var/cache/
du -sh /home/pim/public_html/var/logs/
echo ""

echo "=== TOP 10 LARGEST LOG FILES ==="
find /home/pim/public_html/var/logs -name "*.log" -type f -exec ls -lh {} \; | sort -k5 -hr | head -10
echo ""

echo "=== PROBLEMATIC DATABASE RECORDS ==="
echo "Checking oro_user properties field..."
/opt/mariadb10.6/mariadb/bin/mysql -u root -p'YourNewStrongPassword' -h 127.0.0.1 -P 3307 akeneo_pim -e "
SELECT id, username, LENGTH(properties) as prop_length, 
       CASE WHEN properties = '' OR properties IS NULL THEN 'EMPTY' ELSE 'HAS_DATA' END as status
FROM oro_user;
"
echo ""

echo "=== FILE STORAGE ANALYSIS ==="
echo "Catalog files count:"
find /home/pim/public_html/var/file_storage/catalog -type f | wc -l
echo ""
echo "Sample files:"
find /home/pim/public_html/var/file_storage/catalog -type f | head -10
echo ""

echo "=== PRODUCT-IMAGE LINKAGE ==="
/opt/mariadb10.6/mariadb/bin/mysql -u root -p'YourNewStrongPassword' -h 127.0.0.1 -P 3307 akeneo_pim -e "
SELECT 
    (SELECT COUNT(*) FROM pim_catalog_product) as total_products,
    (SELECT COUNT(*) FROM akeneo_file_storage_file_info) as total_file_records,
    (SELECT COUNT(DISTINCT product_id) 
     FROM pim_catalog_product_unique_data 
     WHERE attribute_id IN (SELECT id FROM pim_catalog_attribute WHERE attribute_type = 'pim_catalog_image')) as products_with_images;
"
echo ""

echo "=== CHANNEL CONFIGURATION ==="
/opt/mariadb10.6/mariadb/bin/mysql -u root -p'YourNewStrongPassword' -h 127.0.0.1 -P 3307 akeneo_pim -e "
SELECT c.code, c.category_id, 
       COUNT(DISTINCT cl.locale_id) as locale_count,
       COUNT(DISTINCT cc.currency_id) as currency_count
FROM pim_catalog_channel c
LEFT JOIN pim_catalog_channel_locale cl ON c.id = cl.channel_id
LEFT JOIN pim_catalog_channel_currency cc ON c.id = cc.channel_id
GROUP BY c.code, c.category_id;
"
echo ""

echo "=== ATTRIBUTE ANALYSIS ==="
/opt/mariadb10.6/mariadb/bin/mysql -u root -p'YourNewStrongPassword' -h 127.0.0.1 -P 3307 akeneo_pim -e "
SELECT attribute_type, COUNT(*) as count 
FROM pim_catalog_attribute 
GROUP BY attribute_type 
ORDER BY count DESC;
"
echo ""

echo "=== RECENT PRODUCT UPDATES ==="
/opt/mariadb10.6/mariadb/bin/mysql -u root -p'YourNewStrongPassword' -h 127.0.0.1 -P 3307 akeneo_pim -e "
SELECT identifier, updated 
FROM pim_catalog_product 
ORDER BY updated DESC 
LIMIT 10;
"
echo ""

echo "=========================================="
echo "DIAGNOSTICS COMPLETE"
echo "=========================================="

} | tee "$REPORT_FILE"

echo ""
echo "Report saved to: $REPORT_FILE"
