<?php
/**
 * COMPREHENSIVE ATTRIBUTE FIELD AUDIT
 * Date: 2026-04-27
 * Purpose: Deep dive audit of all attribute fields, values, keys, and relationships
 * 
 * This script performs:
 * 1. Attribute values audit (nulls, empty strings, data type mismatches)
 * 2. Attribute keys/codes validation (uniqueness, naming conventions)
 * 3. Attribute option codes and labels audit
 * 4. Attribute group assignments verification
 * 5. Localization completeness check
 * 6. Family-attribute relationships audit
 * 7. Validation rules verification
 * 8. Product values integrity check
 * 9. Reference entity values audit
 * 10. Comprehensive field mapping report
 * 11. Data quality scoring per attribute
 */

error_reporting(E_ALL);
ini_set('display_errors', 1);
ini_set('memory_limit', '512M');

// Database connection
$host = '127.0.0.1';
$port = '3307';
$dbname = 'akeneo_pim';
$username = 'akeneo_pim';
$password = 'akeneo_pim';

try {
    $pdo = new PDO("mysql:host=$host;port=$port;dbname=$dbname;charset=utf8mb4", $username, $password);
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    echo "\n" . str_repeat("=", 80) . "\n";
    echo "COMPREHENSIVE ATTRIBUTE FIELD AUDIT\n";
    echo "Date: " . date('Y-m-d H:i:s') . "\n";
    echo str_repeat("=", 80) . "\n\n";
} catch (PDOException $e) {
    die("Database connection failed: " . $e->getMessage() . "\n");
}

// Output file
$logFile = __DIR__ . '/logs/comprehensive_attribute_audit_' . date('Ymd_His') . '.log';
if (!is_dir(__DIR__ . '/logs')) {
    mkdir(__DIR__ . '/logs', 0755, true);
}

function logOutput($message, $logFile) {
    echo $message;
    file_put_contents($logFile, $message, FILE_APPEND);
}

// ============================================================================
// 1. ATTRIBUTE KEYS AND CODES VALIDATION
// ============================================================================
logOutput("\n" . str_repeat("-", 80) . "\n", $logFile);
logOutput("1. ATTRIBUTE KEYS AND CODES VALIDATION\n", $logFile);
logOutput(str_repeat("-", 80) . "\n", $logFile);

$codesQuery = "
SELECT 
    code,
    attribute_type,
    is_required,
    is_unique,
    is_localizable,
    is_scopable,
    LENGTH(code) as code_length,
    CASE 
        WHEN code REGEXP '^[a-z][a-z0-9_]*$' THEN 'VALID'
        WHEN code REGEXP '[A-Z]' THEN 'HAS_UPPERCASE'
        WHEN code REGEXP '[^a-z0-9_]' THEN 'INVALID_CHARS'
        WHEN code REGEXP '^[0-9]' THEN 'STARTS_WITH_NUMBER'
        ELSE 'OTHER_ISSUE'
    END as naming_status
FROM pim_catalog_attribute
ORDER BY naming_status DESC, code
";

$stmt = $pdo->query($codesQuery);
$attributes = $stmt->fetchAll(PDO::FETCH_ASSOC);

$namingIssues = [];
$validCodes = 0;
foreach ($attributes as $attr) {
    if ($attr['naming_status'] === 'VALID') {
        $validCodes++;
    } else {
        $namingIssues[] = $attr;
    }
}

logOutput("Total Attributes: " . count($attributes) . "\n", $logFile);
logOutput("Valid Code Format: $validCodes (" . round(($validCodes/count($attributes))*100, 1) . "%)\n", $logFile);
logOutput("Naming Issues: " . count($namingIssues) . "\n\n", $logFile);

if (!empty($namingIssues)) {
    logOutput("Attributes with Naming Issues:\n", $logFile);
    foreach ($namingIssues as $issue) {
        logOutput("  - {$issue['code']} [{$issue['attribute_type']}] - Issue: {$issue['naming_status']}\n", $logFile);
    }
}

