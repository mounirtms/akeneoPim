<?php
/**
 * Link Products to Images
 * Match product identifiers with image filenames and update raw_values
 */

set_time_limit(0);
ini_set('memory_limit', '1024M');

// Database connection
$host = '127.0.0.1';
$port = 3307;
$dbname = 'akeneo_pim';
$username = 'root';
$password = 'YourNewStrongPassword';

try {
    $pdo = new PDO("mysql:host=$host;port=$port;dbname=$dbname;charset=utf8mb4", $username, $password);
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
} catch (PDOException $e) {
    die("✗ Connection failed: " . $e->getMessage() . "\n");
}

echo "========================================\n";
echo "PRODUCT-IMAGE LINKING ANALYSIS\n";
echo "========================================\n";
echo "Started: " . date('Y-m-d H:i:s') . "\n\n";

// Get image attributes
echo "1. Available Image Attributes:\n";
$stmt = $pdo->query("
    SELECT code, attribute_type 
    FROM pim_catalog_attribute 
    WHERE attribute_type = 'pim_catalog_image'
    ORDER BY code
");
$imageAttributes = $stmt->fetchAll(PDO::FETCH_COLUMN);
echo "   Found " . count($imageAttributes) . " image attributes:\n";
foreach ($imageAttributes as $attr) {
    echo "   - $attr\n";
}

// Get all products
echo "\n2. Analyzing Products:\n";
$stmt = $pdo->query("
    SELECT 
        id,
        identifier,
        raw_values
    FROM pim_catalog_product
    LIMIT 10
");
$products = $stmt->fetchAll(PDO::FETCH_ASSOC);
echo "   Sample products: " . count($products) . "\n";

// Get all image files
echo "\n3. Analyzing Image Files:\n";
$stmt = $pdo->query("
    SELECT 
        id,
        file_key,
        original_filename
    FROM akeneo_file_storage_file_info
    WHERE extension IN ('jpg', 'jpeg', 'png', 'gif', 'webp')
    LIMIT 20
");
$images = $stmt->fetchAll(PDO::FETCH_ASSOC);
echo "   Sample images: " . count($images) . "\n";

// Analyze filename patterns
echo "\n4. Filename Pattern Analysis:\n";
$patterns = [];
foreach ($images as $img) {
    $filename = $img['original_filename'];
    
    // Extract potential product identifier patterns
    if (preg_match('/(\d{10,13})/', $filename, $matches)) {
        $patterns['numeric_id'][] = [
            'identifier' => $matches[1],
            'filename' => $filename,
            'file_key' => $img['file_key']
        ];
    }
    
    // Check for SKU patterns
    if (preg_match('/^([a-zA-Z0-9\-_]+)_/', $filename, $matches)) {
        $patterns['sku_prefix'][] = [
            'identifier' => $matches[1],
            'filename' => $filename,
            'file_key' => $img['file_key']
        ];
    }
}

echo "   Numeric ID pattern matches: " . count($patterns['numeric_id'] ?? []) . "\n";
echo "   SKU prefix pattern matches: " . count($patterns['sku_prefix'] ?? []) . "\n";

// Sample pattern matches
if (!empty($patterns['numeric_id'])) {
    echo "\n   Sample numeric ID matches:\n";
    foreach (array_slice($patterns['numeric_id'], 0, 5) as $match) {
        echo "   - ID: {$match['identifier']} → {$match['filename']}\n";
    }
}

// Check if these IDs exist in products
echo "\n5. Matching Products:\n";
if (!empty($patterns['numeric_id'])) {
    $testIds = array_slice(array_column($patterns['numeric_id'], 'identifier'), 0, 10);
    $placeholders = implode(',', array_fill(0, count($testIds), '?'));
    
    $stmt = $pdo->prepare("
        SELECT identifier 
        FROM pim_catalog_product 
        WHERE identifier IN ($placeholders)
    ");
    $stmt->execute($testIds);
    $matchedProducts = $stmt->fetchAll(PDO::FETCH_COLUMN);
    
    echo "   Products matched by ID: " . count($matchedProducts) . " / " . count($testIds) . "\n";
    if (!empty($matchedProducts)) {
        echo "   Matched products: " . implode(', ', array_slice($matchedProducts, 0, 5)) . "\n";
    }
}

// Analyze product raw_values structure
echo "\n6. Product Structure Analysis:\n";
$stmt = $pdo->query("
    SELECT raw_values 
    FROM pim_catalog_product 
    WHERE raw_values IS NOT NULL 
    LIMIT 1
");
$sampleProduct = $stmt->fetchColumn();
if ($sampleProduct) {
    $values = json_decode($sampleProduct, true);
    echo "   Available attributes in product data:\n";
    if (is_array($values)) {
        foreach (array_keys($values) as $key) {
            if (in_array($key, $imageAttributes)) {
                echo "   - $key (IMAGE ATTRIBUTE) ✓\n";
            } else {
                // Only show first 10 non-image attributes
                static $count = 0;
                if ($count++ < 10) {
                    echo "   - $key\n";
                }
            }
        }
    }
}

// Strategy recommendation
echo "\n========================================\n";
echo "LINKING STRATEGY RECOMMENDATION\n";
echo "========================================\n\n";

echo "Based on analysis:\n\n";

if (!empty($matchedProducts)) {
    echo "✓ STRATEGY A: Identifier-based linking\n";
    echo "  - Extract numeric IDs from image filenames\n";
    echo "  - Match with product identifiers\n";
    echo "  - Update raw_values JSON with image file_keys\n";
    echo "  - Estimated matches: ~" . count($patterns['numeric_id'] ?? []) . " products\n";
    echo "  - Risk: LOW\n";
    echo "  - Time: 30-60 minutes\n\n";
} else {
    echo "⚠ STRATEGY B: Manual mapping required\n";
    echo "  - No automatic pattern match found\n";
    echo "  - Need to create CSV mapping file\n";
    echo "  - Import via Akeneo CSV connector\n";
    echo "  - Risk: MEDIUM\n";
    echo "  - Time: 2-4 hours\n\n";
}

echo "========================================\n";
echo "NEXT STEPS\n";
echo "========================================\n\n";

echo "Option 1: Execute automatic linking (if Strategy A applies)\n";
echo "  php webapp/execute_image_linking.php\n\n";

echo "Option 2: Create manual mapping CSV\n";
echo "  php webapp/create_image_mapping_csv.php\n\n";

echo "Option 3: Review Magento data for existing image references\n";
echo "  Check if products already have images in Magento\n";
echo "  Export and import mapping\n\n";

echo "Completed: " . date('Y-m-d H:i:s') . "\n";
