<?php

require_once __DIR__ . '/vendor/autoload.php';

use Pimcore\Bootstrap;
use Pimcore\Model\DataObject\ClassDefinition;
use Pimcore\Model\DataObject\ClassDefinition\Service;

Bootstrap::setProjectRoot();
Bootstrap::bootstrap();

// Import class definitions
require_once __DIR__ . '/migration/class-definitions/Brand.php';
require_once __DIR__ . '/migration/class-definitions/Category.php';
require_once __DIR__ . '/migration/class-definitions/Product.php';

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

    echo "Base class structure created successfully!\n";

} catch (Exception $e) {
    echo "Error: " . $e->getMessage() . "\n";
    exit(1);
}
