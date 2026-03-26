#!/usr/bin/env php
<?php

require_once __DIR__ . '/vendor/autoload.php';

use Pimcore\Bootstrap;
use Pimcore\Model\DataObject;

// Bootstrap Pimcore
Bootstrap::setProjectRoot();
Bootstrap::bootstrap();

try {
    // Create a simple product
    $product = new DataObject\Product();
    $product->setParentId(1); // Root folder
    $product->setKey('test-product-' . time());
    $product->setPublished(true);
    $product->setSku('TEST-SKU-' . time());
    $product->setTitle('Test Product', 'en');
    $product->setDescription('This is a test product', 'en');
    
    // Save the product
    $product->save();
    
    echo "Product created successfully with ID: " . $product->getId() . "\n";
} catch (Exception $e) {
    echo "Error creating product: " . $e->getMessage() . "\n";
    echo "Trace: " . $e->getTraceAsString() . "\n";
}