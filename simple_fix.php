<?php

include_once __DIR__ . '/vendor/autoload.php';

\Pimcore\Bootstrap::setProjectRoot();
\Pimcore\Bootstrap::bootstrap();

echo "=== Simple Fix Script ===\n\n";

try {
    $db = \Pimcore\Db::get();
    
    // Fix DataHub configuration
    echo "Fixing DataHub configuration...\n";
    $stmt = $db->prepare("UPDATE datahub_configurations SET active = 1 WHERE name = 'products'");
    $stmt->execute();
    
    echo "DataHub configuration fixed.\n";
    
    // Create a basic thumbnail configuration if it doesn't exist
    echo "Checking thumbnail configuration...\n";
    
    // Try to create a basic thumbnail config
    try {
        $thumbnailConfig = new \Pimcore\Model\Asset\Image\Thumbnail\Config();
        $thumbnailConfig->setName("content");
        $thumbnailConfig->setQuality(85);
        $thumbnailConfig->setFormat("JPEG");
        $thumbnailConfig->save();
        echo "Thumbnail configuration 'content' created.\n";
    } catch (Exception $e) {
        echo "Thumbnail config already exists or error: " . $e->getMessage() . "\n";
    }
    
    // Clear cache
    echo "Clearing cache...\n";
    try {
        $cache = \Pimcore\Cache::getInstance();
        $cache->flushAll();
        echo "Cache cleared.\n";
    } catch (Exception $e) {
        echo "Error clearing cache: " . $e->getMessage() . "\n";
    }
    
    echo "\n=== Simple Fix Completed ===\n";
    
} catch (Exception $e) {
    echo "Error: " . $e->getMessage() . "\n";
}