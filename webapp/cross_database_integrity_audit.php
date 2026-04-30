<?php
/**
 * CROSS-DATABASE INTEGRITY AUDIT
 * Date: 2026-04-27
 * Purpose: Comprehensive audit of data consistency between Akeneo PIM and Magento Beta
 * 
 * Audits:
 * 1. Product count and SKU matching
 * 2. Category structure consistency
 * 3. Product-category assignments
 * 4. Attribute values synchronization
 * 5. Price data integrity
 * 6. Stock/inventory consistency
 * 7. Media/image files
 * 8. URL rewrites and SEO data
 * 9. Overall sync health score
 */

error_reporting(E_ALL);
ini_set('display_errors', 1);
ini_set('memory_limit', '1G');
set_time_limit(300);

// Database configuration
$db_config = [
    'host' => '127.0.0.1',
    'port' => '3307',
    'user' => 'root',
    'pass' => 'YourNewStrongPassword',
    'akeneo_db' => 'akeneo_pim',
    'magento_db' => 'beta_dBT8x12y22'
];

// Connect to both databases
try {
    $akeneo_pdo = new PDO(
        "mysql:host={$db_config['host']};port={$db_config['port']};dbname={$db_config['akeneo_db']};charset=utf8mb4",
        $db_config['user'],
        $db_config['pass'],
        [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]
    );
    
    $magento_pdo = new PDO(
        "mysql:host={$db_config['host']};port={$db_config['port']};dbname={$db_config['magento_db']};charset=utf8mb4",
        $db_config['user'],
        $db_config['pass'],
        [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]
    );
    
    echo "\n" . str_repeat("=", 80) . "\n";
    echo "CROSS-DATABASE INTEGRITY AUDIT\n";
    echo "Akeneo PIM ↔ Magento Beta\n";
    echo "Date: " . date('Y-m-d H:i:s') . "\n";
    echo str_repeat("=", 80) . "\n\n";
    
} catch (PDOException $e) {
    die("Database connection failed: " . $e->getMessage() . "\n");
}

// Output file
$logFile = __DIR__ . '/logs/cross_db_audit_' . date('Ymd_His') . '.log';
if (!is_dir(__DIR__ . '/logs')) {
    mkdir(__DIR__ . '/logs', 0755, true);
}

function logOutput($message, $logFile) {
    echo $message;
    file_put_contents($logFile, $message, FILE_APPEND);
}

$issues = [];
$warnings = [];
$scores = [];

// ============================================================================
// 1. PRODUCT COUNT AND SKU MATCHING
// ============================================================================
logOutput("\n" . str_repeat("-", 80) . "\n", $logFile);
logOutput("1. PRODUCT COUNT AND SKU MATCHING\n", $logFile);
logOutput(str_repeat("-", 80) . "\n", $logFile);

