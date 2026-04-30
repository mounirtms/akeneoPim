<?php
/**
 * Akeneo Data Insights & Ecommerce Data Checker
 * Diagnoses missing data grids, product models, and category issues
 */

echo "=== AKENEO DATA INSIGHTS & ECOMMERCE DATA CHECKER ===\n";
echo "Date: " . date('Y-m-d H:i:s') . "\n\n";

// Database connection
$host = '127.0.0.1';
$port = 3307;
$dbname = 'akeneo_pim';
$user = 'akeneo_pim';
$password = 'akeneo_pim';

try {
    $pdo = new PDO("mysql:host=$host;port=$port;dbname=$dbname;charset=utf8mb4", $user, $password);
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    echo "✅ Database connected\n\n";
} catch (PDOException $e) {
    die("❌ Connection failed: " . $e->getMessage() . "\n");
}

// 1. Check Product Models
echo "--- 1. PRODUCT MODELS ANALYSIS ---\n";
$stmt = $pdo->query("SELECT COUNT(*) as total FROM pim_catalog_product_model");
$productModelsCount = $stmt->fetch(PDO::FETCH_ASSOC)['total'];
echo "Total Product Models: $productModelsCount\n";

if ($productModelsCount > 0) {
    $stmt = $pdo->query("
        SELECT pm.code, pm.family_variant_id, pm.parent_id, 
               fv.code as family_variant_code
        FROM pim_catalog_product_model pm
        LEFT JOIN pim_catalog_family_variant fv ON pm.family_variant_id = fv.id
        LIMIT 10
    ");
    echo "Sample Product Models:\n";
    while ($row = $stmt->fetch(PDO::FETCH_ASSOC)) {
        echo "  - Code: {$row['code']}, Family Variant: {$row['family_variant_code']}, Parent: {$row['parent_id']}\n";
    }
}
echo "\n";

// 2. Check Categories
echo "--- 2. CATEGORIES ANALYSIS ---\n";
$stmt = $pdo->query("SELECT COUNT(*) as total FROM pim_catalog_category");
$categoriesCount = $stmt->fetch(PDO::FETCH_ASSOC)['total'];
echo "Total Categories: $categoriesCount\n";

$stmt = $pdo->query("
    SELECT c.id, c.code, c.parent_id, c.root, c.lvl,
           ct.label
    FROM pim_catalog_category c
    LEFT JOIN pim_catalog_category_translation ct ON c.id = ct.foreign_key
    WHERE ct.locale = 'en_US' OR ct.locale IS NULL
    ORDER BY c.lvl, c.code
    LIMIT 20
");
echo "Sample Categories:\n";
while ($row = $stmt->fetch(PDO::FETCH_ASSOC)) {
    $label = $row['label'] ?: 'No label';
    echo "  - Code: {$row['code']}, Level: {$row['lvl']}, Label: $label, Root: {$row['root']}, Parent: {$row['parent_id']}\n";
}
echo "\n";

// 3. Check Products assigned to Categories
echo "--- 3. PRODUCT-CATEGORY ASSIGNMENTS ---\n";
$stmt = $pdo->query("
    SELECT COUNT(DISTINCT product_id) as products_with_categories
    FROM pim_catalog_category_product
");
$productsWithCategories = $stmt->fetch(PDO::FETCH_ASSOC)['products_with_categories'];
echo "Products assigned to categories: $productsWithCategories\n";

$stmt = $pdo->query("
    SELECT p.id, p.identifier, COUNT(DISTINCT cp.category_id) as category_count
    FROM pim_catalog_product p
    LEFT JOIN pim_catalog_category_product cp ON p.id = cp.product_id
    GROUP BY p.id
    HAVING category_count = 0
    LIMIT 10
");
$orphanCount = $stmt->rowCount();
echo "Products WITHOUT categories (orphans): $orphanCount\n";
if ($orphanCount > 0) {
    echo "Sample orphan products:\n";
    while ($row = $stmt->fetch(PDO::FETCH_ASSOC)) {
        echo "  - SKU: {$row['identifier']}\n";
    }
}
echo "\n";

// 4. Check Attributes for Ecommerce
echo "--- 4. ECOMMERCE ATTRIBUTES CHECK ---\n";
$ecommerceAttributes = ['price', 'description', 'short_description', 'ean', 'weight', 'image', 'thumbnail'];
foreach ($ecommerceAttributes as $attrCode) {
    $stmt = $pdo->prepare("SELECT id, attribute_type FROM pim_catalog_attribute WHERE code = ?");
    $stmt->execute([$attrCode]);
    $attr = $stmt->fetch(PDO::FETCH_ASSOC);
    if ($attr) {
        echo "  ✅ $attrCode exists (type: {$attr['attribute_type']})\n";
    } else {
        echo "  ❌ $attrCode MISSING\n";
    }
}
echo "\n";

// 5. Check Channels (for ecommerce scope)
echo "--- 5. CHANNELS (ECOMMERCE SCOPE) ---\n";
$stmt = $pdo->query("SELECT code, category_id FROM pim_catalog_channel");
echo "Available Channels:\n";
while ($row = $stmt->fetch(PDO::FETCH_ASSOC)) {
    echo "  - Channel: {$row['code']}, Root Category: {$row['category_id']}\n";
}
echo "\n";

// 6. Check Locales
echo "--- 6. LOCALES ---\n";
$stmt = $pdo->query("SELECT code, is_activated FROM pim_catalog_locale");
echo "Available Locales:\n";
while ($row = $stmt->fetch(PDO::FETCH_ASSOC)) {
    $status = $row['is_activated'] ? 'Active' : 'Inactive';
    echo "  - {$row['code']} ($status)\n";
}
echo "\n";

// 7. Check Families and Family Variants
echo "--- 7. FAMILIES & FAMILY VARIANTS ---\n";
$stmt = $pdo->query("
    SELECT f.code as family_code, COUNT(fv.id) as variant_count
    FROM pim_catalog_family f
    LEFT JOIN pim_catalog_family_variant fv ON f.id = fv.family_id
    GROUP BY f.id
");
echo "Families with variants:\n";
while ($row = $stmt->fetch(PDO::FETCH_ASSOC)) {
    echo "  - {$row['family_code']}: {$row['variant_count']} variants\n";
}
echo "\n";

// 8. Check Completeness
echo "--- 8. PRODUCT COMPLETENESS ---\n";
$stmt = $pdo->query("
    SELECT 
        ROUND(AVG(ratio), 2) as avg_completeness,
        MIN(ratio) as min_completeness,
        MAX(ratio) as max_completeness
    FROM pim_catalog_completeness
");
$completeness = $stmt->fetch(PDO::FETCH_ASSOC);
echo "Average Completeness: {$completeness['avg_completeness']}%\n";
echo "Min Completeness: {$completeness['min_completeness']}%\n";
echo "Max Completeness: {$completeness['max_completeness']}%\n";
echo "\n";

// 9. Check Data Quality Insights (if exists)
echo "--- 9. DATA QUALITY INSIGHTS TABLES ---\n";
$qualityTables = [
    'pimee_product_data_quality_insight',
    'akeneo_data_quality_product_score',
    'pim_data_quality_insights_product_score'
];
foreach ($qualityTables as $table) {
    $stmt = $pdo->query("SHOW TABLES LIKE '$table'");
    if ($stmt->rowCount() > 0) {
        $count = $pdo->query("SELECT COUNT(*) as c FROM $table")->fetch()['c'];
        echo "  ✅ $table exists ($count records)\n";
    } else {
        echo "  ❌ $table NOT FOUND\n";
    }
}
echo "\n";

// 10. Recommendations
echo "=== RECOMMENDATIONS ===\n";
if ($categoriesCount == 0) {
    echo "❌ CRITICAL: No categories found!\n";
    echo "   → Import categories first\n";
}
if ($productsWithCategories == 0) {
    echo "❌ CRITICAL: No products assigned to categories!\n";
    echo "   → Assign products to categories\n";
}
if ($productModelsCount == 0) {
    echo "⚠️  WARNING: No product models (variants) found\n";
    echo "   → If you need variants, create family variants first\n";
}
echo "\n";

echo "✅ Check complete!\n";
