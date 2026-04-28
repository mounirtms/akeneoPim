<?php
/**
 * Full Data Sync Verification - Akeneo vs Magento Beta
 * Date: 2026-04-27
 */

echo "═══════════════════════════════════════════════════════════════════\n";
echo "  FULL DATA SYNC VERIFICATION - AKENEO vs MAGENTO BETA\n";
echo "  Date: " . date('Y-m-d H:i:s') . "\n";
echo "═══════════════════════════════════════════════════════════════════\n\n";

// Akeneo connection
$akeneo_pdo = new PDO("mysql:host=127.0.0.1;port=3307;dbname=akeneo_pim", "akeneo_pim", "akeneo_pim");
$akeneo_pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);

// Magento connection
$magento_pdo = new PDO("mysql:host=127.0.0.1;port=3307;dbname=beta_dBT8x12y22", "beta_ntdbusr24", "the-correct-password");
$magento_pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n";
echo "1. AKENEO PIM CURRENT STATE\n";
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n";

// Akeneo products
$akeneoProducts = $akeneo_pdo->query("SELECT COUNT(*) FROM pim_catalog_product WHERE enabled = 1")->fetchColumn();
$akeneoTotalProducts = $akeneo_pdo->query("SELECT COUNT(*) FROM pim_catalog_product")->fetchColumn();
$akeneoCategories = $akeneo_pdo->query("SELECT COUNT(*) FROM pim_catalog_category")->fetchColumn();
$akeneoAttributes = $akeneo_pdo->query("SELECT COUNT(*) FROM pim_catalog_attribute")->fetchColumn();
$akeneoFamilies = $akeneo_pdo->query("SELECT COUNT(*) FROM pim_catalog_family")->fetchColumn();

echo "Products (Enabled): $akeneoProducts / $akeneoTotalProducts\n";
echo "Categories: $akeneoCategories\n";
echo "Attributes: $akeneoAttributes\n";
echo "Families: $akeneoFamilies\n\n";

// Sample products
echo "Sample Products:\n";
$stmt = $akeneo_pdo->query("SELECT identifier, family_id, enabled FROM pim_catalog_product LIMIT 10");
$sampleProducts = $stmt->fetchAll(PDO::FETCH_ASSOC);
foreach ($sampleProducts as $prod) {
    echo "  - SKU: {$prod['identifier']}, Family: {$prod['family_id']}, Enabled: " . ($prod['enabled'] ? 'Yes' : 'No') . "\n";
}
echo "\n";

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n";
echo "2. MAGENTO BETA CURRENT STATE\n";
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n";

// Magento products
$magentoProducts = $magento_pdo->query("SELECT COUNT(*) FROM catalog_product_entity")->fetchColumn();
$magentoCategories = $magento_pdo->query("SELECT COUNT(*) FROM catalog_category_entity")->fetchColumn();
$magentoAttributeSets = $magento_pdo->query("SELECT COUNT(*) FROM eav_attribute_set WHERE entity_type_id = 4")->fetchColumn();

