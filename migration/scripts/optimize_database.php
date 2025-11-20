<?php

require_once __DIR__ . '/../../vendor/autoload.php';

use Pimcore\Bootstrap;

// Initialize Pimcore
Bootstrap::setProjectRoot();
Bootstrap::bootstrap();

echo "Optimizing Pimcore Database...\n\n";

try {
    $db = \Pimcore\Db::get();
    
    echo "Running optimizations...\n";
    
    // Optimize tables
    $tables = $db->fetchAllAssociative("SHOW TABLES");
    foreach ($tables as $table) {
        $tableName = current($table);
        echo "Optimizing table $tableName...\n";
        
        // Analyze table
        $db->executeQuery("ANALYZE TABLE " . $db->quoteIdentifier($tableName));
        
        // Optimize table
        $db->executeQuery("OPTIMIZE TABLE " . $db->quoteIdentifier($tableName));
    }
    
    // Add useful indexes if they don't exist
    echo "\nChecking and adding indexes...\n";
    
    // Index for object paths
    $db->executeQuery("
        CREATE INDEX IF NOT EXISTS path_idx ON objects (o_path(255))
    ");
    
    // Index for object modification date
    $db->executeQuery("
        CREATE INDEX IF NOT EXISTS moddate_idx ON objects (o_modificationDate)
    ");
    
    // Index for object creation date
    $db->executeQuery("
        CREATE INDEX IF NOT EXISTS creationdate_idx ON objects (o_creationDate)
    ");
    
    // Index for object type
    $db->executeQuery("
        CREATE INDEX IF NOT EXISTS type_idx ON objects (o_type)
    ");
    
    // Index for classification store
    $db->executeQuery("
        CREATE INDEX IF NOT EXISTS group_key_idx 
        ON object_classificationstore_data (groupId, keyId)
    ");
    
    // Optimize MySQL settings
    echo "\nConfiguring MySQL settings...\n";
    
    // Increase innodb_buffer_pool_size if needed
    $currentBufferPool = $db->fetchOne("SHOW VARIABLES LIKE 'innodb_buffer_pool_size'");
    echo "Current innodb_buffer_pool_size: " . formatBytes($currentBufferPool) . "\n";
    
    // Get total database size
    $dbSize = $db->fetchOne("
        SELECT SUM(data_length + index_length) 
        FROM information_schema.tables 
        WHERE table_schema = DATABASE()
    ");
    echo "Total database size: " . formatBytes($dbSize) . "\n";
    
    echo "\nOptimization completed!\n";
    
} catch (Exception $e) {
    echo "Error: " . $e->getMessage() . "\n";
    exit(1);
}

function formatBytes($bytes, $precision = 2) {
    $units = ['B', 'KB', 'MB', 'GB', 'TB'];
    
    $bytes = max($bytes, 0);
    $pow = floor(($bytes ? log($bytes) : 0) / log(1024));
    $pow = min($pow, count($units) - 1);
    
    $bytes /= pow(1024, $pow);
    
    return round($bytes, $precision) . ' ' . $units[$pow];
}