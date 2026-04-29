#!/usr/bin/env php
<?php
/**
 * CSV IMAGE IMPORT GENERATOR
 * Generates CSV file for importing placeholder images via Akeneo UI
 * 
 * @author Techno DZ
 * @date 2026-04-29
 */

// Configuration
$config = [
    'image_base_path' => '/media/product_images',
    'output_csv' => __DIR__ . '/image_import_' . date('Ymd_His') . '.csv',
];

// Database connection
$db_config = [
    'host' => '127.0.0.1',
    'port' => '3307',
    'database' => 'akeneo_pim',
    'username' => 'akeneo_pim',
    'password' => 'akeneo_pim',
];

echo "\n";
echo "=========================================\n";
echo "  CSV IMAGE IMPORT GENERATOR\n";
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
$query = "SELECT identifier FROM pim_catalog_product WHERE is_enabled = 1 ORDER BY identifier";
$stmt = $pdo->query($query);
$products = $stmt->fetchAll(PDO::FETCH_COLUMN);
$total = count($products);

echo "✓ Found {$total} enabled products\n\n";

// Check which image attributes exist
$query = "SELECT code FROM pim_catalog_attribute WHERE attribute_type = 'pim_catalog_image' ORDER BY code";
$stmt = $pdo->query($query);
$imageAttributes = $stmt->fetchAll(PDO::FETCH_COLUMN);

echo "Image attributes in Akeneo:\n";
foreach ($imageAttributes as $attr) {
    echo "  • {$attr}\n";
}
echo "\n";

// Use the most common attributes
$attributeMap = [
    'large' => 'image',
    'medium' => 'thumbnail',
    'thumbnail' => 'small_image',
];

echo "Creating CSV file...\n";

$csv = fopen($config['output_csv'], 'w');

// CSV Header
$headers = ['sku'];
foreach ($attributeMap as $attr) {
    if (in_array($attr, $imageAttributes)) {
        $headers[] = $attr;
    }
}
fputcsv($csv, $headers);

$processed = 0;
$skipped = 0;
$startTime = microtime(true);

foreach ($products as $sku) {
    $row = [$sku];
    
    // Check if images exist for this product
    $hasImages = false;
    
    foreach ($attributeMap as $size => $attrCode) {
        if (in_array($attrCode, $imageAttributes)) {
            $imagePath = "/home/pim/public_html/public{$config['image_base_path']}/{$size}/{$sku}.jpg";
            
            if (file_exists($imagePath)) {
                $row[] = "{$config['image_base_path']}/{$size}/{$sku}.jpg";
                $hasImages = true;
            } else {
                $row[] = '';
            }
        }
    }
    
    if ($hasImages) {
        fputcsv($csv, $row);
        $processed++;
    } else {
        $skipped++;
    }
    
    if ($processed % 100 === 0 && $processed > 0) {
        $elapsed = microtime(true) - $startTime;
        $rate = $processed / $elapsed;
        $eta = ($total - $processed) / $rate;
        
        echo sprintf(
            "\rProgress: %d/%d (%.1f%%) | Skipped: %d | Rate: %.1f/s | ETA: %s",
            $processed,
            $total,
            ($processed / $total) * 100,
            $skipped,
            $rate,
            gmdate('H:i:s', $eta)
        );
    }
}

fclose($csv);

$elapsed = microtime(true) - $startTime;
$fileSize = filesize($config['output_csv']);

echo "\n\n";
echo "=========================================\n";
echo "  CSV GENERATION COMPLETE\n";
echo "=========================================\n";
echo "Total products: {$total}\n";
echo "Products with images: {$processed}\n";
echo "Products skipped: {$skipped}\n";
echo "CSV file: {$config['output_csv']}\n";
echo "File size: " . number_format($fileSize / 1024, 2) . " KB\n";
echo "Processing time: " . gmdate('H:i:s', $elapsed) . "\n\n";

echo "IMPORT INSTRUCTIONS:\n";
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n";
echo "METHOD 1: Akeneo UI Import (RECOMMENDED)\n";
echo "1. Login to Akeneo: https://pim.technostationery.com\n";
echo "2. Go to: Imports > Create import profile\n";
echo "3. Configuration:\n";
echo "   • Code: product_image_import\n";
echo "   • Job: Product import in CSV\n";
echo "   • Connector: Akeneo CSV Connector\n";
echo "4. Upload file: {$config['output_csv']}\n";
echo "5. Column mapping:\n";
foreach ($attributeMap as $attr) {
    if (in_array($attr, $imageAttributes)) {
        echo "   • {$attr} → {$attr}\n";
    }
}
echo "6. Run import and monitor in Process Tracker\n\n";

echo "METHOD 2: Command Line Import\n";
echo "1. Copy CSV to Akeneo var directory:\n";
echo "   cp {$config['output_csv']} /home/pim/public_html/var/import/\n";
echo "2. Run import command:\n";
echo "   cd /home/pim/public_html\n";
echo "   php bin/console akeneo:batch:publish-product-batch\n\n";

echo "VALIDATION:\n";
echo "After import, check in Akeneo UI:\n";
echo "• Products > Select any product\n";
echo "• Check 'Images' tab\n";
echo "• Verify images are displayed\n\n";

echo "✓ CSV import file ready!\n\n";