// Product status
$stmt = $magento_pdo->query("
    SELECT 
        cpei.value as status,
        COUNT(*) as count
    FROM catalog_product_entity cpe
    LEFT JOIN catalog_product_entity_int cpei ON cpe.entity_id = cpei.entity_id 
        AND cpei.attribute_id = (SELECT attribute_id FROM eav_attribute WHERE attribute_code = 'status' AND entity_type_id = 4)
    GROUP BY cpei.value
");
$productStatus = $stmt->fetchAll(PDO::FETCH_ASSOC);

echo "Total Products: $magentoProducts\n";
echo "Total Categories: $magentoCategories\n";
echo "Attribute Sets: $magentoAttributeSets\n\n";

echo "Product Status Distribution:\n";
foreach ($productStatus as $status) {
    $statusLabel = $status['status'] == 1 ? 'Enabled' : ($status['status'] == 2 ? 'Disabled' : 'Unknown');
    echo "  - {$statusLabel}: {$status['count']}\n";
}
echo "\n";

// Sample products
echo "Sample Products:\n";
$stmt = $magento_pdo->query("
    SELECT 
        sku,
        type_id,
        created_at,
        updated_at
    FROM catalog_product_entity 
    LIMIT 10
");
$magentoSampleProducts = $stmt->fetchAll(PDO::FETCH_ASSOC);
foreach ($magentoSampleProducts as $prod) {
    echo "  - SKU: {$prod['sku']}, Type: {$prod['type_id']}, Updated: {$prod['updated_at']}\n";
}
echo "\n";

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n";
echo "3. SYNC STATUS COMPARISON\n";
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n";

$productDiff = $akeneoProducts - $magentoProducts;
$categoryDiff = $akeneoCategories - $magentoCategories;

printf("%-30s %10s %10s %10s\n", "Entity", "Akeneo", "Magento", "Diff");
echo str_repeat("-", 65) . "\n";
printf("%-30s %10d %10d %10d\n", "Products (Enabled)", $akeneoProducts, $magentoProducts, $productDiff);
printf("%-30s %10d %10d %10d\n", "Categories", $akeneoCategories, $magentoCategories, $categoryDiff);
printf("%-30s %10d %10d %10s\n", "Families/Attr Sets", $akeneoFamilies, $magentoAttributeSets, 'N/A');
echo "\n";

if ($productDiff == 0) {
    echo "✅ Products are in sync (same count)\n";
} else {
    echo "⚠️  Product count mismatch: Need to sync $productDiff products\n";
}

if (abs($categoryDiff) <= 2) {
    echo "✅ Categories are in sync (±2 is acceptable for system categories)\n";
} else {
    echo "⚠️  Category count mismatch: Difference of $categoryDiff\n";
}
echo "\n";

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n";
echo "4. AKENEO CONNECTOR STATUS\n";
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n";

// Check Akeneo connector configuration
$stmt = $magento_pdo->query("
    SELECT path, value 
    FROM core_config_data 
    WHERE path LIKE 'akeneo_connector%' 
    ORDER BY path 
    LIMIT 20
");
$connectorConfig = $stmt->fetchAll(PDO::FETCH_ASSOC);

if (count($connectorConfig) > 0) {
    echo "Akeneo Connector Configuration:\n";
    foreach ($connectorConfig as $config) {
        $value = strlen($config['value']) > 50 ? substr($config['value'], 0, 50) . '...' : $config['value'];
        echo "  - {$config['path']}: $value\n";
    }
} else {
    echo "⚠️  No Akeneo connector configuration found\n";
}
echo "\n";

// Check last sync
$stmt = $magento_pdo->query("
    SELECT 
        code,
        status,
        created_at
    FROM akeneo_connector_import_log
    ORDER BY created_at DESC
    LIMIT 5
");
$lastSyncs = $stmt->fetchAll(PDO::FETCH_ASSOC);

if (count($lastSyncs) > 0) {
    echo "Last 5 Sync Operations:\n";
    foreach ($lastSyncs as $sync) {
        $statusLabel = $sync['status'] == 1 ? 'Success' : 'Failed';
        echo "  - {$sync['code']}: $statusLabel ({$sync['created_at']})\n";
    }
} else {
    echo "⚠️  No sync history found\n";
}
echo "\n";

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n";
echo "5. RECOMMENDATIONS\n";
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n";

if ($productDiff != 0 || abs($categoryDiff) > 2) {
    echo "SYNC REQUIRED:\n";
    if (abs($categoryDiff) > 2) {
        echo "  1. Run category sync first\n";
        echo "     Command: bin/magento akeneo_connector:import --code=category\n\n";
    }
    if ($productDiff != 0) {
        echo "  2. Run full product sync\n";
        echo "     Command: bin/magento akeneo_connector:import --code=product\n\n";
    }
    echo "  3. Reindex Magento\n";
    echo "     Command: bin/magento indexer:reindex\n\n";
    echo "  4. Clear cache\n";
    echo "     Command: bin/magento cache:flush\n\n";
} else {
    echo "✅ Systems are in sync. No immediate action required.\n\n";
    echo "OPTIONAL MAINTENANCE:\n";
    echo "  - Verify product status (all enabled)\n";
    echo "  - Check product visibility settings\n";
    echo "  - Validate category assignments\n";
    echo "  - Review attribute mappings\n\n";
}

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n";
echo "Verification completed: " . date('Y-m-d H:i:s') . "\n";
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n";
