#!/bin/bash

################################################################################
# MariaDB Comprehensive Audit Script
# Purpose: Complete comparison of both MariaDB instances
# Date: 2026-04-23
# Author: AI Development Team
################################################################################

REPORT_FILE="/home/pim/public_html/webapp/mariadb_audit_report_$(date +%Y%m%d_%H%M%S).txt"

exec > >(tee -a "$REPORT_FILE") 2>&1

echo "=========================================="
echo "MARIADB COMPREHENSIVE AUDIT"
echo "=========================================="
echo "Date: $(date '+%Y-%m-%d %H:%M:%S')"
echo "Report File: $REPORT_FILE"
echo ""

# Configuration
MARIADB106="/opt/mariadb10.6/mariadb/bin/mysql"
MARIADB106_DUMP="/opt/mariadb10.6/mariadb/bin/mysqldump"
MARIADB106_HOST="127.0.0.1"
MARIADB106_PORT="3307"
MARIADB106_USER="root"
MARIADB106_PASS="YourNewStrongPassword"

DEFAULT_MARIADB="mysql"
DEFAULT_HOST="localhost"
DEFAULT_PORT="3306"

echo "=========================================="
echo "SECTION 1: INSTANCE STATUS"
echo "=========================================="

echo -e "\n--- Default MariaDB (port 3306) ---"
systemctl status mariadb | head -10
echo ""
$DEFAULT_MARIADB -h $DEFAULT_HOST -P $DEFAULT_PORT -e "SELECT VERSION() as version, @@port as port, @@datadir as datadir;"

echo -e "\n--- MariaDB 10.6 (port 3307) ---"
ps aux | grep mariadbd | grep 3307 | grep -v grep
echo ""
$MARIADB106 -u $MARIADB106_USER -p"$MARIADB106_PASS" -h $MARIADB106_HOST -P $MARIADB106_PORT -e "SELECT VERSION() as version, @@port as port, @@datadir as datadir;"

echo ""
echo "=========================================="
echo "SECTION 2: DATABASE COMPARISON"
echo "=========================================="

echo -e "\n--- Databases in Default MariaDB (3306) ---"
$DEFAULT_MARIADB -h $DEFAULT_HOST -P $DEFAULT_PORT -e "SHOW DATABASES;" | grep -v "Database\|information_schema\|performance_schema\|mysql\|sys"

echo -e "\n--- Databases in MariaDB 10.6 (3307) ---"
$MARIADB106 -u $MARIADB106_USER -p"$MARIADB106_PASS" -h $MARIADB106_HOST -P $MARIADB106_PORT -e "SHOW DATABASES;" | grep -v "Database\|information_schema\|performance_schema\|mysql\|sys"

echo ""
echo "=========================================="
echo "SECTION 3: AKENEO DATABASE - DETAILED COMPARISON"
echo "=========================================="

echo -e "\n┌─────────────────────────────────────────────────────┐"
echo "│ DEFAULT MARIADB (port 3306) - akeneo_pim           │"
echo "└─────────────────────────────────────────────────────┘"

echo -e "\n--- Product Statistics ---"
$DEFAULT_MARIADB -h $DEFAULT_HOST -P $DEFAULT_PORT akeneo_pim <<EOF
SELECT 
    'Total Products' as metric,
    COUNT(*) as count 
FROM pim_catalog_product;

SELECT 
    'Enabled Products' as metric,
    COUNT(*) as count 
FROM pim_catalog_product 
WHERE is_enabled = 1;

SELECT 
    'Products by Family' as metric,
    f.code as family_code,
    COUNT(p.id) as count
FROM pim_catalog_product p
LEFT JOIN pim_catalog_family f ON p.family_id = f.id
GROUP BY f.code
ORDER BY count DESC
LIMIT 10;
EOF

echo -e "\n--- Channel Information ---"
$DEFAULT_MARIADB -h $DEFAULT_HOST -P $DEFAULT_PORT akeneo_pim <<EOF
SELECT 
    c.id,
    c.code,
    c.category_id,
    COUNT(DISTINCT cl.locale_id) as locales,
    COUNT(DISTINCT cc.currency_id) as currencies
FROM pim_catalog_channel c
LEFT JOIN pim_catalog_channel_locale cl ON c.id = cl.channel_id
LEFT JOIN pim_catalog_channel_currency cc ON c.id = cc.channel_id
GROUP BY c.id, c.code, c.category_id
ORDER BY c.code;
EOF

echo -e "\n--- Attribute Count ---"
$DEFAULT_MARIADB -h $DEFAULT_HOST -P $DEFAULT_PORT akeneo_pim -e "SELECT COUNT(*) as total_attributes FROM pim_catalog_attribute;"

