<?php

require_once __DIR__ . '/../../vendor/autoload.php';

use Pimcore\Model\DataObject\ClassDefinition;
use Pimcore\Model\DataObject\ClassDefinition\Service;

// Import class definitions
require_once __DIR__ . '/../class-definitions/Product.php';
require_once __DIR__ . '/../class-definitions/Category.php';
require_once __DIR__ . '/../class-definitions/Brand.php';

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
    
    // Setup Classification Store
    echo "Setting up Classification Store...\n";
    
    // Create a group for product attributes
    $group = new \Pimcore\Model\DataObject\Classificationstore\GroupConfig();
    $group->setName('Product Attributes');
    $group->setDescription('Standard product attributes from Magento');
    $group->save();
    
    // Create a collection
    $collection = new \Pimcore\Model\DataObject\Classificationstore\CollectionConfig();
    $collection->setName('Magento Attributes');
    $collection->setDescription('Imported Magento attribute sets');
    $collection->save();
    
    // Link group to collection
    $collection->addGroup($group->getId());
    
    echo "Base class structure created successfully!\n";
    
} catch (Exception $e) {
    echo "Error: " . $e->getMessage() . "\n";
    exit(1);
}