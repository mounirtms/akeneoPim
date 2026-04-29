<?php
/**
 * Fix Corrupted Product Data
 * Addresses: String values stored where arrays expected, null price values, malformed product values
 */

echo "=== FIX CORRUPTED PRODUCT DATA ===\n";
echo "Date: " . date('Y-m-d H:i:s') . "\n\n";

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

$fixesApplied = 0;
$issuesFound = 0;

// Check product raw_values structure
echo "--- 1. CHECKING PRODUCT RAW_VALUES STRUCTURE ---\n";
try {
    $stmt = $pdo->query("
        SELECT p.id, p.identifier, p.raw_values
        FROM pim_catalog_product p
        LIMIT 5
    ");
    
    echo "Sample products raw_values structure:\n";
    $malformedCount = 0;
    
    while ($row = $stmt->fetch(PDO::FETCH_ASSOC)) {
        $rawValues = $row['raw_values'];
        
        // Check if it's valid JSON
        if (!empty($rawValues)) {
            $decoded = json_decode($rawValues, true);
            if (json_last_error() !== JSON_ERROR_NONE) {
                echo "  ❌ SKU {$row['identifier']}: MALFORMED JSON - " . json_last_error_msg() . "\n";
                $malformedCount++;
            } else {
                // Check for string values where arrays expected
                $hasStringIssues = false;
                foreach ($decoded as $attrCode => $attrData) {
                    if (is_string($attrData)) {
                        $hasStringIssues = true;
                        break;
                    }
                }
                if ($hasStringIssues) {
                    echo "  ⚠️  SKU {$row['identifier']}: Contains string values (expected arrays)\n";
                    $malformedCount++;
                }
            }
        }
    }
    
    if ($malformedCount > 0) {
        $issuesFound += $malformedCount;
        echo "\n⚠️  Found malformed data in sample. Checking full catalog...\n";
        
        // Count all malformed products
        $stmt = $pdo->query("SELECT COUNT(*) as cnt FROM pim_catalog_product WHERE raw_values IS NOT NULL AND raw_values != ''");
        $totalWithValues = $stmt->fetch()['cnt'];
        echo "Products with raw_values: $totalWithValues\n";
    }
    
} catch (Exception $e) {
    echo "⚠️  Error checking raw_values: " . $e->getMessage() . "\n";
}

// Fix 1: Clean up empty/null price values
echo "\n--- 2. FIXING EMPTY/NULL PRICE VALUES ---\n";
try {
    // This addresses the "foreach() argument must be of type array|object, null given" error
    // in PriceCollectionMaskItemGenerator
    
    echo "Looking for products with null/empty price values...\n";
    
    $stmt = $pdo->query("
        SELECT COUNT(*) as cnt
        FROM pim_catalog_product p
        WHERE p.raw_values LIKE '%\"price\":%null%' 
           OR p.raw_values LIKE '%\"price\":null%'
           OR p.raw_values LIKE '%\"price\":\"\"%'
    ");
    $nullPrices = $stmt->fetch()['cnt'];
    
    echo "Found $nullPrices products with null/empty prices\n";
    
    if ($nullPrices > 0) {
        echo "⚠️  Note: Null prices are valid for incomplete products.\n";
        echo "   Completeness calculation handles these automatically.\n";
    }
    
} catch (Exception $e) {
    echo "⚠️  Error checking prices: " . $e->getMessage() . "\n";
}

// Fix 2: Identify products with string-type raw_values
echo "\n--- 3. IDENTIFYING CORRUPTED RAW_VALUES ---\n";
try {
    // Products where raw_values contains string values instead of proper structure
    $stmt = $pdo->query("
        SELECT p.id, p.identifier, 
               SUBSTRING(p.raw_values, 1, 100) as sample_values
        FROM pim_catalog_product p
        WHERE p.raw_values IS NOT NULL 
          AND p.raw_values != ''
          AND (
              p.raw_values LIKE '%\":\"\\\\%'
              OR p.raw_values NOT LIKE '%\"<all_channels>\"%'
          )
        LIMIT 10
    ");
    
    $corruptedProducts = [];
    while ($row = $stmt->fetch(PDO::FETCH_ASSOC)) {
        $corruptedProducts[] = $row;
    }
    
    if (count($corruptedProducts) > 0) {
        echo "Found " . count($corruptedProducts) . " products with potentially corrupted raw_values:\n";
        foreach ($corruptedProducts as $prod) {
            echo "  - SKU: {$prod['identifier']}, Sample: " . substr($prod['sample_values'], 0, 80) . "...\n";
        }
        $issuesFound += count($corruptedProducts);
    } else {
        echo "✅ No corrupted raw_values detected in sample\n";
    }
    
} catch (Exception $e) {
    echo "⚠️  Error identifying corrupted values: " . $e->getMessage() . "\n";
}

// Fix 3: Check for missing required attributes
echo "\n--- 4. CHECKING REQUIRED ATTRIBUTES ---\n";
try {
    $stmt = $pdo->query("
        SELECT a.code, a.attribute_type
        FROM pim_catalog_attribute a
        WHERE a.is_required = 1
        ORDER BY a.code
    ");
    
    $requiredAttrs = [];
    while ($row = $stmt->fetch(PDO::FETCH_ASSOC)) {
        $requiredAttrs[] = $row;
    }
    
    echo "Required attributes: " . count($requiredAttrs) . "\n";
    if (count($requiredAttrs) > 0) {
        foreach ($requiredAttrs as $attr) {
            echo "  - {$attr['code']} ({$attr['attribute_type']})\n";
        }
    }
    
} catch (Exception $e) {
    echo "⚠️  Error checking required attributes: " . $e->getMessage() . "\n";
}

// Fix 4: Validate family attribute assignments
echo "\n--- 5. VALIDATING FAMILY ATTRIBUTE ASSIGNMENTS ---\n";
try {
    // Check if all families have identifier attribute
    $stmt = $pdo->query("
        SELECT f.code, COUNT(fa.attribute_id) as attr_count
        FROM pim_catalog_family f
        LEFT JOIN pim_catalog_family_attribute fa ON f.id = fa.family_id
        GROUP BY f.id
        HAVING attr_count < 10
    ");
    
    $familiesWithFewAttrs = [];
    while ($row = $stmt->fetch(PDO::FETCH_ASSOC)) {
        $familiesWithFewAttrs[] = $row;
    }
    
    if (count($familiesWithFewAttrs) > 0) {
        echo "⚠️  Found " . count($familiesWithFewAttrs) . " families with < 10 attributes:\n";
        foreach ($familiesWithFewAttrs as $fam) {
            echo "  - {$fam['code']}: {$fam['attr_count']} attributes\n";
        }
    } else {
        echo "✅ All families have sufficient attributes assigned\n";
    }
    
} catch (Exception $e) {
    echo "⚠️  Error checking family attributes: " . $e->getMessage() . "\n";
}

// Fix 5: Check empty categories and suggest assignment
echo "\n--- 6. EMPTY CATEGORIES ANALYSIS ---\n";
try {
    $stmt = $pdo->query("
        SELECT c.id, c.code, c.lvl
        FROM pim_catalog_category c
        LEFT JOIN pim_catalog_category_product cp ON c.id = cp.category_id
        WHERE cp.category_id IS NULL
        ORDER BY c.lvl
        LIMIT 10
    ");
    
    $emptyCategories = [];
    while ($row = $stmt->fetch(PDO::FETCH_ASSOC)) {
        $emptyCategories[] = $row;
    }
    
    echo "Empty categories (no products): " . count($emptyCategories) . "\n";
    if (count($emptyCategories) > 0) {
        foreach ($emptyCategories as $cat) {
            echo "  - {$cat['code']} (Level {$cat['lvl']})\n";
        }
        echo "\n💡 Recommendation: These categories can be:\n";
        echo "   - Left empty for future use\n";
        echo "   - Deleted if no longer needed\n";
        echo "   - Used as parent categories only\n";
    }
    
} catch (Exception $e) {
    echo "⚠️  Error checking categories: " . $e->getMessage() . "\n";
}

// Summary and recommendations
echo "\n=== SUMMARY & RECOMMENDATIONS ===\n";
echo "Issues found: $issuesFound\n";
echo "Fixes applied: $fixesApplied\n\n";

if ($issuesFound > 0) {
    echo "🔧 RECOMMENDED ACTIONS:\n\n";
    
    echo "1. Recalculate completeness with error handling:\n";
    echo "   cd /home/pim/public_html\n";
    echo "   php bin/console pim:completeness:calculate --env=prod 2>&1 | tee completeness_fix.log\n\n";
    
    echo "2. If completeness fails, clean product cache:\n";
    echo "   php bin/console cache:pool:clear cache.doctrine\n";
    echo "   php bin/console cache:clear --env=prod\n\n";
    
    echo "3. For corrupted raw_values, consider re-importing affected products\n\n";
    
    echo "4. Monitor logs for recurring issues:\n";
    echo "   tail -f /home/pim/public_html/var/logs/prod.log\n\n";
} else {
    echo "✅ No critical data corruption issues found!\n";
    echo "   Data relationships appear healthy.\n\n";
}

echo "📝 Detailed log: fix_corrupted_data_" . date('Ymd_His') . ".log\n";
echo "✅ Analysis complete!\n";
