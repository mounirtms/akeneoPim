#!/usr/bin/env php
<?php
/**
 * Fix Image Links in Products
 * Updates product raw_values with image references
 */

set_time_limit(0);

$config = [
    'db_host' => '127.0.0.1',
    'db_port' => '3307',
    'db_user' => 'akeneo_pim',
    'db_pass' => 'akeneo_pim',
    'db_name' => 'akeneo_pim'
];

echo "Fixing image links in products...\n\n";

// Connect
try {
    $pdo = new PDO(
        "mysql:host={$config['db_host']};port={$config['db_port']};dbname={$config['db_name']}",
        $config['db_user'],
        $config['db_pass'],
        [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]
    );
} catch (PDOException $e) {
    die("Database error: " . $e->getMessage() . "\n");
}

// Get all files from storage
$stmt = $pdo->query("SELECT file_key, original_filename FROM akeneo_file_storage_file_info");
$files = $stmt->fetchAll(PDO::FETCH_ASSOC);

echo "Found " . count($files) . " files in storage\n";

// Extract SKU from filename and create mapping
$imageMap = [];
foreach ($files as $file) {
    // Try to extract SKU from filename
    $filename = $file['original_filename'];
    
    // Remove extensions and common suffixes
    $sku = preg_replace('/\.(jpg|jpeg|png|gif)$/i', '', $filename);
    $sku = preg_replace('/-optimized|-thumb|_\d+$/', '', $sku);
    
    if (!isset($imageMap[$sku])) {
        $imageMap[$sku] = $file['file_key'];
    }
}

echo "Created mapping for " . count($imageMap) . " SKUs\n\n";

// Get products
$stmt = $pdo->query("SELECT identifier, raw_values FROM pim_catalog_product");
$products = $stmt->fetchAll(PDO::FETCH_ASSOC);

$updated = 0;
$skipped = 0;

foreach ($products as $product) {
    $sku = $product['identifier'];
    
    if (isset($imageMap[$sku])) {
        $fileKey = $imageMap[$sku];
        $rawValues = json_decode($product['raw_values'], true);
        
        if (!$rawValues) {
            $rawValues = [];
        }
        
        // Add image attribute
        $rawValues['image'] = [[
            'locale' => null,
            'scope' => null,
            'data' => $fileKey
        ]];
        
        // Update product
        $newRawValues = json_encode($rawValues, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
        
        $updateStmt = $pdo->prepare("UPDATE pim_catalog_product SET raw_values = ? WHERE identifier = ?");
        $updateStmt->execute([$newRawValues, $sku]);
        
        $updated++;
        
        if ($updated % 10 == 0) {
            echo "\rUpdated: $updated products";
        }
    } else {
        $skipped++;
    }
}

echo "\n\n";
echo "============================================\n";
echo "RESULTS\n";
echo "============================================\n";
echo "Total products: " . count($products) . "\n";
echo "Updated with images: $updated\n";
echo "Skipped (no image): $skipped\n";
echo "============================================\n\n";

// Verify
$stmt = $pdo->query("SELECT COUNT(*) FROM pim_catalog_product WHERE raw_values LIKE '%\"image\"%'");
$withImages = $stmt->fetchColumn();
echo "Verification: $withImages products now have image data\n";

// Show samples
echo "\nSample products with images:\n";
$stmt = $pdo->query("
    SELECT identifier, raw_values 
    FROM pim_catalog_product 
    WHERE raw_values LIKE '%\"image\"%'
    LIMIT 5
");

while ($row = $stmt->fetch(PDO::FETCH_ASSOC)) {
    $values = json_decode($row['raw_values'], true);
    $imagePath = $values['image'][0]['data'] ?? 'N/A';
    echo "  - {$row['identifier']}: $imagePath\n";
}

echo "\nDone!\n";
