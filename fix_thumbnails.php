<?php

// Script to fix thumbnail generation issues

include_once __DIR__ . '/vendor/autoload.php';

\Pimcore\Bootstrap::setProjectRoot();
\Pimcore\Bootstrap::bootstrap();

echo "=== Thumbnail Generation Fix ===\n\n";

try {
    // Check if we can access assets
    $db = \Pimcore\Db::get();
    
    echo "Checking assets...\n";
    $count = $db->fetchOne("SELECT COUNT(*) FROM assets");
    echo "Total assets: " . $count . "\n";
    
    // Get a sample image asset
    $assetData = $db->fetchAssociative("SELECT id, filename, path FROM assets WHERE type = 'image' LIMIT 1");
    
    if ($assetData) {
        echo "Sample asset:\n";
        echo "- ID: " . $assetData['id'] . "\n";
        echo "- Filename: " . $assetData['filename'] . "\n";
        echo "- Path: " . $assetData['path'] . "\n";
        
        // Try to load the asset
        $asset = \Pimcore\Model\Asset::getById($assetData['id']);
        
        if ($asset) {
            echo "Asset loaded successfully.\n";
            
            // Try to get thumbnail configuration
            echo "Checking thumbnail configurations...\n";
            
            try {
                // Try to generate a default thumbnail
                echo "Generating thumbnail...\n";
                $thumbnail = $asset->getThumbnail("content");
                echo "Thumbnail generated: " . $thumbnail . "\n";
                
                // Get thumbnail file path
                $thumbnailPath = $thumbnail->getFileSystemPath();
                echo "Thumbnail file path: " . $thumbnailPath . "\n";
                
                if (file_exists($thumbnailPath)) {
                    echo "Thumbnail file exists.\n";
                } else {
                    echo "Thumbnail file does not exist. Trying to generate it...\n";
                    
                    // Force generation
                    $thumbnailConfig = $asset->getThumbnailConfig("content");
                    if ($thumbnailConfig) {
                        echo "Thumbnail config found.\n";
                        $thumbnail = $asset->generateThumbnail($thumbnailConfig);
                        echo "Thumbnail generated: " . $thumbnail . "\n";
                    } else {
                        echo "Thumbnail config not found.\n";
                    }
                }
            } catch (Exception $e) {
                echo "Error generating thumbnail: " . $e->getMessage() . "\n";
                
                // Try to create a basic thumbnail config
                echo "Creating basic thumbnail configuration...\n";
                
                try {
                    $thumbnailConfig = new \Pimcore\Model\Asset\Image\Thumbnail\Config();
                    $thumbnailConfig->setName("content");
                    $thumbnailConfig->setQuality(85);
                    $thumbnailConfig->setFormat("JPEG");
                    $thumbnailConfig->save();
                    echo "Thumbnail configuration 'content' created.\n";
                } catch (Exception $configException) {
                    echo "Failed to create thumbnail configuration: " . $configException->getMessage() . "\n";
                }
            }
        } else {
            echo "Failed to load asset.\n";
        }
    } else {
        echo "No image assets found.\n";
    }
    
    // Check if image optimization libraries are available
    echo "\nChecking image optimization libraries...\n";
    
    if (extension_loaded('gd')) {
        echo "GD extension: Available\n";
    } else {
        echo "GD extension: Not available\n";
    }
    
    if (extension_loaded('imagick')) {
        echo "ImageMagick extension: Available\n";
    } else {
        echo "ImageMagick extension: Not available\n";
    }
    
    // Check if we can execute image processing commands
    echo "\nChecking image processing commands...\n";
    
    $convertPath = trim(shell_exec('which convert'));
    if ($convertPath) {
        echo "ImageMagick convert: " . $convertPath . "\n";
    } else {
        echo "ImageMagick convert: Not found\n";
    }
    
    $identifyPath = trim(shell_exec('which identify'));
    if ($identifyPath) {
        echo "ImageMagick identify: " . $identifyPath . "\n";
    } else {
        echo "ImageMagick identify: Not found\n";
    }
    
    echo "\n=== Thumbnail Generation Fix Completed ===\n";
    
} catch (Exception $e) {
    echo "Error: " . $e->getMessage() . "\n";
}