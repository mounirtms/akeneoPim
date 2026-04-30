<?php
/**
 * Comprehensive Attribute Analysis Report
 * Date: 2026-04-26
 */

echo "═══════════════════════════════════════════════════════════════════\n";
echo "  COMPREHENSIVE ATTRIBUTE ANALYSIS & OPTIMIZATION PLAN\n";
echo "  Date: " . date('Y-m-d H:i:s') . "\n";
echo "═══════════════════════════════════════════════════════════════════\n\n";

// Database connection
$pdo = new PDO("mysql:host=127.0.0.1;port=3307;dbname=akeneo_pim", "akeneo_pim", "akeneo_pim");
$pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);

$report = [];
$issues = [];
$recommendations = [];

// 1. Attribute Overview
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n";
echo "1. ATTRIBUTE OVERVIEW\n";
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n";

$totalAttrs = $pdo->query("SELECT COUNT(*) FROM pim_catalog_attribute")->fetchColumn();
$requiredAttrs = $pdo->query("SELECT COUNT(*) FROM pim_catalog_attribute WHERE is_required = 1")->fetchColumn();
$uniqueAttrs = $pdo->query("SELECT COUNT(*) FROM pim_catalog_attribute WHERE is_unique = 1")->fetchColumn();
$localizableAttrs = $pdo->query("SELECT COUNT(*) FROM pim_catalog_attribute WHERE is_localizable = 1")->fetchColumn();
$scopableAttrs = $pdo->query("SELECT COUNT(*) FROM pim_catalog_attribute WHERE is_scopable = 1")->fetchColumn();

$report['attributes'] = [
    'total' => $totalAttrs,
    'required' => $requiredAttrs,
    'unique' => $uniqueAttrs,
    'localizable' => $localizableAttrs,
    'scopable' => $scopableAttrs
];

echo "Total Attributes: $totalAttrs\n";
echo "  ├─ Required: $requiredAttrs\n";
echo "  ├─ Unique: $uniqueAttrs\n";
echo "  ├─ Localizable: $localizableAttrs\n";
echo "  └─ Scopable: $scopableAttrs\n\n";

// 2. Attribute Types
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n";
echo "2. ATTRIBUTE TYPES DISTRIBUTION\n";
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n";

