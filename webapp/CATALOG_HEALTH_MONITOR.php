<?php
/**
 * CATALOG HEALTH MONITORING TOOL
 * Daily automated health checks for Akeneo catalog
 * Date: 2026-04-29
 */

// Configuration
$config = [
    'db_host' => '127.0.0.1',
    'db_port' => 3307,
    'db_name' => 'akeneo_pim',
    'db_user' => 'akeneo_pim',
    'db_pass' => 'akeneo_pim',
    'alert_email' => 'webmaster@techno-dz.com',
    'log_dir' => '/home/pim/public_html/webapp/logs/',
    'thresholds' => [
        'completeness_min' => 80,
        'image_coverage_min' => 95,
        'enabled_products_min' => 90
    ]
];

echo "=========================================\n";
echo "  CATALOG HEALTH MONITOR\n";
echo "=========================================\n";
echo "Date: " . date('Y-m-d H:i:s') . "\n\n";

// Create log directory
if (!is_dir($config['log_dir'])) {
    mkdir($config['log_dir'], 0755, true);
}

$logFile = $config['log_dir'] . 'health_' . date('Y-m-d') . '.log';

// Database connection
try {
    $pdo = new PDO(
        "mysql:host={$config['db_host']};port={$config['db_port']};dbname={$config['db_name']};charset=utf8mb4",
        $config['db_user'],
        $config['db_pass'],
        [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]
    );
    echo "✓ Database connected\n\n";
} catch (PDOException $e) {
    die("❌ Database connection failed: " . $e->getMessage() . "\n");
}

$alerts = [];
$report = [];

// ============================================
// 1. PRODUCT STATISTICS
// ============================================
echo "STEP 1: Product Statistics\n";
echo "─────────────────────────────────────────\n";

$stmt = $pdo->query("SELECT COUNT(*) as total FROM pim_catalog_product");
$totalProducts = $stmt->fetch()['total'];
echo "Total products: $totalProducts\n";
$report['total_products'] = $totalProducts;

$stmt = $pdo->query("SELECT COUNT(*) as enabled FROM pim_catalog_product WHERE is_enabled = 1");
$enabledProducts = $stmt->fetch()['enabled'];
$enabledPercent = round(($enabledProducts / max($totalProducts, 1)) * 100, 2);
echo "Enabled products: $enabledProducts ($enabledPercent%)\n";
$report['enabled_products'] = $enabledProducts;
$report['enabled_percent'] = $enabledPercent;

if ($enabledPercent < $config['thresholds']['enabled_products_min']) {
    $alerts[] = "⚠ Enabled products below threshold: $enabledPercent% (min: {$config['thresholds']['enabled_products_min']}%)";
}

echo "\n";

// ============================================
// 2. IMAGE COVERAGE
// ============================================
echo "STEP 2: Image Coverage Analysis\n";
echo "─────────────────────────────────────────\n";

// Count products in product_images directory
$imageDir = '/home/pim/public_html/public/media/product_images/large/';
if (is_dir($imageDir)) {
    $imageCount = count(glob($imageDir . '*.jpg'));
    $imageCoverage = round(($imageCount / max($totalProducts, 1)) * 100, 2);
    echo "Products with images: $imageCount ($imageCoverage%)\n";
    $report['image_coverage'] = $imageCoverage;
    $report['images_available'] = $imageCount;
    
    if ($imageCoverage < $config['thresholds']['image_coverage_min']) {
        $alerts[] = "⚠ Image coverage below threshold: $imageCoverage% (min: {$config['thresholds']['image_coverage_min']}%)";
    }
} else {
    echo "⚠ Image directory not found: $imageDir\n";
    $alerts[] = "⚠ Image directory not accessible";
}

echo "\n";

// ============================================
// 3. CATEGORY DISTRIBUTION
// ============================================
echo "STEP 3: Category Distribution\n";
echo "─────────────────────────────────────────\n";

$stmt = $pdo->query("SELECT COUNT(*) as total FROM pim_catalog_category");
$totalCategories = $stmt->fetch()['total'];
echo "Total categories: $totalCategories\n";
$report['total_categories'] = $totalCategories;

