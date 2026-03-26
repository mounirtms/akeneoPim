<?php

use Pimcore\Model\DataObject\Product;

include_once __DIR__ . '/../vendor/autoload.php';

\Pimcore\Bootstrap::setProjectRoot();
\Pimcore\Bootstrap::bootstrap();

try {
    echo "Creating product via console script...\n";
    
    // Create a new product
    $product = new Product();
    $product->setParentId(1);
    $product->setKey('console-product-' . time());
    $product->setPublished(true);
    $product->setSku('CONSOLE-SKU-' . time());
    $product->setTitle('Console Product', 'en');
    $product->setDescription('Product created via console script', 'en');
    
    echo "Saving product...\n";
    $product->save();
    
    echo "SUCCESS: Product created with ID " . $product->getId() . "\n";
    
} catch (Exception $e) {
    echo "ERROR: " . $e->getMessage() . "\n";
    echo "Trace: " . $e->getTraceAsString() . "\n";
}