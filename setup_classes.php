#!/usr/bin/env php
<?php

require_once __DIR__ . '/vendor/autoload.php';
require_once __DIR__ . '/config/bootstrap.php';

use Pimcore\Bootstrap;
use Pimcore\Model\DataObject\ClassDefinition;

// Initialize Pimcore
Bootstrap::setProjectRoot();
Bootstrap::bootstrap();

// Import class definitions
require_once __DIR__ . '/migration/class-definitions/Product.php';
require_once __DIR__ . '/migration/class-definitions/Category.php';
require_once __DIR__ . '/migration/class-definitions/Brand.php';

echo "Creating Pimcore class definitions...\n";

try {
    // Create Brand class first (since it's referenced by Product)
    echo "Creating Brand class... ";
    \AppBundle\Model\DataObject\BrandClass::create();
    echo "Done\n";
    
    // Create Category class
    echo "Creating Category class... ";
    \AppBundle\Model\DataObject\CategoryClass::create();
    echo "Done\n";
    
    // Create Product class
    echo "Creating Product class... ";
    \AppBundle\Model\DataObject\ProductClass::create();
    echo "Done\n";
    
    echo "All class definitions created successfully!\n";
    
} catch (Exception $e) {
    echo "Error: " . $e->getMessage() . "\n";
    exit(1);
}