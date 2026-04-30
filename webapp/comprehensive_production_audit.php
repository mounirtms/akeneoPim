<?php
/**
 * Comprehensive Production Audit & Optimization Script
 * Date: 2026-04-28
 * 
 * Audits:
 * 1. Color attribute analysis (631 options)
 * 2. Complex attribute values (price, metric, etc.)
 * 3. Product completeness status
 * 4. SEO metadata coverage
 * 5. Data quality metrics
 * 6. System optimization recommendations
 */

require_once __DIR__ . '/../vendor/autoload.php';

use Symfony\Component\Dotenv\Dotenv;

$dotenv = new Dotenv();
$dotenv->load(__DIR__ . '/../.env');

$host = '127.0.0.1';
$port = '3307';
$dbname = 'akeneo_pim';
$user = 'root';
$pass = 'YourNewStrongPassword';

$dsn = "mysql:host={$host};port={$port};dbname={$dbname};charset=utf8mb4";

try {
    $pdo = new PDO($dsn, $user, $pass, [
        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC
    ]);
    
    echo "================================================================================\n";
    echo "COMPREHENSIVE PRODUCTION AUDIT & OPTIMIZATION\n";
    echo "Date: " . date('Y-m-d H:i:s') . "\n";
    echo "================================================================================\n\n";
    
    // ========================================
    // 1. COLOR ATTRIBUTE ANALYSIS
    // ========================================
    echo "=== 1. COLOR ATTRIBUTE ANALYSIS ===\n\n";
    
    $stmt = $pdo->query("
        SELECT 
            a.code,
            a.attribute_type,
            COUNT(DISTINCT ao.id) as option_count,
            a.is_localizable,
            a.is_scopable
        FROM pim_catalog_attribute a
        LEFT JOIN pim_catalog_attribute_option ao ON a.id = ao.attribute_id
        WHERE a.code = 'color'
        GROUP BY a.code, a.attribute_type, a.is_localizable, a.is_scopable
    ");
    $colorInfo = $stmt->fetch();
    
    echo "Color Attribute Configuration:\n";
    echo "  Code: {$colorInfo['code']}\n";
    echo "  Type: {$colorInfo['attribute_type']}\n";
    echo "  Total Options: {$colorInfo['option_count']}\n";
    echo "  Localizable: " . ($colorInfo['is_localizable'] ? 'Yes' : 'No') . "\n";
    echo "  Scopable: " . ($colorInfo['is_scopable'] ? 'Yes' : 'No') . "\n\n";
    
    // Check if color is used
    $stmt = $pdo->query("
        SELECT COUNT(DISTINCT cp.id) as product_count
        FROM pim_catalog_product cp
        WHERE cp.raw_values LIKE '%\"color\"%'
    ");
    $colorUsage = $stmt->fetch();
    echo "Products using color attribute: {$colorUsage['product_count']}\n\n";
    
    // Get color option distribution
    $stmt = $pdo->query("
        SELECT 
            COUNT(*) as total_options,
            COUNT(DISTINCT aov.locale_code) as locales,
            SUM(CASE WHEN aov.locale_code = 'fr_FR' THEN 1 ELSE 0 END) as fr_labels,
            SUM(CASE WHEN aov.locale_code = 'en_US' THEN 1 ELSE 0 END) as en_labels
        FROM pim_catalog_attribute_option ao
        JOIN pim_catalog_attribute a ON ao.attribute_id = a.id
        LEFT JOIN pim_catalog_attribute_option_value aov ON ao.id = aov.option_id
        WHERE a.code = 'color'
    ");
    $colorDist = $stmt->fetch();
    
    echo "Color Options Localization:\n";
    echo "  Total options: {$colorDist['total_options']}\n";
    echo "  French labels: {$colorDist['fr_labels']}\n";
    echo "  English labels: {$colorDist['en_labels']}\n";
    echo "  Missing English: " . ($colorDist['total_options'] - $colorDist['en_labels']) . "\n\n";
    
    if ($colorInfo['option_count'] > 200) {
        echo "⚠️  WARNING: {$colorInfo['option_count']} color options is excessive!\n";
        echo "    Recommendation: Consolidate to 50-100 standard colors\n";
        echo "    Benefits: Better UX, faster queries, easier management\n\n";
    }
    
    // ========================================
    // 2. COMPLEX ATTRIBUTE VALUES AUDIT
    // ========================================
    echo "\n=== 2. COMPLEX ATTRIBUTE VALUES AUDIT ===\n\n";
    
    // Price attribute
    $stmt = $pdo->query("
        SELECT 
            COUNT(DISTINCT cp.id) as total_products,
            SUM(CASE WHEN cp.raw_values LIKE '%\"price\"%' AND cp.raw_values NOT LIKE '%\"price\":null%' THEN 1 ELSE 0 END) as with_price,
            SUM(CASE WHEN cp.raw_values LIKE '%\"price\":null%' OR cp.raw_values NOT LIKE '%\"price\"%' THEN 1 ELSE 0 END) as without_price
        FROM pim_catalog_product cp
        WHERE cp.is_enabled = 1
    ");
    $priceStats = $stmt->fetch();
    
    echo "Price Attribute Coverage:\n";
    echo "  Total products: {$priceStats['total_products']}\n";
    echo "  With price: {$priceStats['with_price']} (" . round(($priceStats['with_price'] / $priceStats['total_products']) * 100, 2) . "%)\n";
    echo "  Without price: {$priceStats['without_price']} (" . round(($priceStats['without_price'] / $priceStats['total_products']) * 100, 2) . "%)\n\n";
    
    // Weight attribute  
    $stmt = $pdo->query("
        SELECT 
            COUNT(DISTINCT cp.id) as total_products,
            SUM(CASE WHEN cp.raw_values LIKE '%\"weight\"%' AND cp.raw_values NOT LIKE '%\"weight\":null%' THEN 1 ELSE 0 END) as with_weight,
            SUM(CASE WHEN cp.raw_values LIKE '%\"weight\":null%' OR cp.raw_values NOT LIKE '%\"weight\"%' THEN 1 ELSE 0 END) as without_weight
        FROM pim_catalog_product cp
        WHERE cp.is_enabled = 1
    ");
    $weightStats = $stmt->fetch();
    
    echo "Weight Attribute Coverage:\n";
    echo "  With weight: {$weightStats['with_weight']} (" . round(($weightStats['with_weight'] / $weightStats['total_products']) * 100, 2) . "%)\n";
    echo "  Without weight: {$weightStats['without_weight']} (" . round(($weightStats['without_weight'] / $weightStats['total_products']) * 100, 2) . "%)\n\n";
    
    // ========================================
    // 3. COMPLETENESS STATUS
    // ========================================
    echo "\n=== 3. PRODUCT COMPLETENESS STATUS ===\n\n";
    
    $stmt = $pdo->query("
        SELECT 
            c.code as channel,
            l.code as locale,
            COUNT(DISTINCT comp.product_id) as products,
            AVG(comp.required_count) as avg_required,
            AVG(comp.missing_count) as avg_missing,
            ROUND(AVG((comp.required_count - comp.missing_count) / NULLIF(comp.required_count, 0) * 100), 2) as avg_completeness,
            SUM(CASE WHEN comp.missing_count = 0 THEN 1 ELSE 0 END) as complete_products,
            SUM(CASE WHEN comp.missing_count > 0 THEN 1 ELSE 0 END) as incomplete_products
        FROM pim_catalog_completeness comp
        JOIN pim_catalog_channel c ON comp.channel_id = c.id
        JOIN pim_catalog_locale l ON comp.locale_id = l.id
        WHERE c.code = 'ecommerce'
        GROUP BY c.code, l.code
    ");
    
    echo "Ecommerce Channel Completeness:\n";
    while ($row = $stmt->fetch()) {
        echo "  Locale: {$row['locale']}\n";
        echo "    Products tracked: {$row['products']}\n";
        echo "    Avg required attrs: " . round($row['avg_required'], 2) . "\n";
        echo "    Avg missing attrs: " . round($row['avg_missing'], 2) . "\n";
        echo "    Avg completeness: " . ($row['avg_completeness'] ?: '0.00') . "%\n";
        echo "    Complete products: {$row['complete_products']}\n";
        echo "    Incomplete products: {$row['incomplete_products']}\n\n";
    }
    
    // ========================================
    // 4. SEO METADATA COVERAGE
    // ========================================
    echo "\n=== 4. SEO METADATA COVERAGE (AKENEO) ===\n\n";
    
    $seoAttributes = ['url_key', 'meta_title', 'meta_description', 'meta_keyword'];
    
    foreach ($seoAttributes as $attr) {
        $stmt = $pdo->prepare("
            SELECT 
                COUNT(DISTINCT cp.id) as total_products,
                SUM(CASE WHEN cp.raw_values LIKE CONCAT('%\"', ?, '\"%') AND cp.raw_values NOT LIKE CONCAT('%\"', ?, '\":null%') THEN 1 ELSE 0 END) as with_value,
                SUM(CASE WHEN cp.raw_values LIKE CONCAT('%\"', ?, '\":null%') OR cp.raw_values NOT LIKE CONCAT('%\"', ?, '\"%') THEN 1 ELSE 0 END) as without_value
            FROM pim_catalog_product cp
            WHERE cp.is_enabled = 1
        ");
        $stmt->execute([$attr, $attr, $attr, $attr]);
        $seoStats = $stmt->fetch();
        
        $coverage = $seoStats['total_products'] > 0 ? round(($seoStats['with_value'] / $seoStats['total_products']) * 100, 2) : 0;
        $status = $coverage >= 95 ? '✅' : ($coverage >= 50 ? '⚠️' : '🔴');
        
        echo "{$status} {$attr}:\n";
        echo "    With value: {$seoStats['with_value']} ({$coverage}%)\n";
        echo "    Without value: {$seoStats['without_value']}\n\n";
    }
    
    // ========================================
    // 5. ATTRIBUTE GROUPS OPTIMIZATION
    // ========================================
    echo "\n=== 5. ATTRIBUTE GROUPS DISTRIBUTION ===\n\n";
    
    $stmt = $pdo->query("
        SELECT 
            ag.code,
            ag.sort_order,
            COUNT(DISTINCT a.id) as attribute_count
        FROM pim_catalog_attribute_group ag
        LEFT JOIN pim_catalog_attribute a ON ag.id = a.group_id
        GROUP BY ag.code, ag.sort_order
        ORDER BY ag.sort_order
    ");
    
    echo "Attribute Groups:\n";
    while ($row = $stmt->fetch()) {
        $status = $row['attribute_count'] == 0 ? '⚠️  EMPTY' : '✅';
        echo "  {$status} {$row['code']}: {$row['attribute_count']} attributes (sort: {$row['sort_order']})\n";
    }
    
    // ========================================
    // 6. SYSTEM OPTIMIZATION RECOMMENDATIONS
    // ========================================
    echo "\n\n=== 6. OPTIMIZATION RECOMMENDATIONS ===\n\n";
    
    $recommendations = [];
    $priority = [];
    
    // Check color options
    if ($colorInfo['option_count'] > 200) {
        $recommendations[] = "Consolidate color options from {$colorInfo['option_count']} to 50-100 standard colors";
        $priority[] = 'HIGH';
    }
    
    // Check SEO metadata
    foreach ($seoAttributes as $attr) {
        $stmt = $pdo->prepare("
            SELECT COUNT(*) as missing
            FROM pim_catalog_product cp
            WHERE cp.is_enabled = 1
            AND (cp.raw_values LIKE CONCAT('%\"', ?, '\":null%') OR cp.raw_values NOT LIKE CONCAT('%\"', ?, '\"%'))
        ");
        $stmt->execute([$attr, $attr]);
        $result = $stmt->fetch();
        
        if ($result['missing'] > 100) {
            $recommendations[] = "Generate {$attr} for {$result['missing']} products";
            $priority[] = 'CRITICAL';
        }
    }
    
    // Check completeness
    if ($priceStats['without_price'] > 0) {
        $recommendations[] = "Add price data for {$priceStats['without_price']} products";
        $priority[] = 'HIGH';
    }
    
    if ($weightStats['without_weight'] > 1000) {
        $recommendations[] = "Add weight data for {$weightStats['without_weight']} products";
        $priority[] = 'MEDIUM';
    }
    
    // Display recommendations
    if (count($recommendations) > 0) {
        foreach ($recommendations as $idx => $rec) {
            echo sprintf("[%s] %s\n", $priority[$idx], $rec);
        }
    } else {
        echo "✅ No critical optimization issues found!\n";
    }
    
    // ========================================
    // SUMMARY
    // ========================================
    echo "\n\n=== AUDIT SUMMARY ===\n";
    echo "Date: " . date('Y-m-d H:i:s') . "\n";
    echo "Total Products: {$priceStats['total_products']}\n";
    echo "Color Options: {$colorInfo['option_count']}\n";
    echo "Price Coverage: " . round(($priceStats['with_price'] / $priceStats['total_products']) * 100, 2) . "%\n";
    echo "Weight Coverage: " . round(($weightStats['with_weight'] / $weightStats['total_products']) * 100, 2) . "%\n";
    echo "Recommendations: " . count($recommendations) . "\n";
    echo "\n";
    
    echo "================================================================================\n";
    echo "Audit completed successfully!\n";
    echo "================================================================================\n";
    
} catch (Exception $e) {
    echo "ERROR: " . $e->getMessage() . "\n";
    exit(1);
}
