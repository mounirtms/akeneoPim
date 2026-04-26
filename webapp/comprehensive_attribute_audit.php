<?php
/**
 * Comprehensive Attribute Audit Script
 * Analyzes all product attributes, values, and data quality
 */

echo "=== COMPREHENSIVE ATTRIBUTE AUDIT ===\n";
echo "Date: " . date('Y-m-d H:i:s') . "\n\n";

// Database connection
$pdo = new PDO("mysql:host=127.0.0.1;port=3307;dbname=akeneo_pim", "akeneo_pim", "akeneo_pim");
$pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);

$results = [];

// SECTION 1: Attribute Overview
echo "=== SECTION 1: ATTRIBUTE OVERVIEW ===\n";
echo str_repeat("=", 50) . "\n\n";

$totalAttributes = $pdo->fetchOne("SELECT COUNT(*) FROM pim_catalog_attribute");
echo "Total Attributes: $totalAttributes\n\n";

// 1.1 Attributes by Type
echo "[1.1] Attributes by Type:\n";
$stmt = $pdo->query("
    SELECT attribute_type, COUNT(*) as count 
    FROM pim_catalog_attribute 
    GROUP BY attribute_type 
    ORDER BY count DESC
");
$typeResults = $stmt->fetchAll(PDO::FETCH_ASSOC);
foreach ($typeResults as $row) {
    echo "  {$row['attribute_type']}: {$row['count']}\n";
}
echo "\n";

// 1.2 Attributes by Group
echo "[1.2] Attributes by Group:\n";
$stmt = $pdo->query("
    SELECT 
        pag.code as group_code,
        pag.sort_order,
        COUNT(pa.id) as attribute_count
    FROM pim_catalog_attribute_group pag
    LEFT JOIN pim_catalog_attribute pa ON pa.group_id = pag.id
    GROUP BY pag.id, pag.code, pag.sort_order
    ORDER BY pag.sort_order
");
$groupResults = $stmt->fetchAll(PDO::FETCH_ASSOC);
foreach ($groupResults as $row) {
    echo "  {$row['group_code']} (sort: {$row['sort_order']}): {$row['attribute_count']} attributes\n";
}
echo "\n";

// SECTION 2: Attribute Properties
echo "=== SECTION 2: ATTRIBUTE PROPERTIES ===\n";
echo str_repeat("=", 50) . "\n\n";

// 2.1 Required Attributes
echo "[2.1] Required Attributes:\n";
$requiredCount = $pdo->fetchOne("SELECT COUNT(*) FROM pim_catalog_attribute WHERE is_required = 1");
$optionalCount = $totalAttributes - $requiredCount;
echo "  Required: $requiredCount (" . round(($requiredCount/$totalAttributes)*100, 1) . "%)\n";
echo "  Optional: $optionalCount (" . round(($optionalCount/$totalAttributes)*100, 1) . "%)\n\n";

// 2.2 Localizable Attributes
echo "[2.2] Localizable Attributes:\n";
$localizableCount = $pdo->fetchOne("SELECT COUNT(*) FROM pim_catalog_attribute WHERE is_localizable = 1");
echo "  Localizable: $localizableCount (" . round(($localizableCount/$totalAttributes)*100, 1) . "%)\n";
echo "  Non-localizable: " . ($totalAttributes - $localizableCount) . "\n\n";

// 2.3 Scopable Attributes
echo "[2.3] Scopable Attributes:\n";
$scopableCount = $pdo->fetchOne("SELECT COUNT(*) FROM pim_catalog_attribute WHERE is_scopable = 1");
echo "  Scopable: $scopableCount (" . round(($scopableCount/$totalAttributes)*100, 1) . "%)\n";
echo "  Non-scopable: " . ($totalAttributes - $scopableCount) . "\n\n";

// 2.4 Unique Attributes
echo "[2.4] Unique Attributes:\n";
$uniqueCount = $pdo->fetchOne("SELECT COUNT(*) FROM pim_catalog_attribute WHERE is_unique = 1");
echo "  Unique: $uniqueCount\n";
echo "  Non-unique: " . ($totalAttributes - $uniqueCount) . "\n\n";

// SECTION 3: Attribute Codes and Naming
echo "=== SECTION 3: ATTRIBUTE CODES & NAMING ===\n";
echo str_repeat("=", 50) . "\n\n";

// 3.1 Attribute Code Patterns
echo "[3.1] Attribute Code Patterns:\n";
$stmt = $pdo->query("
    SELECT code FROM pim_catalog_attribute ORDER BY code LIMIT 20
");
$codes = $stmt->fetchAll(PDO::FETCH_COLUMN);
echo "  Sample attribute codes:\n";
foreach (array_slice($codes, 0, 15) as $code) {
    echo "    - $code\n";
}
echo "\n";

// 3.2 Code Length Analysis
echo "[3.2] Code Length Statistics:\n";
$stmt = $pdo->query("
    SELECT 
        MIN(LENGTH(code)) as min_length,
        MAX(LENGTH(code)) as max_length,
        AVG(LENGTH(code)) as avg_length
    FROM pim_catalog_attribute
");
$lengthStats = $stmt->fetch(PDO::FETCH_ASSOC);
echo "  Min length: {$lengthStats['min_length']} characters\n";
echo "  Max length: {$lengthStats['max_length']} characters\n";
echo "  Avg length: " . round($lengthStats['avg_length'], 1) . " characters\n\n";

// SECTION 4: Attribute Options (for select types)
echo "=== SECTION 4: ATTRIBUTE OPTIONS ===\n";
echo str_repeat("=", 50) . "\n\n";

// 4.1 Select Attributes with Options
echo "[4.1] Select/Multi-select Attributes:\n";
$stmt = $pdo->query("
    SELECT 
        pa.code,
        pa.attribute_type,
        COUNT(DISTINCT pao.id) as option_count
    FROM pim_catalog_attribute pa
    LEFT JOIN pim_catalog_attribute_option pao ON pao.attribute_id = pa.id
    WHERE pa.attribute_type IN ('pim_catalog_simpleselect', 'pim_catalog_multiselect')
    GROUP BY pa.id
    ORDER BY option_count DESC
    LIMIT 10
");
$selectAttrs = $stmt->fetchAll(PDO::FETCH_ASSOC);
echo "  Top 10 select attributes by option count:\n";
foreach ($selectAttrs as $row) {
    echo "    {$row['code']}: {$row['option_count']} options ({$row['attribute_type']})\n";
}
echo "\n";

// SECTION 5: Attribute Usage in Products
echo "=== SECTION 5: ATTRIBUTE USAGE IN PRODUCTS ===\n";
echo str_repeat("=", 50) . "\n\n";

// 5.1 Most Used Attributes
echo "[5.1] Most Used Attributes (by value count):\n";
$stmt = $pdo->query("
    SELECT 
        pa.code,
        pa.attribute_type,
        COUNT(DISTINCT ppv.id) as value_count
    FROM pim_catalog_attribute pa
    LEFT JOIN pim_catalog_product_value ppv ON ppv.attribute_id = pa.id
    GROUP BY pa.id
    ORDER BY value_count DESC
    LIMIT 15
");
$usedAttrs = $stmt->fetchAll(PDO::FETCH_ASSOC);
foreach ($usedAttrs as $row) {
    echo "    {$row['code']}: {$row['value_count']} values ({$row['attribute_type']})\n";
}
echo "\n";

// 5.2 Unused Attributes
echo "[5.2] Unused Attributes (no values):\n";
$stmt = $pdo->query("
    SELECT pa.code, pa.attribute_type
    FROM pim_catalog_attribute pa
    LEFT JOIN pim_catalog_product_value ppv ON ppv.attribute_id = pa.id
    WHERE ppv.id IS NULL
    LIMIT 20
");
$unusedAttrs = $stmt->fetchAll(PDO::FETCH_ASSOC);
$unusedCount = count($unusedAttrs);
if ($unusedCount > 0) {
    echo "  Found $unusedCount unused attributes:\n";
    foreach (array_slice($unusedAttrs, 0, 10) as $row) {
        echo "    - {$row['code']} ({$row['attribute_type']})\n";
    }
    if ($unusedCount > 10) {
        echo "    ... and " . ($unusedCount - 10) . " more\n";
    }
} else {
    echo "  ✅ All attributes are being used\n";
}
echo "\n";

// SECTION 6: Data Quality Analysis
echo "=== SECTION 6: DATA QUALITY ANALYSIS ===\n";
echo str_repeat("=", 50) . "\n\n";

// 6.1 Product Value Distribution
echo "[6.1] Product Value Statistics:\n";
$stmt = $pdo->query("
    SELECT 
        COUNT(DISTINCT product_id) as products_with_values,
        COUNT(*) as total_values,
        COUNT(*)/COUNT(DISTINCT product_id) as avg_values_per_product
    FROM pim_catalog_product_value
");
$valueStats = $stmt->fetch(PDO::FETCH_ASSOC);
echo "  Products with values: {$valueStats['products_with_values']}\n";
echo "  Total values: {$valueStats['total_values']}\n";
echo "  Avg values per product: " . round($valueStats['avg_values_per_product'], 1) . "\n\n";

// 6.2 Empty Values Check
echo "[6.2] Empty Value Analysis:\n";
$stmt = $pdo->query("
    SELECT COUNT(*) as empty_text_count
    FROM pim_catalog_product_value ppv
    JOIN pim_catalog_attribute pa ON pa.id = ppv.attribute_id
    WHERE pa.attribute_type IN ('pim_catalog_text', 'pim_catalog_textarea')
    AND (ppv.value_string IS NULL OR ppv.value_string = '')
");
$emptyCount = $stmt->fetchColumn();
echo "  Empty text values: $emptyCount\n\n";

// SECTION 7: Summary and Recommendations
echo "=== SECTION 7: SUMMARY ===\n";
echo str_repeat("=", 50) . "\n\n";

echo "Key Findings:\n";
echo "  Total Attributes: $totalAttributes\n";
echo "  Required Attributes: $requiredCount (" . round(($requiredCount/$totalAttributes)*100, 1) . "%)\n";
echo "  Localizable: $localizableCount (" . round(($localizableCount/$totalAttributes)*100, 1) . "%)\n";
echo "  Scopable: $scopableCount (" . round(($scopableCount/$totalAttributes)*100, 1) . "%)\n";
echo "  Unique: $uniqueCount\n";
if ($unusedCount > 0) {
    echo "  ⚠️  Unused Attributes: $unusedCount\n";
} else {
    echo "  ✅ All Attributes Used\n";
}

echo "\n✅ AUDIT COMPLETE\n";