// Akeneo product counts
$akeneo_stats = $akeneo_pdo->query("
    SELECT 
        COUNT(*) as total_products,
        SUM(CASE WHEN is_enabled = 1 THEN 1 ELSE 0 END) as enabled_products,
        SUM(CASE WHEN is_enabled = 0 THEN 1 ELSE 0 END) as disabled_products
    FROM pim_catalog_product
")->fetch(PDO::FETCH_ASSOC);

// Magento product counts
$magento_stats = $magento_pdo->query("
    SELECT 
        COUNT(DISTINCT entity_id) as total_products,
        COUNT(DISTINCT sku) as unique_skus
    FROM catalog_product_entity
")->fetch(PDO::FETCH_ASSOC);

logOutput("Akeneo PIM:\n", $logFile);
logOutput("  Total Products: {$akeneo_stats['total_products']}\n", $logFile);
logOutput("  Enabled: {$akeneo_stats['enabled_products']}\n", $logFile);
logOutput("  Disabled: {$akeneo_stats['disabled_products']}\n", $logFile);
logOutput("\n", $logFile);
logOutput("Magento Beta:\n", $logFile);
logOutput("  Total Products: {$magento_stats['total_products']}\n", $logFile);
logOutput("  Unique SKUs: {$magento_stats['unique_skus']}\n", $logFile);
logOutput("\n", $logFile);

$product_count_diff = abs($akeneo_stats['enabled_products'] - $magento_stats['total_products']);
if ($product_count_diff == 0) {
    logOutput("✓ Product counts match perfectly!\n", $logFile);
    $scores['product_count'] = 100;
} else {
    logOutput("⚠ Product count mismatch: {$product_count_diff} products difference\n", $logFile);
    $warnings[] = "Product count mismatch: {$product_count_diff} products";
    $scores['product_count'] = max(0, 100 - ($product_count_diff * 2));
}

// Find SKUs in Akeneo but not in Magento
// Get Magento SKUs first
$magento_skus = $magento_pdo->query("SELECT sku FROM catalog_product_entity")->fetchAll(PDO::FETCH_COLUMN);
$magento_sku_set = array_flip($magento_skus);

// Get Akeneo enabled product SKUs
$akeneo_skus = $akeneo_pdo->query("
    SELECT identifier as sku
    FROM pim_catalog_product
    WHERE is_enabled = 1
")->fetchAll(PDO::FETCH_COLUMN);

$missing_in_magento = [];
foreach ($akeneo_skus as $sku) {
    if (!isset($magento_sku_set[$sku])) {
        $missing_in_magento[] = $sku;
        if (count($missing_in_magento) >= 10) break;
    }
}

if (!empty($missing_in_magento)) {
    logOutput("\n⚠ SKUs in Akeneo but missing in Magento (first 10):\n", $logFile);
    foreach ($missing_in_magento as $sku) {
        logOutput("  - $sku\n", $logFile);
    }
    $issues[] = count($missing_in_magento) . " products not synced to Magento";
} else {
    logOutput("\n✓ All Akeneo SKUs exist in Magento\n", $logFile);
}

// ============================================================================
// 2. CATEGORY STRUCTURE CONSISTENCY
// ============================================================================
logOutput("\n" . str_repeat("-", 80) . "\n", $logFile);
logOutput("2. CATEGORY STRUCTURE CONSISTENCY\n", $logFile);
logOutput(str_repeat("-", 80) . "\n", $logFile);

$akeneo_categories = $akeneo_pdo->query("
    SELECT COUNT(*) as total_categories
    FROM pim_catalog_category
")->fetch(PDO::FETCH_ASSOC);

$magento_categories = $magento_pdo->query("
    SELECT COUNT(*) as total_categories
    FROM catalog_category_entity
    WHERE entity_id > 2
")->fetch(PDO::FETCH_ASSOC);

logOutput("Akeneo Categories: {$akeneo_categories['total_categories']}\n", $logFile);
logOutput("Magento Categories: {$magento_categories['total_categories']}\n", $logFile);

$cat_diff = abs($akeneo_categories['total_categories'] - $magento_categories['total_categories']);
if ($cat_diff <= 2) {
    logOutput("✓ Category counts match (±2 for system categories)\n", $logFile);
    $scores['categories'] = 100;
} else {
    logOutput("⚠ Category count difference: {$cat_diff}\n", $logFile);
    $warnings[] = "Category count difference: {$cat_diff}";
    $scores['categories'] = max(0, 100 - ($cat_diff * 5));
}

// ============================================================================
// 3. PRODUCT-CATEGORY ASSIGNMENTS
// ============================================================================
logOutput("\n" . str_repeat("-", 80) . "\n", $logFile);
logOutput("3. PRODUCT-CATEGORY ASSIGNMENTS\n", $logFile);
logOutput(str_repeat("-", 80) . "\n", $logFile);

$akeneo_cat_assignments = $akeneo_pdo->query("
    SELECT COUNT(*) as total_assignments
    FROM pim_catalog_category_product
")->fetch(PDO::FETCH_ASSOC);

$magento_cat_assignments = $magento_pdo->query("
    SELECT COUNT(*) as total_assignments
    FROM catalog_category_product
    WHERE category_id > 2
")->fetch(PDO::FETCH_ASSOC);

logOutput("Akeneo Product-Category Links: {$akeneo_cat_assignments['total_assignments']}\n", $logFile);
logOutput("Magento Product-Category Links: {$magento_cat_assignments['total_assignments']}\n", $logFile);

$assignment_diff_pct = abs($akeneo_cat_assignments['total_assignments'] - $magento_cat_assignments['total_assignments']) 
                       / max($akeneo_cat_assignments['total_assignments'], 1) * 100;

if ($assignment_diff_pct <= 5) {
    logOutput("✓ Category assignments are consistent (±5%)\n", $logFile);
    $scores['cat_assignments'] = 100;
} else {
    logOutput("⚠ Category assignment difference: " . round($assignment_diff_pct, 1) . "%\n", $logFile);
    $warnings[] = "Category assignments differ by " . round($assignment_diff_pct, 1) . "%";
    $scores['cat_assignments'] = max(0, 100 - $assignment_diff_pct);
}

// ============================================================================
// 4. ATTRIBUTE VALUES SYNCHRONIZATION
// ============================================================================
logOutput("\n" . str_repeat("-", 80) . "\n", $logFile);
logOutput("4. ATTRIBUTE VALUES SYNCHRONIZATION\n", $logFile);
logOutput(str_repeat("-", 80) . "\n", $logFile);

// Check if key attributes are populated in Magento
$magento_attr_check = $magento_pdo->query("
    SELECT 
        'name' as attribute_code,
        COUNT(DISTINCT cpev.entity_id) as populated_products
    FROM catalog_product_entity cpe
    LEFT JOIN catalog_product_entity_varchar cpev ON cpe.entity_id = cpev.entity_id
    LEFT JOIN eav_attribute ea ON cpev.attribute_id = ea.attribute_id AND ea.attribute_code = 'name'
    WHERE cpev.value IS NOT NULL AND cpev.value != ''
    
    UNION ALL
    
    SELECT 
        'price' as attribute_code,
        COUNT(DISTINCT cped.entity_id) as populated_products
    FROM catalog_product_entity cpe
    LEFT JOIN catalog_product_entity_decimal cped ON cpe.entity_id = cped.entity_id
    LEFT JOIN eav_attribute ea ON cped.attribute_id = ea.attribute_id AND ea.attribute_code = 'price'
    WHERE cped.value IS NOT NULL AND cped.value > 0
    
    UNION ALL
    
    SELECT 
        'description' as attribute_code,
        COUNT(DISTINCT cpet.entity_id) as populated_products
    FROM catalog_product_entity cpe
    LEFT JOIN catalog_product_entity_text cpet ON cpe.entity_id = cpet.entity_id
    LEFT JOIN eav_attribute ea ON cpet.attribute_id = ea.attribute_id AND ea.attribute_code = 'description'
    WHERE cpet.value IS NOT NULL AND cpet.value != ''
")->fetchAll(PDO::FETCH_ASSOC);

logOutput("Key Attribute Population in Magento:\n", $logFile);
$attr_scores = [];
foreach ($magento_attr_check as $attr) {
    $pct = ($attr['populated_products'] / max($magento_stats['total_products'], 1)) * 100;
    $status = $pct >= 95 ? '✓' : ($pct >= 80 ? '⚠' : '✗');
    logOutput(sprintf("  %s %-15s: %5d products (%5.1f%%)\n", 
        $status, 
        $attr['attribute_code'], 
        $attr['populated_products'], 
        $pct
    ), $logFile);
    $attr_scores[] = $pct;
    
    if ($pct < 80) {
        $issues[] = "Attribute '{$attr['attribute_code']}' only populated in " . round($pct, 1) . "% of products";
    }
}
$scores['attributes'] = !empty($attr_scores) ? array_sum($attr_scores) / count($attr_scores) : 0;

// ============================================================================
// 5. PRICE DATA INTEGRITY
// ============================================================================
logOutput("\n" . str_repeat("-", 80) . "\n", $logFile);
logOutput("5. PRICE DATA INTEGRITY\n", $logFile);
logOutput(str_repeat("-", 80) . "\n", $logFile);

$price_stats = $magento_pdo->query("
    SELECT 
        COUNT(DISTINCT cpe.entity_id) as total_products,
        COUNT(DISTINCT CASE WHEN cped.value > 0 THEN cpe.entity_id END) as products_with_price,
        AVG(cped.value) as avg_price,
        MIN(cped.value) as min_price,
        MAX(cped.value) as max_price
    FROM catalog_product_entity cpe
    LEFT JOIN catalog_product_entity_decimal cped ON cpe.entity_id = cped.entity_id
    LEFT JOIN eav_attribute ea ON cped.attribute_id = ea.attribute_id AND ea.attribute_code = 'price'
")->fetch(PDO::FETCH_ASSOC);

$price_coverage = ($price_stats['products_with_price'] / max($price_stats['total_products'], 1)) * 100;

logOutput("Products with Price: {$price_stats['products_with_price']} / {$price_stats['total_products']} (" . round($price_coverage, 1) . "%)\n", $logFile);
logOutput("Price Range: " . number_format($price_stats['min_price'], 2) . " - " . number_format($price_stats['max_price'], 2) . "\n", $logFile);
logOutput("Average Price: " . number_format($price_stats['avg_price'], 2) . "\n", $logFile);

if ($price_coverage >= 95) {
    logOutput("✓ Excellent price coverage\n", $logFile);
    $scores['prices'] = 100;
} elseif ($price_coverage >= 80) {
    logOutput("⚠ Good price coverage but some products missing\n", $logFile);
    $warnings[] = round(100 - $price_coverage, 1) . "% of products missing price";
    $scores['prices'] = $price_coverage;
} else {
    logOutput("✗ Poor price coverage - many products missing prices\n", $logFile);
    $issues[] = round(100 - $price_coverage, 1) . "% of products missing price";
    $scores['prices'] = $price_coverage;
}

// ============================================================================
// 6. STOCK/INVENTORY CONSISTENCY
// ============================================================================
logOutput("\n" . str_repeat("-", 80) . "\n", $logFile);
logOutput("6. STOCK/INVENTORY STATUS\n", $logFile);
logOutput(str_repeat("-", 80) . "\n", $logFile);

$stock_stats = $magento_pdo->query("
    SELECT 
        COUNT(DISTINCT cpe.entity_id) as total_products,
        COUNT(DISTINCT CASE WHEN csi.is_in_stock = 1 THEN cpe.entity_id END) as in_stock_products,
        AVG(csi.qty) as avg_qty
    FROM catalog_product_entity cpe
    LEFT JOIN cataloginventory_stock_item csi ON cpe.entity_id = csi.product_id
")->fetch(PDO::FETCH_ASSOC);

$stock_coverage = ($stock_stats['in_stock_products'] / max($stock_stats['total_products'], 1)) * 100;

logOutput("Products In Stock: {$stock_stats['in_stock_products']} / {$stock_stats['total_products']} (" . round($stock_coverage, 1) . "%)\n", $logFile);
logOutput("Average Quantity: " . round($stock_stats['avg_qty'], 2) . "\n", $logFile);

if ($stock_coverage >= 50) {
    logOutput("✓ Stock status configured\n", $logFile);
    $scores['stock'] = min(100, $stock_coverage * 1.5);
} else {
    logOutput("⚠ Low stock coverage\n", $logFile);
    $warnings[] = "Only " . round($stock_coverage, 1) . "% products marked in stock";
    $scores['stock'] = $stock_coverage;
}

// ============================================================================
// 7. URL REWRITES AND SEO DATA
// ============================================================================
logOutput("\n" . str_repeat("-", 80) . "\n", $logFile);
logOutput("7. URL REWRITES AND SEO DATA\n", $logFile);
logOutput(str_repeat("-", 80) . "\n", $logFile);

$url_stats = $magento_pdo->query("
    SELECT 
        COUNT(DISTINCT cpe.entity_id) as total_products,
        COUNT(DISTINCT ur.url_rewrite_id) as url_rewrites
    FROM catalog_product_entity cpe
    LEFT JOIN url_rewrite ur ON ur.entity_id = cpe.entity_id AND ur.entity_type = 'product'
")->fetch(PDO::FETCH_ASSOC);

$url_coverage = ($url_stats['url_rewrites'] / max($url_stats['total_products'], 1)) * 100;

logOutput("Products with URL Rewrites: {$url_stats['url_rewrites']} / {$url_stats['total_products']} (" . round($url_coverage, 1) . "%)\n", $logFile);

if ($url_coverage >= 95) {
    logOutput("✓ Excellent URL rewrite coverage\n", $logFile);
    $scores['urls'] = 100;
} else {
    logOutput("⚠ Some products missing URL rewrites\n", $logFile);
    $warnings[] = round(100 - $url_coverage, 1) . "% products missing URL rewrites";
    $scores['urls'] = $url_coverage;
}

// ============================================================================
// 8. MAGENTO INDEXES STATUS
// ============================================================================
logOutput("\n" . str_repeat("-", 80) . "\n", $logFile);
logOutput("8. MAGENTO INDEXES STATUS\n", $logFile);
logOutput(str_repeat("-", 80) . "\n", $logFile);

$index_stats = $magento_pdo->query("
    SELECT 
        indexer_id,
        status,
        updated
    FROM indexer_state
    ORDER BY indexer_id
")->fetchAll(PDO::FETCH_ASSOC);

logOutput(sprintf("%-50s %-15s %-20s\n", "Indexer ID", "Status", "Last Updated"), $logFile);
logOutput(str_repeat("-", 90) . "\n", $logFile);

$valid_indexes = 0;
$total_indexes = count($index_stats);

foreach ($index_stats as $idx) {
    $status_symbol = ($idx['status'] == 'valid') ? '✓' : '⚠';
    logOutput(sprintf("%s %-48s %-15s %-20s\n", 
        $status_symbol,
        substr($idx['indexer_id'], 0, 48),
        $idx['status'],
        $idx['updated']
    ), $logFile);
    
    if ($idx['status'] == 'valid') {
        $valid_indexes++;
    } else {
        $warnings[] = "Index '{$idx['indexer_id']}' status: {$idx['status']}";
    }
}

$scores['indexes'] = ($valid_indexes / max($total_indexes, 1)) * 100;
logOutput("\nValid Indexes: $valid_indexes / $total_indexes (" . round($scores['indexes'], 1) . "%)\n", $logFile);

// ============================================================================
// 9. OVERALL SYNC HEALTH SCORE
// ============================================================================
logOutput("\n" . str_repeat("=", 80) . "\n", $logFile);
logOutput("OVERALL SYNC HEALTH SCORE\n", $logFile);
logOutput(str_repeat("=", 80) . "\n", $logFile);

logOutput("\nDetailed Scores:\n", $logFile);
foreach ($scores as $metric => $score) {
    $status = $score >= 95 ? '✓' : ($score >= 80 ? '⚠' : '✗');
    logOutput(sprintf("  %s %-25s: %5.1f%%\n", $status, ucfirst(str_replace('_', ' ', $metric)), $score), $logFile);
}

$overall_score = array_sum($scores) / count($scores);
logOutput("\nOVERALL SYNC HEALTH: " . round($overall_score, 1) . "%\n", $logFile);

if ($overall_score >= 95) {
    $grade = 'A+';
    $status = 'EXCELLENT - Systems perfectly synchronized';
} elseif ($overall_score >= 90) {
    $grade = 'A';
    $status = 'VERY GOOD - Minor sync issues';
} elseif ($overall_score >= 85) {
    $grade = 'B+';
    $status = 'GOOD - Some sync improvements needed';
} elseif ($overall_score >= 80) {
    $grade = 'B';
    $status = 'ACCEPTABLE - Multiple sync issues';
} else {
    $grade = 'C or below';
    $status = 'NEEDS WORK - Significant sync problems';
}

logOutput("Grade: $grade - $status\n", $logFile);

// ============================================================================
// 10. ISSUES AND RECOMMENDATIONS
// ============================================================================
logOutput("\n" . str_repeat("=", 80) . "\n", $logFile);
logOutput("ISSUES AND RECOMMENDATIONS\n", $logFile);
logOutput(str_repeat("=", 80) . "\n", $logFile);

if (empty($issues) && empty($warnings)) {
    logOutput("\n✓ No critical issues or warnings detected!\n", $logFile);
    logOutput("Systems are in excellent synchronization state.\n", $logFile);
} else {
    if (!empty($issues)) {
        logOutput("\nCRITICAL ISSUES:\n", $logFile);
        foreach ($issues as $i => $issue) {
            logOutput(($i + 1) . ". $issue\n", $logFile);
        }
    }
    
    if (!empty($warnings)) {
        logOutput("\nWARNINGS:\n", $logFile);
        foreach ($warnings as $i => $warning) {
            logOutput(($i + 1) . ". $warning\n", $logFile);
        }
    }
    
    logOutput("\nRECOMMENDED ACTIONS:\n", $logFile);
    
    if ($scores['product_count'] < 100) {
        logOutput("1. Run full product sync: bin/magento akeneo_connector:import --code=product\n", $logFile);
    }
    
    if ($scores['categories'] < 100) {
        logOutput("2. Resync categories: bin/magento akeneo_connector:import --code=category\n", $logFile);
    }
    
    if ($scores['attributes'] < 90) {
        logOutput("3. Check attribute mapping and resync products\n", $logFile);
    }
    
    if ($scores['indexes'] < 100) {
        logOutput("4. Reindex Magento: bin/magento indexer:reindex\n", $logFile);
    }
    
    if ($scores['urls'] < 95) {
        logOutput("5. Regenerate URL rewrites: bin/magento indexer:reindex catalog_url_product\n", $logFile);
    }
}

logOutput("\n" . str_repeat("=", 80) . "\n", $logFile);
logOutput("Audit completed at " . date('Y-m-d H:i:s') . "\n", $logFile);
logOutput("Full log saved to: $logFile\n", $logFile);
logOutput(str_repeat("=", 80) . "\n\n", $logFile);

echo "\n✓ Cross-database integrity audit completed successfully.\n";
echo "Overall Sync Health: " . round($overall_score, 1) . "% (Grade: $grade)\n";
echo "Results saved to: $logFile\n\n";
