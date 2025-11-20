<?php

require_once __DIR__ . '/../../vendor/autoload.php';

use Pimcore\Bootstrap;
use Pimcore\Model\DataObject;
use Pimcore\Model\Asset;

// Initialize Pimcore
Bootstrap::setProjectRoot();
Bootstrap::bootstrap();

echo "Checking Pimcore Database State...\n\n";

try {
    // Check Objects
    echo "Objects Status:\n";
    echo "==============\n";
    
    // Check Products
    $products = new DataObject\Listing();
    $productCount = $products->getTotalCount();
    echo "Total Products: $productCount\n";
    
    // Check Categories
    $categories = new DataObject\Category\Listing();
    $categoryCount = $categories->getTotalCount();
    echo "Total Categories: $categoryCount\n";
    
    // Check Assets
    echo "\nAssets Status:\n";
    echo "=============\n";
    $assets = new Asset\Listing();
    $assetCount = $assets->getTotalCount();
    echo "Total Assets: $assetCount\n";
    
    // Check Class Definitions
    echo "\nClass Definitions:\n";
    echo "================\n";
    $classes = DataObject\ClassDefinition\Listing::getByKey('Product', true);
    if ($classes) {
        echo "Product class is defined\n";
    }
    
    $classes = DataObject\ClassDefinition\Listing::getByKey('Category', true);
    if ($classes) {
        echo "Category class is defined\n";
    }
    
    // Check Classification Store
    echo "\nClassification Store:\n";
    echo "===================\n";
    $groups = new DataObject\Classificationstore\GroupConfig\Listing();
    $groupCount = $groups->getTotalCount();
    echo "Total attribute groups: $groupCount\n";
    
    $keys = new DataObject\Classificationstore\KeyConfig\Listing();
    $keyCount = $keys->getTotalCount();
    echo "Total attribute keys: $keyCount\n";
    
    // Sample some recent products
    if ($productCount > 0) {
        echo "\nRecent Products Sample:\n";
        echo "====================\n";
        $products->setLimit(5);
        $products->setOrderKey('o_creationDate');
        $products->setOrder('DESC');
        
        foreach ($products as $product) {
            echo sprintf(
                "- %s (SKU: %s, Created: %s)\n",
                $product->getTitle(),
                $product->getSku(),
                date('Y-m-d H:i:s', $product->getCreationDate())
            );
        }
    }
    
    // Check database connection details
    echo "\nDatabase Connection:\n";
    echo "==================\n";
    $db = \Pimcore\Db::get();
    $dbParams = $db->getParams();
    echo "Host: {$dbParams['host']}\n";
    echo "Port: {$dbParams['port']}\n";
    echo "Database: {$dbParams['dbname']}\n";
    
} catch (Exception $e) {
    echo "Error: " . $e->getMessage() . "\n";
    exit(1);
}