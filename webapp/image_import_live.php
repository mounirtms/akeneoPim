<?php
/**
 * Image Import - LIVE VERSION
 * Import physical files into Akeneo database
 * Uses pattern from existing records to maintain consistency
 */

set_time_limit(0);
ini_set('memory_limit', '512M');

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
echo "IMAGE IMPORT - LIVE EXECUTION\n";
echo "========================================\n";
echo "Started: " . date('Y-m-d H:i:s') . "\n\n";

// Configuration
$catalogPath = '/home/pim/public_html/var/file_storage/catalog';
$batchSize = 1000; // Import 1000 files at a time
$maxFiles = 11561; // Import all remaining files
$storage = 'catalogStorage';

// Get existing file keys to avoid duplicates
echo "Loading existing file keys...\n";
$stmt = $pdo->query("SELECT file_key FROM akeneo_file_storage_file_info");
$existingKeys = array_flip($stmt->fetchAll(PDO::FETCH_COLUMN));
$existingCount = count($existingKeys);
echo "Existing records: $existingCount\n\n";

// Analyze existing pattern
echo "Analyzing file_key pattern from existing records...\n";
$stmt = $pdo->query("SELECT file_key, original_filename, hash FROM akeneo_file_storage_file_info LIMIT 5");
$samples = $stmt->fetchAll(PDO::FETCH_ASSOC);
foreach ($samples as $sample) {
    echo "  Pattern: {$sample['file_key']}\n";
    echo "    Filename: {$sample['original_filename']}\n";
    echo "    Hash: {$sample['hash']}\n\n";
}

// Scan files
echo "Scanning catalog directory...\n";
$files = [];
$iterator = new RecursiveIteratorIterator(
    new RecursiveDirectoryIterator($catalogPath, RecursiveDirectoryIterator::SKIP_DOTS)
);

foreach ($iterator as $file) {
    if ($file->isFile() && count($files) < $maxFiles) {
        $relativePath = str_replace($catalogPath . '/', '', $file->getPathname());
        $files[] = [
            'path' => $file->getPathname(),
            'relative' => $relativePath,
            'filename' => $file->getFilename(),
            'size' => $file->getSize(),
            'extension' => strtolower($file->getExtension())
        ];
    }
}

$totalFiles = count($files);
echo "Files to process: $totalFiles\n\n";

// Prepare insert statement
$insertStmt = $pdo->prepare("
    INSERT INTO akeneo_file_storage_file_info 
    (file_key, original_filename, mime_type, size, extension, hash, storage)
    VALUES (:file_key, :original_filename, :mime_type, :size, :extension, :hash, :storage)
");

// Process in batches
$imported = 0;
$skipped = 0;
$errors = 0;
$batchNum = 0;

echo "Starting import in batches of $batchSize...\n";
echo "===========================================\n\n";

for ($i = 0; $i < $totalFiles; $i += $batchSize) {
    $batchNum++;
    $batch = array_slice($files, $i, $batchSize);
    $batchStart = microtime(true);
    
    echo "Batch $batchNum: Processing " . count($batch) . " files...\n";
    
    $pdo->beginTransaction();
    
    foreach ($batch as $file) {
        try {
            // Generate file_key using Akeneo's pattern
            // Pattern: first 2 chars of hash / next 2 chars / full hash / filename
            $fileHash = md5($file['filename']);
            $fileKey = substr($fileHash, 0, 1) . '/' . 
                       substr($fileHash, 1, 1) . '/' . 
                       $fileHash . '/' . 
                       $file['filename'];
            
            // Skip if already exists
            if (isset($existingKeys[$fileKey])) {
                $skipped++;
                continue;
            }
            
            // Determine MIME type
            $mimeType = 'image/jpeg';
            if ($file['extension'] === 'png') $mimeType = 'image/png';
            elseif ($file['extension'] === 'gif') $mimeType = 'image/gif';
            elseif ($file['extension'] === 'webp') $mimeType = 'image/webp';
            
            // Insert record
            $insertStmt->execute([
                ':file_key' => $fileKey,
                ':original_filename' => $file['filename'],
                ':mime_type' => $mimeType,
                ':size' => $file['size'],
                ':extension' => $file['extension'],
                ':hash' => $fileHash,
                ':storage' => $storage
            ]);
            
            $imported++;
            $existingKeys[$fileKey] = true; // Add to cache
            
        } catch (PDOException $e) {
            $errors++;
            echo "  ✗ Error importing {$file['filename']}: " . $e->getMessage() . "\n";
        }
    }
    
    $pdo->commit();
    
    $batchTime = microtime(true) - $batchStart;
    $filesPerSec = count($batch) / $batchTime;
    
    echo "  ✓ Batch complete: {$imported} imported, {$skipped} skipped, {$errors} errors\n";
    echo "  ⏱ Time: " . number_format($batchTime, 2) . "s (" . number_format($filesPerSec, 0) . " files/sec)\n";
    echo "  📊 Progress: " . number_format(($i + $batchSize) / $totalFiles * 100, 1) . "%\n\n";
    
    // Brief pause between batches
    usleep(100000); // 0.1 second
}

echo "\n========================================\n";
echo "IMPORT COMPLETE\n";
echo "========================================\n";
echo "Finished: " . date('Y-m-d H:i:s') . "\n\n";
echo "Summary:\n";
echo "  ✓ Successfully imported: $imported files\n";
echo "  ⊘ Skipped (duplicates): $skipped files\n";
echo "  ✗ Errors: $errors files\n";
echo "  📦 Total processed: " . ($imported + $skipped + $errors) . " files\n\n";

// Verify import
echo "Verifying import...\n";
$stmt = $pdo->query("SELECT COUNT(*) FROM akeneo_file_storage_file_info");
$finalCount = $stmt->fetchColumn();
echo "  Database records after import: $finalCount\n";
echo "  New records added: " . ($finalCount - $existingCount) . "\n\n";

if ($imported > 0) {
    echo "✓ Import successful! Images should now be available in Akeneo.\n";
    echo "\nNext steps:\n";
    echo "1. Clear Akeneo cache: php bin/console cache:clear --env=prod\n";
    echo "2. Check dashboard: https://pim.technostationery.com/dashboard.php\n";
    echo "3. Verify images in Akeneo UI\n";
    echo "4. Run this script again to import remaining files\n";
} else {
    echo "⚠ No new files imported. All files may already be in database.\n";
}

echo "\n";
