<?php
/**
 * Akeneo Data Diagnostic Script
 * Run: php /home/pim/public_html/webapp/diagnose_data.php
 */

ini_set('display_errors', 1);
error_reporting(E_ALL);

$host = '127.0.0.1';
$port = '3307';
$dbname = 'akeneo_pim';
$user = 'akeneo_pim';
$password = 'akeneo_pim';

try {
    $pdo = new PDO("mysql:host=$host;port=$port;dbname=$dbname;charset=utf8mb4", $user, $password, [
        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
    ]);

    echo "=== AKENEO PIM DATA DIAGNOSTIC ===\n\n";

    // Products
    $stmt = $pdo->query("SELECT COUNT(*) as count FROM pim_catalog_product");
    $products = $stmt->fetch()['count'];
    echo "✓ Products in DB: $products\n";

    // Product Models
    $stmt = $pdo->query("SELECT COUNT(*) as count FROM pim_catalog_product_model");
    $models = $stmt->fetch()['count'];
    echo "✓ Product Models in DB: $models\n";

    // Categories
    $stmt = $pdo->query("SELECT COUNT(*) as count FROM pim_catalog_category");
    $categories = $stmt->fetch()['count'];
    echo "✓ Categories in DB: $categories\n";

    // Attributes
    $stmt = $pdo->query("SELECT COUNT(*) as count FROM pim_catalog_attribute");
    $attributes = $stmt->fetch()['count'];
    echo "✓ Attributes in DB: $attributes\n";

    // Attribute Groups
    $stmt = $pdo->query("SELECT COUNT(*) as count FROM pim_catalog_attribute_group");
    $attrGroups = $stmt->fetch()['count'];
    echo "✓ Attribute Groups in DB: $attrGroups\n";
    
    if ($attrGroups < 10) {
        echo "  ⚠ WARNING: Only $attrGroups attribute groups found!\n";
        $stmt = $pdo->query("SELECT code, label FROM pim_catalog_attribute_group ORDER BY code");
        while ($row = $stmt->fetch()) {
            echo "    - {$row['code']}: {$row['label']}\n";
        }
    }

    // Families
    $stmt = $pdo->query("SELECT COUNT(*) as count FROM pim_catalog_family");
    $families = $stmt->fetch()['count'];
    echo "✓ Families in DB: $families\n";

    // Family Variants
    $stmt = $pdo->query("SELECT COUNT(*) as count FROM pim_catalog_family_variant");
    $famVariants = $stmt->fetch()['count'];
    echo "✓ Family Variants in DB: $famVariants\n";

    // Product completeness
    $stmt = $pdo->query("
        SELECT 
            COUNT(DISTINCT p.id) as total_products,
            COUNT(DISTINCT CASE WHEN c.ratio = 100 THEN p.id END) as complete,
            COUNT(DISTINCT CASE WHEN c.ratio > 0 AND c.ratio < 100 THEN p.id END) as incomplete,
            COUNT(DISTINCT CASE WHEN c.ratio IS NULL OR c.ratio = 0 THEN p.id END) as empty
        FROM pim_catalog_product p
        LEFT JOIN pim_catalog_completeness c ON p.id = c.product_id
    ");
    $completeness = $stmt->fetch();
    echo "\n=== PRODUCT COMPLETENESS ===\n";
    echo "Total products: {$completeness['total_products']}\n";
    echo "Complete (100%): {$completeness['complete']}\n";
    echo "Incomplete (1-99%): {$completeness['incomplete']}\n";
    echo "Empty (0%): {$completeness['empty']}\n";

    // Quality scores
    $stmt = $pdo->query("
        SELECT 
            COUNT(*) as total,
            AVG(score) as avg_score,
            MIN(score) as min_score,
            MAX(score) as max_score
        FROM pim_data_quality_insights_product_score
    ");
    $quality = $stmt->fetch();
    echo "\n=== DATA QUALITY SCORES ===\n";
    echo "Products with scores: {$quality['total']}\n";
    echo "Average score: " . round($quality['avg_score'], 2) . "%\n";
    echo "Min score: {$quality['min_score']}%\n";
    echo "Max score: {$quality['max_score']}%\n";

    // Products with images
    $stmt = $pdo->query("
        SELECT COUNT(DISTINCT p.id) as count
        FROM pim_catalog_product p
        INNER JOIN pim_catalog_product_value v ON p.id = v.entity_id
        INNER JOIN pim_catalog_attribute a ON v.attribute_id = a.id
        WHERE a.attribute_type = 'pim_catalog_image'
        AND v.data IS NOT NULL
        AND v.data != ''
    ");
    $withImages = $stmt->fetch()['count'];
    echo "\n=== PRODUCTS WITH IMAGES ===\n";
    echo "Products with at least 1 image: $withImages\n";
    echo "Percentage: " . round(($withImages / $products) * 100, 1) . "%\n";

    // Attribute groups detail
    echo "\n=== ATTRIBUTE GROUPS DETAIL ===\n";
    $stmt = $pdo->query("
        SELECT ag.code, ag.label, COUNT(a.id) as attr_count
        FROM pim_catalog_attribute_group ag
        LEFT JOIN pim_catalog_attribute a ON a.group_id = ag.id
        GROUP BY ag.id, ag.code, ag.label
        ORDER BY attr_count DESC
    ");
    while ($row = $stmt->fetch()) {
        echo "{$row['code']} ({$row['label']}): {$row['attr_count']} attributes\n";
    }

    // Categories tree
    echo "\n=== CATEGORIES ===\n";
    $stmt = $pdo->query("
        SELECT 
            COUNT(*) as total,
            COUNT(CASE WHEN parent_id IS NULL THEN 1 END) as root_categories,
            COUNT(CASE WHEN parent_id IS NOT NULL THEN 1 END) as sub_categories
        FROM pim_catalog_category
    ");
    $catData = $stmt->fetch();
    echo "Total categories: {$catData['total']}\n";
    echo "Root categories: {$catData['root_categories']}\n";
    echo "Sub-categories: {$catData['sub_categories']}\n";

    echo "\n=== DIAGNOSTIC COMPLETE ===\n";

} catch (PDOException $e) {
    echo "Database error: " . $e->getMessage() . "\n";
    exit(1);
}