echo -e "\n--- Category Count ---"
$DEFAULT_MARIADB -h $DEFAULT_HOST -P $DEFAULT_PORT akeneo_pim -e "SELECT COUNT(*) as total_categories FROM pim_catalog_category;"

echo -e "\n--- File Storage Count ---"
$DEFAULT_MARIADB -h $DEFAULT_HOST -P $DEFAULT_PORT akeneo_pim -e "SELECT COUNT(*) as total_files FROM akeneo_file_storage_file_info;"

echo -e "\n--- Recent Products (Last Updated) ---"
$DEFAULT_MARIADB -h $DEFAULT_HOST -P $DEFAULT_PORT akeneo_pim <<EOF
SELECT 
    identifier,
    is_enabled,
    updated
FROM pim_catalog_product
ORDER BY updated DESC
LIMIT 10;
EOF

echo ""
echo -e "\n┌─────────────────────────────────────────────────────┐"
echo "│ MARIADB 10.6 (port 3307) - akeneo_pim              │"
echo "└─────────────────────────────────────────────────────┘"

echo -e "\n--- Product Statistics ---"
$MARIADB106 -u $MARIADB106_USER -p"$MARIADB106_PASS" -h $MARIADB106_HOST -P $MARIADB106_PORT akeneo_pim <<EOF
SELECT 
    'Total Products' as metric,
    COUNT(*) as count 
FROM pim_catalog_product;

SELECT 
    'Enabled Products' as metric,
    COUNT(*) as count 
FROM pim_catalog_product 
WHERE is_enabled = 1;

SELECT 
    'Products by Family' as metric,
    f.code as family_code,
    COUNT(p.id) as count
FROM pim_catalog_product p
LEFT JOIN pim_catalog_family f ON p.family_id = f.id
GROUP BY f.code
ORDER BY count DESC
LIMIT 10;
EOF

echo -e "\n--- Channel Information ---"
$MARIADB106 -u $MARIADB106_USER -p"$MARIADB106_PASS" -h $MARIADB106_HOST -P $MARIADB106_PORT akeneo_pim <<EOF
SELECT 
    c.id,
    c.code,
    c.category_id,
    COUNT(DISTINCT cl.locale_id) as locales,
    COUNT(DISTINCT cc.currency_id) as currencies
FROM pim_catalog_channel c
LEFT JOIN pim_catalog_channel_locale cl ON c.id = cl.channel_id
LEFT JOIN pim_catalog_channel_currency cc ON c.id = cc.channel_id
GROUP BY c.id, c.code, c.category_id
ORDER BY c.code;
EOF

echo -e "\n--- Attribute Count ---"
$MARIADB106 -u $MARIADB106_USER -p"$MARIADB106_PASS" -h $MARIADB106_HOST -P $MARIADB106_PORT akeneo_pim -e "SELECT COUNT(*) as total_attributes FROM pim_catalog_attribute;"

echo -e "\n--- Category Count ---"
$MARIADB106 -u $MARIADB106_USER -p"$MARIADB106_PASS" -h $MARIADB106_HOST -P $MARIADB106_PORT akeneo_pim -e "SELECT COUNT(*) as total_categories FROM pim_catalog_category;"

echo -e "\n--- File Storage Count ---"
$MARIADB106 -u $MARIADB106_USER -p"$MARIADB106_PASS" -h $MARIADB106_HOST -P $MARIADB106_PORT akeneo_pim -e "SELECT COUNT(*) as total_files FROM akeneo_file_storage_file_info;"

echo -e "\n--- Recent Products (Last Updated) ---"
$MARIADB106 -u $MARIADB106_USER -p"$MARIADB106_PASS" -h $MARIADB106_HOST -P $MARIADB106_PORT akeneo_pim <<EOF
SELECT 
    identifier,
    is_enabled,
    updated
FROM pim_catalog_product
ORDER BY updated DESC
LIMIT 10;
EOF

echo ""
echo "=========================================="
echo "SECTION 4: AKENEO CONFIGURATION AUDIT"
echo "=========================================="

echo -e "\n--- Current Akeneo Configuration ---"
cd /home/pim/public_html
echo "Configuration in .env:"
grep -E "DATABASE" .env 2>/dev/null | head -10

echo -e "\nConfiguration in .env.local:"
cat .env.local 2>/dev/null

echo ""
echo "=========================================="
echo "SECTION 5: TABLE STRUCTURE COMPARISON"
echo "=========================================="

echo -e "\n--- Table Count Comparison ---"
echo "Tables in DEFAULT MariaDB (3306):"
$DEFAULT_MARIADB -h $DEFAULT_HOST -P $DEFAULT_PORT akeneo_pim -e "SELECT COUNT(*) as table_count FROM information_schema.tables WHERE table_schema='akeneo_pim';"

