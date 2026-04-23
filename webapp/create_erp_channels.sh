#!/bin/bash

################################################################################
# Create ERP Integration Channels for Akeneo PIM
# Purpose: Create JDE Edwards and Cegid ERP channels for multi-system integration
# Date: 2026-04-23
################################################################################

AKENEO_ROOT="/home/pim/public_html"
DB_NAME="akeneo_pim"

echo "==================================="
echo "Creating ERP Integration Channels"
echo "==================================="
echo "Date: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

cd "$AKENEO_ROOT"

# Get required IDs
echo "Fetching required IDs..."
ROOT_CATEGORY_ID=$(mariadb $DB_NAME -sN -e "SELECT id FROM pim_catalog_category WHERE code='master';" 2>&1)
FR_LOCALE_ID=$(mariadb $DB_NAME -sN -e "SELECT id FROM pim_catalog_locale WHERE code='fr_FR';" 2>&1)
EN_LOCALE_ID=$(mariadb $DB_NAME -sN -e "SELECT id FROM pim_catalog_locale WHERE code='en_US';" 2>&1)
DZD_CURRENCY_ID=$(mariadb $DB_NAME -sN -e "SELECT id FROM pim_catalog_currency WHERE code='DZD';" 2>&1)
EUR_CURRENCY_ID=$(mariadb $DB_NAME -sN -e "SELECT id FROM pim_catalog_currency WHERE code='EUR';" 2>&1)

echo "Root Category ID: $ROOT_CATEGORY_ID"
echo "FR Locale ID: $FR_LOCALE_ID"
echo "EN Locale ID: $EN_LOCALE_ID"
echo "DZD Currency ID: $DZD_CURRENCY_ID"
echo "EUR Currency ID: $EUR_CURRENCY_ID"
echo ""

# Check if channels already exist
echo "Checking for existing channels..."
JDE_EXISTS=$(mariadb $DB_NAME -sN -e "SELECT COUNT(*) FROM pim_catalog_channel WHERE code='jde_edwards';" 2>&1)
CEGID_EXISTS=$(mariadb $DB_NAME -sN -e "SELECT COUNT(*) FROM pim_catalog_channel WHERE code='cegid_erp';" 2>&1)

echo "JDE Edwards channel exists: $JDE_EXISTS"
echo "Cegid ERP channel exists: $CEGID_EXISTS"
echo ""

# Create JDE Edwards Channel
if [ "$JDE_EXISTS" == "0" ]; then
    echo "Creating JDE Edwards Integration Channel..."
    
    mariadb $DB_NAME <<EOF
-- Insert JDE Edwards channel
INSERT INTO pim_catalog_channel (code, category_id, conversionUnits)
VALUES ('jde_edwards', $ROOT_CATEGORY_ID, 'a:0:{}');

SET @jde_channel_id = LAST_INSERT_ID();

-- Add channel translation
INSERT INTO pim_catalog_channel_translation (foreign_key, locale, label)
VALUES (@jde_channel_id, 'en_US', 'JDE Edwards ERP'),
       (@jde_channel_id, 'fr_FR', 'JDE Edwards ERP');

-- Link locales to channel
INSERT INTO pim_catalog_channel_locale (channel_id, locale_id)
VALUES (@jde_channel_id, $FR_LOCALE_ID),
       (@jde_channel_id, $EN_LOCALE_ID);

-- Link currencies to channel
INSERT INTO pim_catalog_channel_currency (channel_id, currency_id)
VALUES (@jde_channel_id, $DZD_CURRENCY_ID),
       (@jde_channel_id, $EUR_CURRENCY_ID);
EOF
    
    if [ $? -eq 0 ]; then
        echo "✓ JDE Edwards channel created successfully"
    else
        echo "✗ Failed to create JDE Edwards channel"
    fi
else
    echo "⚠ JDE Edwards channel already exists, skipping"
fi

echo ""

# Create Cegid ERP Channel
if [ "$CEGID_EXISTS" == "0" ]; then
    echo "Creating Cegid ERP Integration Channel..."
    
    mariadb $DB_NAME <<EOF
-- Insert Cegid ERP channel
INSERT INTO pim_catalog_channel (code, category_id, conversionUnits)
VALUES ('cegid_erp', $ROOT_CATEGORY_ID, 'a:0:{}');

SET @cegid_channel_id = LAST_INSERT_ID();

-- Add channel translation
INSERT INTO pim_catalog_channel_translation (foreign_key, locale, label)
VALUES (@cegid_channel_id, 'en_US', 'Cegid ERP'),
       (@cegid_channel_id, 'fr_FR', 'Cegid ERP');

-- Link locales to channel
INSERT INTO pim_catalog_channel_locale (channel_id, locale_id)
VALUES (@cegid_channel_id, $FR_LOCALE_ID),
       (@cegid_channel_id, $EN_LOCALE_ID);

-- Link currencies to channel
INSERT INTO pim_catalog_channel_currency (channel_id, currency_id)
VALUES (@cegid_channel_id, $DZD_CURRENCY_ID),
       (@cegid_channel_id, $EUR_CURRENCY_ID);
EOF
    
    if [ $? -eq 0 ]; then
        echo "✓ Cegid ERP channel created successfully"
    else
        echo "✗ Failed to create Cegid ERP channel"
    fi
else
    echo "⚠ Cegid ERP channel already exists, skipping"
fi

echo ""
echo "==================================="
echo "Verifying Channels"
echo "==================================="

mariadb $DB_NAME <<EOF
SELECT 
    c.code as channel_code,
    COUNT(DISTINCT cl.locale_id) as locales,
    COUNT(DISTINCT cc.currency_id) as currencies
FROM pim_catalog_channel c
LEFT JOIN pim_catalog_channel_locale cl ON c.id = cl.channel_id
LEFT JOIN pim_catalog_channel_currency cc ON c.id = cc.channel_id
GROUP BY c.code
ORDER BY c.code;
EOF

echo ""
echo "==================================="
echo "Channel Creation Complete"
echo "==================================="
echo ""
echo "Next steps:"
echo "1. Clear cache: php bin/console cache:clear --env=prod"
echo "2. Verify channels in Akeneo UI: Settings > Channels"
echo "3. Configure API connections for JDE Edwards and Cegid ERP"
echo ""

exit 0
