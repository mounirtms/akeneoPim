<?php

use Pimcore\Model\DataObject\ClassDefinition;

// Import class definitions
require_once __DIR__ . '/migration/class-definitions/Product.php';
require_once __DIR__ . '/migration/class-definitions/Category.php';
require_once __DIR__ . '/migration/class-definitions/Brand.php';

// Import field collections
require_once __DIR__ . '/migration/class-definitions/fieldcollections/ProductSpecifications.php';
require_once __DIR__ . '/migration/class-definitions/fieldcollections/TierPrice.php';

// Import object bricks
require_once __DIR__ . '/migration/class-definitions/objectbricks/SeoMetadata.php';
require_once __DIR__ . '/migration/class-definitions/objectbricks/ProductPricing.php';

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
    
    // Create field collections
    echo "Creating ProductSpecifications field collection... ";
    \AppBundle\Model\DataObject\Fieldcollection\ProductSpecifications::create();
    echo "Done\n";
    
    echo "Creating TierPrice field collection... ";
    \AppBundle\Model\DataObject\Fieldcollection\TierPrice::create();
    echo "Done\n";
    
    // Create object bricks
    echo "Creating SeoMetadata object brick... ";
    \AppBundle\Model\DataObject\Objectbrick\SeoMetadata::create();
    echo "Done\n";
    
    echo "Creating ProductPricing object brick... ";
    \AppBundle\Model\DataObject\Objectbrick\ProductPricing::create();
    echo "Done\n";
    
    echo "All class definitions created successfully!\n";
    
} catch (Exception $e) {
    echo "Error: " . $e->getMessage() . "\n";
    exit(1);
}