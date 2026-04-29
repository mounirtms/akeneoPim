<?php
/**
 * DATA QUALITY CHECKER - AUTOMATED VALIDATION
 * Checks catalog data integrity and quality
 * Date: 2026-04-29
 */

$config = [
    'db_host' => '127.0.0.1',
    'db_port' => 3307,
    'db_name' => 'akeneo_pim',
    'db_user' => 'akeneo_pim',
    'db_pass' => 'akeneo_pim',
    'log_dir' => '/home/pim/public_html/webapp/logs/',
    'auto_fix' => false // Set to true to enable automatic fixes
];

echo "=========================================\n";
echo "  DATA QUALITY CHECKER\n";
echo "=========================================\n";
echo "Date: " . date('Y-m-d H:i:s') . "\n\n";

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
    die("❌ Connection failed: " . $e->getMessage() . "\n");
}

$issues = [];
$fixed = 0;

// ============================================
// 1. DUPLICATE SKU CHECK
// ============================================
echo "CHECK 1: Duplicate Product Identifiers\n";
echo "─────────────────────────────────────────\n";

$stmt = $pdo->query("
    SELECT identifier, COUNT(*) as count
    FROM pim_catalog_product
    GROUP BY identifier
    HAVING count > 1
");

$duplicates = $stmt->fetchAll();
if (!empty($duplicates)) {
    echo "❌ Found " . count($duplicates) . " duplicate SKUs:\n";
    foreach ($duplicates as $dup) {
        echo "  - {$dup['identifier']} (appears {$dup['count']} times)\n";
        $issues[] = ['type' => 'duplicate_sku', 'identifier' => $dup['identifier'], 'count' => $dup['count']];
    }
} else {
    echo "✓ No duplicate SKUs found\n";
}
echo "\n";

// ============================================
// 2. MISSING REQUIRED ATTRIBUTES
// ============================================
echo "CHECK 2: Products Without Family\n";
echo "─────────────────────────────────────────\n";

$stmt = $pdo->query("
    SELECT identifier
    FROM pim_catalog_product
    WHERE family_id IS NULL
    LIMIT 10
");

$noFamily = $stmt->fetchAll();
if (!empty($noFamily)) {
    echo "❌ Found products without family assignment:\n";
    foreach ($noFamily as $product) {
        echo "  - {$product['identifier']}\n";
        $issues[] = ['type' => 'no_family', 'identifier' => $product['identifier']];
    }
    
    $stmt = $pdo->query("SELECT COUNT(*) as total FROM pim_catalog_product WHERE family_id IS NULL");
    $totalNoFamily = $stmt->fetch()['total'];
    echo "  Total: $totalNoFamily products\n";
} else {
    echo "✓ All products have family assignment\n";
}
echo "\n";

// ============================================
// 3. DISABLED PRODUCTS ANALYSIS
// ============================================
echo "CHECK 3: Disabled Products\n";
echo "─────────────────────────────────────────\n";

$stmt = $pdo->query("
    SELECT identifier
    FROM pim_catalog_product
    WHERE is_enabled = 0
    LIMIT 10
");

$disabled = $stmt->fetchAll();
if (!empty($disabled)) {
    echo "⚠ Found disabled products:\n";
    foreach ($disabled as $product) {
        echo "  - {$product['identifier']}\n";
    }
    
    $stmt = $pdo->query("SELECT COUNT(*) as total FROM pim_catalog_product WHERE is_enabled = 0");
    $totalDisabled = $stmt->fetch()['total'];
    echo "  Total: $totalDisabled products disabled\n";
    echo "  (This may be intentional - review before enabling)\n";
} else {
    echo "✓ All products are enabled\n";
}
echo "\n";

// ============================================
// 4. CATEGORY ASSIGNMENT CHECK
// ============================================
echo "CHECK 4: Products Without Categories\n";
echo "─────────────────────────────────────────\n";

$stmt = $pdo->query("
    SELECT p.identifier
    FROM pim_catalog_product p
    LEFT JOIN pim_catalog_category_product cp ON p.id = cp.product_id
    WHERE cp.category_id IS NULL
    LIMIT 10
");

$noCategory = $stmt->fetchAll();
if (!empty($noCategory)) {
    echo "❌ Found products without category:\n";
    foreach ($noCategory as $product) {
        echo "  - {$product['identifier']}\n";
        $issues[] = ['type' => 'no_category', 'identifier' => $product['identifier']];
    }
    
    $stmt = $pdo->query("
        SELECT COUNT(DISTINCT p.id) as total
        FROM pim_catalog_product p
        LEFT JOIN pim_catalog_category_product cp ON p.id = cp.product_id
        WHERE cp.category_id IS NULL
    ");
    $totalNoCategory = $stmt->fetch()['total'];
    echo "  Total: $totalNoCategory products\n";
} else {
    echo "✓ All products have category assignment\n";
}
echo "\n";

// ============================================
// 5. IMAGE VALIDATION
// ============================================
echo "CHECK 5: Image Path Validation\n";
echo "─────────────────────────────────────────\n";

$imageDir = '/home/pim/public_html/public/media/product_images/';
$stmt = $pdo->query("SELECT identifier FROM pim_catalog_product LIMIT 100");

$missingImages = 0;
$checked = 0;

while ($row = $stmt->fetch()) {
    $sku = $row['identifier'];
    $imagePath = $imageDir . 'large/' . $sku . '.jpg';
    
    if (!file_exists($imagePath)) {
        if ($missingImages < 10) {
            echo "  ⚠ Missing image: $sku\n";
        }
        $missingImages++;
        $issues[] = ['type' => 'missing_image', 'identifier' => $sku];
    }
    $checked++;
}

if ($missingImages > 0) {
    echo "⚠ Found $missingImages products with missing images (checked $checked products)\n";
} else {
    echo "✓ All checked products have images ($checked checked)\n";
}
echo "\n";

// ============================================
// 6. EMPTY IDENTIFIER CHECK
// ============================================
echo "CHECK 6: Empty or Invalid Identifiers\n";
echo "─────────────────────────────────────────\n";

$stmt = $pdo->query("
    SELECT id, identifier
    FROM pim_catalog_product
    WHERE identifier IS NULL OR identifier = '' OR identifier LIKE '% %'
    LIMIT 10
");

$invalidIds = $stmt->fetchAll();
if (!empty($invalidIds)) {
    echo "❌ Found products with invalid identifiers:\n";
    foreach ($invalidIds as $product) {
        echo "  - ID: {$product['id']}, SKU: '{$product['identifier']}'\n";
        $issues[] = ['type' => 'invalid_identifier', 'id' => $product['id'], 'identifier' => $product['identifier']];
    }
} else {
    echo "✓ All product identifiers are valid\n";
}
echo "\n";

// ============================================
// SUMMARY & RECOMMENDATIONS
// ============================================
echo "=========================================\n";
echo "  SUMMARY\n";
echo "=========================================\n\n";

$issueCount = count($issues);
echo "Total issues found: $issueCount\n\n";

if ($issueCount > 0) {
    $byType = [];
    foreach ($issues as $issue) {
        $type = $issue['type'];
        if (!isset($byType[$type])) {
            $byType[$type] = 0;
        }
        $byType[$type]++;
    }
    
    echo "Issues by type:\n";
    foreach ($byType as $type => $count) {
        $typeLabel = str_replace('_', ' ', ucwords($type, '_'));
        echo "  - $typeLabel: $count\n";
    }
    
    echo "\nRECOMMENDATIONS:\n";
    
    if (isset($byType['duplicate_sku'])) {
        echo "  1. Review and merge duplicate SKUs\n";
    }
    
    if (isset($byType['no_family'])) {
        echo "  2. Assign appropriate family to products without family\n";
    }
    
    if (isset($byType['no_category'])) {
        echo "  3. Assign products to appropriate categories\n";
    }
    
    if (isset($byType['missing_image'])) {
        echo "  4. Generate or upload missing product images\n";
    }
    
    if (isset($byType['invalid_identifier'])) {
        echo "  5. Fix invalid product identifiers\n";
    }
} else {
    echo "✓ No data quality issues found!\n";
    echo "Catalog data integrity is excellent.\n";
}

// Save report
if (!is_dir($config['log_dir'])) {
    mkdir($config['log_dir'], 0755, true);
}

$reportFile = $config['log_dir'] . 'data_quality_' . date('Y-m-d_His') . '.json';
file_put_contents($reportFile, json_encode([
    'timestamp' => date('Y-m-d H:i:s'),
    'total_issues' => $issueCount,
    'issues' => $issues,
    'fixed' => $fixed
], JSON_PRETTY_PRINT));

echo "\n✓ Report saved: $reportFile\n";

echo "\n=========================================\n";
echo "✓ Data quality check complete!\n";
echo "=========================================\n";
