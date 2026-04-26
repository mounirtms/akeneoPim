<?php
/**
 * Validate Product Attributes
 * Checks attribute completeness and data quality
 */

echo "=== PRODUCT ATTRIBUTE VALIDATION ===\n\n";

// Database connection
$pdo = new PDO("mysql:host=127.0.0.1;port=3307;dbname=akeneo_pim", "akeneo_pim", "akeneo_pim");
$pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);

// Test 1: Attributes by Group
echo "[1/5] Checking Attribute Distribution by Group...\n";
$stmt = $pdo->query("
    SELECT 
        pag.code AS group_code,
        pag.label AS group_label,
        pag.sort_order,
        COUNT(pa.id) AS attribute_count
    FROM pim_catalog_attribute_group pag
    LEFT JOIN pim_catalog_attribute pa ON pa.group_id = pag.id
    GROUP BY pag.id
    ORDER BY pag.sort_order
");

$groups = $stmt->fetchAll(PDO::FETCH_ASSOC);
echo "  Attribute Groups:\n";
$totalAttrs = 0;
foreach ($groups as $group) {
    echo "    {$group['sort_order']}. {$group['group_code']}: {$group['attribute_count']} attributes\n";
    $totalAttrs += $group['attribute_count'];
}
echo "  Total: $totalAttrs attributes\n\n";

// Test 2: Attribute Types
echo "[2/5] Checking Attribute Types...\n";
$stmt = $pdo->query("
    SELECT 
        attribute_type,
        COUNT(*) AS count
    FROM pim_catalog_attribute
    GROUP BY attribute_type
    ORDER BY count DESC
    LIMIT 10
");

$types = $stmt->fetchAll(PDO::FETCH_ASSOC);
echo "  Top Attribute Types:\n";
foreach ($types as $type) {
    echo "    - {$type['attribute_type']}: {$type['count']}\n";
}
echo "\n";

// Test 3: Required Attributes
echo "[3/5] Checking Required Attributes...\n";
$stmt = $pdo->query("
    SELECT COUNT(*) FROM pim_catalog_attribute WHERE is_required = 1
");
$requiredCount = $stmt->fetchColumn();
echo "  Required Attributes: $requiredCount\n\n";

// Test 4: Localizable & Scopable Attributes
echo "[4/5] Checking Localizable & Scopable Attributes...\n";
$stmt = $pdo->query("
    SELECT 
        is_localizable,
        is_scopable,
        COUNT(*) AS count
    FROM pim_catalog_attribute
    GROUP BY is_localizable, is_scopable
");

$locScope = $stmt->fetchAll(PDO::FETCH_ASSOC);
foreach ($locScope as $row) {
    $loc = $row['is_localizable'] ? 'Localizable' : 'Not Localizable';
    $scope = $row['is_scopable'] ? 'Scopable' : 'Not Scopable';
    echo "  $loc + $scope: {$row['count']}\n";
}
echo "\n";

// Test 5: Products with Complete Attributes
echo "[5/5] Checking Product Attribute Completeness...\n";
$stmt = $pdo->query("
    SELECT 
        COUNT(DISTINCT p.id) AS total_products,
        (SELECT COUNT(*) FROM pim_catalog_product WHERE is_enabled = 1) AS enabled_products
    FROM pim_catalog_product p
");
$result = $stmt->fetch(PDO::FETCH_ASSOC);
echo "  Total Products: {$result['total_products']}\n";
echo "  Enabled Products: {$result['enabled_products']}\n";

// Sample products with their attribute count
$stmt = $pdo->query("
    SELECT 
        p.identifier,
        COUNT(DISTINCT pv.attribute_id) AS attr_count
    FROM pim_catalog_product p
    LEFT JOIN pim_catalog_product_value pv ON pv.product_id = p.id
    WHERE p.is_enabled = 1
    GROUP BY p.id
    ORDER BY RAND()
    LIMIT 5
");

echo "\n  Sample Products:\n";
$samples = $stmt->fetchAll(PDO::FETCH_ASSOC);
foreach ($samples as $sample) {
    echo "    SKU: {$sample['identifier']} - {$sample['attr_count']} attributes\n";
}

echo "\n✅ ATTRIBUTE VALIDATION COMPLETE\n";
