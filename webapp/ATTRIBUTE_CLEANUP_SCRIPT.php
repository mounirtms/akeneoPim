#!/usr/bin/env php
<?php
/**
 * ATTRIBUTE CLEANUP & OPTIMIZATION SCRIPT
 * Analyzes and cleans unused attributes, consolidates duplicates
 * 
 * @author Techno DZ
 * @date 2026-04-29
 */

// Database configuration
$db_config = [
    'host' => '127.0.0.1',
    'port' => '3307',
    'database' => 'akeneo_pim',
    'username' => 'akeneo_pim',
    'password' => 'akeneo_pim',
];

echo "\n";
echo "=========================================\n";
echo "  ATTRIBUTE CLEANUP & OPTIMIZATION\n";
echo "=========================================\n";
echo "Date: " . date('Y-m-d H:i:s') . "\n\n";

// Connect to database
try {
    $dsn = "mysql:host={$db_config['host']};port={$db_config['port']};dbname={$db_config['database']};charset=utf8mb4";
    $pdo = new PDO($dsn, $db_config['username'], $db_config['password'], [
        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
    ]);
    echo "✓ Database connected\n\n";
} catch (PDOException $e) {
    die("✗ Database connection failed: " . $e->getMessage() . "\n");
}

// Step 1: Analyze attribute usage
echo "STEP 1: Analyzing attribute usage...\n";
echo "─────────────────────────────────────────\n";

$query = "
    SELECT 
        a.code,
        a.attribute_type,
        ag.code as attribute_group,
        a.is_required,
        a.is_unique,
        a.is_scopable,
        a.is_localizable,
        COUNT(DISTINCT pv.product_id) as product_count
    FROM pim_catalog_attribute a
    LEFT JOIN pim_catalog_attribute_group ag ON a.group_id = ag.id
    LEFT JOIN pim_catalog_product_value pv ON a.id = pv.attribute_id
    GROUP BY a.id
    ORDER BY product_count DESC, a.code
";

$stmt = $pdo->query($query);
$attributes = $stmt->fetchAll();

$totalAttributes = count($attributes);
$usedAttributes = 0;
$unusedAttributes = 0;
$lowUsageAttributes = [];

foreach ($attributes as $attr) {
    if ($attr['product_count'] > 0) {
        $usedAttributes++;
        if ($attr['product_count'] < 10) {
            $lowUsageAttributes[] = $attr;
        }
    } else {
        $unusedAttributes++;
    }
}

echo "Total attributes: {$totalAttributes}\n";
echo "Used attributes: {$usedAttributes}\n";
echo "Unused attributes: {$unusedAttributes}\n";
echo "Low usage (<10 products): " . count($lowUsageAttributes) . "\n\n";

// Step 2: Identify unused attributes
echo "STEP 2: Unused attributes (candidates for removal)...\n";
echo "─────────────────────────────────────────\n";

$unusedList = array_filter($attributes, function($a) {
    return $a['product_count'] == 0 && !$a['is_required'];
});

if (count($unusedList) > 0) {
    printf("%-30s %-20s %-20s\n", "Attribute Code", "Type", "Group");
    echo str_repeat("─", 70) . "\n";
    
    foreach ($unusedList as $attr) {
        printf("%-30s %-20s %-20s\n", 
            $attr['code'], 
            $attr['attribute_type'], 
            $attr['attribute_group'] ?? 'N/A'
        );
    }
} else {
    echo "✓ No unused attributes found!\n";
}
echo "\n";

// Step 3: Identify duplicate attributes (similar names)
echo "STEP 3: Potential duplicate attributes...\n";
echo "─────────────────────────────────────────\n";

$duplicates = [];
foreach ($attributes as $i => $attr1) {
    foreach ($attributes as $j => $attr2) {
        if ($i >= $j) continue;
        
        // Check for similar names
        $similarity = 0;
        similar_text(strtolower($attr1['code']), strtolower($attr2['code']), $similarity);
        
        if ($similarity > 70 && $attr1['attribute_type'] === $attr2['attribute_type']) {
            $duplicates[] = [
                'attr1' => $attr1['code'],
                'attr2' => $attr2['code'],
                'type' => $attr1['attribute_type'],
                'similarity' => round($similarity, 1),
                'count1' => $attr1['product_count'],
                'count2' => $attr2['product_count'],
            ];
        }
    }
}

if (count($duplicates) > 0) {
    printf("%-25s %-25s %-15s %-10s %-10s\n", "Attribute 1", "Attribute 2", "Type", "Products", "Similar%");
    echo str_repeat("─", 95) . "\n";
    
    foreach ($duplicates as $dup) {
        printf("%-25s %-25s %-15s %4d / %4d  %6.1f%%\n",
            $dup['attr1'],
            $dup['attr2'],
            $dup['type'],
            $dup['count1'],
            $dup['count2'],
            $dup['similarity']
        );
    }
} else {
    echo "✓ No duplicate attributes found!\n";
}
echo "\n";

