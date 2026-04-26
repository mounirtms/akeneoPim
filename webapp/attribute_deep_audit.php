<?php
/**
 * Comprehensive Attribute, Values, Keys and Fields Audit
 * Date: 2026-04-26
 */

echo "=== COMPREHENSIVE ATTRIBUTE & DATA AUDIT ===\n";
echo "Date: " . date('Y-m-d H:i:s') . "\n\n";

// Database connection
$host = '127.0.0.1';
$port = '3307';
$dbname = 'akeneo_pim';
$username = 'akeneo_pim';
$password = 'akeneo_pim';

try {
    $pdo = new PDO("mysql:host=$host;port=$port;dbname=$dbname", $username, $password);
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    echo "✅ Database connected\n\n";
} catch (PDOException $e) {
    die("❌ Database connection failed: " . $e->getMessage() . "\n");
}

// 1. ATTRIBUTE ANALYSIS
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n";
echo "1. ATTRIBUTE STRUCTURE ANALYSIS\n";
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n";

// Total attributes by type
$stmt = $pdo->query("
    SELECT 
        type,
        COUNT(*) as count,
        SUM(CASE WHEN is_required = 1 THEN 1 ELSE 0 END) as required_count,
        SUM(CASE WHEN is_unique = 1 THEN 1 ELSE 0 END) as unique_count,
        SUM(CASE WHEN is_localizable = 1 THEN 1 ELSE 0 END) as localizable_count,
        SUM(CASE WHEN is_scopable = 1 THEN 1 ELSE 0 END) as scopable_count
    FROM pim_catalog_attribute
    GROUP BY type
    ORDER BY count DESC
");
$attributeTypes = $stmt->fetchAll(PDO::FETCH_ASSOC);

echo "Attributes by Type:\n";
printf("%-25s %8s %10s %10s %13s %11s\n", "Type", "Count", "Required", "Unique", "Localizable", "Scopable");
echo str_repeat("-", 90) . "\n";
foreach ($attributeTypes as $attr) {
    printf("%-25s %8d %10d %10d %13d %11d\n", 
        $attr['type'], 
        $attr['count'],
        $attr['required_count'],
        $attr['unique_count'],
        $attr['localizable_count'],
        $attr['scopable_count']
    );
}
echo "\n";

// 2. ATTRIBUTE GROUPS
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n";
echo "2. ATTRIBUTE GROUPS DISTRIBUTION\n";
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n";

$stmt = $pdo->query("
    SELECT 
        ag.code as group_code,
        ag.sort_order,
        COUNT(a.id) as attribute_count
    FROM pim_catalog_attribute_group ag
    LEFT JOIN pim_catalog_attribute a ON ag.id = a.group_id
    GROUP BY ag.id, ag.code, ag.sort_order
    ORDER BY ag.sort_order
");
$groups = $stmt->fetchAll(PDO::FETCH_ASSOC);

echo "Attribute Groups:\n";
printf("%-30s %12s %18s\n", "Group Code", "Sort Order", "Attribute Count");
echo str_repeat("-", 65) . "\n";
foreach ($groups as $group) {
    printf("%-30s %12d %18d\n", 
        $group['group_code'], 
        $group['sort_order'],
        $group['attribute_count']
    );
}
echo "\n";

// 3. ATTRIBUTE OPTIONS (for select/multiselect)
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n";
echo "3. ATTRIBUTE OPTIONS ANALYSIS\n";
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n";

$stmt = $pdo->query("
    SELECT 
        a.code as attribute_code,
        a.type,
        COUNT(DISTINCT ao.id) as option_count
    FROM pim_catalog_attribute a
    LEFT JOIN pim_catalog_attribute_option ao ON a.id = ao.attribute_id
    WHERE a.type IN ('pim_catalog_simpleselect', 'pim_catalog_multiselect')
    GROUP BY a.id, a.code, a.type
    HAVING option_count > 0
    ORDER BY option_count DESC
");
$options = $stmt->fetchAll(PDO::FETCH_ASSOC);

echo "Attributes with Options:\n";
printf("%-40s %-30s %15s\n", "Attribute Code", "Type", "Option Count");
echo str_repeat("-", 90) . "\n";
foreach ($options as $opt) {
    printf("%-40s %-30s %15d\n", 
        $opt['attribute_code'], 
        $opt['type'],
        $opt['option_count']
    );
}
echo "\n";

// 4. PRODUCT VALUES ANALYSIS
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n";
echo "4. PRODUCT VALUES UTILIZATION\n";
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n";

// Count product values by attribute
$stmt = $pdo->query("
    SELECT 
        a.code as attribute_code,
        a.type,
        COUNT(DISTINCT JSON_UNQUOTE(JSON_EXTRACT(p.raw_values, CONCAT('$.\"', a.code, '\"')))) as products_with_value
    FROM pim_catalog_attribute a
    CROSS JOIN pim_catalog_product p
    WHERE JSON_EXTRACT(p.raw_values, CONCAT('$.\"', a.code, '\"')) IS NOT NULL
    GROUP BY a.id, a.code, a.type
    ORDER BY products_with_value DESC
    LIMIT 20
");
$productValues = $stmt->fetchAll(PDO::FETCH_ASSOC);

echo "Top 20 Most Used Attributes:\n";
printf("%-40s %-30s %20s\n", "Attribute Code", "Type", "Products Using");
echo str_repeat("-", 95) . "\n";
foreach ($productValues as $pv) {
    printf("%-40s %-30s %20d\n", 
        $pv['attribute_code'], 
        $pv['type'],
        $pv['products_with_value']
    );
}
echo "\n";

// 5. FAMILY ATTRIBUTE REQUIREMENTS
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n";
echo "5. FAMILY ATTRIBUTE REQUIREMENTS\n";
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n";

$stmt = $pdo->query("
    SELECT 
        f.code as family_code,
        COUNT(DISTINCT fa.attribute_id) as attribute_count,
        SUM(CASE WHEN far.required = 1 THEN 1 ELSE 0 END) as required_count
    FROM pim_catalog_family f
    LEFT JOIN pim_catalog_family_attribute fa ON f.id = fa.family_id
    LEFT JOIN pim_catalog_attribute_requirement far ON f.id = far.family_id AND fa.attribute_id = far.attribute_id
    GROUP BY f.id, f.code
    ORDER BY attribute_count DESC
");
$families = $stmt->fetchAll(PDO::FETCH_ASSOC);

echo "Family Attribute Configuration:\n";
printf("%-30s %18s %18s\n", "Family Code", "Total Attributes", "Required Attrs");
echo str_repeat("-", 70) . "\n";
foreach ($families as $fam) {
    printf("%-30s %18d %18d\n", 
        $fam['family_code'], 
        $fam['attribute_count'],
        $fam['required_count']
    );
}
echo "\n";

// 6. DATA QUALITY METRICS
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n";
echo "6. DATA QUALITY METRICS\n";
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n";

// Products with empty required attributes
$stmt = $pdo->query("
    SELECT COUNT(*) as count FROM pim_catalog_product WHERE enabled = 1
");
$totalProducts = $stmt->fetch(PDO::FETCH_ASSOC)['count'];

// Get completeness stats
$stmt = $pdo->query("
    SELECT 
        ROUND(AVG(CAST(JSON_UNQUOTE(JSON_EXTRACT(completeness, '$.ecommerce.en_US')) AS DECIMAL(5,2))), 2) as avg_completeness_ecom,
        MIN(CAST(JSON_UNQUOTE(JSON_EXTRACT(completeness, '$.ecommerce.en_US')) AS DECIMAL(5,2))) as min_completeness,
        MAX(CAST(JSON_UNQUOTE(JSON_EXTRACT(completeness, '$.ecommerce.en_US')) AS DECIMAL(5,2))) as max_completeness
    FROM pim_catalog_product
    WHERE enabled = 1 
    AND JSON_EXTRACT(completeness, '$.ecommerce.en_US') IS NOT NULL
");
$completeness = $stmt->fetch(PDO::FETCH_ASSOC);

echo "Data Quality Summary:\n";
echo "  Total Products: $totalProducts\n";
echo "  Average Completeness (ecommerce): " . ($completeness['avg_completeness_ecom'] ?? 'N/A') . "%\n";
echo "  Min Completeness: " . ($completeness['min_completeness'] ?? 'N/A') . "%\n";
echo "  Max Completeness: " . ($completeness['max_completeness'] ?? 'N/A') . "%\n\n";

// 7. IDENTIFIER & KEY ATTRIBUTES
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n";
echo "7. IDENTIFIER & UNIQUE KEY ATTRIBUTES\n";
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n";

$stmt = $pdo->query("
    SELECT 
        code,
        type,
        is_unique,
        is_required
    FROM pim_catalog_attribute
    WHERE is_unique = 1 OR code = 'sku'
    ORDER BY code
");
$identifiers = $stmt->fetchAll(PDO::FETCH_ASSOC);

echo "Unique/Identifier Attributes:\n";
printf("%-30s %-30s %10s %12s\n", "Code", "Type", "Unique", "Required");
echo str_repeat("-", 85) . "\n";
foreach ($identifiers as $id) {
    printf("%-30s %-30s %10s %12s\n", 
        $id['code'], 
        $id['type'],
        $id['is_unique'] ? 'Yes' : 'No',
        $id['is_required'] ? 'Yes' : 'No'
    );
}
echo "\n";

// 8. UNUSED ATTRIBUTES
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n";
echo "8. UNUSED ATTRIBUTES DETECTION\n";
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n";

$stmt = $pdo->query("
    SELECT 
        a.code,
        a.type,
        a.created
    FROM pim_catalog_attribute a
    LEFT JOIN pim_catalog_family_attribute fa ON a.id = fa.attribute_id
    WHERE fa.attribute_id IS NULL
    AND a.code NOT IN ('sku')
    ORDER BY a.created DESC
    LIMIT 20
");
$unused = $stmt->fetchAll(PDO::FETCH_ASSOC);

if (count($unused) > 0) {
    echo "Attributes NOT assigned to any family:\n";
    printf("%-40s %-30s %20s\n", "Code", "Type", "Created");
    echo str_repeat("-", 95) . "\n";
    foreach ($unused as $u) {
        printf("%-40s %-30s %20s\n", 
            $u['code'], 
            $u['type'],
            $u['created']
        );
    }
} else {
    echo "✅ All attributes are assigned to families\n";
}
echo "\n";

// 9. ATTRIBUTE VALIDATION RULES
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n";
echo "9. ATTRIBUTE VALIDATION RULES\n";
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n";

$stmt = $pdo->query("
    SELECT 
        code,
        type,
        validation_rule,
        validation_regexp,
        max_characters
    FROM pim_catalog_attribute
    WHERE validation_rule IS NOT NULL OR validation_regexp IS NOT NULL OR max_characters IS NOT NULL
    ORDER BY code
");
$validations = $stmt->fetchAll(PDO::FETCH_ASSOC);

if (count($validations) > 0) {
    echo "Attributes with Validation Rules:\n";
    printf("%-30s %-25s %-20s %15s\n", "Code", "Type", "Rule", "Max Chars");
    echo str_repeat("-", 95) . "\n";
    foreach ($validations as $val) {
        printf("%-30s %-25s %-20s %15s\n", 
            $val['code'], 
            $val['type'],
            $val['validation_rule'] ?? '-',
            $val['max_characters'] ?? '-'
        );
    }
} else {
    echo "No attributes with validation rules found\n";
}
echo "\n";

// 10. SUMMARY & RECOMMENDATIONS
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n";
echo "10. SUMMARY & RECOMMENDATIONS\n";
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n";

$totalAttrs = $pdo->query("SELECT COUNT(*) FROM pim_catalog_attribute")->fetchColumn();
$requiredAttrs = $pdo->query("SELECT COUNT(*) FROM pim_catalog_attribute WHERE is_required = 1")->fetchColumn();
$uniqueAttrs = $pdo->query("SELECT COUNT(*) FROM pim_catalog_attribute WHERE is_unique = 1")->fetchColumn();
$localizableAttrs = $pdo->query("SELECT COUNT(*) FROM pim_catalog_attribute WHERE is_localizable = 1")->fetchColumn();
$scopableAttrs = $pdo->query("SELECT COUNT(*) FROM pim_catalog_attribute WHERE is_scopable = 1")->fetchColumn();

echo "AUDIT SUMMARY:\n";
echo "  Total Attributes: $totalAttrs\n";
echo "  Required Attributes: $requiredAttrs\n";
echo "  Unique Attributes: $uniqueAttrs\n";
echo "  Localizable Attributes: $localizableAttrs\n";
echo "  Scopable Attributes: $scopableAttrs\n\n";

echo "RECOMMENDATIONS:\n";
echo "  1. Review unused attributes and consider removal if not needed\n";
echo "  2. Ensure all required attributes have values for enabled products\n";
echo "  3. Validate attribute options for consistency\n";
echo "  4. Check data quality scores and improve completeness\n";
echo "  5. Review attribute validation rules for data integrity\n";
echo "  6. Optimize attribute groups for better organization\n";
echo "  7. Document attribute usage and mapping for Magento sync\n\n";

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n";
echo "Audit completed at: " . date('Y-m-d H:i:s') . "\n";
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n";
