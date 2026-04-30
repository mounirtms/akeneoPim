#!/usr/bin/env php
<?php
/**
 * Akeneo Image Import - Fast PHP Version
 * Imports product images from Magento catalog to Akeneo PIM
 */

set_time_limit(0);
ini_set('memory_limit', '512M');

// Configuration
$config = [
    'magento_images' => '/home/technadminy7/public_html/pub/media/catalog/product',
    'akeneo_storage' => '/home/pim/public_html/var/file_storage/catalog',
    'db_host' => '127.0.0.1',
    'db_port' => '3307',
    'db_user' => 'akeneo_pim',
    'db_pass' => 'akeneo_pim',
    'db_name' => 'akeneo_pim',
    'batch_size' => isset($argv[1]) ? (int)$argv[1] : 100,
    'log_file' => '/home/pim/public_html/webapp/image_import_' . date('Ymd_His') . '.log'
];

// Start logging
function logMessage($msg, $config) {
    $timestamp = date('Y-m-d H:M:S');
    $message = "[$timestamp] $msg\n";
    echo $message;
    file_put_contents($config['log_file'], $message, FILE_APPEND);
}

echo "============================================\n";
echo "AKENEO IMAGE IMPORT - PHP VERSION\n";
echo "============================================\n\n";

logMessage("Starting image import for {$config['batch_size']} products", $config);

// Connect to database
try {
    $pdo = new PDO(
        "mysql:host={$config['db_host']};port={$config['db_port']};dbname={$config['db_name']}",
        $config['db_user'],
        $config['db_pass'],
        [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]
    );
    logMessage("✓ Database connected", $config);
} catch (PDOException $e) {
    logMessage("✗ Database connection failed: " . $e->getMessage(), $config);
    exit(1);
}

// Step 1: Get products
logMessage("Step 1: Getting {$config['batch_size']} products...", $config);
$stmt = $pdo->query("SELECT identifier FROM pim_catalog_product LIMIT {$config['batch_size']}");
$products = $stmt->fetchAll(PDO::FETCH_COLUMN);
logMessage("✓ Retrieved " . count($products) . " products", $config);
echo "\n";

// Step 2: Build image index for faster lookup
logMessage("Step 2: Building image index...", $config);
$imageIndex = [];
$iterator = new RecursiveIteratorIterator(
    new RecursiveDirectoryIterator($config['magento_images'], RecursiveDirectoryIterator::SKIP_DOTS),
    RecursiveIteratorIterator::SELF_FIRST
);

foreach ($iterator as $file) {
    if ($file->isFile()) {
        $ext = strtolower($file->getExtension());
        if (in_array($ext, ['jpg', 'jpeg', 'png', 'gif'])) {
            $filename = $file->getFilename();
            // Skip cache, thumbnails, etc.
            if (strpos($file->getPath(), '/cache/') === false && 
                strpos($filename, 'thumb') === false && 
                strpos($filename, 'small') === false) {
                $imageIndex[$filename] = $file->getPathname();
            }
        }
    }
}
logMessage("✓ Indexed " . count($imageIndex) . " images", $config);
echo "\n";

// Step 3: Match and import
logMessage("Step 3: Matching and importing images...", $config);
$foundCount = 0;
$copiedCount = 0;
$missingCount = 0;
$processedCount = 0;

