#!/usr/bin/env php
<?php

use Pimcore\Bootstrap;
use Pimcore\Model\DataObject\Product;

include_once __DIR__ . '/vendor/autoload.php';

Bootstrap::setProjectRoot();
Bootstrap::bootstrap();

echo "Starting robust product creation test...\n";

try {
    echo "Checking if Product class exists...\n";
    if (!class_exists(Product::class)) {
        echo "ERROR: Product class does not exist\n";
        exit(1);
    }
    
    echo "Product class exists. Creating product...\n";
    
    // Create a new product
    $product = new Product();
    $product->setParentId(1); // Root folder
    $product->setKey('robust-test-product-' . time());
    $product->setPublished(true);
    $product->setSku('ROBUST-SKU-' . time());
    $product->setTitle('Robust Test Product', 'en');
    $product->setDescription('This is a test product created via robust script', 'en');
    
    echo "Saving product...\n";
    $product->save();
    
    echo "SUCCESS: Product created with ID " . $product->getId() . "\n";
    
} catch (Exception $e) {
    echo "ERROR: " . $e->getMessage() . "\n";
    echo "File: " . $e->getFile() . " (Line: " . $e->getLine() . ")\n";
    echo "Trace:\n" . $e->getTraceAsString() . "\n";
}