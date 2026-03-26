<?php

use Pimcore\Model\DataObject\Product;

include_once __DIR__ . '/../vendor/autoload.php';

\Pimcore\Bootstrap::setProjectRoot();
\Pimcore\Bootstrap::bootstrap();

try {
    echo "Creating a simple product...\n";
    
    // Create a new product
    $product = new Product();
    $product->setParentId(1); // Root folder
    $product->setKey('test-product-' . time());
    $product->setPublished(true);
    $product->setSku('SKU-' . time());
    
    // Save the product
    $product->save();
    
    echo "Product created successfully with ID: " . $product->getId() . "\n";
} catch (Exception $e) {
    echo "Error creating product: " . $e->getMessage() . "\n";
    echo "Trace: " . $e->getTraceAsString() . "\n";
}