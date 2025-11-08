<?php

// Script to optimize assets in Pimcore

require_once __DIR__ . '/vendor/autoload.php';

use Pimcore\Bootstrap;
use Pimcore\Model\Asset;
use Pimcore\Model\Asset\Image;
use Pimcore\Tool\Console;

// Initialize Pimcore
Bootstrap::setProjectRoot();
Bootstrap::bootstrap();

echo "Starting asset optimization...\n";

// Get total asset count
$totalAssets = Asset::getList()->getTotalCount();
echo "Total assets found: $totalAssets\n";

// Process assets in batches to avoid memory issues
$batchSize = 50;
$offset = 0;
$processed = 0;

do {
    $assets = Asset::getList([
        'limit' => $batchSize,
        'offset' => $offset
    ]);
    
    if ($assets->getCount() == 0) {
        break;
    }
    
    foreach ($assets as $asset) {
        try {
            // Skip folders
            if ($asset->getType() == 'folder') {
                continue;
            }
            
            // Regenerate thumbnails for images
            if ($asset instanceof Image) {
                echo "Processing image: " . $asset->getFullPath() . "\n";
                
                // Clear existing thumbnails
                $asset->clearThumbnails(true);
                
                // Generate new thumbnails
                $asset->getThumbnail('content');
                $asset->getThumbnail('preview');
                $asset->getThumbnail('gallery');
            }
            
            // Update asset metadata
            $asset->save();
            
            $processed++;
            
            if ($processed % 10 == 0) {
                echo "Processed $processed assets...\n";
            }
            
        } catch (Exception $e) {
            echo "Error processing asset ID " . $asset->getId() . ": " . $e->getMessage() . "\n";
        }
    }
    
    $offset += $batchSize;
    
} while ($assets->getCount() == $batchSize);

echo "Asset optimization completed. Processed $processed assets.\n";

// Run maintenance tasks
echo "Running maintenance tasks...\n";
Console::runPhpScript('bin/console', ['pimcore:maintenance', '--job=optimizeImageThumbnails']);
Console::runPhpScript('bin/console', ['pimcore:maintenance', '--job=cleanupTmpFiles']);

echo "Maintenance tasks completed.\n";