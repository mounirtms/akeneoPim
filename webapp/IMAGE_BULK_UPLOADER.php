#!/usr/bin/env php
<?php
/**
 * IMAGE BULK UPLOADER FOR AKENEO PIM
 * Uploads generated placeholder images to Akeneo products via API
 * 
 * @author Techno DZ
 * @date 2026-04-29
 */

// Configuration
$config = [
    'akeneo_url' => 'https://pim.technostationery.com',
    'client_id' => '1_your_client_id',  // Update with actual credentials
    'secret' => 'your_secret',
    'username' => 'admin',
    'password' => 'your_password',
    'image_base_path' => '/home/pim/product_images/placeholders/',
    'image_attribute' => 'image',  // Main product image attribute
    'batch_size' => 50,
    'delay_ms' => 100,  // Delay between API calls to avoid rate limiting
];

// Database connection for product SKU lookup
$db_config = [
    'host' => 'localhost',
    'port' => '3307',
    'database' => 'akeneo_pim',
    'username' => 'akeneo_pim',
    'password' => 'akeneo_pim',
];

echo "\n";
echo "=========================================\n";
echo "  IMAGE BULK UPLOADER FOR AKENEO PIM\n";
echo "=========================================\n";
echo "Date: " . date('Y-m-d H:i:s') . "\n\n";

// Connect to database
try {
    $dsn = "mysql:host={$db_config['host']};port={$db_config['port']};dbname={$db_config['database']};charset=utf8mb4";
    $pdo = new PDO($dsn, $db_config['username'], $db_config['password'], [
        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
    ]);
    echo "✓ Database connected\n";
} catch (PDOException $e) {
    die("✗ Database connection failed: " . $e->getMessage() . "\n");
}

// Get all products
$query = "SELECT identifier, family_code FROM pim_catalog_product ORDER BY identifier";
$stmt = $pdo->query($query);
$products = $stmt->fetchAll();
$total = count($products);

echo "✓ Found {$total} products\n\n";

// Akeneo API Authentication
function getAkeneoToken($config) {
    $ch = curl_init();
    curl_setopt($ch, CURLOPT_URL, $config['akeneo_url'] . '/api/oauth/v1/token');
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_POST, true);
    curl_setopt($ch, CURLOPT_HTTPHEADER, [
        'Content-Type: application/json',
        'Authorization: Basic ' . base64_encode($config['client_id'] . ':' . $config['secret'])
    ]);
    curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode([
        'grant_type' => 'password',
        'username' => $config['username'],
        'password' => $config['password']
    ]));
    
    $response = curl_exec($ch);
    $http_code = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    curl_close($ch);
    
    if ($http_code === 200) {
        $data = json_decode($response, true);
        return $data['access_token'] ?? null;
    }
    
    return null;
}

// Upload image via Akeneo API
function uploadImageToAkeneo($sku, $imagePath, $token, $config) {
    if (!file_exists($imagePath)) {
        return ['success' => false, 'error' => 'File not found'];
    }
    
    // Step 1: Upload media file
    $ch = curl_init();
    $mediaFile = new CURLFile($imagePath, 'image/jpeg', basename($imagePath));
    
    curl_setopt($ch, CURLOPT_URL, $config['akeneo_url'] . '/api/rest/v1/media-files');
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_POST, true);
    curl_setopt($ch, CURLOPT_HTTPHEADER, [
        'Authorization: Bearer ' . $token,
    ]);
    curl_setopt($ch, CURLOPT_POSTFIELDS, ['file' => $mediaFile]);
    
    $response = curl_exec($ch);
    $http_code = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    curl_close($ch);
    
    if ($http_code !== 201) {
        return ['success' => false, 'error' => 'Media upload failed: ' . $http_code];
    }
    
    $mediaData = json_decode($response, true);
    $mediaCode = basename($mediaData['_links']['download']['href']);
    
    // Step 2: Link media to product
    $ch = curl_init();
    curl_setopt($ch, CURLOPT_URL, $config['akeneo_url'] . '/api/rest/v1/products/' . urlencode($sku));
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_CUSTOMREQUEST, 'PATCH');
    curl_setopt($ch, CURLOPT_HTTPHEADER, [
        'Authorization: Bearer ' . $token,
        'Content-Type: application/json',
    ]);
    curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode([
        'values' => [
            $config['image_attribute'] => [
                [
                    'locale' => null,
                    'scope' => null,
                    'data' => $mediaCode
                ]
            ]
        ]
    ]));
    
    $response = curl_exec($ch);
    $http_code = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    curl_close($ch);
    
    if ($http_code === 204) {
        return ['success' => true];
    }
    
    return ['success' => false, 'error' => 'Product update failed: ' . $http_code];
}

// Manual CSV export alternative
echo "NOTE: Akeneo API upload requires valid credentials.\n";
echo "Alternative: Generate CSV import file for manual import via Akeneo UI\n\n";
echo "Creating CSV import file...\n";

$csvPath = __DIR__ . '/image_import_' . date('Ymd_His') . '.csv';
$csv = fopen($csvPath, 'w');

// CSV Header
fputcsv($csv, ['sku', 'image', 'thumbnail_image', 'small_image']);

$processed = 0;
$startTime = microtime(true);

foreach ($products as $product) {
    $sku = $product['identifier'];
    
    // Check if images exist
    $largeImage = $config['image_base_path'] . 'large/' . $sku . '.jpg';
    $mediumImage = $config['image_base_path'] . 'medium/' . $sku . '.jpg';
    $thumbnailImage = $config['image_base_path'] . 'thumbnail/' . $sku . '.jpg';
    
    if (file_exists($largeImage)) {
        fputcsv($csv, [
            $sku,
            $largeImage,
            $mediumImage,
            $thumbnailImage
        ]);
        $processed++;
    }
    
    if ($processed % 100 === 0) {
        $elapsed = microtime(true) - $startTime;
        $rate = $processed / $elapsed;
        $eta = ($total - $processed) / $rate;
        
        echo sprintf(
            "\rProgress: %d/%d (%.1f%%) | Rate: %.1f/s | ETA: %s",
            $processed,
            $total,
            ($processed / $total) * 100,
            $rate,
            gmdate('H:i:s', $eta)
        );
    }
}

fclose($csv);

$elapsed = microtime(true) - $startTime;

echo "\n\n";
echo "=========================================\n";
echo "  UPLOAD PREPARATION COMPLETE\n";
echo "=========================================\n";
echo "Total products: {$total}\n";
echo "Products with images: {$processed}\n";
echo "CSV file: {$csvPath}\n";
echo "Processing time: " . gmdate('H:i:s', $elapsed) . "\n\n";

echo "NEXT STEPS:\n";
echo "1. Import images via Akeneo UI:\n";
echo "   - Go to Imports > Create import profile\n";
echo "   - Type: Product\n";
echo "   - Upload CSV: {$csvPath}\n";
echo "   - Map columns: sku → identifier, image columns → respective attributes\n";
echo "   - Run import\n\n";
echo "2. Verify in Akeneo:\n";
echo "   - Products > Assets > Check image assignments\n\n";
echo "3. Sync to Magento:\n";
echo "   - Run: php bin/console akeneo:batch:publish-product-batch\n\n";

echo "✓ Image upload preparation completed!\n\n";