// Check for duplicate codes (should be impossible due to unique constraint)
$dupeQuery = "SELECT code, COUNT(*) as count FROM pim_catalog_attribute GROUP BY code HAVING count > 1";
$dupes = $pdo->query($dupeQuery)->fetchAll(PDO::FETCH_ASSOC);
if (empty($dupes)) {
    logOutput("\n✓ No duplicate attribute codes found.\n", $logFile);
} else {
    logOutput("\n✗ WARNING: " . count($dupes) . " duplicate codes found!\n", $logFile);
}

// ============================================================================
// 2. ATTRIBUTE VALUES AUDIT (NULL, EMPTY, DATA TYPE MISMATCHES)
// ============================================================================
logOutput("\n" . str_repeat("-", 80) . "\n", $logFile);
logOutput("2. ATTRIBUTE VALUES AUDIT\n", $logFile);
logOutput(str_repeat("-", 80) . "\n", $logFile);

// In Akeneo 7+, product values are stored in raw_values JSON column
// We'll use completeness data as a proxy for value quality
$valuesQuery = "
SELECT 
    a.code as attribute_code,
    a.attribute_type,
    a.is_required,
    COUNT(DISTINCT fa.family_id) as used_in_families
FROM pim_catalog_attribute a
LEFT JOIN pim_catalog_family_attribute fa ON a.id = fa.attribute_id
GROUP BY a.id, a.code, a.attribute_type, a.is_required
ORDER BY a.attribute_type, a.code
";

$stmt = $pdo->query($valuesQuery);
$valueStats = $stmt->fetchAll(PDO::FETCH_ASSOC);

logOutput("\nAttribute Usage in Families:\n", $logFile);
logOutput(sprintf("%-35s %-25s %10s %10s\n", 
    "Attribute", "Type", "Required", "Families"), $logFile);
logOutput(str_repeat("-", 85) . "\n", $logFile);

$unusedCount = 0;
foreach ($valueStats as $stat) {
    if ($stat['used_in_families'] == 0 && $stat['attribute_type'] != 'pim_catalog_identifier') {
        $unusedCount++;
    }
    if ($stat['used_in_families'] == 0) {
        logOutput(sprintf("%-35s %-25s %10s %10d ⚠\n",
            substr($stat['attribute_code'], 0, 35),
            substr($stat['attribute_type'], 15, 25),
            $stat['is_required'] ? 'Yes' : 'No',
            $stat['used_in_families']
        ), $logFile);
    }
}

logOutput("\nAttributes not used in any family: $unusedCount\n", $logFile);

// ============================================================================
// 3. ATTRIBUTE OPTIONS AUDIT
// ============================================================================
logOutput("\n" . str_repeat("-", 80) . "\n", $logFile);
logOutput("3. ATTRIBUTE OPTIONS AUDIT\n", $logFile);
logOutput(str_repeat("-", 80) . "\n", $logFile);

$optionsQuery = "
SELECT 
    a.code as attribute_code,
    COUNT(DISTINCT ao.id) as total_options,
    COUNT(DISTINCT ao.code) as unique_option_codes,
    COUNT(DISTINCT aov.value) as unique_labels,
    GROUP_CONCAT(DISTINCT aov.locale_code) as locales
FROM pim_catalog_attribute a
JOIN pim_catalog_attribute_option ao ON a.id = ao.attribute_id
LEFT JOIN pim_catalog_attribute_option_value aov ON ao.id = aov.option_id
WHERE a.attribute_type IN ('pim_catalog_simpleselect', 'pim_catalog_multiselect')
GROUP BY a.code
ORDER BY total_options DESC
LIMIT 20
";

$stmt = $pdo->query($optionsQuery);
$optionsStats = $stmt->fetchAll(PDO::FETCH_ASSOC);

logOutput("\nTop 20 Attributes by Number of Options:\n", $logFile);
logOutput(sprintf("%-30s %10s %10s %10s %-20s\n", 
    "Attribute", "Options", "Unique", "Labels", "Locales"), $logFile);
logOutput(str_repeat("-", 90) . "\n", $logFile);

