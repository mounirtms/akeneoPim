<?php
/**
 * PHASE 1.1: CONFIGURE REQUIRED ATTRIBUTES
 * Date: 2026-04-27
 * Purpose: Configure minimum required attributes for all families
 * 
 * This script will:
 * 1. Identify current required attributes
 * 2. Configure 8 core required attributes for all families
 * 3. Add family-specific required attributes
 * 4. Verify configuration
 * 
 * IMPORTANT: This will enforce data quality at product creation/edit time
 */

error_reporting(E_ALL);
ini_set('display_errors', 1);
ini_set('memory_limit', '256M');

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
    echo "PHASE 1.1: CONFIGURE REQUIRED ATTRIBUTES\n";
    echo "Date: " . date('Y-m-d H:i:s') . "\n";
    echo str_repeat("=", 80) . "\n\n";
} catch (PDOException $e) {
    die("Database connection failed: " . $e->getMessage() . "\n");
}

// Dry run mode - set to false to actually apply changes
$DRY_RUN = false; // LIVE MODE - changes will be applied

echo "Mode: " . ($DRY_RUN ? "DRY RUN (no changes will be made)" : "LIVE (changes will be applied)") . "\n\n";

// Core required attributes for ALL families
$coreRequiredAttributes = [
    'sku',           // Product identifier (unique)
    'name',          // Product name
    'price',         // Product price
    'description',   // Product description
    'enabled',       // Product status
];

// Family-specific required attributes
$familySpecificRequired = [
    'beaux_arts' => ['color', 'material'],
    'calculatrices' => ['brand'],
    'peinture' => ['color', 'size'],
    'cahier' => ['pages'],
    // Add more as needed
];

