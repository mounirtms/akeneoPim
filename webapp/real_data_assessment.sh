#!/bin/bash

REPORT="REAL_DATA_QUALITY_ASSESSMENT_$(date +%Y%m%d_%H%M%S).txt"
echo "=====================================================================" | tee $REPORT
echo "REAL DATA QUALITY ASSESSMENT - Akeneo PIM" | tee -a $REPORT
echo "Date: $(date '+%Y-%m-%d %H:%M:%S')" | tee -a $REPORT
echo "=====================================================================" | tee -a $REPORT
echo "" | tee -a $REPORT

# Check .env for database connection
echo "1. DATABASE CONFIGURATION" | tee -a $REPORT
echo "-------------------------" | tee -a $REPORT
if [ -f /home/pim/public_html/.env ]; then
    echo "Database settings from .env:" | tee -a $REPORT
    grep -E "DATABASE_|APP_DATABASE" /home/pim/public_html/.env | grep -v "#" | tee -a $REPORT
else
    echo ".env file not found!" | tee -a $REPORT
fi
echo "" | tee -a $REPORT

# Check config/parameters.yml
echo "2. PARAMETERS CONFIGURATION" | tee -a $REPORT
echo "---------------------------" | tee -a $REPORT
if [ -f /home/pim/public_html/config/parameters.yml ]; then
    echo "Database parameters:" | tee -a $REPORT
    grep -A 5 "database_" /home/pim/public_html/config/parameters.yml | tee -a $REPORT
else
    echo "parameters.yml not found!" | tee -a $REPORT
fi
echo "" | tee -a $REPORT

# Check Elasticsearch status
echo "3. ELASTICSEARCH STATUS" | tee -a $REPORT
echo "-----------------------" | tee -a $REPORT
echo "All Indices:" | tee -a $REPORT
curl -s "http://localhost:9200/_cat/indices?v&h=index,docs.count,store.size,health" | tee -a $REPORT
echo "" | tee -a $REPORT

# Check the techno_stationery index
echo "Checking techno_stationery_product_1_v54 index:" | tee -a $REPORT
curl -s "http://localhost:9200/techno_stationery_product_1_v54/_count" | tee -a $REPORT
echo "" | tee -a $REPORT

# Sample data from techno_stationery index
echo "Sample product from techno_stationery index:" | tee -a $REPORT
curl -s "http://localhost:9200/techno_stationery_product_1_v54/_search?size=1" | python3 -m json.tool 2>/dev/null | head -100 | tee -a $REPORT
echo "" | tee -a $REPORT

# Check website status
echo "4. WEBSITE STATUS" | tee -a $REPORT
echo "-----------------" | tee -a $REPORT
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" https://pim.technostationery.com/user/login)
echo "Login page: HTTP $HTTP_CODE" | tee -a $REPORT