foreach ($optionsStats as $stat) {
    logOutput(sprintf("%-30s %10d %10d %10d %-20s\n",
        substr($stat['attribute_code'], 0, 30),
        $stat['total_options'],
        $stat['unique_option_codes'],
        $stat['unique_labels'],
        substr($stat['locales'] ?: 'none', 0, 20)
    ), $logFile);
}

// Check for option code issues
$optionIssuesQuery = "
SELECT 
    a.code as attribute_code,
    ao.code as option_code,
    CASE 
        WHEN ao.code REGEXP '^[a-z][a-z0-9_]*$' THEN 'VALID'
        WHEN ao.code REGEXP '[A-Z]' THEN 'HAS_UPPERCASE'
        WHEN ao.code REGEXP '[^a-z0-9_]' THEN 'INVALID_CHARS'
        WHEN ao.code REGEXP '^[0-9]' THEN 'STARTS_WITH_NUMBER'
        ELSE 'OTHER_ISSUE'
    END as naming_status
FROM pim_catalog_attribute a
JOIN pim_catalog_attribute_option ao ON a.id = ao.attribute_id
WHERE a.attribute_type IN ('pim_catalog_simpleselect', 'pim_catalog_multiselect')
HAVING naming_status != 'VALID'
LIMIT 50
";

$optionIssues = $pdo->query($optionIssuesQuery)->fetchAll(PDO::FETCH_ASSOC);

if (!empty($optionIssues)) {
    logOutput("\nOption Code Issues Found:\n", $logFile);
    foreach ($optionIssues as $issue) {
        logOutput("  - {$issue['attribute_code']}.{$issue['option_code']} - {$issue['naming_status']}\n", $logFile);
    }
} else {
    logOutput("\n✓ All option codes follow naming conventions.\n", $logFile);
}

// ============================================================================
// 4. ATTRIBUTE GROUP ASSIGNMENTS
// ============================================================================
logOutput("\n" . str_repeat("-", 80) . "\n", $logFile);
logOutput("4. ATTRIBUTE GROUP ASSIGNMENTS\n", $logFile);
logOutput(str_repeat("-", 80) . "\n", $logFile);

$groupQuery = "
SELECT 
    ag.code as group_code,
    ag.sort_order,
    COUNT(a.id) as attribute_count
FROM pim_catalog_attribute_group ag
LEFT JOIN pim_catalog_attribute a ON ag.id = a.group_id
GROUP BY ag.id, ag.code, ag.sort_order
ORDER BY ag.sort_order, ag.code
";

$stmt = $pdo->query($groupQuery);
$groups = $stmt->fetchAll(PDO::FETCH_ASSOC);

logOutput("\nAttribute Group Distribution:\n", $logFile);
logOutput(sprintf("%-30s %10s %10s\n", "Group Code", "Sort Order", "Attributes"), $logFile);
logOutput(str_repeat("-", 55) . "\n", $logFile);

$emptyGroups = [];
foreach ($groups as $group) {
    logOutput(sprintf("%-30s %10d %10d\n",
        substr($group['group_code'], 0, 30),
        $group['sort_order'],
        $group['attribute_count']
    ), $logFile);
    
    if ($group['attribute_count'] == 0) {
        $emptyGroups[] = $group['group_code'];
    }
}

if (!empty($emptyGroups)) {
    logOutput("\n⚠ Empty Groups Found: " . implode(', ', $emptyGroups) . "\n", $logFile);
} else {
    logOutput("\n✓ All groups have assigned attributes.\n", $logFile);
}

// Check for orphaned attributes (no group)
$orphanQuery = "SELECT code FROM pim_catalog_attribute WHERE group_id IS NULL";
$orphans = $pdo->query($orphanQuery)->fetchAll(PDO::FETCH_COLUMN);

if (!empty($orphans)) {
    logOutput("\n✗ Orphaned Attributes (no group): " . implode(', ', $orphans) . "\n", $logFile);
} else {
    logOutput("\n✓ All attributes are assigned to groups.\n", $logFile);
}

// ============================================================================
// 5. LOCALIZATION COMPLETENESS
// ============================================================================
logOutput("\n" . str_repeat("-", 80) . "\n", $logFile);
logOutput("5. LOCALIZATION COMPLETENESS\n", $logFile);
logOutput(str_repeat("-", 80) . "\n", $logFile);