// Products per category (top 10)
$stmt = $pdo->query("
    SELECT c.code, c.label, COUNT(cp.product_id) as product_count
    FROM pim_catalog_category c
    LEFT JOIN pim_catalog_category_product cp ON c.id = cp.category_id
    GROUP BY c.id
    ORDER BY product_count DESC
    LIMIT 10
");

echo "\nTop 10 categories by product count:\n";
$categories = [];
while ($row = $stmt->fetch()) {
    echo "  {$row['code']}: {$row['product_count']} products\n";
    $categories[] = [
        'code' => $row['code'],
        'label' => $row['label'],
        'count' => $row['product_count']
    ];
}
$report['top_categories'] = $categories;

echo "\n";

// ============================================
// 4. ATTRIBUTE USAGE
// ============================================
echo "STEP 4: Attribute Usage Statistics\n";
echo "─────────────────────────────────────────\n";

$stmt = $pdo->query("SELECT COUNT(*) as total FROM pim_catalog_attribute");
$totalAttributes = $stmt->fetch()['total'];
echo "Total attributes: $totalAttributes\n";
$report['total_attributes'] = $totalAttributes;

echo "\n";

// ============================================
// 5. FAMILY DISTRIBUTION
// ============================================
echo "STEP 5: Family Distribution\n";
echo "─────────────────────────────────────────\n";

$stmt = $pdo->query("
    SELECT f.code, f.label, COUNT(p.id) as product_count
    FROM pim_catalog_family f
    LEFT JOIN pim_catalog_product p ON f.id = p.family_id
    GROUP BY f.id
    ORDER BY product_count DESC
");

echo "Products by family:\n";
$families = [];
while ($row = $stmt->fetch()) {
    echo "  {$row['code']}: {$row['product_count']} products\n";
    $families[] = [
        'code' => $row['code'],
        'label' => $row['label'],
        'count' => $row['product_count']
    ];
}
$report['families'] = $families;

echo "\n";

// ============================================
// 6. DATA QUALITY CHECKS
// ============================================
echo "STEP 6: Data Quality Checks\n";
echo "─────────────────────────────────────────\n";

// Products without family
$stmt = $pdo->query("SELECT COUNT(*) as count FROM pim_catalog_product WHERE family_id IS NULL");
$noFamily = $stmt->fetch()['count'];
echo "Products without family: $noFamily\n";
$report['products_no_family'] = $noFamily;

if ($noFamily > 0) {
    $alerts[] = "⚠ $noFamily products without family assignment";
}

// Disabled products
$disabledProducts = $totalProducts - $enabledProducts;
echo "Disabled products: $disabledProducts\n";
$report['disabled_products'] = $disabledProducts;

echo "\n";

// ============================================
// 7. STORAGE ANALYSIS
// ============================================
echo "STEP 7: Storage Analysis\n";
echo "─────────────────────────────────────────\n";

// Calculate image storage
if (is_dir($imageDir)) {
    $totalSize = 0;
    $files = glob('/home/pim/public_html/public/media/product_images/*/*.jpg');
    foreach ($files as $file) {
        $totalSize += filesize($file);
    }
    $sizeMB = round($totalSize / 1048576, 2);
    echo "Image storage: {$sizeMB} MB\n";
    $report['image_storage_mb'] = $sizeMB;
}

// Database size
$stmt = $pdo->query("
    SELECT 
        ROUND(SUM(data_length + index_length) / 1024 / 1024, 2) AS size_mb
    FROM information_schema.tables
    WHERE table_schema = '{$config['db_name']}'
");
$dbSize = $stmt->fetch()['size_mb'];
echo "Database size: {$dbSize} MB\n";
$report['database_size_mb'] = $dbSize;

echo "\n";

// ============================================
// 8. TREND ANALYSIS
// ============================================
echo "STEP 8: Trend Analysis\n";
echo "─────────────────────────────────────────\n";

// Load previous day's report if exists
$yesterdayLog = $config['log_dir'] . 'health_' . date('Y-m-d', strtotime('-1 day')) . '.json';
if (file_exists($yesterdayLog)) {
    $yesterday = json_decode(file_get_contents($yesterdayLog), true);
    
    if ($yesterday) {
        echo "Changes since yesterday:\n";
        
        $productDiff = $totalProducts - ($yesterday['total_products'] ?? 0);
        echo "  Products: " . ($productDiff >= 0 ? "+$productDiff" : $productDiff) . "\n";
        
        if (isset($yesterday['image_coverage'])) {
            $imageDiff = round($report['image_coverage'] - $yesterday['image_coverage'], 2);
            echo "  Image coverage: " . ($imageDiff >= 0 ? "+$imageDiff" : $imageDiff) . "%\n";
        }
        
        if (isset($yesterday['enabled_percent'])) {
            $enabledDiff = round($report['enabled_percent'] - $yesterday['enabled_percent'], 2);
            echo "  Enabled products: " . ($enabledDiff >= 0 ? "+$enabledDiff" : $enabledDiff) . "%\n";
        }
    }
} else {
    echo "No previous data for comparison\n";
}

echo "\n";

// ============================================
// 9. HEALTH SCORE CALCULATION
// ============================================
echo "STEP 9: Overall Health Score\n";
echo "─────────────────────────────────────────\n";

$healthScore = 0;
$maxScore = 100;

// Image coverage (30 points)
$healthScore += min(30, ($report['image_coverage'] ?? 0) * 0.3);

// Enabled products (20 points)
$healthScore += min(20, ($report['enabled_percent'] ?? 0) * 0.2);

// Products without family (deduct up to 20 points)
$familyPenalty = min(20, ($noFamily / max($totalProducts, 1)) * 100);
$healthScore -= $familyPenalty;

// Category distribution (10 points if products spread across categories)
$healthScore += 10;

// Attribute usage (10 points)
$healthScore += 10;

// Data quality (10 points)
$healthScore += 10;

// Recent growth (20 points - neutral if no data)
$healthScore += 20;

$healthScore = max(0, min(100, $healthScore));
$healthGrade = $healthScore >= 90 ? 'A' : ($healthScore >= 80 ? 'B' : ($healthScore >= 70 ? 'C' : ($healthScore >= 60 ? 'D' : 'F')));

echo "Health Score: " . round($healthScore, 1) . "/100 (Grade: $healthGrade)\n";
$report['health_score'] = round($healthScore, 1);
$report['health_grade'] = $healthGrade;

echo "\n";

// ============================================
// 10. ALERTS & RECOMMENDATIONS
// ============================================
echo "STEP 10: Alerts & Recommendations\n";
echo "─────────────────────────────────────────\n";

if (!empty($alerts)) {
    echo "⚠ ALERTS:\n";
    foreach ($alerts as $alert) {
        echo "  $alert\n";
    }
    $report['alerts'] = $alerts;
} else {
    echo "✓ No alerts - catalog health is good!\n";
    $report['alerts'] = [];
}

echo "\n";

// Recommendations
$recommendations = [];

if (($report['image_coverage'] ?? 0) < 95) {
    $recommendations[] = "Import remaining product images to improve coverage";
}

if ($noFamily > 0) {
    $recommendations[] = "Assign family to $noFamily products without family";
}

if (($report['enabled_percent'] ?? 0) < 95) {
    $recommendations[] = "Review and enable disabled products if appropriate";
}

if (!empty($recommendations)) {
    echo "💡 RECOMMENDATIONS:\n";
    foreach ($recommendations as $rec) {
        echo "  - $rec\n";
    }
    $report['recommendations'] = $recommendations;
} else {
    $report['recommendations'] = [];
}

echo "\n";

// ============================================
// SAVE REPORT
// ============================================
$report['timestamp'] = date('Y-m-d H:i:s');
$report['date'] = date('Y-m-d');

// Save JSON report
$jsonFile = $config['log_dir'] . 'health_' . date('Y-m-d') . '.json';
file_put_contents($jsonFile, json_encode($report, JSON_PRETTY_PRINT));
echo "✓ Report saved: $jsonFile\n";

// Save text log
$logContent = ob_get_contents();
file_put_contents($logFile, $logContent);
echo "✓ Log saved: $logFile\n";

// ============================================
// EMAIL ALERTS (if configured)
// ============================================
if (!empty($alerts) && !empty($config['alert_email'])) {
    $subject = "[Akeneo Health Monitor] Alerts for " . date('Y-m-d');
    $message = "Catalog Health Report\n";
    $message .= "====================\n\n";
    $message .= "Health Score: {$report['health_score']}/100 (Grade: {$report['health_grade']})\n\n";
    $message .= "Alerts:\n";
    foreach ($alerts as $alert) {
        $message .= "  $alert\n";
    }
    $message .= "\n";
    $message .= "Full report: https://pim.technostationery.com/health-reports/\n";
    
    // Uncomment to enable email alerts
    // mail($config['alert_email'], $subject, $message);
    
    echo "\n📧 Alert email would be sent to: {$config['alert_email']}\n";
}

echo "\n=========================================\n";
echo "✓ Health monitoring complete!\n";
echo "=========================================\n";
