<?php
/**
 * Production Optimization Script
 * Implements Phase 3 improvements and monitoring
 * 
 * Usage: php production_optimization.php [action]
 * Actions: analyze, fix-prices, cleanup-groups, monitor
 */

error_reporting(E_ALL);
ini_set('display_errors', 1);

$action = $argv[1] ?? 'analyze';

echo "=== PRODUCTION OPTIMIZATION - " . date('Y-m-d H:i:s') . " ===\n";
echo "Action: $action\n\n";

// Database connection
$db = new mysqli('127.0.0.1', 'root', 'YourNewStrongPassword', 'akeneo_pim', 3307);
if ($db->connect_error) {
    die("Connection failed: " . $db->connect_error);
}

switch ($action) {
    case 'analyze':
        analyzeSystem($db);
        break;
    case 'fix-prices':
        fixPriceWarnings($db);
        break;
    case 'cleanup-groups':
        cleanupEmptyGroups($db);
        break;
    case 'monitor':
        dailyMonitoring($db);
        break;
    default:
        echo "Unknown action: $action\n";
        echo "Available actions: analyze, fix-prices, cleanup-groups, monitor\n";
}

$db->close();

// ============================================================================
// FUNCTIONS
// ============================================================================

function analyzeSystem($db) {
    echo "🔍 SYSTEM ANALYSIS\n";
    echo str_repeat("=", 70) . "\n\n";
    
    // 1. Overall health
    echo "1. System Health Check\n";
    $metrics = [
        'Total Products' => "SELECT COUNT(*) FROM pim_catalog_product WHERE is_enabled = 1",
        'Products with Completeness' => "SELECT COUNT(DISTINCT product_id) FROM pim_catalog_completeness",
        'Total Attributes' => "SELECT COUNT(*) FROM pim_catalog_attribute",
        'Total Families' => "SELECT COUNT(*) FROM pim_catalog_family",
        'Total Channels' => "SELECT COUNT(*) FROM pim_catalog_channel"
    ];
    
    foreach ($metrics as $name => $query) {
        $result = $db->query($query);
        $row = $result->fetch_row();
        echo "   " . str_pad($name . ":", 35) . number_format($row[0]) . "\n";
    }
    
    // 2. Data quality
    echo "\n2. Data Quality Metrics\n";
    $result = $db->query("SELECT 
        COUNT(*) as total,
        SUM(CASE WHEN JSON_EXTRACT(raw_values, '$.price') IS NOT NULL THEN 1 ELSE 0 END) as with_price,
        SUM(CASE WHEN JSON_EXTRACT(raw_values, '$.weight') IS NOT NULL THEN 1 ELSE 0 END) as with_weight,
        SUM(CASE WHEN JSON_EXTRACT(raw_values, '$.image') IS NOT NULL THEN 1 ELSE 0 END) as with_image
        FROM pim_catalog_product WHERE is_enabled = 1");
    
    $data = $result->fetch_assoc();
    echo "   Price Coverage:  " . number_format($data['with_price']) . " / " . 
         number_format($data['total']) . " (" . 
         round($data['with_price'] / $data['total'] * 100, 1) . "%)\n";
    echo "   Weight Coverage: " . number_format($data['with_weight']) . " / " . 
         number_format($data['total']) . " (" . 
         round($data['with_weight'] / $data['total'] * 100, 1) . "%)\n";
    echo "   Image Coverage:  " . number_format($data['with_image']) . " / " . 
         number_format($data['total']) . " (" . 
         round($data['with_image'] / $data['total'] * 100, 1) . "%)\n";
    
    // 3. Completeness
    echo "\n3. Completeness Status\n";
    $result = $db->query("SELECT 
        ch.code,
        COUNT(DISTINCT c.product_id) as products,
        SUM(CASE WHEN c.missing_count = 0 THEN 1 ELSE 0 END) as complete,
        ROUND(AVG(c.missing_count), 2) as avg_missing
        FROM pim_catalog_completeness c
        JOIN pim_catalog_channel ch ON c.channel_id = ch.id
        WHERE ch.code = 'ecommerce'
        GROUP BY ch.code");
    
    while ($row = $result->fetch_assoc()) {
        $pct = $row['products'] > 0 ? round($row['complete'] / $row['products'] * 100, 1) : 0;
        echo "   " . strtoupper($row['code']) . ": " . 
             number_format($row['complete']) . " / " . number_format($row['products']) . 
             " complete ($pct%) - Avg missing: " . $row['avg_missing'] . "\n";
    }
    
    // 4. Color attribute
    echo "\n4. Color Attribute Status\n";
    $result = $db->query("SELECT 
        (SELECT COUNT(*) FROM pim_catalog_attribute_option ao 
         JOIN pim_catalog_attribute a ON ao.attribute_id = a.id 
         WHERE a.code = 'color') as total_options,
        (SELECT COUNT(*) FROM pim_catalog_product 
         WHERE is_enabled = 1 AND JSON_EXTRACT(raw_values, '$.color') IS NOT NULL) as products_using
    ");
    $color = $result->fetch_assoc();
    echo "   Total Color Options: " . $color['total_options'] . "\n";
    echo "   Products Using Color: " . $color['products_using'] . "\n";
    echo "   Status: " . ($color['total_options'] > 100 ? "⚠️  TOO MANY OPTIONS" : "✅ OK") . "\n";
    
    // 5. Empty groups
    echo "\n5. Empty Attribute Groups\n";
    $result = $db->query("SELECT ag.code, COUNT(DISTINCT a.id) as attr_count
        FROM pim_catalog_attribute_group ag
        LEFT JOIN pim_catalog_attribute a ON ag.id = a.group_id
        GROUP BY ag.code
        HAVING attr_count = 0");
    
    $empty = [];
    while ($row = $result->fetch_assoc()) {
        $empty[] = $row['code'];
    }
    
    if (empty($empty)) {
        echo "   ✅ No empty groups\n";
    } else {
        echo "   ⚠️  Empty groups found: " . implode(', ', $empty) . "\n";
    }
    
    echo "\n" . str_repeat("=", 70) . "\n";
    echo "Analysis complete. Use specific actions to fix issues.\n";
}

function fixPriceWarnings($db) {
    echo "💰 FIXING PRICE WARNINGS\n";
    echo str_repeat("=", 70) . "\n\n";
    
    // Find products with null price structure
    echo "1. Identifying products with null price structure...\n";
    $result = $db->query("SELECT COUNT(*) as cnt FROM pim_catalog_product 
        WHERE is_enabled = 1 
        AND JSON_TYPE(JSON_EXTRACT(raw_values, '$.price')) = 'NULL'");
    $row = $result->fetch_assoc();
    $count = $row['cnt'];
    
    echo "   Found: $count products\n\n";
    
    if ($count == 0) {
        echo "✅ No price warnings to fix!\n";
        return;
    }
    
    echo "2. Would you like to fix these? (y/n): ";
    $handle = fopen("php://stdin", "r");
    $line = fgets($handle);
    if (trim($line) != 'y') {
        echo "Cancelled.\n";
        return;
    }
    
    echo "\n3. Fixing price structures...\n";
    
    // This is a dry-run - actual fix would be:
    // UPDATE pim_catalog_product
    // SET raw_values = JSON_SET(raw_values, '$.price', JSON_ARRAY())
    // WHERE is_enabled = 1 
    // AND JSON_TYPE(JSON_EXTRACT(raw_values, '$.price')) = 'NULL'
    
    echo "   ⚠️  DRY RUN MODE - No changes made\n";
    echo "   To apply changes, uncomment UPDATE query in script\n";
    
    echo "\n✅ Fix complete!\n";
}

function cleanupEmptyGroups($db) {
    echo "📦 CLEANUP EMPTY ATTRIBUTE GROUPS\n";
    echo str_repeat("=", 70) . "\n\n";
    
    echo "1. Finding empty groups...\n";
    $result = $db->query("SELECT ag.id, ag.code 
        FROM pim_catalog_attribute_group ag
        LEFT JOIN pim_catalog_attribute a ON ag.id = a.group_id
        GROUP BY ag.id, ag.code
        HAVING COUNT(DISTINCT a.id) = 0");
    
    $empty = [];
    while ($row = $result->fetch_assoc()) {
        $empty[] = $row;
    }
    
    if (empty($empty)) {
        echo "   ✅ No empty groups to cleanup!\n";
        return;
    }
    
    echo "   Found " . count($empty) . " empty groups:\n";
    foreach ($empty as $group) {
        echo "      - " . $group['code'] . " (ID: " . $group['id'] . ")\n";
    }
    
    echo "\n2. Would you like to delete these groups? (y/n): ";
    $handle = fopen("php://stdin", "r");
    $line = fgets($handle);
    if (trim($line) != 'y') {
        echo "Cancelled.\n";
        return;
    }
    
    echo "\n3. Deleting empty groups...\n";
    
    foreach ($empty as $group) {
        // Delete translations first
        $db->query("DELETE FROM pim_catalog_attribute_group_translation 
                   WHERE foreign_key = " . $group['id']);
        
        // Delete group
        $db->query("DELETE FROM pim_catalog_attribute_group 
                   WHERE id = " . $group['id']);
        
        echo "   ✅ Deleted: " . $group['code'] . "\n";
    }
    
    echo "\n✅ Cleanup complete!\n";
    echo "Remember to clear cache: bin/console cache:clear --env=prod\n";
}

function dailyMonitoring($db) {
    echo "📊 DAILY MONITORING REPORT\n";
    echo str_repeat("=", 70) . "\n\n";
    
    $report = [];
    
    // Products count
    $result = $db->query("SELECT COUNT(*) as cnt FROM pim_catalog_product WHERE is_enabled = 1");
    $row = $result->fetch_assoc();
    $report['total_products'] = $row['cnt'];
    
    // Completeness
    $result = $db->query("SELECT 
        ch.code,
        COUNT(DISTINCT c.product_id) as products,
        SUM(CASE WHEN c.missing_count = 0 THEN 1 ELSE 0 END) as complete
        FROM pim_catalog_completeness c
        JOIN pim_catalog_channel ch ON c.channel_id = ch.id
        GROUP BY ch.code");
    
    $report['completeness'] = [];
    while ($row = $result->fetch_assoc()) {
        $pct = $row['products'] > 0 ? round($row['complete'] / $row['products'] * 100, 1) : 0;
        $report['completeness'][$row['code']] = $pct;
    }
    
    // Data quality
    $result = $db->query("SELECT 
        SUM(CASE WHEN JSON_EXTRACT(raw_values, '$.price') IS NOT NULL THEN 1 ELSE 0 END) as with_price,
        SUM(CASE WHEN JSON_EXTRACT(raw_values, '$.weight') IS NOT NULL THEN 1 ELSE 0 END) as with_weight,
        SUM(CASE WHEN JSON_EXTRACT(raw_values, '$.image') IS NOT NULL THEN 1 ELSE 0 END) as with_image
        FROM pim_catalog_product WHERE is_enabled = 1");
    $data = $result->fetch_assoc();
    
    $report['data_quality'] = [
        'price' => round($data['with_price'] / $report['total_products'] * 100, 1),
        'weight' => round($data['with_weight'] / $report['total_products'] * 100, 1),
        'image' => round($data['with_image'] / $report['total_products'] * 100, 1)
    ];
    
    // Print report
    echo "Date: " . date('Y-m-d H:i:s') . "\n\n";
    echo "Total Products: " . number_format($report['total_products']) . "\n\n";
    
    echo "Completeness by Channel:\n";
    foreach ($report['completeness'] as $channel => $pct) {
        echo "   " . str_pad(strtoupper($channel) . ":", 15) . "$pct%\n";
    }
    
    echo "\nData Quality:\n";
    echo "   Price:  " . $report['data_quality']['price'] . "%\n";
    echo "   Weight: " . $report['data_quality']['weight'] . "%\n";
    echo "   Image:  " . $report['data_quality']['image'] . "%\n";
    
    // Alerts
    echo "\n🚨 Alerts:\n";
    $alerts = [];
    
    if ($report['data_quality']['price'] < 100) {
        $alerts[] = "Price coverage below 100%";
    }
    if ($report['data_quality']['weight'] < 95) {
        $alerts[] = "Weight coverage below 95%";
    }
    if ($report['data_quality']['image'] < 90) {
        $alerts[] = "Image coverage below 90%";
    }
    foreach ($report['completeness'] as $channel => $pct) {
        if ($pct < 80 && $channel == 'ecommerce') {
            $alerts[] = "Ecommerce completeness below 80%";
        }
    }
    
    if (empty($alerts)) {
        echo "   ✅ No alerts\n";
    } else {
        foreach ($alerts as $alert) {
            echo "   ⚠️  $alert\n";
        }
    }
    
    echo "\n" . str_repeat("=", 70) . "\n";
    
    // Save to log file
    $logDir = '/home/pim/public_html/webapp/logs';
    if (!is_dir($logDir)) {
        mkdir($logDir, 0755, true);
    }
    
    $logFile = $logDir . '/daily_monitor_' . date('Ymd') . '.log';
    ob_start();
    echo "=== DAILY MONITORING REPORT ===\n";
    echo "Date: " . date('Y-m-d H:i:s') . "\n\n";
    echo "Total Products: " . number_format($report['total_products']) . "\n\n";
    echo "Completeness:\n";
    foreach ($report['completeness'] as $channel => $pct) {
        echo "   " . strtoupper($channel) . ": $pct%\n";
    }
    echo "\nData Quality:\n";
    echo "   Price: " . $report['data_quality']['price'] . "%\n";
    echo "   Weight: " . $report['data_quality']['weight'] . "%\n";
    echo "   Image: " . $report['data_quality']['image'] . "%\n";
    if (!empty($alerts)) {
        echo "\nAlerts:\n";
        foreach ($alerts as $alert) {
            echo "   - $alert\n";
        }
    }
    $logContent = ob_get_clean();
    file_put_contents($logFile, $logContent);
    
    echo "Report saved to: $logFile\n";
}
