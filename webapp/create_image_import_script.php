<?php
/**
 * Image Import Script - Register Files in Akeneo Database
 * This script creates mapping between physical files and database records
 */

// Database connection
$host = '127.0.0.1';
$port = 3307;
$dbname = 'akeneo_pim';
$username = 'root';
$password = 'YourNewStrongPassword';

try {
    $pdo = new PDO("mysql:host=$host;port=$port;dbname=$dbname;charset=utf8mb4", $username, $password);
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    echo "✓ Database connected\n\n";
} catch (PDOException $e) {
    die("✗ Connection failed: " . $e->getMessage() . "\n");
}

// Configuration
$catalogPath = '/home/pim/public_html/var/file_storage/catalog';
$dryRun = true; // Set to false to actually insert records
$batchSize = 100;

echo "========================================\n";
echo "IMAGE IMPORT SCRIPT\n";
echo "========================================\n";
echo "Mode: " . ($dryRun ? "DRY RUN (no changes)" : "LIVE IMPORT") . "\n";
echo "Catalog path: $catalogPath\n";
echo "Batch size: $batchSize\n\n";

// 1. Count existing records
$stmt = $pdo->query("SELECT COUNT(*) FROM akeneo_file_storage_file_info");
$existingRecords = $stmt->fetchColumn();
echo "Existing DB records: $existingRecords\n\n";

// 2. Scan catalog directory
echo "Scanning catalog directory...\n";
$files = [];
$iterator = new RecursiveIteratorIterator(
    new RecursiveDirectoryIterator($catalogPath, RecursiveDirectoryIterator::SKIP_DOTS)
);

foreach ($iterator as $file) {
    if ($file->isFile()) {
        $files[] = [
            'path' => $file->getPathname(),
            'filename' => $file->getFilename(),
            'size' => $file->getSize(),
            'hash' => basename(dirname($file->getPathname()), '/') // Get hash from parent dir
        ];
    }
}

$totalFiles = count($files);
echo "✓ Found $totalFiles physical files\n\n";

// 3. Sample analysis
echo "=== Sample Files Analysis ===\n";
for ($i = 0; $i < min(5, $totalFiles); $i++) {
    echo "File " . ($i + 1) . ":\n";
    echo "  Path: " . $files[$i]['path'] . "\n";
    echo "  Name: " . $files[$i]['filename'] . "\n";
    echo "  Size: " . number_format($files[$i]['size']) . " bytes\n";
    echo "  Hash: " . $files[$i]['hash'] . "\n\n";
}

// 4. Check for existing file keys
echo "=== Checking Existing File Keys ===\n";
$stmt = $pdo->query("SELECT file_key FROM akeneo_file_storage_file_info LIMIT 5");
$existingKeys = $stmt->fetchAll(PDO::FETCH_COLUMN);
echo "Sample existing keys:\n";
foreach ($existingKeys as $key) {
    echo "  - $key\n";
}
echo "\n";

// 5. Prepare import strategy
echo "=== Import Strategy ===\n";
$toImport = $totalFiles - $existingRecords;
echo "Files to import: $toImport\n";
echo "Estimated batches: " . ceil($toImport / $batchSize) . "\n";
echo "Estimated time: " . ceil($toImport / 500) . " minutes (assuming 500 files/min)\n\n";

// 6. Sample import (dry run)
if ($dryRun) {
    echo "=== DRY RUN: Sample Import (no actual insert) ===\n";
    $sampleSize = min(10, $totalFiles);
    
    for ($i = 0; $i < $sampleSize; $i++) {
        $file = $files[$i];
        $fileKey = hash('sha256', $file['path']); // Generate unique key
        $originalFilename = $file['filename'];
        $mimeType = mime_content_type($file['path']) ?: 'image/jpeg';
        $size = $file['size'];
        $extension = pathinfo($file['filename'], PATHINFO_EXTENSION);
        $hash = $file['hash'];
        
        echo "Would insert:\n";
        echo "  file_key: $fileKey\n";
        echo "  original_filename: $originalFilename\n";
        echo "  mime_type: $mimeType\n";
        echo "  size: $size bytes\n";
        echo "  extension: $extension\n";
        echo "  hash: $hash\n\n";
    }
    
    echo "\n";
    echo "========================================\n";
    echo "DRY RUN COMPLETE\n";
    echo "========================================\n";
    echo "\n";
    echo "To run actual import:\n";
    echo "1. Review this output carefully\n";
    echo "2. Set \$dryRun = false in the script\n";
    echo "3. Run: php webapp/create_image_import_script.php\n";
    echo "4. Monitor progress and validate results\n";
} else {
    echo "=== LIVE IMPORT ===\n";
    echo "⚠ THIS WILL MODIFY THE DATABASE\n";
    echo "Press Ctrl+C within 5 seconds to cancel...\n";
    sleep(5);
    
    // TODO: Implement actual import logic here
    echo "Import logic would go here...\n";
}

echo "\n";
