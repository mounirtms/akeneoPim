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
    $product->setKey('test-product-cli-' . time());
    $product->setPublished(true);
    $product->setSku('SKU-CLI-' . time());
    $product->setTitle('Test Product CLI', 'en');
    $product->setDescription('This is a test product created via CLI', 'en');
    
    // Save the product
    $product->save();
    
    echo "SUCCESS: Product created successfully with ID: " . $product->getId() . "\n";
} catch (Exception $e) {
    echo "ERROR: Failed to create product\n";
    echo "Message: " . $e->getMessage() . "\n";
    echo "Trace: " . $e->getTraceAsString() . "\n";
}