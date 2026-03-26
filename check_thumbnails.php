<?php

// Check thumbnail configuration and generation

include_once __DIR__ . '/vendor/autoload.php';

\Pimcore\Bootstrap::setProjectRoot();
\Pimcore\Bootstrap::bootstrap();

// Initialize kernel
$kernel = \Pimcore\Bootstrap::kernel();
$app = new \Pimcore\Console\Application($kernel);
$app->setAutoExit(false);

echo "=== Thumbnail Configuration Check ===\n\n";

try {
    // Check if we can access the thumbnail configuration
    $db = \Pimcore\Db::get();
    
    // Check if there are any thumbnail configurations
    $query = "SELECT * FROM assets_image_thumbnail_configs LIMIT 5";
    $configs = $db->fetchAllAssociative($query);
    
    if (empty($configs)) {
        echo "No thumbnail configurations found in database.\n";
    } else {
        echo "Found " . count($configs) . " thumbnail configurations:\n";
        foreach ($configs as $config) {
            echo "- " . $config['name'] . " (ID: " . $config['id'] . ")\n";
        }
    }
    
    echo "\n=== Checking Asset Structure ===\n";
    
    // Check a sample asset
    $query = "SELECT id, filename, path FROM assets WHERE type = 'image' LIMIT 1";
    $asset = $db->fetchAssociative($query);
    
    if ($asset) {
        echo "Sample asset:\n";
        echo "- ID: " . $asset['id'] . "\n";
        echo "- Filename: " . $asset['filename'] . "\n";
        echo "- Path: " . $asset['path'] . "\n";
        
        // Try to load the asset
        try {
            $assetObject = \Pimcore\Model\Asset::getById($asset['id']);
            if ($assetObject) {
                echo "- Asset loaded successfully\n";
                echo "- Asset type: " . $assetObject->getType() . "\n";
                echo "- Full path: " . $assetObject->getRealFullPath() . "\n";
                
                // Check if we can get thumbnail
                try {
                    $thumbnail = $assetObject->getThumbnail("content");
                    echo "- Thumbnail generated: " . $thumbnail . "\n";
                } catch (Exception $e) {
                    echo "- Error generating thumbnail: " . $e->getMessage() . "\n";
                }
            } else {
                echo "- Failed to load asset object\n";
            }
        } catch (Exception $e) {
            echo "- Error loading asset: " . $e->getMessage() . "\n";
        }
    } else {
        echo "No image assets found.\n";
    }
    
} catch (Exception $e) {
    echo "Error: " . $e->getMessage() . "\n";
}

echo "\n=== Checking Thumbnail Cache ===\n";

try {
    // Check thumbnail cache table
    $query = "SELECT COUNT(*) as count FROM assets_image_thumbnail_cache";
    $count = $db->fetchOne($query);
    echo "Thumbnail cache entries: " . $count . "\n";
} catch (Exception $e) {
    echo "Error checking thumbnail cache: " . $e->getMessage() . "\n";
}