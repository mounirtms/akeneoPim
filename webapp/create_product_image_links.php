<?php
/**
 * Create Product-Image Links
 * Direct approach: Match image filenames to product identifiers
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
echo "PRODUCT-IMAGE LINKING - DIRECT APPROACH\n";
echo "========================================\n";
echo "Started: " . date('Y-m-d H:i:s') . "\n\n";

// Configuration
$dryRun = false; // Set to false to actually update
$batchSize = 100;
$imageAttribute = 'image'; // Primary image attribute

// Get all products
echo "1. Loading Products...\n";
$stmt = $pdo->query("
    SELECT id, identifier 
    FROM pim_catalog_product 
    ORDER BY identifier
");
$products = $stmt->fetchAll(PDO::FETCH_ASSOC);
echo "   Found " . count($products) . " products\n\n";

// Get all image files with their patterns
echo "2. Loading Image Files...\n";
$stmt = $pdo->query("
    SELECT id, file_key, original_filename 
    FROM akeneo_file_storage_file_info 
    WHERE extension IN ('jpg', 'jpeg', 'png', 'gif', 'webp')
    ORDER BY original_filename
");
$images = $stmt->fetchAll(PDO::FETCH_ASSOC);
echo "   Found " . count($images) . " images\n\n";

// Create filename lookup
$imagesByFilename = [];
foreach ($images as $img) {
    $imagesByFilename[$img['original_filename']] = $img['file_key'];
    
    // Also index by filename without extension for fuzzy matching
    $baseFilename = pathinfo($img['original_filename'], PATHINFO_FILENAME);
    $imagesByFilename[$baseFilename] = $img['file_key'];
}

// Strategy: Match product identifier to image filename
echo "3. Matching Products to Images...\n";
$matches = [];
$notMatched = [];

foreach ($products as $product) {
    $identifier = $product['identifier'];
    $matched = false;
    
    // Try exact match
    if (isset($imagesByFilename[$identifier . '.jpg'])) {
        $matches[$identifier] = $imagesByFilename[$identifier . '.jpg'];
        $matched = true;
    } elseif (isset($imagesByFilename[$identifier . '.png'])) {
        $matches[$identifier] = $imagesByFilename[$identifier . '.png'];
        $matched = true;
    } elseif (isset($imagesByFilename[$identifier])) {
        $matches[$identifier] = $imagesByFilename[$identifier];
        $matched = true;
    } else {
        // Try fuzzy match: find images containing the identifier
        foreach ($images as $img) {
            if (stripos($img['original_filename'], $identifier) !== false) {
                $matches[$identifier] = $img['file_key'];
                $matched = true;
                break;
            }
        }
    }
    
    if (!$matched) {
        $notMatched[] = $identifier;
    }
}

echo "   Matched: " . count($matches) . " products\n";
echo "   Not matched: " . count($notMatched) . " products\n\n";

// Show sample matches
echo "4. Sample Matches (first 10):\n";
$count = 0;
foreach ($matches as $sku => $fileKey) {
    if ($count++ >= 10) break;
    echo "   - $sku → $fileKey\n";
}
echo "\n";

// Update products with image links
if (!$dryRun && count($matches) > 0) {
    echo "5. Updating Products...\n";
    $updated = 0;
    $errors = 0;
    
    $pdo->beginTransaction();
    
    try {
        foreach ($matches as $identifier => $fileKey) {
            // Get product
            $stmt = $pdo->prepare("SELECT id, raw_values FROM pim_catalog_product WHERE identifier = ?");
            $stmt->execute([$identifier]);
            $product = $stmt->fetch(PDO::FETCH_ASSOC);
            
            if (!$product) continue;
            
            // Parse raw_values
            $rawValues = json_decode($product['raw_values'], true);
            if (!is_array($rawValues)) {
                $rawValues = [];
            }
            
            // Add image to raw_values
            $rawValues[$imageAttribute] = [
                '<all_channels>' => [
                    '<all_locales>' => $fileKey
                ]
            ];
            
            // Also add to small_image and thumbnail
            $rawValues['small_image'] = [
                '<all_channels>' => [
                    '<all_locales>' => $fileKey
                ]
            ];
            $rawValues['thumbnail'] = [
                '<all_channels>' => [
                    '<all_locales>' => $fileKey
                ]
            ];
            
            // Update product
            $updateStmt = $pdo->prepare("UPDATE pim_catalog_product SET raw_values = ?, updated = NOW() WHERE id = ?");
            $updateStmt->execute([json_encode($rawValues), $product['id']]);
            
            $updated++;
            
            if ($updated % $batchSize == 0) {
                echo "   Progress: $updated products updated...\n";
            }
        }
        
        $pdo->commit();
        echo "   ✓ Successfully updated $updated products\n\n";
        
    } catch (Exception $e) {
        $pdo->rollBack();
        echo "   ✗ Error: " . $e->getMessage() . "\n\n";
        $errors++;
    }
    
    // Verify
    echo "6. Verification:\n";
    $stmt = $pdo->query("
        SELECT COUNT(DISTINCT id) as count
        FROM pim_catalog_product
        WHERE raw_values LIKE '%\"$imageAttribute\"%'
    ");
    $result = $stmt->fetch(PDO::FETCH_ASSOC);
    echo "   Products with images: " . $result['count'] . "\n";
    
} else {
    echo "5. DRY RUN - No updates performed\n";
    echo "   To execute: Set \$dryRun = false in script\n\n";
}

// Export not matched to CSV for manual review
if (count($notMatched) > 0) {
    $csvFile = '/home/pim/public_html/webapp/products_without_images.csv';
    $fp = fopen($csvFile, 'w');
    fputcsv($fp, ['Product SKU', 'Status']);
    foreach ($notMatched as $sku) {
        fputcsv($fp, [$sku, 'No image match found']);
    }
    fclose($fp);
    echo "   ℹ Products without matches exported to:\n";
    echo "   $csvFile\n\n";
}

echo "========================================\n";
echo "SUMMARY\n";
echo "========================================\n";
echo "Total products: " . count($products) . "\n";
echo "Total images: " . count($images) . "\n";
echo "Matched: " . count($matches) . " (" . round(count($matches)/count($products)*100, 1) . "%)\n";
echo "Not matched: " . count($notMatched) . " (" . round(count($notMatched)/count($products)*100, 1) . "%)\n";
if (!$dryRun) {
    echo "Updated: $updated products\n";
    echo "Errors: $errors\n";
}
echo "\nCompleted: " . date('Y-m-d H:i:s') . "\n";
