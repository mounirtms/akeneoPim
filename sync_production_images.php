<?php
/**
 * Sync product images from Production (Magento) to Akeneo PIM
 * 
 * Production DB: technadminy7_dBT8x12y22
 * Production Media: /home/technadminy7/public_html/pub/media/catalog/product
 * Akeneo Storage: /home/pim/public_html/var/file_storage/catalog
 */

require __DIR__ . '/vendor/autoload.php';
use Doctrine\DBAL\DriverManager;

echo "=== Production to Akeneo Image Sync ===\n";
echo "Date: " . date('Y-m-d H:i:s') . "\n\n";

// Production database config
$prodDbConfig = [
    'driver' => 'pdo_mysql',
    'host' => '127.0.0.1',
    'port' => 3307,
    'dbname' => 'technadminy7_dBT8x12y22',
    'user' => 'root',
    'password' => 'YourNewStrongPassword',
];

// Akeneo PIM database config
$pimDbConfig = [
    'driver' => 'pdo_mysql',
    'host' => '127.0.0.1',
    'port' => 3307,
    'dbname' => 'akeneo_pim',
    'user' => 'root',
    'password' => 'YourNewStrongPassword',
    'charset' => 'utf8mb4',
];

$prodDb = DriverManager::getConnection($prodDbConfig);
$pimDb = DriverManager::getConnection($pimDbConfig);

// Ensure UTF-8
$pimDb->executeStatement("SET NAMES utf8mb4 COLLATE utf8mb4_unicode_ci");

// Configuration
$prodMediaPath = '/home/technadminy7/public_html/pub/media/catalog/product';
$pimStoragePath = '/home/pim/public_html/var/file_storage/catalog';