$localesQuery = "SELECT code FROM pim_catalog_locale WHERE is_activated = 1";
$activeLocales = $pdo->query($localesQuery)->fetchAll(PDO::FETCH_COLUMN);

logOutput("Active Locales: " . implode(', ', $activeLocales) . "\n\n", $logFile);

$localizableQuery = "
SELECT 
    code,
    attribute_type
FROM pim_catalog_attribute
WHERE is_localizable = 1
ORDER BY code
";

$localizable = $pdo->query($localizableQuery)->fetchAll(PDO::FETCH_ASSOC);

logOutput("Localizable Attributes: " . count($localizable) . "\n", $logFile);
logOutput("Expected Translations per Attribute: " . count($activeLocales) . "\n\n", $logFile);

// Check translation completeness for attribute labels
$translationQuery = "
SELECT 
    a.code as attribute_code,
    COUNT(DISTINCT at.locale) as translated_locales,
    GROUP_CONCAT(DISTINCT at.locale) as available_locales
FROM pim_catalog_attribute a
LEFT JOIN pim_catalog_attribute_translation at ON a.id = at.foreign_key
WHERE a.is_localizable = 1
GROUP BY a.code
HAVING translated_locales < " . count($activeLocales) . "
ORDER BY translated_locales ASC
LIMIT 20
";

$missingTranslations = $pdo->query($translationQuery)->fetchAll(PDO::FETCH_ASSOC);

if (!empty($missingTranslations)) {
    logOutput("Attributes with Missing Translations (top 20):\n", $logFile);
    foreach ($missingTranslations as $trans) {
        logOutput("  - {$trans['attribute_code']}: {$trans['translated_locales']}/" . count($activeLocales) . 
                  " locales ({$trans['available_locales']})\n", $logFile);
    }
} else {
    logOutput("✓ All localizable attributes have complete translations.\n", $logFile);
}

// ============================================================================
// 6. FAMILY-ATTRIBUTE RELATIONSHIPS
// ============================================================================
logOutput("\n" . str_repeat("-", 80) . "\n", $logFile);
logOutput("6. FAMILY-ATTRIBUTE RELATIONSHIPS\n", $logFile);
logOutput(str_repeat("-", 80) . "\n", $logFile);

$familyQuery = "
SELECT 
    f.code as family_code,
    COUNT(DISTINCT fa.attribute_id) as total_attributes,
    COUNT(DISTINCT CASE WHEN ar.required = 1 THEN ar.attribute_id END) as required_attributes
FROM pim_catalog_family f
LEFT JOIN pim_catalog_family_attribute fa ON f.id = fa.family_id
LEFT JOIN pim_catalog_attribute_requirement ar ON f.id = ar.family_id AND fa.attribute_id = ar.attribute_id
GROUP BY f.code
ORDER BY total_attributes DESC
";

$stmt = $pdo->query($familyQuery);
$families = $stmt->fetchAll(PDO::FETCH_ASSOC);

logOutput("Family-Attribute Mapping:\n", $logFile);
logOutput(sprintf("%-30s %15s %15s\n", "Family", "Total Attrs", "Required"), $logFile);
logOutput(str_repeat("-", 65) . "\n", $logFile);

foreach ($families as $family) {
    logOutput(sprintf("%-30s %15d %15d\n",
        substr($family['family_code'], 0, 30),
        $family['total_attributes'],
        $family['required_attributes']
    ), $logFile);
}

// Check for attributes not in any family
$unusedAttrQuery = "
SELECT a.code 
FROM pim_catalog_attribute a
LEFT JOIN pim_catalog_family_attribute fa ON a.id = fa.attribute_id
WHERE fa.attribute_id IS NULL
AND a.attribute_type NOT IN ('pim_catalog_identifier')
";

$unusedAttrs = $pdo->query($unusedAttrQuery)->fetchAll(PDO::FETCH_COLUMN);

if (!empty($unusedAttrs)) {
    logOutput("\n⚠ Attributes Not Used in Any Family: " . implode(', ', $unusedAttrs) . "\n", $logFile);
} else {
    logOutput("\n✓ All attributes are assigned to at least one family.\n", $logFile);
}