$types = $pdo->query("
    SELECT type, COUNT(*) as count 
    FROM pim_catalog_attribute 
    GROUP BY type 
    ORDER BY count DESC
")->fetchAll(PDO::FETCH_ASSOC);

foreach ($types as $type) {
    echo sprintf("  %-40s %5d\n", $type['type'], $type['count']);
}
echo "\n";

// 3. Attribute Groups
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n";
echo "3. ATTRIBUTE GROUPS\n";
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n";

$groups = $pdo->query("
    SELECT 
        ag.code as group_code,
        ag.sort_order,
        COUNT(a.id) as attribute_count
    FROM pim_catalog_attribute_group ag
    LEFT JOIN pim_catalog_attribute a ON ag.id = a.group_id
    GROUP BY ag.id
    ORDER BY ag.sort_order
")->fetchAll(PDO::FETCH_ASSOC);

echo sprintf("%-30s %12s %15s\n", "Group", "Sort Order", "Attributes");
echo str_repeat("─", 60) . "\n";
foreach ($groups as $group) {
    echo sprintf("%-30s %12d %15d\n", $group['group_code'], $group['sort_order'], $group['attribute_count']);
}
echo "\n";

// 4. Families and Their Attributes
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n";
echo "4. FAMILY ATTRIBUTE CONFIGURATION\n";
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n";

$families = $pdo->query("
    SELECT 
        f.code,
        COUNT(DISTINCT fa.attribute_id) as attr_count
    FROM pim_catalog_family f
    LEFT JOIN pim_catalog_family_attribute fa ON f.id = fa.family_id
    GROUP BY f.id
    ORDER BY attr_count DESC
")->fetchAll(PDO::FETCH_ASSOC);

echo sprintf("%-30s %15s\n", "Family", "Attributes");
echo str_repeat("─", 50) . "\n";
foreach ($families as $family) {
    echo sprintf("%-30s %15d\n", $family['code'], $family['attr_count']);
}
echo "\n";

// 5. Attribute Options
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n";
echo "5. SELECT/MULTISELECT ATTRIBUTE OPTIONS\n";
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n";

$options = $pdo->query("
    SELECT 
        a.code,
        a.type,
        COUNT(DISTINCT ao.id) as option_count
    FROM pim_catalog_attribute a
    LEFT JOIN pim_catalog_attribute_option ao ON a.id = ao.attribute_id
    WHERE a.type IN ('pim_catalog_simpleselect', 'pim_catalog_multiselect')
    GROUP BY a.id
    HAVING option_count > 0
    ORDER BY option_count DESC
    LIMIT 20
")->fetchAll(PDO::FETCH_ASSOC);

echo sprintf("%-40s %15s\n", "Attribute", "Options");
echo str_repeat("─", 60) . "\n";
foreach ($options as $opt) {
    echo sprintf("%-40s %15d\n", $opt['code'], $opt['option_count']);
}
echo "\n";

// 6. Unused Attributes
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n";
echo "6. UNUSED ATTRIBUTES (Not in any family)\n";
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n";

$unused = $pdo->query("
    SELECT 
        a.code,
        a.type,
        DATE(a.created) as created_date
    FROM pim_catalog_attribute a
    LEFT JOIN pim_catalog_family_attribute fa ON a.id = fa.attribute_id
    WHERE fa.attribute_id IS NULL
    AND a.code NOT IN ('sku')
    ORDER BY a.created DESC
")->fetchAll(PDO::FETCH_ASSOC);

if (count($unused) > 0) {
    echo sprintf("%-40s %-30s %15s\n", "Code", "Type", "Created");
    echo str_repeat("─", 90) . "\n";
    foreach ($unused as $u) {
        echo sprintf("%-40s %-30s %15s\n", $u['code'], $u['type'], $u['created_date']);
        $issues[] = "Unused attribute: " . $u['code'];
    }
    echo "\n⚠️  Found " . count($unused) . " unused attributes\n";
    $recommendations[] = "Consider removing or assigning unused attributes to families";
} else {
    echo "✅ All attributes are assigned to families\n";
}
echo "\n";

// 7. Identifier Attributes
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n";
echo "7. IDENTIFIER & UNIQUE ATTRIBUTES\n";
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n";

$identifiers = $pdo->query("
    SELECT code, type, is_unique, is_required
    FROM pim_catalog_attribute
    WHERE is_unique = 1 OR code = 'sku'
    ORDER BY code
")->fetchAll(PDO::FETCH_ASSOC);

echo sprintf("%-30s %-30s %10s %12s\n", "Code", "Type", "Unique", "Required");
echo str_repeat("─", 85) . "\n";
foreach ($identifiers as $id) {
    echo sprintf("%-30s %-30s %10s %12s\n", 
        $id['code'], 
        $id['type'],
        $id['is_unique'] ? 'Yes' : 'No',
        $id['is_required'] ? 'Yes' : 'No'
    );
}
echo "\n";

// 8. Data Quality
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n";
echo "8. DATA QUALITY METRICS\n";
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n";

$totalProducts = $pdo->query("SELECT COUNT(*) FROM pim_catalog_product WHERE enabled = 1")->fetchColumn();
$totalCategories = $pdo->query("SELECT COUNT(*) FROM pim_catalog_category")->fetchColumn();
$totalFamilies = $pdo->query("SELECT COUNT(*) FROM pim_catalog_family")->fetchColumn();

echo "Catalog Overview:\n";
echo "  Total Products (enabled): $totalProducts\n";
echo "  Total Categories: $totalCategories\n";
echo "  Total Families: $totalFamilies\n\n";

// 9. Magento Sync Check
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n";
echo "9. MAGENTO ATTRIBUTE SYNC STATUS\n";
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n";

try {
    $magento_pdo = new PDO("mysql:host=127.0.0.1;port=3307;dbname=beta_dBT8x12y22", "beta_ntdbusr24", "the-correct-password");
    $magento_pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    
    $magentoAttrs = $magento_pdo->query("
        SELECT COUNT(*) 
        FROM eav_attribute 
        WHERE entity_type_id = 4
    ")->fetchColumn();
    
    echo "Magento Product Attributes: $magentoAttrs\n";
    echo "Akeneo Attributes: $totalAttrs\n";
    
    if ($magentoAttrs < $totalAttrs) {
        $diff = $totalAttrs - $magentoAttrs;
        echo "\n⚠️  $diff attributes from Akeneo may not be synced to Magento\n";
        $recommendations[] = "Review attribute mapping configuration for Magento sync";
    } else {
        echo "\n✅ Magento has equal or more attributes\n";
    }
} catch (Exception $e) {
    echo "⚠️  Could not connect to Magento database\n";
}
echo "\n";

// 10. Summary & Recommendations
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n";
echo "10. SUMMARY & ACTION PLAN\n";
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n";

echo "ISSUES FOUND:\n";
if (count($issues) > 0) {
    foreach ($issues as $i => $issue) {
        echo "  " . ($i+1) . ". " . $issue . "\n";
    }
} else {
    echo "  ✅ No critical issues found\n";
}
echo "\n";

echo "RECOMMENDATIONS:\n";
if (count($recommendations) > 0) {
    foreach ($recommendations as $i => $rec) {
        echo "  " . ($i+1) . ". " . $rec . "\n";
    }
} else {
    $recommendations = [
        "Continue monitoring attribute usage",
        "Keep attributes organized by groups",
        "Maintain data quality above 90%",
        "Regular sync validation with Magento"
    ];
    foreach ($recommendations as $i => $rec) {
        echo "  " . ($i+1) . ". " . $rec . "\n";
    }
}
echo "\n";

echo "═══════════════════════════════════════════════════════════════════\n";
echo "Report generated: " . date('Y-m-d H:i:s') . "\n";
echo "═══════════════════════════════════════════════════════════════════\n";

// Save report data
file_put_contents(
    'webapp/logs/attribute_analysis_' . date('Ymd') . '.json',
    json_encode($report, JSON_PRETTY_PRINT)
);