PAGE_LOAD=$(curl -s -o /dev/null -w "%{time_total}" https://pim.technostationery.com/user/login)
echo "Page load time: ${PAGE_LOAD}s" | tee -a $REPORT
echo "" | tee -a $REPORT

# Check cache status
echo "5. CACHE STATUS" | tee -a $REPORT
echo "---------------" | tee -a $REPORT
if [ -d /home/pim/public_html/var/cache/prod ]; then
    CACHE_SIZE=$(du -sh /home/pim/public_html/var/cache/prod 2>/dev/null | cut -f1)
    echo "Cache directory size: $CACHE_SIZE" | tee -a $REPORT
    echo "Cache permissions:" | tee -a $REPORT
    ls -ld /home/pim/public_html/var/cache/prod | tee -a $REPORT
fi
echo "" | tee -a $REPORT

# Check log files
echo "6. LOG FILE STATUS" | tee -a $REPORT
echo "------------------" | tee -a $REPORT
if [ -f /home/pim/public_html/var/logs/prod.log ]; then
    LOG_SIZE=$(du -h /home/pim/public_html/var/logs/prod.log | cut -f1)
    echo "prod.log size: $LOG_SIZE" | tee -a $REPORT
    echo "Recent critical errors:" | tee -a $REPORT
    grep -i "critical\|error\|exception" /home/pim/public_html/var/logs/prod.log 2>/dev/null | tail -5 | tee -a $REPORT
fi
echo "" | tee -a $REPORT

# Try to use Akeneo console commands
echo "7. AKENEO CONSOLE DIAGNOSTICS" | tee -a $REPORT
echo "-----------------------------" | tee -a $REPORT
cd /home/pim/public_html

# Try to get product count via console
echo "Attempting to count products via Akeneo API..." | tee -a $REPORT
php bin/console pim:product:query-help 2>&1 | head -5 | tee -a $REPORT
echo "" | tee -a $REPORT

# Check if we can list commands
echo "Available PIM commands:" | tee -a $REPORT
php bin/console list pim 2>&1 | grep -E "pim:(product|catalog|locale|channel)" | head -20 | tee -a $REPORT
echo "" | tee -a $REPORT

# Try alternative database connection (TCP)
echo "8. DATABASE CONNECTION (TCP ATTEMPT)" | tee -a $REPORT
echo "------------------------------------" | tee -a $REPORT
echo "Attempting TCP connection to localhost:3306..." | tee -a $REPORT
mysql -h 127.0.0.1 -u u341287766_akeneodb -pTmsPim2o24 u341287766_akeneodb -e "SELECT 'Connection successful' as status;" 2>&1 | grep -v "password" | tee -a $REPORT
echo "" | tee -a $REPORT

# If TCP works, try to get actual data
if mysql -h 127.0.0.1 -u u341287766_akeneodb -pTmsPim2o24 u341287766_akeneodb -e "SELECT 1;" &>/dev/null; then
    echo "TCP connection successful! Fetching data..." | tee -a $REPORT
    
    echo "9. ACTUAL DATA FROM DATABASE" | tee -a $REPORT
    echo "----------------------------" | tee -a $REPORT
    
    # Locales
    echo "Active Locales:" | tee -a $REPORT
    mysql -h 127.0.0.1 -u u341287766_akeneodb -pTmsPim2o24 u341287766_akeneodb -e "SELECT code, is_activated FROM pim_catalog_locale ORDER BY code;" 2>&1 | grep -v "password" | tee -a $REPORT
    echo "" | tee -a $REPORT
    
    # Channels
    echo "Channels:" | tee -a $REPORT
    mysql -h 127.0.0.1 -u u341287766_akeneodb -pTmsPim2o24 u341287766_akeneodb -e "SELECT code, category_tree FROM pim_catalog_channel;" 2>&1 | grep -v "password" | tee -a $REPORT
    echo "" | tee -a $REPORT
    
    # Product count
    echo "Product Statistics:" | tee -a $REPORT
    mysql -h 127.0.0.1 -u u341287766_akeneodb -pTmsPim2o24 u341287766_akeneodb -e "SELECT COUNT(*) as total_products FROM pim_catalog_product;" 2>&1 | grep -v "password" | tee -a $REPORT
    mysql -h 127.0.0.1 -u u341287766_akeneodb -pTmsPim2o24 u341287766_akeneodb -e "SELECT COUNT(*) as enabled_products FROM pim_catalog_product WHERE is_enabled = 1;" 2>&1 | grep -v "password" | tee -a $REPORT
    echo "" | tee -a $REPORT
    
    # Family count
    echo "Family Statistics:" | tee -a $REPORT
    mysql -h 127.0.0.1 -u u341287766_akeneodb -pTmsPim2o24 u341287766_akeneodb -e "SELECT COUNT(*) as total_families FROM pim_catalog_family;" 2>&1 | grep -v "password" | tee -a $REPORT
    echo "" | tee -a $REPORT
    
    # Top families
    echo "Top 10 Families by Product Count:" | tee -a $REPORT
    mysql -h 127.0.0.1 -u u341287766_akeneodb -pTmsPim2o24 u341287766_akeneodb -e "
    SELECT f.code, COUNT(p.id) as product_count
    FROM pim_catalog_family f
    LEFT JOIN pim_catalog_product p ON p.family_id = f.id
    GROUP BY f.code
    ORDER BY product_count DESC
    LIMIT 10;" 2>&1 | grep -v "password" | tee -a $REPORT
    echo "" | tee -a $REPORT
    
    # Attribute statistics
    echo "Attribute Statistics:" | tee -a $REPORT
    mysql -h 127.0.0.1 -u u341287766_akeneodb -pTmsPim2o24 u341287766_akeneodb -e "
    SELECT 
        COUNT(*) as total_attributes,
        SUM(is_localizable) as localizable,
        SUM(is_scopable) as scopable
    FROM pim_catalog_attribute;" 2>&1 | grep -v "password" | tee -a $REPORT
    echo "" | tee -a $REPORT
    
    # Completeness overview
    echo "Completeness Overview:" | tee -a $REPORT
    mysql -h 127.0.0.1 -u u341287766_akeneodb -pTmsPim2o24 u341287766_akeneodb -e "
    SELECT 
        c.code as channel,
        l.code as locale,
        ROUND(AVG(comp.ratio), 2) as avg_completeness,
        COUNT(*) as product_count
    FROM pim_catalog_completeness comp
    JOIN pim_catalog_channel c ON comp.channel_id = c.id
    JOIN pim_catalog_locale l ON comp.locale_id = l.id
    GROUP BY c.code, l.code;" 2>&1 | grep -v "password" | tee -a $REPORT
    echo "" | tee -a $REPORT
fi

echo "=====================================================================" | tee -a $REPORT
echo "ASSESSMENT COMPLETE - Report saved to: $REPORT" | tee -a $REPORT
echo "=====================================================================" | tee -a $REPORT

