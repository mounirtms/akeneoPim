#!/bin/bash

################################################################################
# Phase 1.2: Fix Database Unserialization Errors
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
echo "Step 1: Getting default locale and scope IDs..."
EN_LOCALE=$($DB -sN -e "SELECT id FROM pim_catalog_locale WHERE code='en_US' LIMIT 1;")
FR_LOCALE=$($DB -sN -e "SELECT id FROM pim_catalog_locale WHERE code='fr_FR' LIMIT 1;")
ECOMMERCE_SCOPE=$($DB -sN -e "SELECT id FROM pim_catalog_channel WHERE code='ecommerce' LIMIT 1;")

echo "  en_US locale ID: $EN_LOCALE"
echo "  fr_FR locale ID: $FR_LOCALE"
echo "  ecommerce channel ID: $ECOMMERCE_SCOPE"
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

# Step 3: Fix NULL catalog_locale_id
echo "Step 3: Fixing NULL catalog_locale_id in oro_user..."
NULL_CAT=$($DB -sN -e "SELECT COUNT(*) FROM oro_user WHERE catalog_locale_id IS NULL;")
if [ "$NULL_CAT" -gt 0 ]; then
    echo "  Found $NULL_CAT users with NULL catalog_locale_id"
    $DB -e "UPDATE oro_user SET catalog_locale_id = $FR_LOCALE WHERE catalog_locale_id IS NULL;"
    echo "  ✓ Fixed $NULL_CAT users"
else
    echo "  ✓ No NULL catalog_locale_id found"
fi
echo ""

# Step 4: Fix NULL catalog_scope_id
echo "Step 4: Fixing NULL catalog_scope_id in oro_user..."
NULL_SCOPE=$($DB -sN -e "SELECT COUNT(*) FROM oro_user WHERE catalog_scope_id IS NULL;")
if [ "$NULL_SCOPE" -gt 0 ]; then
    echo "  Found $NULL_SCOPE users with NULL catalog_scope_id"
    $DB -e "UPDATE oro_user SET catalog_scope_id = $ECOMMERCE_SCOPE WHERE catalog_scope_id IS NULL;"
    echo "  ✓ Fixed $NULL_SCOPE users"
else
    echo "  ✓ No NULL catalog_scope_id found"
fi
echo ""

# Step 5: Verify users
echo "Step 5: Verifying oro_user table..."
$DB -e "SELECT id, username, ui_locale_id, catalog_locale_id, catalog_scope_id FROM oro_user;"
echo ""

# Step 6: Clear cache
echo "Step 6: Clearing cache..."
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
echo "  - NULL catalog_locale_id: $NULL_CAT users"
echo "  - NULL catalog_scope_id: $NULL_SCOPE users"
echo ""

exit 0
