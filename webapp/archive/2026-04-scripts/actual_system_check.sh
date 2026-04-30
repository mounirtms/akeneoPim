#!/bin/bash

echo "======================================================================"
echo "ACTUAL SYSTEM STATUS CHECK - April 23, 2026"
echo "======================================================================"
echo ""

# 1. Check Elasticsearch indices with actual data
echo "1. ELASTICSEARCH CURRENT INDICES:"
echo "---------------------------------"
curl -s "http://localhost:9200/_cat/indices?v" | head -20
echo ""

# 2. Check if the old indices exist
echo "2. CHECKING FOR LEGACY INDICES:"
echo "-------------------------------"
OLD_INDEX=$(curl -s "http://localhost:9200/_cat/indices" | grep "akeneo_pim_product_and_product_model" | grep -v "d7b81f90" | head -1)
if [ -n "$OLD_INDEX" ]; then
    echo "Found old index: $OLD_INDEX"
else
    echo "No old indices found"
fi
echo ""

# 3. Check the actual database connection
echo "3. DATABASE CONNECTION TEST:"
echo "----------------------------"
mysql -u u341287766_akeneodb -pTmsPim2o24 u341287766_akeneodb -e "SELECT VERSION();" 2>&1 | grep -v "password"
echo ""

# 4. List all tables in database
echo "4. DATABASE TABLES:"
echo "-------------------"
mysql -u u341287766_akeneodb -pTmsPim2o24 u341287766_akeneodb -e "SHOW TABLES LIKE 'pim_%';" 2>&1 | grep -v "password" | head -30
echo ""

# 5. Check if there's data in product table
echo "5. CHECKING PRODUCT TABLE:"
echo "--------------------------"
PRODUCT_CHECK=$(mysql -u u341287766_akeneodb -pTmsPim2o24 u341287766_akeneodb -sN -e "SHOW TABLES LIKE 'pim_catalog_product';" 2>&1 | grep -v "password")
if [ -n "$PRODUCT_CHECK" ]; then
    echo "Product table exists. Checking row count..."
    mysql -u u341287766_akeneodb -pTmsPim2o24 u341287766_akeneodb -e "SELECT COUNT(*) as product_count FROM pim_catalog_product;" 2>&1 | grep -v "password"
else
    echo "Product table does not exist!"
fi
echo ""

# 6. Check website accessibility
echo "6. WEBSITE STATUS:"
echo "------------------"
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" https://pim.technostationery.com/user/login)
echo "Login Page HTTP Status: $HTTP_STATUS"
echo ""

# 7. Check cache status
echo "7. CACHE DIRECTORY STATUS:"
echo "--------------------------"
ls -lah /home/pim/public_html/var/cache/prod/ 2>/dev/null | head -15
echo ""

# 8. Check var/logs for recent errors
echo "8. RECENT LOG ERRORS (last 10 lines):"
echo "--------------------------------------"
tail -10 /home/pim/public_html/var/logs/prod.log 2>/dev/null
echo ""

# 9. Test database query directly
echo "9. DIRECT DATABASE QUERY TEST:"
echo "-------------------------------"
echo "Testing locale table..."
mysql -u u341287766_akeneodb -pTmsPim2o24 u341287766_akeneodb -e "SELECT * FROM pim_catalog_locale LIMIT 5;" 2>&1 | grep -v "password"
echo ""

echo "Testing channel table..."
mysql -u u341287766_akeneodb -pTmsPim2o24 u341287766_akeneodb -e "SELECT * FROM pim_catalog_channel LIMIT 5;" 2>&1 | grep -v "password"
echo ""

# 10. Check PHP version and extensions
echo "10. PHP ENVIRONMENT:"
echo "--------------------"
php -v | head -2
echo ""
echo "PHP Extensions (relevant):"
php -m | grep -E "pdo|mysql|curl|json|xml"
echo ""

echo "======================================================================"
echo "CHECK COMPLETE"
echo "======================================================================"

