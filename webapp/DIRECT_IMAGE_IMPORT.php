<?php
/**
 * DIRECT IMAGE IMPORT TO AKENEO DATABASE
 * Imports product images directly into Akeneo database
 * Date: 2026-04-29
 */

echo "=== DIRECT AKENEO IMAGE IMPORT ===\n";
echo "Date: " . date('Y-m-d H:i:s') . "\n\n";

// Database configuration
$host = '127.0.0.1';
$port = 3307;
$database = 'akeneo_pim';
$username = 'akeneo_pim';
$password = 'akeneo_pim';

try {
    $dsn = "mysql:host=$host;port=$port;dbname=$database;charset=utf8mb4";
    $pdo = new PDO($dsn, $username, $password, [
        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC
    ]);
    echo "✓ Database connected\n\n";
} catch (PDOException $e) {
    die("❌ Database connection failed: " . $e->getMessage() . "\n");
}

// Step 1: Fix CSV file
echo "Step 1: Processing CSV file...\n";
$csvFile = '/home/pim/public_html/webapp/image_import_20260429_151054.csv';
$fixedCsvFile = '/home/pim/public_html/webapp/image_import_fixed.csv';

$inputHandle = fopen($csvFile, 'r');
$outputHandle = fopen($fixedCsvFile, 'w');

$rowCount = 0;
$validCount = 0;

while (($row = fgetcsv($inputHandle)) !== false) {
    $rowCount++;
    
    // Write header
    if ($rowCount === 1) {
        fputcsv($outputHandle, $row);
        continue;
    }
    
    // Skip invalid rows
    if (empty($row[0]) || strpos($row[1] ?? '', '//') !== false) {
        continue;
    }
    
    fputcsv($outputHandle, $row);
    $validCount++;
}

fclose($inputHandle);
fclose($outputHandle);

echo "✓ Processed $rowCount rows, kept $validCount valid records\n";
echo "✓ Fixed CSV: $fixedCsvFile\n\n";

// Step 2: Get attribute IDs
echo "Step 2: Getting attribute information...\n";

$attributes = [];
$attributeCodes = ['image', 'thumbnail', 'small_image'];

foreach ($attributeCodes as $code) {
    $stmt = $pdo->prepare("SELECT id FROM pim_catalog_attribute WHERE code = ?");
    $stmt->execute([$code]);
    $result = $stmt->fetch();
    
    if ($result) {
        $attributes[$code] = $result['id'];
        echo "✓ Found attribute '$code' with ID: {$result['id']}\n";
    } else {
        echo "⚠ Attribute '$code' not found, will skip\n";
    }
}

if (empty($attributes)) {
    die("\n❌ No image attributes found in database\n");
}

echo "\n";

// Step 3: Import images
echo "Step 3: Importing images to products...\n";

$handle = fopen($fixedCsvFile, 'r');
$headers = fgetcsv($handle);

$processed = 0;
$updated = 0;
$notFound = 0;
$failed = 0;

// Get product model table structure
$stmt = $pdo->query("SHOW TABLES LIKE 'pim_catalog_product'");
$productTable = $stmt->fetch();

if (!$productTable) {
    die("❌ Product table not found\n");
}

// Start transaction
$pdo->beginTransaction();

try {
    while (($row = fgetcsv($handle)) !== false) {
        $data = array_combine($headers, $row);
        $sku = $data['sku'] ?? '';
        
        if (empty($sku)) {
            continue;
        }
        
        $processed++;
        
        // Get product ID
        $stmt = $pdo->prepare("SELECT id FROM pim_catalog_product WHERE identifier = ?");
        $stmt->execute([$sku]);
        $product = $stmt->fetch();
        
        if (!$product) {
            $notFound++;
            if ($notFound <= 10) {
                echo "  ⚠ Product not found: $sku\n";
            }
            continue;
        }
        
        $productId = $product['id'];
        
        // Update each image attribute
        foreach ($attributeCodes as $attrCode) {
            if (!isset($attributes[$attrCode]) || empty($data[$attrCode])) {
                continue;
            }
            
            $attributeId = $attributes[$attrCode];
            $imagePath = $data[$attrCode];
            
            // Remove /media/product_images/ prefix to get relative path
            $imagePath = str_replace('/media/product_images/', '', $imagePath);
            
            // Check if value exists
            $stmt = $pdo->prepare("
                SELECT id FROM pim_catalog_product_value 
                WHERE product_id = ? AND attribute_id = ? AND scope_code IS NULL AND locale_code IS NULL
            ");
            $stmt->execute([$productId, $attributeId]);
            $existingValue = $stmt->fetch();
            
            if ($existingValue) {
                // Update existing value
                $stmt = $pdo->prepare("
                    UPDATE pim_catalog_product_value 
                    SET raw_data = ? 
                    WHERE id = ?
                ");
                $stmt->execute([json_encode(['filePath' => $imagePath]), $existingValue['id']]);
            } else {
                // Insert new value
                $stmt = $pdo->prepare("
                    INSERT INTO pim_catalog_product_value (product_id, attribute_id, scope_code, locale_code, raw_data)
                    VALUES (?, ?, NULL, NULL, ?)
                ");
                $stmt->execute([$productId, $attributeId, json_encode(['filePath' => $imagePath])]);
            }
        }
        
        $updated++;
        
        // Progress indicator
        if ($processed % 100 === 0) {
            echo "Progress: $processed processed, $updated updated, $notFound not found\n";
        }
    }
    
    // Commit transaction
    $pdo->commit();
    echo "\n✓ Transaction committed successfully\n";
    
} catch (Exception $e) {
    $pdo->rollBack();
    echo "\n❌ Transaction failed: " . $e->getMessage() . "\n";
    $failed = $processed - $updated;
}

fclose($handle);

// Results
echo "\n=== IMPORT COMPLETE ===\n";
echo "Total processed: $processed\n";
echo "Successfully updated: $updated\n";
echo "Products not found: $notFound\n";
echo "Failed: $failed\n";
echo "Success rate: " . round(($updated / max($processed, 1)) * 100, 2) . "%\n\n";

// Step 4: Verify import
echo "Step 4: Verifying import...\n";

$stmt = $pdo->query("
    SELECT COUNT(DISTINCT p.id) as product_count
    FROM pim_catalog_product p
    INNER JOIN pim_catalog_product_value pv ON p.id = pv.product_id
    INNER JOIN pim_catalog_attribute a ON pv.attribute_id = a.id
    WHERE a.code IN ('image', 'thumbnail', 'small_image')
    AND pv.raw_data IS NOT NULL
    AND pv.raw_data != ''
");

$result = $stmt->fetch();
echo "✓ Products with images: {$result['product_count']}\n\n";

echo "=== NEXT STEPS ===\n";
echo "1. Recalculate product completeness:\n";
echo "   cd /home/pim/public_html\n";
echo "   php bin/console pim:completeness:calculate\n\n";
echo "2. Clear cache:\n";
echo "   php bin/console cache:clear --env=prod\n\n";
echo "3. Verify in Akeneo UI:\n";
echo "   https://pim.technostationery.com/\n\n";
echo "4. Sync to Magento:\n";
echo "   php bin/console akeneo:batch:publish-product-batch --env=prod\n\n";