// Step 4: Analyze attribute groups
echo "STEP 4: Attribute group distribution...\n";
echo "─────────────────────────────────────────\n";

$query = "
    SELECT 
        ag.code as group_code,
        ag.sort_order,
        COUNT(a.id) as attribute_count
    FROM pim_catalog_attribute_group ag
    LEFT JOIN pim_catalog_attribute a ON ag.id = a.group_id
    GROUP BY ag.id
    ORDER BY ag.sort_order, ag.code
";

$stmt = $pdo->query($query);
$groups = $stmt->fetchAll();

printf("%-30s %-15s %-10s\n", "Group", "Sort Order", "Attributes");
echo str_repeat("─", 55) . "\n";

foreach ($groups as $group) {
    printf("%-30s %-15s %-10d\n",
        $group['group_code'],
        $group['sort_order'],
        $group['attribute_count']
    );
}
echo "\n";

// Step 5: Generate cleanup recommendations
echo "STEP 5: Cleanup recommendations...\n";
echo "─────────────────────────────────────────\n";

$recommendations = [];

// Recommendation 1: Remove unused attributes
if (count($unusedList) > 0) {
    $recommendations[] = [
        'priority' => 'HIGH',
        'action' => 'Remove ' . count($unusedList) . ' unused attributes',
        'impact' => 'Simplify catalog structure, improve performance',
        'risk' => 'LOW (attributes not in use)',
    ];
}

// Recommendation 2: Consolidate duplicates
if (count($duplicates) > 0) {
    $recommendations[] = [
        'priority' => 'MEDIUM',
        'action' => 'Review and consolidate ' . count($duplicates) . ' potential duplicate attributes',
        'impact' => 'Reduce confusion, standardize data entry',
        'risk' => 'MEDIUM (requires data migration)',
    ];
}

// Recommendation 3: Low usage attributes
if (count($lowUsageAttributes) > 0) {
    $recommendations[] = [
        'priority' => 'LOW',
        'action' => 'Review ' . count($lowUsageAttributes) . ' low-usage attributes (<10 products)',
        'impact' => 'Optimize attribute list, reduce clutter',
        'risk' => 'LOW (minimal product impact)',
    ];
}

if (count($recommendations) > 0) {
    printf("%-10s %-60s %-10s\n", "Priority", "Action", "Risk");
    echo str_repeat("─", 80) . "\n";
    
    foreach ($recommendations as $rec) {
        printf("%-10s %-60s %-10s\n",
            $rec['priority'],
            $rec['action'],
            $rec['risk']
        );
        echo "           Impact: {$rec['impact']}\n\n";
    }
} else {
    echo "✓ No cleanup recommendations - attributes are well optimized!\n";
}

// Step 6: Export cleanup SQL scripts
echo "STEP 6: Generating cleanup scripts...\n";
echo "─────────────────────────────────────────\n";

$sqlFile = __DIR__ . '/attribute_cleanup_' . date('Ymd_His') . '.sql';
$sql = fopen($sqlFile, 'w');

fwrite($sql, "-- ATTRIBUTE CLEANUP SCRIPT\n");
fwrite($sql, "-- Generated: " . date('Y-m-d H:i:s') . "\n");
fwrite($sql, "-- CAUTION: Review before executing!\n\n");

fwrite($sql, "-- Backup current state\n");
fwrite($sql, "CREATE TABLE IF NOT EXISTS pim_catalog_attribute_backup_" . date('Ymd') . " AS SELECT * FROM pim_catalog_attribute;\n\n");

fwrite($sql, "-- Remove unused attributes (REVIEW FIRST!)\n");
foreach ($unusedList as $attr) {
    fwrite($sql, "-- DELETE FROM pim_catalog_attribute WHERE code = '{$attr['code']}'; -- Type: {$attr['attribute_type']}, Group: {$attr['attribute_group']}\n");
}

fwrite($sql, "\n-- Note: Duplicate consolidation requires manual data migration\n");
fwrite($sql, "-- Review the duplicate list above and create migration scripts as needed\n");

fclose($sql);

echo "✓ SQL script saved: {$sqlFile}\n";
echo "  IMPORTANT: Review before executing!\n\n";

// Summary
echo "=========================================\n";
echo "  ANALYSIS COMPLETE\n";
echo "=========================================\n";
echo "Total attributes analyzed: {$totalAttributes}\n";
echo "Unused attributes: {$unusedAttributes}\n";
echo "Potential duplicates: " . count($duplicates) . "\n";
echo "Low usage attributes: " . count($lowUsageAttributes) . "\n";
echo "Recommendations: " . count($recommendations) . "\n";
echo "\nCleanup script: {$sqlFile}\n";
echo "\nNEXT STEPS:\n";
echo "1. Review unused attributes list\n";
echo "2. Verify duplicate attributes manually\n";
echo "3. Test cleanup script in staging environment\n";
echo "4. Backup database before applying changes\n";
echo "5. Execute cleanup in production\n\n";

echo "✓ Attribute cleanup analysis completed!\n\n";