echo "Tables in MariaDB 10.6 (3307):"
$MARIADB106 -u $MARIADB106_USER -p"$MARIADB106_PASS" -h $MARIADB106_HOST -P $MARIADB106_PORT akeneo_pim -e "SELECT COUNT(*) as table_count FROM information_schema.tables WHERE table_schema='akeneo_pim';"

echo -e "\n--- Key Tables Row Counts (DEFAULT 3306) ---"
$DEFAULT_MARIADB -h $DEFAULT_HOST -P $DEFAULT_PORT akeneo_pim <<EOF
SELECT 'pim_catalog_product' as table_name, COUNT(*) as rows FROM pim_catalog_product
UNION ALL
SELECT 'pim_catalog_category', COUNT(*) FROM pim_catalog_category
UNION ALL
SELECT 'pim_catalog_attribute', COUNT(*) FROM pim_catalog_attribute
UNION ALL
SELECT 'pim_catalog_family', COUNT(*) FROM pim_catalog_family
UNION ALL
SELECT 'pim_catalog_channel', COUNT(*) FROM pim_catalog_channel
UNION ALL
SELECT 'akeneo_file_storage_file_info', COUNT(*) FROM akeneo_file_storage_file_info
UNION ALL
SELECT 'pim_catalog_product_model', COUNT(*) FROM pim_catalog_product_model;
EOF

echo -e "\n--- Key Tables Row Counts (MariaDB 10.6 - 3307) ---"
$MARIADB106 -u $MARIADB106_USER -p"$MARIADB106_PASS" -h $MARIADB106_HOST -P $MARIADB106_PORT akeneo_pim <<EOF
SELECT 'pim_catalog_product' as table_name, COUNT(*) as rows FROM pim_catalog_product
UNION ALL
SELECT 'pim_catalog_category', COUNT(*) FROM pim_catalog_category
UNION ALL
SELECT 'pim_catalog_attribute', COUNT(*) FROM pim_catalog_attribute
UNION ALL
SELECT 'pim_catalog_family', COUNT(*) FROM pim_catalog_family
UNION ALL
SELECT 'pim_catalog_channel', COUNT(*) FROM pim_catalog_channel
UNION ALL
SELECT 'akeneo_file_storage_file_info', COUNT(*) FROM akeneo_file_storage_file_info
UNION ALL
SELECT 'pim_catalog_product_model', COUNT(*) FROM pim_catalog_product_model;
EOF

echo ""
echo "=========================================="
echo "SECTION 6: DATA FRESHNESS COMPARISON"
echo "=========================================="

echo -e "\n--- Most Recent Update Times (DEFAULT 3306) ---"
$DEFAULT_MARIADB -h $DEFAULT_HOST -P $DEFAULT_PORT akeneo_pim -e "SELECT MAX(updated) as last_product_update FROM pim_catalog_product;"

echo -e "\n--- Most Recent Update Times (MariaDB 10.6 - 3307) ---"
$MARIADB106 -u $MARIADB106_USER -p"$MARIADB106_PASS" -h $MARIADB106_HOST -P $MARIADB106_PORT akeneo_pim -e "SELECT MAX(updated) as last_product_update FROM pim_catalog_product;"

echo ""
echo "=========================================="
echo "SECTION 7: DISK SPACE ANALYSIS"
echo "=========================================="

echo -e "\n--- Database Sizes (DEFAULT 3306) ---"
$DEFAULT_MARIADB -h $DEFAULT_HOST -P $DEFAULT_PORT information_schema <<EOF
SELECT 
    table_schema as database_name,
    ROUND(SUM(data_length + index_length) / 1024 / 1024, 2) as size_mb
FROM information_schema.tables
WHERE table_schema = 'akeneo_pim'
GROUP BY table_schema;
EOF

echo -e "\n--- Database Sizes (MariaDB 10.6 - 3307) ---"
$MARIADB106 -u $MARIADB106_USER -p"$MARIADB106_PASS" -h $MARIADB106_HOST -P $MARIADB106_PORT information_schema <<EOF
SELECT 
    table_schema as database_name,
    ROUND(SUM(data_length + index_length) / 1024 / 1024, 2) as size_mb
FROM information_schema.tables
WHERE table_schema = 'akeneo_pim'
GROUP BY table_schema;
EOF

echo ""
echo "=========================================="
echo "SECTION 8: SUMMARY & RECOMMENDATIONS"
echo "=========================================="

