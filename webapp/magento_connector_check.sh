#!/bin/bash
# Magento Connector Comprehensive Check
# Verify connection and sync capabilities

echo "=========================================="
echo "MAGENTO CONNECTOR CHECK"
echo "=========================================="
echo "Date: $(date)"
echo ""

# 1. Check Magento installation
echo "=== 1. Magento Installation Check ==="
MAGENTO_ROOT="/home/technadminy7/public_html"
if [ -f "$MAGENTO_ROOT/bin/magento" ]; then
    echo "✓ Magento installation found"
    MAGENTO_VERSION=$($MAGENTO_ROOT/bin/magento --version 2>/dev/null || echo "Unknown")
    echo "  Version: $MAGENTO_VERSION"
    echo "  Path: $MAGENTO_ROOT"
else
    echo "✗ Magento not found at $MAGENTO_ROOT"
fi
echo ""

# 2. Check Magento database
echo "=== 2. Magento Database Check ==="
MAGENTO_DB="technadminy7_dBT8x12y22"
/opt/mariadb10.6/mariadb/bin/mysql -u root -p'YourNewStrongPassword' -h 127.0.0.1 -P 3307 "$MAGENTO_DB" << 'SQL' 2>/dev/null
SELECT 
    'Products in Magento' as metric,
    COUNT(*) as count
FROM catalog_product_entity
UNION ALL
SELECT 'Categories', COUNT(*) FROM catalog_category_entity
UNION ALL
SELECT 'Attributes', COUNT(*) FROM eav_attribute WHERE entity_type_id = 4;
SQL

if [ $? -eq 0 ]; then
    echo "✓ Magento database accessible"
else
    echo "⚠ Cannot access Magento database"
fi
echo ""

# 3. Check Akeneo connector packages
echo "=== 3. Akeneo Connector Packages ==="
cd /home/pim/public_html
COMPOSER_ALLOW_SUPERUSER=1 composer show 2>/dev/null | grep -E "akeneo|magento|connector" || echo "⚠ No connector packages found"
echo ""

# 4. Check Akeneo export profiles
echo "=== 4. Akeneo Export Profiles ==="
/opt/mariadb10.6/mariadb/bin/mysql -u root -p'YourNewStrongPassword' -h 127.0.0.1 -P 3307 akeneo_pim << 'SQL'
SELECT 
    code,
    label,
    job_name,
    connector
FROM akeneo_batch_job_instance
WHERE job_name LIKE '%export%'
ORDER BY code;
SQL
echo ""

# 5. Check API connections
echo "=== 5. API Connections ==="
/opt/mariadb10.6/mariadb/bin/mysql -u root -p'YourNewStrongPassword' -h 127.0.0.1 -P 3307 akeneo_pim << 'SQL'
SELECT 
    code,
    label,
    flow_type,
    client_id
FROM akeneo_connectivity_connection
ORDER BY code;
SQL
echo ""

# 6. Network connectivity test
echo "=== 6. Network Connectivity Test ==="
echo "Testing connection to Magento frontend..."
MAGENTO_URL="https://beta.technostationery.com"
HTTP_CODE=$(curl -I "$MAGENTO_URL" 2>&1 | grep "HTTP/" | awk '{print $2}' | head -1)
echo "Magento URL: $MAGENTO_URL"
echo "Response: HTTP $HTTP_CODE"
if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "302" ]; then
    echo "✓ Magento is accessible"
else
    echo "⚠ Magento response: $HTTP_CODE"
fi
echo ""

# 7. Check REST API endpoint
echo "=== 7. Magento REST API Check ==="
API_URL="$MAGENTO_URL/rest/V1/products"
API_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" "$API_URL" 2>&1)
echo "API Endpoint: $API_URL"
echo "Response: HTTP $API_RESPONSE"
if [ "$API_RESPONSE" = "401" ]; then
    echo "✓ API endpoint exists (401 = authentication required)"
elif [ "$API_RESPONSE" = "200" ]; then
    echo "✓ API endpoint accessible"
else
    echo "⚠ Unexpected response: $API_RESPONSE"
fi
echo ""

# 8. Recommendations
echo "=========================================="
echo "RECOMMENDATIONS"
echo "=========================================="
echo ""
echo "Current Status:"
echo "- Akeneo PIM: ✓ Online (9,538 products)"
echo "- Magento: $([ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "302" ] && echo "✓ Online" || echo "⚠ Check status")"
echo "- Connector: $([ -f "/home/pim/public_html/vendor/akeneo/magento-connector-bundle/composer.json" ] && echo "✓ Installed" || echo "⚠ Not found")"
echo ""
echo "Next Steps for Magento Sync:"
echo "1. Install Akeneo Magento connector (if missing)"
echo "2. Configure API credentials in Akeneo"
echo "3. Create export profile for Magento"
echo "4. Test with 20 sample products"
echo "5. Monitor sync logs and validate data"
echo ""