// Step 1: Get all families
echo "Step 1: Fetching all families...\n";
$families = $pdo->query("
    SELECT id, code 
    FROM pim_catalog_family 
    ORDER BY code
")->fetchAll(PDO::FETCH_ASSOC);

echo "Found " . count($families) . " families\n\n";

// Step 2: Get all channels
echo "Step 2: Fetching all channels...\n";
$channels = $pdo->query("
    SELECT id, code 
    FROM pim_catalog_channel 
    ORDER BY code
")->fetchAll(PDO::FETCH_ASSOC);

echo "Found " . count($channels) . " channels\n\n";

// Step 3: Get attribute IDs for core required attributes
echo "Step 3: Resolving attribute IDs...\n";
$attributeIds = [];
foreach ($coreRequiredAttributes as $attrCode) {
    $stmt = $pdo->prepare("SELECT id FROM pim_catalog_attribute WHERE code = ?");
    $stmt->execute([$attrCode]);
    $result = $stmt->fetch(PDO::FETCH_ASSOC);
    
    if ($result) {
        $attributeIds[$attrCode] = $result['id'];
        echo "  ✓ Found: $attrCode (ID: {$result['id']})\n";
    } else {
        echo "  ✗ NOT FOUND: $attrCode (will be skipped)\n";
    }
}

echo "\n";

// Step 4: Configure required attributes for each family
echo "Step 4: Configuring required attributes...\n";
echo str_repeat("-", 80) . "\n";

$totalInserted = 0;
$totalSkipped = 0;
$totalErrors = 0;

foreach ($families as $family) {
    echo "\nFamily: {$family['code']} (ID: {$family['id']})\n";
    
    // Get required attributes for this family (core + family-specific)
    $requiredForFamily = $coreRequiredAttributes;
    
    if (isset($familySpecificRequired[$family['code']])) {
        $requiredForFamily = array_merge($requiredForFamily, $familySpecificRequired[$family['code']]);
        echo "  + Family-specific: " . implode(', ', $familySpecificRequired[$family['code']]) . "\n";
    }
    
    $familyInserted = 0;
    $familySkipped = 0;
    
    foreach ($requiredForFamily as $attrCode) {
        // Skip if attribute doesn't exist
        if (!isset($attributeIds[$attrCode])) {
            // Try to find it (for family-specific attributes)
            $stmt = $pdo->prepare("SELECT id FROM pim_catalog_attribute WHERE code = ?");
            $stmt->execute([$attrCode]);
            $result = $stmt->fetch(PDO::FETCH_ASSOC);
            
            if ($result) {
                $attributeIds[$attrCode] = $result['id'];
            } else {
                echo "  ⚠ Attribute '$attrCode' not found in database\n";
                $totalErrors++;
                continue;
            }
        }
        
        $attributeId = $attributeIds[$attrCode];
        
        // Check if requirement already exists for each channel
        foreach ($channels as $channel) {
            $stmt = $pdo->prepare("
                SELECT id FROM pim_catalog_attribute_requirement 
                WHERE family_id = ? AND attribute_id = ? AND channel_id = ?
            ");
            $stmt->execute([$family['id'], $attributeId, $channel['id']]);
            $existing = $stmt->fetch(PDO::FETCH_ASSOC);
            
            if ($existing) {
                // Update to required if not already
                $stmt = $pdo->prepare("
                    SELECT required FROM pim_catalog_attribute_requirement 
                    WHERE id = ?
                ");
                $stmt->execute([$existing['id']]);
                $isRequired = $stmt->fetchColumn();
                
                if (!$isRequired) {
                    if (!$DRY_RUN) {
                        $stmt = $pdo->prepare("
                            UPDATE pim_catalog_attribute_requirement 
                            SET required = 1 
                            WHERE id = ?
                        ");
                        $stmt->execute([$existing['id']]);
                        echo "  ✓ Updated: $attrCode -> required (channel: {$channel['code']})\n";
                        $familyInserted++;
                    } else {
                        echo "  [DRY RUN] Would update: $attrCode -> required (channel: {$channel['code']})\n";
                        $familyInserted++;
                    }
                } else {
                    $familySkipped++;
                }
            } else {
                // Insert new requirement
                if (!$DRY_RUN) {
                    $stmt = $pdo->prepare("
                        INSERT INTO pim_catalog_attribute_requirement 
                        (family_id, attribute_id, channel_id, required) 
                        VALUES (?, ?, ?, 1)
                    ");
                    $stmt->execute([$family['id'], $attributeId, $channel['id']]);
                    echo "  ✓ Inserted: $attrCode -> required (channel: {$channel['code']})\n";
                    $familyInserted++;
                } else {
                    echo "  [DRY RUN] Would insert: $attrCode -> required (channel: {$channel['code']})\n";
                    $familyInserted++;
                }
            }
        }
    }
    
    echo "  Summary: Inserted/Updated: $familyInserted, Already set: $familySkipped\n";
    $totalInserted += $familyInserted;
    $totalSkipped += $familySkipped;
}

echo "\n" . str_repeat("-", 80) . "\n";
echo "\nGLOBAL SUMMARY:\n";
echo "  Total configured: $totalInserted\n";
echo "  Already required: $totalSkipped\n";
echo "  Errors/Warnings: $totalErrors\n";

// Step 5: Verification
echo "\n" . str_repeat("=", 80) . "\n";
echo "VERIFICATION\n";
echo str_repeat("=", 80) . "\n\n";

$stmt = $pdo->query("
    SELECT 
        f.code as family_code,
        COUNT(DISTINCT ar.attribute_id) as required_count,
        GROUP_CONCAT(DISTINCT a.code ORDER BY a.code SEPARATOR ', ') as required_attributes
    FROM pim_catalog_family f
    LEFT JOIN pim_catalog_attribute_requirement ar ON ar.family_id = f.id AND ar.required = 1
    LEFT JOIN pim_catalog_attribute a ON a.id = ar.attribute_id
    GROUP BY f.id, f.code
    ORDER BY required_count DESC, f.code
");

$results = $stmt->fetchAll(PDO::FETCH_ASSOC);

echo "Required attributes by family:\n\n";
printf("%-25s | %-10s | %s\n", "Family", "Count", "Required Attributes");
echo str_repeat("-", 80) . "\n";

$totalRequired = 0;
foreach ($results as $row) {
    printf("%-25s | %-10d | %s\n", 
        $row['family_code'], 
        $row['required_count'],
        $row['required_attributes'] ?: '(none)'
    );
    $totalRequired += $row['required_count'];
}

echo str_repeat("-", 80) . "\n";
echo "Average required attributes per family: " . round($totalRequired / count($results), 1) . "\n\n";

// Step 6: Recommendations
echo str_repeat("=", 80) . "\n";
echo "RECOMMENDATIONS\n";
echo str_repeat("=", 80) . "\n\n";

if ($DRY_RUN) {
    echo "This was a DRY RUN. To apply changes:\n";
    echo "1. Review the output above\n";
    echo "2. Edit this script and set: \$DRY_RUN = false;\n";
    echo "3. Run the script again\n\n";
} else {
    echo "✅ Required attributes have been configured!\n\n";
    echo "Next steps:\n";
    echo "1. Test product creation/editing in Akeneo PIM interface\n";
    echo "2. Verify that required attributes are enforced\n";
    echo "3. Run comprehensive audit to verify improvements\n";
    echo "4. Proceed to Phase 1.2: Add missing translations\n\n";
}

// Check for attributes that should be required but aren't configured
echo "Suggested additional required attributes:\n";
$suggestions = ['weight', 'categories', 'image'];
foreach ($suggestions as $attrCode) {
    $stmt = $pdo->prepare("
        SELECT COUNT(*) as count
        FROM pim_catalog_attribute a
        JOIN pim_catalog_attribute_requirement ar ON ar.attribute_id = a.id AND ar.required = 1
        WHERE a.code = ?
    ");
    $stmt->execute([$attrCode]);
    $count = $stmt->fetchColumn();
    
    if ($count == 0) {
        echo "  ⚠ Consider making '$attrCode' required (currently not required in any family)\n";
    }
}

echo "\n" . str_repeat("=", 80) . "\n";
echo "Script completed at: " . date('Y-m-d H:i:s') . "\n";
echo str_repeat("=", 80) . "\n\n";
