#!/bin/bash

# Create Integration Channels for JDE Edwards and Cegid ERP
# Date: April 23, 2026

set -e

echo "============================================"
echo "AKENEO PIM - CREATE INTEGRATION CHANNELS"
echo "============================================"
echo ""

DB_HOST="127.0.0.1"
DB_PORT="3307"
DB_USER="akeneo_pim"
DB_PASS="akeneo_pim"
DB_NAME="akeneo_pim"

echo "Creating integration channels..."
echo ""

# Get IDs
ROOT_CATEGORY_ID=$(mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASS" --skip-ssl "$DB_NAME" -sN -e "SELECT id FROM pim_catalog_category WHERE code = 'master' LIMIT 1" 2>/dev/null)
FR_LOCALE_ID=$(mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASS" --skip-ssl "$DB_NAME" -sN -e "SELECT id FROM pim_catalog_locale WHERE code = 'fr_FR' LIMIT 1" 2>/dev/null)
EN_LOCALE_ID=$(mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASS" --skip-ssl "$DB_NAME" -sN -e "SELECT id FROM pim_catalog_locale WHERE code = 'en_US' LIMIT 1" 2>/dev/null)
DZD_CURRENCY_ID=$(mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASS" --skip-ssl "$DB_NAME" -sN -e "SELECT id FROM pim_catalog_currency WHERE code = 'DZD' LIMIT 1" 2>/dev/null)
EUR_CURRENCY_ID=$(mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASS" --skip-ssl "$DB_NAME" -sN -e "SELECT id FROM pim_catalog_currency WHERE code = 'EUR' LIMIT 1" 2>/dev/null)

echo "Retrieved IDs:"
echo "  Root Category ID: $ROOT_CATEGORY_ID"
echo "  FR Locale ID: $FR_LOCALE_ID"
echo "  EN Locale ID: $EN_LOCALE_ID"
echo "  DZD Currency ID: $DZD_CURRENCY_ID"
echo "  EUR Currency ID: $EUR_CURRENCY_ID"
echo ""

# 1. Create JDE Edwards Channel
echo "[1/2] Creating JDE Edwards channel..."

mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASS" --skip-ssl "$DB_NAME" <<SQL 2>/dev/null
-- Check if channel exists
SET @channel_exists = (SELECT COUNT(*) FROM pim_catalog_channel WHERE code = 'jde_edwards');

-- Create channel if doesn't exist
INSERT INTO pim_catalog_channel (code, category_id, conversionUnits)
SELECT 'jde_edwards', $ROOT_CATEGORY_ID, '[]'
WHERE @channel_exists = 0;

-- Get channel ID
SET @jde_channel_id = (SELECT id FROM pim_catalog_channel WHERE code = 'jde_edwards');

-- Link locales
INSERT IGNORE INTO pim_catalog_channel_locale (channel_id, locale_id)
VALUES (@jde_channel_id, $FR_LOCALE_ID),
       (@jde_channel_id, $EN_LOCALE_ID);

-- Link currencies
INSERT IGNORE INTO pim_catalog_channel_currency (channel_id, currency_id)
VALUES (@jde_channel_id, $DZD_CURRENCY_ID),
       (@jde_channel_id, $EUR_CURRENCY_ID);

-- Create channel translation
INSERT IGNORE INTO pim_catalog_channel_translation (foreign_key, locale, label)
VALUES (@jde_channel_id, 'en_US', 'JDE Edwards ERP'),
       (@jde_channel_id, 'fr_FR', 'JDE Edwards ERP');
SQL

if [ $? -eq 0 ]; then
    echo "  ✓ JDE Edwards channel created successfully"
else
    echo "  ✗ Failed to create JDE Edwards channel"
fi
echo ""

# 2. Create Cegid ERP Channel
echo "[2/2] Creating Cegid ERP channel..."

mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASS" --skip-ssl "$DB_NAME" <<SQL 2>/dev/null
-- Check if channel exists
SET @channel_exists = (SELECT COUNT(*) FROM pim_catalog_channel WHERE code = 'cegid_erp');

-- Create channel if doesn't exist
INSERT INTO pim_catalog_channel (code, category_id, conversionUnits)
SELECT 'cegid_erp', $ROOT_CATEGORY_ID, '[]'
WHERE @channel_exists = 0;

-- Get channel ID
SET @cegid_channel_id = (SELECT id FROM pim_catalog_channel WHERE code = 'cegid_erp');

-- Link locales
INSERT IGNORE INTO pim_catalog_channel_locale (channel_id, locale_id)
VALUES (@cegid_channel_id, $FR_LOCALE_ID),
       (@cegid_channel_id, $EN_LOCALE_ID);

-- Link currencies
INSERT IGNORE INTO pim_catalog_channel_currency (channel_id, currency_id)
VALUES (@cegid_channel_id, $DZD_CURRENCY_ID),
       (@cegid_channel_id, $EUR_CURRENCY_ID);

-- Create channel translation
INSERT IGNORE INTO pim_catalog_channel_translation (foreign_key, locale, label)
VALUES (@cegid_channel_id, 'en_US', 'Cegid ERP'),
       (@cegid_channel_id, 'fr_FR', 'Cegid ERP');
SQL

if [ $? -eq 0 ]; then
    echo "  ✓ Cegid ERP channel created successfully"
else
    echo "  ✗ Failed to create Cegid ERP channel"
fi
echo ""

# Verify channels
echo "Verifying created channels..."
echo ""

mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASS" --skip-ssl "$DB_NAME" <<SQL 2>/dev/null
SELECT 
    c.code as channel_code,
    COUNT(DISTINCT cl.locale_id) as locales_count,
    COUNT(DISTINCT cc.currency_id) as currencies_count
FROM pim_catalog_channel c
LEFT JOIN pim_catalog_channel_locale cl ON c.id = cl.channel_id
LEFT JOIN pim_catalog_channel_currency cc ON c.id = cc.channel_id
WHERE c.code IN ('jde_edwards', 'cegid_erp', 'ecommerce')
GROUP BY c.id, c.code
ORDER BY c.code;
SQL

echo ""
echo "============================================"
echo "CHANNELS CREATED SUCCESSFULLY"
echo "============================================"
echo ""
echo "Summary:"
echo "  ✓ JDE Edwards channel"
echo "  ✓ Cegid ERP channel"
echo "  ✓ Existing ecommerce channel"
echo ""
echo "Next steps:"
echo "  1. Clear cache: php bin/console cache:clear --env=prod"
echo "  2. Verify in Akeneo UI: Settings > Channels"
echo "  3. Configure API connections for each channel"
echo ""