# Get product counts for comparison
DEFAULT_PRODUCTS=$($DEFAULT_MARIADB -h $DEFAULT_HOST -P $DEFAULT_PORT akeneo_pim -sN -e "SELECT COUNT(*) FROM pim_catalog_product;")
MARIADB106_PRODUCTS=$($MARIADB106 -u $MARIADB106_USER -p"$MARIADB106_PASS" -h $MARIADB106_HOST -P $MARIADB106_PORT akeneo_pim -sN -e "SELECT COUNT(*) FROM pim_catalog_product;")

# Get channel counts
DEFAULT_CHANNELS=$($DEFAULT_MARIADB -h $DEFAULT_HOST -P $DEFAULT_PORT akeneo_pim -sN -e "SELECT COUNT(*) FROM pim_catalog_channel;")
MARIADB106_CHANNELS=$($MARIADB106 -u $MARIADB106_USER -p"$MARIADB106_PASS" -h $MARIADB106_HOST -P $MARIADB106_PORT akeneo_pim -sN -e "SELECT COUNT(*) FROM pim_catalog_channel;")

echo ""
echo "┌─────────────────────────────────────────────────────────┐"
echo "│                    SUMMARY                              │"
echo "└─────────────────────────────────────────────────────────┘"
echo ""
echo "DEFAULT MARIADB (port 3306):"
echo "  - Products: $DEFAULT_PRODUCTS"
echo "  - Channels: $DEFAULT_CHANNELS"
echo ""
echo "MARIADB 10.6 (port 3307):"
echo "  - Products: $MARIADB106_PRODUCTS"
echo "  - Channels: $MARIADB106_CHANNELS"
echo ""

# Determine which is production
if [ "$MARIADB106_PRODUCTS" -gt "$DEFAULT_PRODUCTS" ]; then
    echo "✓ PRODUCTION DATABASE: MariaDB 10.6 (port 3307)"
    echo "  Reason: Has MORE products ($MARIADB106_PRODUCTS vs $DEFAULT_PRODUCTS)"
    PRODUCTION="MariaDB 10.6"
elif [ "$DEFAULT_PRODUCTS" -gt "$MARIADB106_PRODUCTS" ]; then
    echo "⚠ WARNING: Default MariaDB has MORE products!"
    echo "  DEFAULT: $DEFAULT_PRODUCTS products"
    echo "  MariaDB 10.6: $MARIADB106_PRODUCTS products"
    PRODUCTION="DEFAULT (but should investigate)"
else
    echo "⚠ EQUAL product counts - need to check update times"
    PRODUCTION="UNCLEAR"
fi

echo ""
echo "CURRENT AKENEO CONFIGURATION:"
grep "APP_DATABASE_PORT" /home/pim/public_html/.env | head -1

if grep -q "APP_DATABASE_PORT=3307" /home/pim/public_html/.env; then
    echo "✓ Akeneo is configured to use MariaDB 10.6 (port 3307)"
    if [ "$PRODUCTION" == "MariaDB 10.6" ]; then
        echo "✓ Configuration is CORRECT - using production database"
    else
        echo "⚠ Configuration may need review"
    fi
else
    echo "⚠ Akeneo is NOT using port 3307!"
    echo "  ACTION REQUIRED: Update configuration to use MariaDB 10.6"
fi

echo ""
echo "=========================================="
echo "SECTION 9: RECOMMENDED ACTIONS"
echo "=========================================="

if [ "$PRODUCTION" == "MariaDB 10.6" ] && grep -q "APP_DATABASE_PORT=3307" /home/pim/public_html/.env; then
    echo ""
    echo "✓ SYSTEM IS CORRECTLY CONFIGURED"
    echo ""
    echo "Recommended actions:"
    echo "1. Continue using MariaDB 10.6 (port 3307)"
    echo "2. Consider stopping default MariaDB to avoid confusion"
    echo "3. Create backup before any changes:"
    echo "   /opt/mariadb10.6/mariadb/bin/mysqldump -u root -p'YourNewStrongPassword' \\"
    echo "     -h 127.0.0.1 -P 3307 akeneo_pim | gzip > /home/pim/backups/akeneo_$(date +%Y%m%d).sql.gz"
    echo ""
    echo "To stop default MariaDB:"
    echo "   sudo systemctl stop mariadb"
    echo "   sudo systemctl disable mariadb"
else
    echo ""
    echo "⚠ CONFIGURATION NEEDS ATTENTION"
    echo ""
    echo "Required actions:"
    echo "1. Verify which database has the correct production data"
    echo "2. Update Akeneo .env to point to correct instance"
    echo "3. Backup both databases before making changes"
    echo "4. Stop unused MariaDB instance"
fi

echo ""
echo "=========================================="
echo "AUDIT COMPLETE"
echo "=========================================="
echo "Report saved to: $REPORT_FILE"
echo "Date: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

exit 0
