<?php
/**
 * FIX CSV AND IMPORT PRODUCT IMAGES TO AKENEO
 * Cleans CSV data and imports via Akeneo API
 * Date: 2026-04-29
 */

require __DIR__ . '/vendor/autoload.php';

use Akeneo\Pim\ApiClient\AkeneoPimClientBuilder;

echo "=== PRODUCT IMAGE IMPORT TO AKENEO ===\n";
echo "Date: " . date('Y-m-d H:i:s') . "\n\n";

// Configuration
$baseUrl = 'https://pim.technostationery.com';
$clientId = '2_ml5f52erhggg0s484gckwgs4kg8gwc4c48ksgko4gkgos4k48';
$clientSecret = '1zniz3jfcmcgg0wckskw8k4c80ccwc4o0cokcwk80cs8cs0cs4';
$username = 'apiconnector';
$password = 'ApiConnector@2026!Secure';

$csvFile = '/home/pim/public_html/webapp/image_import_20260429_151054.csv';
$fixedCsvFile = '/home/pim/public_html/webapp/image_import_fixed.csv';

// Step 1: Fix CSV file
echo "Step 1: Fixing CSV file...\n";
$inputHandle = fopen($csvFile, 'r');
$outputHandle = fopen($fixedCsvFile, 'w');

$rowCount = 0;
$fixedCount = 0;

while (($row = fgetcsv($inputHandle)) !== false) {
    $rowCount++;
    
    // Skip header
    if ($rowCount === 1) {
        fputcsv($outputHandle, $row);
        continue;
    }
    
    // Skip rows with empty SKU or invalid paths
    if (empty($row[0]) || strpos($row[1], '//') !== false) {
        $fixedCount++;
        continue;
    }
    
    fputcsv($outputHandle, $row);
}

fclose($inputHandle);
fclose($outputHandle);

echo "✓ CSV fixed: $rowCount rows processed, $fixedCount invalid rows removed\n";
echo "✓ Fixed CSV saved to: $fixedCsvFile\n\n";

// Step 2: Initialize Akeneo API client
echo "Step 2: Connecting to Akeneo API...\n";

try {
    $clientBuilder = new AkeneoPimClientBuilder($baseUrl);
    $client = $clientBuilder->buildAuthenticatedByPassword(
        $clientId,
        $clientSecret,
        $username,
        $password
    );
    echo "✓ Connected to Akeneo API\n\n";
} catch (\Exception $e) {
    die("❌ Failed to connect: " . $e->getMessage() . "\n");
}

// Step 3: Import images via API
echo "Step 3: Importing product images...\n";
echo "This will update products with image attributes\n\n";

$handle = fopen($fixedCsvFile, 'r');
$headers = fgetcsv($handle);

$processed = 0;
$success = 0;
$failed = 0;
$batchSize = 100;
$products = [];

while (($row = fgetcsv($handle)) !== false) {
    $data = array_combine($headers, $row);
    $sku = $data['sku'];
    
    if (empty($sku)) {
        continue;
    }
    
    // Prepare product data
    $productData = [
        'identifier' => $sku,
        'values' => []
    ];
    
    // Add image attributes
    if (!empty($data['image'])) {
        $productData['values']['image'] = [
            [
                'locale' => null,
                'scope' => null,
                'data' => $data['image']
            ]
        ];
    }
    
    if (!empty($data['thumbnail'])) {
        $productData['values']['thumbnail'] = [
            [
                'locale' => null,
                'scope' => null,
                'data' => $data['thumbnail']
            ]
        ];
    }
    
    if (!empty($data['small_image'])) {
        $productData['values']['small_image'] = [
            [
                'locale' => null,
                'scope' => null,
                'data' => $data['small_image']
            ]
        ];
    }
    
    $products[] = $productData;
    $processed++;
    
    // Process in batches
    if (count($products) >= $batchSize) {
        echo "Processing batch of " . count($products) . " products...\n";
        
        foreach ($products as $product) {
            try {
                $client->getProductApi()->upsert($product['identifier'], $product);
                $success++;
            } catch (\Exception $e) {
                $failed++;
                echo "  ✗ Failed to update {$product['identifier']}: " . $e->getMessage() . "\n";
            }
        }
        
        echo "Progress: $success successful, $failed failed out of $processed processed\n\n";
        $products = [];
        
        // Small delay to avoid rate limiting
        usleep(100000); // 0.1 second
    }
}

// Process remaining products
if (!empty($products)) {
    echo "Processing final batch of " . count($products) . " products...\n";
    
    foreach ($products as $product) {
        try {
            $client->getProductApi()->upsert($product['identifier'], $product);
            $success++;
        } catch (\Exception $e) {
            $failed++;
            echo "  ✗ Failed to update {$product['identifier']}: " . $e->getMessage() . "\n";
        }
    }
}

fclose($handle);

echo "\n=== IMPORT COMPLETE ===\n";
echo "Total processed: $processed\n";
echo "Successful: $success\n";
echo "Failed: $failed\n";
echo "Success rate: " . round(($success / $processed) * 100, 2) . "%\n\n";

echo "=== NEXT STEPS ===\n";
echo "1. Verify images in Akeneo UI:\n";
echo "   https://pim.technostationery.com/\n\n";
echo "2. Recalculate product completeness:\n";
echo "   cd /home/pim/public_html\n";
echo "   php bin/console pim:completeness:calculate\n\n";
echo "3. Sync to Magento:\n";
echo "   php bin/console akeneo:batch:publish-product-batch --env=prod\n\n";
