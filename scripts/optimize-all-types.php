<?php

// Script to optimize all data types in Pimcore

require_once __DIR__ . '/vendor/autoload.php';

use Pimcore\Bootstrap;
use Pimcore\Model\DataObject;
use Pimcore\Model\Document;
use Pimcore\Model\Asset;
use Pimcore\Tool\Console;

// Initialize Pimcore
Bootstrap::setProjectRoot();
Bootstrap::bootstrap();

echo "Starting optimization of all data types...\n";

// Optimize objects
echo "Optimizing objects...\n";
$totalObjects = DataObject::getList()->getTotalCount();
echo "Total objects found: $totalObjects\n";

$batchSize = 50;
$offset = 0;
$processedObjects = 0;

do {
    $objects = DataObject::getList([
        'limit' => $batchSize,
        'offset' => $offset
    ]);
    
    if ($objects->getCount() == 0) {
        break;
    }
    
    foreach ($objects as $object) {
        try {
            // Skip folders
            if ($object->getType() == 'folder') {
                continue;
            }
            
            // Re-save object to ensure consistency
            $object->save();
            
            $processedObjects++;
            
            if ($processedObjects % 50 == 0) {
                echo "Processed $processedObjects objects...\n";
            }
            
        } catch (Exception $e) {
            echo "Error processing object ID " . $object->getId() . ": " . $e->getMessage() . "\n";
        }
    }
    
    $offset += $batchSize;
    
} while ($objects->getCount() == $batchSize);

echo "Objects optimization completed. Processed $processedObjects objects.\n";

// Optimize documents
echo "Optimizing documents...\n";
$totalDocuments = Document::getList()->getTotalCount();
echo "Total documents found: $totalDocuments\n";

$offset = 0;
$processedDocuments = 0;

do {
    $documents = Document::getList([
        'limit' => $batchSize,
        'offset' => $offset
    ]);
    
    if ($documents->getCount() == 0) {
        break;
    }
    
    foreach ($documents as $document) {
        try {
            // Skip folders
            if ($document->getType() == 'folder') {
                continue;
            }
            
            // Re-save document to ensure consistency
            $document->save();
            
            $processedDocuments++;
            
            if ($processedDocuments % 50 == 0) {
                echo "Processed $processedDocuments documents...\n";
            }
            
        } catch (Exception $e) {
            echo "Error processing document ID " . $document->getId() . ": " . $e->getMessage() . "\n";
        }
    }
    
    $offset += $batchSize;
    
} while ($documents->getCount() == $batchSize);

echo "Documents optimization completed. Processed $processedDocuments documents.\n";

// Optimize assets (simplified version)
echo "Optimizing assets...\n";
$totalAssets = Asset::getList()->getTotalCount();
echo "Total assets found: $totalAssets\n";

$offset = 0;
$processedAssets = 0;

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
            
            // Re-save asset to ensure consistency
            $asset->save();
            
            $processedAssets++;
            
            if ($processedAssets % 50 == 0) {
                echo "Processed $processedAssets assets...\n";
            }
            
        } catch (Exception $e) {
            echo "Error processing asset ID " . $asset->getId() . ": " . $e->getMessage() . "\n";
        }
    }
    
    $offset += $batchSize;
    
} while ($assets->getCount() == $batchSize);

echo "Assets optimization completed. Processed $processedAssets assets.\n";

// Run maintenance tasks
echo "Running maintenance tasks...\n";
Console::runPhpScript('bin/console', ['pimcore:maintenance', '--job=optimizeImageThumbnails']);
Console::runPhpScript('bin/console', ['pimcore:maintenance', '--job=cleanupTmpFiles']);
Console::runPhpScript('bin/console', ['pimcore:maintenance', '--job=cleanupCache']);
Console::runPhpScript('bin/console', ['pimcore:maintenance', '--job=scheduledtasks']);

echo "All maintenance tasks completed.\n";
echo "Optimization of all data types completed successfully!\n";