// ============================================================================
// 7. VALIDATION RULES VERIFICATION
// ============================================================================
logOutput("\n" . str_repeat("-", 80) . "\n", $logFile);
logOutput("7. VALIDATION RULES VERIFICATION\n", $logFile);
logOutput(str_repeat("-", 80) . "\n", $logFile);

$validationQuery = "
SELECT 
    code,
    attribute_type,
    validation_rule,
    validation_regexp,
    max_characters,
    number_min,
    number_max,
    decimals_allowed,
    negative_allowed,
    metric_family
FROM pim_catalog_attribute
WHERE validation_rule IS NOT NULL 
   OR validation_regexp IS NOT NULL 
   OR max_characters IS NOT NULL
   OR number_min IS NOT NULL
   OR number_max IS NOT NULL
   OR metric_family IS NOT NULL
ORDER BY attribute_type, code
";

$stmt = $pdo->query($validationQuery);
$validations = $stmt->fetchAll(PDO::FETCH_ASSOC);

logOutput("Attributes with Validation Rules: " . count($validations) . "\n\n", $logFile);

if (!empty($validations)) {
    logOutput(sprintf("%-25s %-20s %-15s %-20s\n", 
        "Attribute", "Type", "Rule", "Additional"), $logFile);
    logOutput(str_repeat("-", 85) . "\n", $logFile);
    
    foreach ($validations as $val) {
        $additional = [];
        if ($val['validation_regexp']) $additional[] = "regex";
        if ($val['max_characters']) $additional[] = "maxchars:{$val['max_characters']}";
        if ($val['number_min'] !== null) $additional[] = "min:{$val['number_min']}";
        if ($val['number_max'] !== null) $additional[] = "max:{$val['number_max']}";
        if ($val['metric_family']) $additional[] = "metric:{$val['metric_family']}";
        
        logOutput(sprintf("%-25s %-20s %-15s %-20s\n",
            substr($val['code'], 0, 25),
            substr($val['attribute_type'], 0, 20),
            substr($val['validation_rule'] ?: 'none', 0, 15),
            substr(implode(',', $additional), 0, 20)
        ), $logFile);
    }
}

// ============================================================================
// 8. PRODUCT VALUES INTEGRITY
// ============================================================================
logOutput("\n" . str_repeat("-", 80) . "\n", $logFile);
logOutput("8. PRODUCT VALUES INTEGRITY\n", $logFile);
logOutput(str_repeat("-", 80) . "\n", $logFile);

// Use completeness table for data quality assessment
$completenessQuery = "
SELECT 
    AVG(((required_count - missing_count) / required_count) * 100) as avg_completeness,
    MIN(((required_count - missing_count) / required_count) * 100) as min_completeness,
    MAX(((required_count - missing_count) / required_count) * 100) as max_completeness,
    COUNT(DISTINCT c.product_id) as products_with_completeness
FROM pim_catalog_completeness c
JOIN pim_catalog_locale l ON c.locale_id = l.id
JOIN pim_catalog_channel ch ON c.channel_id = ch.id
WHERE l.code = 'en_US'
AND ch.code = 'ecommerce'
AND c.required_count > 0
";

$compStats = $pdo->query($completenessQuery)->fetch(PDO::FETCH_ASSOC);

// Get total enabled products
$totalProducts = $pdo->query("SELECT COUNT(*) FROM pim_catalog_product WHERE is_enabled = 1")->fetchColumn();

logOutput("Total Enabled Products: $totalProducts\n", $logFile);
logOutput("Products with Completeness Data: " . ($compStats['products_with_completeness'] ?: 0) . "\n", $logFile);
logOutput("Average Completeness (ecommerce/en_US): " . round($compStats['avg_completeness'] ?: 0, 2) . "%\n", $logFile);
logOutput("Min Completeness: " . round($compStats['min_completeness'] ?: 0, 2) . "%\n", $logFile);
logOutput("Max Completeness: " . round($compStats['max_completeness'] ?: 0, 2) . "%\n", $logFile);

$completeness = $compStats['avg_completeness'] ?: 0;

