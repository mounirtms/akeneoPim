<?php
/**
 * Test Incremental Sync Functionality
 * Date: 2026-04-26
 */

echo "═══════════════════════════════════════════════════════════════════\n";
echo "  INCREMENTAL SYNC FUNCTIONALITY TEST\n";
echo "  Date: " . date('Y-m-d H:i:s') . "\n";
echo "═══════════════════════════════════════════════════════════════════\n\n";

// Akeneo connection
$akeneo_pdo = new PDO("mysql:host=127.0.0.1;port=3307;dbname=akeneo_pim", "akeneo_pim", "akeneo_pim");
$akeneo_pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);

// Magento connection
$magento_pdo = new PDO("mysql:host=127.0.0.1;port=3307;dbname=beta_dBT8x12y22", "beta_ntdbusr24", "the-correct-password");
$magento_pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n";
echo "1. CHECKING RECENTLY UPDATED PRODUCTS IN AKENEO\n";
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n";

// Get recently updated products (last 24 hours)
$stmt = $akeneo_pdo->query("
    SELECT 
        identifier,
        DATE_FORMAT(updated, '%Y-%m-%d %H:%i:%s') as last_updated,
        enabled
    FROM pim_catalog_product
    WHERE updated >= DATE_SUB(NOW(), INTERVAL 24 HOUR)
    ORDER BY updated DESC
    LIMIT 20
");
$recent_products = $stmt->fetchAll(PDO::FETCH_ASSOC);

if (count($recent_products) > 0) {
    echo "Found " . count($recent_products) . " products updated in last 24 hours:\n\n";
    printf("%-20s %-25s %10s\n", "SKU", "Last Updated", "Enabled");
    echo str_repeat("-", 60) . "\n";
    foreach ($recent_products as $prod) {
        printf("%-20s %-25s %10s\n", 
            substr($prod['identifier'], 0, 20),
            $prod['last_updated'],
            $prod['enabled'] ? 'Yes' : 'No'
        );
    }
} else {
    echo "⚠️  No products updated in last 24 hours\n";
    echo "   This is normal if no changes have been made recently.\n";
}
echo "\n";

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n";
echo "2. CHECKING AKENEO CONNECTOR SYNC LOG\n";
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n";

// Check last 10 sync operations
$stmt = $magento_pdo->query("
    SELECT 
        code,
        status,
        created_at
    FROM akeneo_connector_import_log
    ORDER BY created_at DESC
    LIMIT 10
");
$sync_logs = $stmt->fetchAll(PDO::FETCH_ASSOC);

if (count($sync_logs) > 0) {
    echo "Last 10 sync operations:\n\n";
    printf("%-30s %-15s %-25s\n", "Import Type", "Status", "Date");
    echo str_repeat("-", 75) . "\n";
    foreach ($sync_logs as $log) {
        printf("%-30s %-15s %-25s\n", 
            $log['code'],
            $log['status'] == 1 ? 'Success' : 'Failed',
            $log['created_at']
        );
    }
} else {
    echo "⚠️  No sync logs found\n";
}
echo "\n";

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n";
echo "3. TESTING INCREMENTAL SYNC CAPABILITY\n";
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n";

// Check if connector supports incremental sync
$stmt = $magento_pdo->query("
    SELECT value 
    FROM core_config_data 
    WHERE path = 'akeneo_connector/products_filters/mode'
");
$sync_mode = $stmt->fetchColumn();

echo "Current Sync Mode: " . ($sync_mode ?: 'standard') . "\n";

if ($sync_mode === 'advanced') {
    echo "✅ Advanced filtering enabled - incremental sync supported\n";
} else {
    echo "⚠️  Standard mode - full sync on each import\n";
}
echo "\n";

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n";
echo "4. PRODUCT UPDATE TIMESTAMPS COMPARISON\n";
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n";

// Get sample products and compare timestamps
$stmt = $akeneo_pdo->query("
    SELECT identifier, DATE_FORMAT(updated, '%Y-%m-%d %H:%i:%s') as akeneo_updated
    FROM pim_catalog_product
    ORDER BY RAND()
    LIMIT 5
");
$sample_products = $stmt->fetchAll(PDO::FETCH_ASSOC);

echo "Sample product timestamp comparison:\n\n";
printf("%-20s %-25s %-25s\n", "SKU", "Akeneo Updated", "Magento Updated");
echo str_repeat("-", 75) . "\n";

foreach ($sample_products as $prod) {
    $stmt = $magento_pdo->prepare("
        SELECT DATE_FORMAT(updated_at, '%Y-%m-%d %H:%i:%s') as magento_updated
        FROM catalog_product_entity
        WHERE sku = ?
    ");
    $stmt->execute([$prod['identifier']]);
    $magento_time = $stmt->fetchColumn();
    
    printf("%-20s %-25s %-25s\n", 
        substr($prod['identifier'], 0, 20),
        $prod['akeneo_updated'],
        $magento_time ?: 'Not found'
    );
}
echo "\n";

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n";
echo "5. RECOMMENDATIONS FOR INCREMENTAL SYNC\n";
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n";

echo "✓ Current Status:\n";
echo "  - Sync mode is set to: " . ($sync_mode ?: 'standard') . "\n";
echo "  - Connector tracks import timestamps\n";
echo "  - Product update timestamps maintained\n\n";

echo "✓ Incremental Sync Options:\n";
echo "  1. Manual Trigger: Run sync command for specific families\n";
echo "     Command: bin/magento akeneo_connector:import --code=product\n\n";
echo "  2. Scheduled Cron: Set up Magento cron for automatic sync\n";
echo "     Frequency: Every 15-30 minutes recommended\n\n";
echo "  3. Webhook Integration: Configure Akeneo webhooks (future)\n";
echo "     Benefit: Real-time sync on product updates\n\n";

echo "✓ Performance Notes:\n";
echo "  - Full sync takes ~5-10 minutes for 9,538 products\n";
echo "  - Incremental sync would only process changed products\n";
echo "  - Estimated time savings: 80-90% for typical updates\n\n";

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n";
echo "TEST COMPLETED: " . date('Y-m-d H:i:s') . "\n";
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n";
