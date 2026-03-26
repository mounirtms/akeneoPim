<?php

use Pimcore\Model\DataObject\ClassDefinition;
use Pimcore\Model\DataObject\Fieldcollection\Definition as FieldCollectionDefinition;
use Pimcore\Model\DataObject\Objectbrick\Definition as ObjectBrickDefinition;

// Bootstrap Pimcore
include_once __DIR__ . '/vendor/autoload.php';
\Pimcore\Bootstrap::startupCli();

echo "Setting up complete product structure...\n";

try {
    // Setup Classification Store
    echo "Setting up Classification Store...\n";
    
    // Create Classification Store Group
    $group = \Pimcore\Model\DataObject\Classificationstore\GroupConfig::getByName('Default');
    if (!$group) {
        $group = new \Pimcore\Model\DataObject\Classificationstore\GroupConfig();
        $group->setName('Default');
        $group->setDescription('Default Attribute Group');
        $group->save();
    }
    
    // Create Classification Store Key for Color
    $colorKey = \Pimcore\Model\DataObject\Classificationstore\KeyConfig::getByName('color', $group->getId());
    if (!$colorKey) {
        $colorKey = new \Pimcore\Model\DataObject\Classificationstore\KeyConfig();
        $colorKey->setName('color');
        $colorKey->setDescription('Color attribute');
        $colorKey->setType('input');
        $colorKey->setDefinition(json_encode([
            'name' => 'color',
            'title' => 'Color',
            'mandatory' => false,
            'type' => 'input'
        ]));
        $colorKey->setStoreId(1);
        $colorKey->save();
        
        // Add key to group
        $keyGroupRelation = new \Pimcore\Model\DataObject\Classificationstore\KeyGroupRelation();
        $keyGroupRelation->setKeyId($colorKey->getId());
        $keyGroupRelation->setGroupId($group->getId());
        $keyGroupRelation->setSorter(1);
        $keyGroupRelation->save();
    }
    
    // Create Classification Store Key for Size
    $sizeKey = \Pimcore\Model\DataObject\Classificationstore\KeyConfig::getByName('size', $group->getId());
    if (!$sizeKey) {
        $sizeKey = new \Pimcore\Model\DataObject\Classificationstore\KeyConfig();
        $sizeKey->setName('size');
        $sizeKey->setDescription('Size attribute');
        $sizeKey->setType('input');
        $sizeKey->setDefinition(json_encode([
            'name' => 'size',
            'title' => 'Size',
            'mandatory' => false,
            'type' => 'input'
        ]));
        $sizeKey->setStoreId(1);
        $sizeKey->save();
        
        // Add key to group
        $keyGroupRelation = new \Pimcore\Model\DataObject\Classificationstore\KeyGroupRelation();
        $keyGroupRelation->setKeyId($sizeKey->getId());
        $keyGroupRelation->setGroupId($group->getId());
        $keyGroupRelation->setSorter(2);
        $keyGroupRelation->save();
    }
    
    echo "Classification Store configured.\n";
    
    // Setup Field Collections
    echo "Setting up Field Collections...\n";
    
    // Product Specifications
    include_once __DIR__ . '/migration/class-definitions/fieldcollections/ProductSpecifications.php';
    \AppBundle\Model\DataObject\Fieldcollection\ProductSpecifications::create();
    
    // Tier Price
    include_once __DIR__ . '/migration/class-definitions/fieldcollections/TierPrice.php';
    \AppBundle\Model\DataObject\Fieldcollection\TierPrice::create();
    
    echo "Field Collections created.\n";
    
    // Setup Object Bricks
    echo "Setting up Object Bricks...\n";
    
    // Product Pricing
    include_once __DIR__ . '/migration/class-definitions/objectbricks/ProductPricing.php';
    \AppBundle\Model\DataObject\Objectbrick\ProductPricing::create();
    
    // SEO Metadata
    include_once __DIR__ . '/migration/class-definitions/objectbricks/SeoMetadata.php';
    \AppBundle\Model\DataObject\Objectbrick\SeoMetadata::create();
    
    echo "Object Bricks created.\n";
    
    // Setup Classes
    echo "Setting up Classes...\n";
    
    // Brand
    include_once __DIR__ . '/migration/class-definitions/Brand.php';
    \AppBundle\Model\DataObject\BrandClass::create();
    
    // Category
    include_once __DIR__ . '/migration/class-definitions/Category.php';
    \AppBundle\Model\DataObject\CategoryClass::create();
    
    // Product
    include_once __DIR__ . '/migration/class-definitions/Product.php';
    \AppBundle\Model\DataObject\ProductClass::create();
    
    echo "Classes created.\n";
    
    // Rebuild classes
    echo "Rebuilding classes...\n";
    $script = new \Pimcore\Bundle\CoreBundle\Command\ClassesRebuildCommand();
    $input = new \Symfony\Component\Console\Input\ArrayInput(['--create-classes' => true]);
    $output = new \Symfony\Component\Console\Output\BufferedOutput();
    $script->run($input, $output);
    
    echo "Class structure rebuilt successfully.\n";
    
    // Activate DataHub configuration
    echo "Activating DataHub configuration...\n";
    $db = \Pimcore\Db::get();
    $db->executeQuery("UPDATE datahub_configurations SET active = 1 WHERE name = 'products'");
    
    echo "Setup completed successfully!\n";
    echo "Please run the following commands to finalize:\n";
    echo "1. bin/console cache:clear\n";
    echo "2. bin/console assets:install\n";
    echo "3. Restart your webserver\n";
    
} catch (\Exception $e) {
    echo "Error during setup: " . $e->getMessage() . "\n";
    echo $e->getTraceAsString() . "\n";
}