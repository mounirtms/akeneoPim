#!/bin/bash

# Akeneo PIM Database Verification Script
# This script checks the database for missing master data

echo "============================================="
echo "Akeneo PIM Database Verification"
echo "Date: $(date)"
echo "============================================="
echo ""

# Database credentials from .env
DB_HOST="127.0.0.1"
DB_PORT="3307"
DB_NAME="akeneo_pim"
DB_USER="akeneo_pim"
DB_PASS="akeneo_pim"

# MySQL command with SSL disabled
MYSQL_CMD="mysql -h $DB_HOST -P $DB_PORT -u $DB_USER -p$DB_PASS $DB_NAME --ssl=0"

echo "=== TESTING DATABASE CONNECTION ==="
if echo "SELECT 1;" | $MYSQL_CMD 2>/dev/null | grep -q "1"; then
    echo "✅ Database connection successful"
else
    echo "❌ Database connection failed"
    echo "Error: Cannot connect to MariaDB on $DB_HOST:$DB_PORT"
    exit 1
fi
echo ""

echo "=== MARIADB VERSION ==="
$MYSQL_CMD -e "SELECT VERSION();" 2>/dev/null
echo ""

echo "=== DATA COUNTS ==="
$MYSQL_CMD -e "
SELECT 
  'Categories' as entity,
  COUNT(*) as count 
FROM pim_catalog_category
UNION ALL
SELECT 
  'Attribute Groups' as entity,
  COUNT(*) as count 
FROM pim_catalog_attribute_group
UNION ALL
SELECT 
  'Attributes' as entity,
  COUNT(*) as count 
FROM pim_catalog_attribute
UNION ALL
SELECT 
  'Families' as entity,
  COUNT(*) as count 
FROM pim_catalog_family
UNION ALL
SELECT 
  'Products' as entity,
  COUNT(*) as count 
FROM pim_catalog_product
UNION ALL
SELECT 
  'Channels' as entity,
  COUNT(*) as count 
FROM pim_catalog_channel
UNION ALL
SELECT 
  'Locales' as entity,
  COUNT(*) as count 
FROM pim_catalog_locale
UNION ALL
SELECT 
  'Currencies' as entity,
  COUNT(*) as count 
FROM pim_catalog_currency
;" 2>/dev/null
echo ""

echo "=== SAMPLE CATEGORIES (first 10) ==="
$MYSQL_CMD -e "
SELECT 
  id,
  code,
  parent_id,
  created
FROM pim_catalog_category 
ORDER BY id 
LIMIT 10;
" 2>/dev/null
echo ""

echo "=== SAMPLE ATTRIBUTE GROUPS (first 10) ==="
$MYSQL_CMD -e "
SELECT 
  id,
  code,
  created
FROM pim_catalog_attribute_group 
ORDER BY id 
LIMIT 10;
" 2>/dev/null
echo ""

echo "=== SAMPLE ATTRIBUTES (first 10) ==="
$MYSQL_CMD -e "
SELECT 
  id,
  code,
  attribute_type,
  is_required
FROM pim_catalog_attribute 
ORDER BY id 
LIMIT 10;
" 2>/dev/null
echo ""

echo "=== SAMPLE FAMILIES (first 10) ==="
$MYSQL_CMD -e "
SELECT 
  id,
  code,
  created
FROM pim_catalog_family 
ORDER BY id 
LIMIT 10;
" 2>/dev/null
echo ""

echo "=== SAMPLE PRODUCTS (first 5) ==="
$MYSQL_CMD -e "
SELECT 
  id,
  identifier,
  family_id,
  created
FROM pim_catalog_product 
ORDER BY id 
LIMIT 5;
" 2>/dev/null
echo ""

echo "=== CHANNELS LIST ==="
$MYSQL_CMD -e "
SELECT 
  id,
  code
FROM pim_catalog_channel;
" 2>/dev/null
echo ""

echo "=== LOCALES LIST ==="
$MYSQL_CMD -e "
SELECT 
  id,
  code,
  is_activated
FROM pim_catalog_locale;
" 2>/dev/null
echo ""

echo "============================================="
echo "Verification Complete"
echo "============================================="
echo ""
echo "📊 Summary:"
echo "- If counts show 0, the data is missing and needs to be restored"
echo "- If categories/attributes/families are missing, sync cannot proceed"
echo "- Expected product count: ~9,538"
echo ""
echo "💡 Next Steps:"
echo "1. Review the counts above"
echo "2. If data is missing, check backup or run import"
echo "3. If data looks good, proceed with Magento sync"
echo ""