foreach ($products as $sku) {
    $processedCount++;
    $imagePath = null;
    
    // Try different naming patterns
    $patterns = [
        "{$sku}.jpg",
        "{$sku}.jpeg",
        "{$sku}.png",
        "{$sku}-optimized.jpg",
        "{$sku}_1.jpg"
    ];
    
    foreach ($patterns as $pattern) {
        if (isset($imageIndex[$pattern])) {
            $imagePath = $imageIndex[$pattern];
            break;
        }
    }
    
    // Fallback: search for partial match
    if (!$imagePath) {
        foreach ($imageIndex as $filename => $path) {
            if (strpos($filename, $sku) !== false) {
                $imagePath = $path;
                break;
            }
        }
    }
    
    if ($imagePath && file_exists($imagePath)) {
        $foundCount++;
        
        // Copy image to Akeneo storage
        $filename = basename($imagePath);
        $hash = md5($sku . '-' . $filename);
        $first = substr($hash, 0, 1);
        $second = substr($hash, 1, 1);
        $storageKey = "$first/$second/$hash/$filename";
        $targetDir = "{$config['akeneo_storage']}/$first/$second/$hash";
        
        if (!file_exists($targetDir)) {
            mkdir($targetDir, 0755, true);
        }
        
        $targetPath = "$targetDir/$filename";
        if (copy($imagePath, $targetPath)) {
            // Set ownership
            chown($targetPath, 'pim');
            chgrp($targetPath, 'pim');
            chmod($targetPath, 0644);
            
            // Get file info
            $size = filesize($targetPath);
            $mimeType = mime_content_type($targetPath);
            $ext = pathinfo($filename, PATHINFO_EXTENSION);
            
            // Insert file info
            try {
                $stmt = $pdo->prepare("
                    INSERT IGNORE INTO akeneo_file_storage_file_info 
                    (file_key, original_filename, mime_type, size, extension, hash)
                    VALUES (?, ?, ?, ?, ?, ?)
                ");
                $stmt->execute([$storageKey, $filename, $mimeType, $size, $ext, $hash]);
                
                // Update product
                $stmt = $pdo->prepare("
                    UPDATE pim_catalog_product 
                    SET raw_values = JSON_SET(
                        COALESCE(raw_values, '{}'),
                        '$.image[0]',
                        JSON_OBJECT('locale', NULL, 'scope', NULL, 'data', ?)
                    )
                    WHERE identifier = ?
                ");
                $stmt->execute([$storageKey, $sku]);
                
                $copiedCount++;
            } catch (PDOException $e) {
                logMessage("Warning: Database error for $sku: " . $e->getMessage(), $config);
            }
        }
    } else {
        $missingCount++;
    }
    
    // Progress indicator
    if ($processedCount % 10 == 0 || $processedCount == count($products)) {
        echo "\rProgress: $processedCount/" . count($products) . 
             " | Found: $foundCount | Imported: $copiedCount | Missing: $missingCount";
    }
}

echo "\n\n";
logMessage("✓ Import complete", $config);
echo "\n";

// Summary
echo "============================================\n";
echo "IMPORT SUMMARY\n";
echo "============================================\n";
echo "Products processed: " . count($products) . "\n";
echo "Images found: $foundCount\n";
echo "Images imported: $copiedCount\n";
echo "Images missing: $missingCount\n";
$successRate = count($products) > 0 ? round(($copiedCount / count($products)) * 100, 1) : 0;
echo "Success rate: {$successRate}%\n";
echo "\nLog file: {$config['log_file']}\n";
echo "============================================\n";

// Verify
$stmt = $pdo->query("SELECT COUNT(*) FROM pim_catalog_product WHERE JSON_EXTRACT(raw_values, '$.image[0].data') IS NOT NULL");
$totalWithImages = $stmt->fetchColumn();
echo "\nTotal products with images in database: $totalWithImages\n";

// Show sample
echo "\nSample products with images:\n";
$stmt = $pdo->query("
    SELECT identifier, JSON_EXTRACT(raw_values, '$.image[0].data') as image_path 
    FROM pim_catalog_product 
    WHERE JSON_EXTRACT(raw_values, '$.image[0].data') IS NOT NULL 
    LIMIT 5
");
while ($row = $stmt->fetch(PDO::FETCH_ASSOC)) {
    echo "  - {$row['identifier']}: {$row['image_path']}\n";
}

logMessage("Import session complete!", $config);
echo "\n";
