#!/bin/bash

################################################################################
# Phase 1.2: Fix Database Unserialization Errors (Corrected)
# Purpose: Fix corrupted serialized data and NULL locale issues
# Date: 2026-04-23
################################################################################

echo "=========================================="
echo "PHASE 1.2: Fixing Database Unserialization Errors"
echo "=========================================="
echo "Date: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

DB="/opt/mariadb10.6/mariadb/bin/mysql -u root -p'YourNewStrongPassword' -h 127.0.0.1 -P 3307 akeneo_pim"

# Step 1: Get default locale IDs
echo "Step 1: Getting default locale IDs..."
FR_LOCALE=$($DB -sN -e "SELECT id FROM pim_catalog_locale WHERE code='fr_FR' LIMIT 1;")
EN_LOCALE=$($DB -sN -e "SELECT id FROM pim_catalog_locale WHERE code='en_US' LIMIT 1;")
ROOT_CATEGORY=$($DB -sN -e "SELECT id FROM pim_catalog_category WHERE code='master' LIMIT 1;")

echo "  fr_FR locale ID: $FR_LOCALE"
echo "  en_US locale ID: $EN_LOCALE"
echo "  Root category ID: $ROOT_CATEGORY"
echo ""

# Step 2: Fix NULL ui_locale_id
echo "Step 2: Fixing NULL ui_locale_id in oro_user..."
NULL_UI=$($DB -sN -e "SELECT COUNT(*) FROM oro_user WHERE ui_locale_id IS NULL;")
if [ "$NULL_UI" -gt 0 ]; then
    echo "  Found $NULL_UI users with NULL ui_locale_id"
    $DB -e "UPDATE oro_user SET ui_locale_id = $FR_LOCALE WHERE ui_locale_id IS NULL;"
    echo "  ✓ Fixed $NULL_UI users"
else
    echo "  ✓ No NULL ui_locale_id found"
fi
echo ""

# Step 3: Fix NULL default_tree_id
echo "Step 3: Fixing NULL default_tree_id in oro_user..."
NULL_TREE=$($DB -sN -e "SELECT COUNT(*) FROM oro_user WHERE default_tree_id IS NULL;")
if [ "$NULL_TREE" -gt 0 ]; then
    echo "  Found $NULL_TREE users with NULL default_tree_id"
    $DB -e "UPDATE oro_user SET default_tree_id = $ROOT_CATEGORY WHERE default_tree_id IS NULL;"
    echo "  ✓ Fixed $NULL_TREE users"
else
    echo "  ✓ No NULL default_tree_id found"
fi
echo ""

# Step 4: Fix corrupted properties
echo "Step 4: Checking for corrupted properties..."
$DB -e "SELECT id, username, LENGTH(COALESCE(properties, '')) as prop_length FROM oro_user;"
echo ""

# Step 5: Fix empty or short properties (likely corrupted)
echo "Step 5: Fixing corrupted properties..."
$DB <<EOF
UPDATE oro_user 
SET properties = 'a:0:{}' 
WHERE properties IS NULL 
   OR LENGTH(properties) < 5 
   OR properties = '';
EOF
echo "  ✓ Fixed corrupted properties"
echo ""

# Step 6: Verify users
echo "Step 6: Verifying oro_user table..."
$DB -e "SELECT id, username, ui_locale_id, default_tree_id, LENGTH(COALESCE(properties, '')) as prop_len FROM oro_user;"
echo ""

# Step 7: Clear cache
echo "Step 7: Clearing cache..."
cd /home/pim/public_html
php bin/console cache:clear --env=prod --no-warmup > /dev/null 2>&1
bash webapp/fix_cache_permissions.sh > /dev/null 2>&1
echo "  ✓ Cache cleared"
echo ""

echo "=========================================="
echo "Phase 1.2 Complete"
echo "=========================================="
echo ""
echo "Fixed issues:"
echo "  - NULL ui_locale_id: $NULL_UI users"
echo "  - NULL default_tree_id: $NULL_TREE users"
echo "  - Corrupted properties: Fixed all"
echo ""

exit 0