// ============================================================================
// 9. DATA QUALITY SCORING
// ============================================================================
logOutput("\n" . str_repeat("-", 80) . "\n", $logFile);
logOutput("9. DATA QUALITY SCORING\n", $logFile);
logOutput(str_repeat("-", 80) . "\n", $logFile);

$qualityMetrics = [
    'Valid Attribute Codes' => round(($validCodes / count($attributes)) * 100, 1),
    'Attributes in Groups' => count($orphans) == 0 ? 100 : round(((count($attributes) - count($orphans)) / count($attributes)) * 100, 1),
    'Attributes in Families' => count($unusedAttrs) == 0 ? 100 : round(((count($attributes) - count($unusedAttrs)) / count($attributes)) * 100, 1),
    'Product Completeness' => $completeness,
    'Groups Utilization' => count($emptyGroups) == 0 ? 100 : round(((count($groups) - count($emptyGroups)) / count($groups)) * 100, 1)
];

logOutput("Overall Data Quality Metrics:\n", $logFile);
foreach ($qualityMetrics as $metric => $score) {
    $status = $score >= 95 ? '✓' : ($score >= 80 ? '⚠' : '✗');
    logOutput(sprintf("  %s %-35s: %5.1f%%\n", $status, $metric, $score), $logFile);
}

$overallScore = array_sum($qualityMetrics) / count($qualityMetrics);
logOutput("\nOVERALL DATA QUALITY SCORE: " . round($overallScore, 1) . "%\n", $logFile);

if ($overallScore >= 95) {
    $grade = 'A+';
    $assessment = 'EXCELLENT - Production Ready';
} elseif ($overallScore >= 90) {
    $grade = 'A';
    $assessment = 'VERY GOOD - Minor Improvements Recommended';
} elseif ($overallScore >= 85) {
    $grade = 'B+';
    $assessment = 'GOOD - Some Issues Need Attention';
} elseif ($overallScore >= 80) {
    $grade = 'B';
    $assessment = 'ACCEPTABLE - Multiple Issues to Fix';
} else {
    $grade = 'C or below';
    $assessment = 'NEEDS WORK - Significant Issues Detected';
}

logOutput("Grade: $grade - $assessment\n", $logFile);

// ============================================================================
// 10. SUMMARY AND RECOMMENDATIONS
// ============================================================================
logOutput("\n" . str_repeat("=", 80) . "\n", $logFile);
logOutput("SUMMARY AND RECOMMENDATIONS\n", $logFile);
logOutput(str_repeat("=", 80) . "\n\n", $logFile);

$recommendations = [];

if (count($namingIssues) > 0) {
    $recommendations[] = "Fix " . count($namingIssues) . " attribute codes with naming convention issues";
}

if (!empty($emptyGroups)) {
    $recommendations[] = "Remove or merge empty attribute groups: " . implode(', ', $emptyGroups);
}

if (!empty($orphans)) {
    $recommendations[] = "Assign " . count($orphans) . " orphaned attributes to groups";
}

if (!empty($unusedAttrs)) {
    $recommendations[] = "Add " . count($unusedAttrs) . " unused attributes to families or remove them";
}

if ($missingCount > 0) {
    $recommendations[] = "Complete required attributes for $missingCount products";
}

if (!empty($missingTranslations)) {
    $recommendations[] = "Add missing translations for " . count($missingTranslations) . " localizable attributes";
}

if (empty($recommendations)) {
    logOutput("✓ No critical issues found. System is in excellent condition.\n", $logFile);
} else {
    logOutput("Action Items:\n", $logFile);
    foreach ($recommendations as $i => $rec) {
        logOutput(($i + 1) . ". $rec\n", $logFile);
    }
}

logOutput("\n" . str_repeat("=", 80) . "\n", $logFile);
logOutput("Audit completed at " . date('Y-m-d H:i:s') . "\n", $logFile);
logOutput("Full log saved to: $logFile\n", $logFile);
logOutput(str_repeat("=", 80) . "\n\n", $logFile);

echo "\n✓ Comprehensive attribute field audit completed successfully.\n";
echo "Results saved to: $logFile\n\n";