echo "Step 1: Extracting images from production database...\n";
$images = $prodDb->fetchAllAssociative("
    SELECT 
        e.sku,
        mg.value AS image_path,
        mgv.label AS image_label,
        mgv.position,
        mg.attribute_id
    FROM catalog_product_entity e
    JOIN catalog_product_entity_media_gallery_value_to_entity mgvte ON e.entity_id = mgvte.entity_id
    JOIN catalog_product_entity_media_gallery mg ON mgvte.value_id = mg.value_id
    LEFT JOIN catalog_product_entity_media_gallery_value mgv ON mg.value_id = mgv.value_id AND mgv.store_id = 0
    WHERE mgv.disabled = 0 OR mgv.disabled IS NULL
    ORDER BY e.sku, mgv.position
");

echo "✓ Found " . count($images) . " image records in production\n\n";

echo "Step 2: Getting Akeneo attribute and product mapping...\n";
$imageAttr = $pimDb->fetchAssociative("SELECT id FROM pim_catalog_attribute WHERE code = 'image'");
if (!$imageAttr) {
    die("ERROR: Image attribute not found in Akeneo\n");
}
$imageAttrId = $imageAttr['id'];
echo "✓ Image attribute ID: {$imageAttrId}\n";

$products = $pimDb->fetchAllAssociative("SELECT id, identifier FROM pim_catalog_product");
$productMap = [];
foreach ($products as $p) {
    $productMap[$p['identifier']] = $p['id'];
}
echo "✓ " . count($productMap) . " products in Akeneo\n\n";

echo "Step 3: Processing and copying images...\n";
$copied = 0;
$skipped = 0;
$registered = 0;
$errors = 0;

// Track already registered files to avoid duplicates
$existingFiles = $pimDb->fetchAllAssociative("SELECT id, original_filename, hash FROM akeneo_file_storage_file_info");
$existingFileMap = [];
foreach ($existingFiles as $f) {
    $existingFileMap[$f['original_filename']] = $f['id'];
}

$pimDb->beginTransaction();
try {
    $stmtInsert = $pimDb->prepare("INSERT IGNORE INTO pim_catalog_product_unique_data (product_id, attribute_id, raw_data) VALUES (?, ?, ?)");
    $stmtFileInsert = $pimDb->prepare("INSERT INTO akeneo_file_storage_file_info (file_key, original_filename, mime_type, size, extension, hash, storage) VALUES (?, ?, ?, ?, ?, ?, ?)");
    
    $processed = 0;
    foreach ($images as $image) {
        $sku = $image['sku'];
        $imagePath = $image['image_path'];
        
        // Skip root path
        if ($imagePath === '/') {
            $skipped++;
            continue;
        }
        
        // Remove leading slash for file path
        $relativePath = ltrim($imagePath, '/');
        $fullPath = $prodMediaPath . '/' . $relativePath;
        
        // Check if file exists
        if (!file_exists($fullPath)) {
            echo "  WARNING: File not found: {$fullPath}\n";
            $skipped++;
            continue;
        }
        
        // Get file info
        $filename = basename($fullPath);
        $extension = pathinfo($filename, PATHINFO_EXTENSION);
        $mimeType = mime_content_type($fullPath);
        $fileSize = filesize($fullPath);
        $fileHash = md5_file($fullPath);
        
        // Check if already registered
        if (isset($existingFileMap[$filename])) {
            $fileId = $existingFileMap[$filename];
            $registered++;
        } else {
            // Create file key (Akeneo format: random path structure)
            $randomPath = str_split($fileHash, 1);
            $fileKey = implode('/', array_slice($randomPath, 0, 3)) . '/' . $fileHash . '_' . $filename;
            
            // Copy file to Akeneo storage
            $destPath = $pimStoragePath . '/' . $fileKey;
            $destDir = dirname($destPath);
            
            if (!is_dir($destDir)) {
                mkdir($destDir, 0775, true);
            }
            
            if (!file_exists($destPath)) {
                copy($fullPath, $destPath);
                chmod($destPath, 0644);
                $copied++;
            } else {
                $registered++;
            }
            
            // Register in file_info table
            $storage = 'catalogStorage';
            $stmtFileInsert->executeStatement([
                $fileKey,
                $filename,
                $mimeType,
                $fileSize,
                $extension,
                $fileHash,
                $storage
            ]);
            
            $fileId = $pimDb->lastInsertId();
            $existingFileMap[$filename] = $fileId;
        }
        
        // Link to product in unique_data
        if (isset($productMap[$sku])) {
            $productId = $productMap[$sku];
            // Store the file_key as the image reference
            $fileKey = $pimDb->fetchOne(
                "SELECT file_key FROM akeneo_file_storage_file_info WHERE id = ?",
                [$fileId]
            );
            
            $stmtInsert->executeStatement([
                $productId,
                $imageAttrId,
                $fileKey
            ]);
        } else {
            $skipped++;
        }
        
        $processed++;
        if ($processed % 1000 === 0) {
            echo "  Processed {$processed} images...\n";
        }
    }
    
    $pimDb->commit();
    echo "\n✓ Image sync complete!\n\n";
    
} catch (Exception $e) {
    $pimDb->rollBack();
    die("ERROR: " . $e->getMessage() . "\n");
}

echo "=== Summary ===\n";
echo "Total images in production: " . count($images) . "\n";
echo "Files copied to Akeneo: {$copied}\n";
echo "Files already registered: {$registered}\n";
echo "Products linked with images: " . ($copied + $registered - $skipped) . "\n";
echo "Skipped/Missing: {$skipped}\n";
echo "Errors: {$errors}\n\n";

// Verify
$imageCount = $pimDb->fetchOne("SELECT COUNT(*) FROM pim_catalog_product_unique_data WHERE attribute_id = ?", [$imageAttrId]);
echo "Products with images in Akeneo: {$imageCount}\n";

$fileCount = $pimDb->fetchOne("SELECT COUNT(*) FROM akeneo_file_storage_file_info");
echo "Total files in Akeneo storage: {$fileCount}\n\n";

echo "=== Sync Complete ===\n";
echo "Next: Check PIM UI to verify images are displaying\n";
