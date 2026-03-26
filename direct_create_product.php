<?php

use Pimcore\Bootstrap;
use Pimcore\Model\DataObject;

// Set the project root before bootstrapping
Bootstrap::setProjectRoot();

// Bootstrap Pimcore
Bootstrap::bootstrap();

include_once __DIR__ . '/vendor/autoload.php';

echo "Starting product creation...\n";

// Check if Product class exists
if (!class_exists(DataObject\Product::class)) {
    echo "ERROR: Product class does not exist!\n";
    exit(1);
}

try {
    echo "Creating product instance...\n";
    // Try to create a simple product
    $product = new DataObject\Product();
    echo "Setting product properties...\n";
    $product->setParentId(1); // Root folder
    $product->setKey('test-product-' . time());
    $product->setPublished(true);
    $product->setSku('TEST-SKU-' . time());
    
    echo "Saving product...\n";
    // Save the product
    $product->save();
    
    echo "SUCCESS: Product created successfully with ID: " . $product->getId() . "\n";
} catch (Exception $e) {
    echo "ERROR: Error creating product: " . $e->getMessage() . "\n";
    echo "Trace: " . $e->getTraceAsString() . "\n";
    exit(1);
}