<?php

use Pimcore\Model\DataObject\Classificationstore;

echo "Setting up classification store for product attributes...\n";

try {
    // Create a default store
    $store = Classificationstore\StoreConfig::getByName('Default');
    if (!$store) {
        $store = new Classificationstore\StoreConfig();
        $store->setName('Default');
        $store->setDescription('Default classification store');
        $store->save();
        echo "Created Default store\n";
    }
    
    // Create groups for different attribute categories
    $generalGroup = Classificationstore\GroupConfig::getByName('General');
    if (!$generalGroup) {
        $generalGroup = new Classificationstore\GroupConfig();
        $generalGroup->setName('General');
        $generalGroup->setDescription('General product attributes');
        $generalGroup->setStoreId($store->getId());
        $generalGroup->save();
        echo "Created General group\n";
    }
    
    $technicalGroup = Classificationstore\GroupConfig::getByName('Technical');
    if (!$technicalGroup) {
        $technicalGroup = new Classificationstore\GroupConfig();
        $technicalGroup->setName('Technical');
        $technicalGroup->setDescription('Technical product attributes');
        $technicalGroup->setStoreId($store->getId());
        $technicalGroup->save();
        echo "Created Technical group\n";
    }
    
    $marketingGroup = Classificationstore\GroupConfig::getByName('Marketing');
    if (!$marketingGroup) {
        $marketingGroup = new Classificationstore\GroupConfig();
        $marketingGroup->setName('Marketing');
        $marketingGroup->setDescription('Marketing-related attributes');
        $marketingGroup->setStoreId($store->getId());
        $marketingGroup->save();
        echo "Created Marketing group\n";
    }
    
    // Create some key definitions
    // Color attribute
    $colorKey = Classificationstore\KeyConfig::getByName('color');
    if (!$colorKey) {
        $colorKey = new Classificationstore\KeyConfig();
        $colorKey->setName('color');
        $colorKey->setDescription('Product color');
        $colorKey->setEnabled(true);
        $colorKey->setType('input');
        $colorKey->setDefinition(json_encode([
            'name' => 'color',
            'title' => 'Color',
            'fieldtype' => 'input'
        ]));
        $colorKey->setStoreId($store->getId());
        $colorKey->save();
        
        // Add to groups
        $relation = new Classificationstore\KeyGroupRelation();
        $relation->setKeyId($colorKey->getId());
        $relation->setGroupId($generalGroup->getId());
        $relation->setSorter(1);
        $relation->setMandatory(false);
        $relation->save();
        echo "Created color attribute\n";
    }
    
    // Size attribute
    $sizeKey = Classificationstore\KeyConfig::getByName('size');
    if (!$sizeKey) {
        $sizeKey = new Classificationstore\KeyConfig();
        $sizeKey->setName('size');
        $sizeKey->setDescription('Product size');
        $sizeKey->setEnabled(true);
        $sizeKey->setType('input');
        $sizeKey->setDefinition(json_encode([
            'name' => 'size',
            'title' => 'Size',
            'fieldtype' => 'input'
        ]));
        $sizeKey->setStoreId($store->getId());
        $sizeKey->save();
        
        // Add to groups
        $relation = new Classificationstore\KeyGroupRelation();
        $relation->setKeyId($sizeKey->getId());
        $relation->setGroupId($generalGroup->getId());
        $relation->setSorter(2);
        $relation->setMandatory(false);
        $relation->save();
        echo "Created size attribute\n";
    }
    
    // Material attribute
    $materialKey = Classificationstore\KeyConfig::getByName('material');
    if (!$materialKey) {
        $materialKey = new Classificationstore\KeyConfig();
        $materialKey->setName('material');
        $materialKey->setDescription('Product material');
        $materialKey->setEnabled(true);
        $materialKey->setType('input');
        $materialKey->setDefinition(json_encode([
            'name' => 'material',
            'title' => 'Material',
            'fieldtype' => 'input'
        ]));
        $materialKey->setStoreId($store->getId());
        $materialKey->save();
        
        // Add to groups
        $relation = new Classificationstore\KeyGroupRelation();
        $relation->setKeyId($materialKey->getId());
        $relation->setGroupId($technicalGroup->getId());
        $relation->setSorter(1);
        $relation->setMandatory(false);
        $relation->save();
        echo "Created material attribute\n";
    }
    
    echo "Classification store setup completed successfully!\n";
    
} catch (Exception $e) {
    echo "Error setting up classification store: " . $e->getMessage() . "\n";
    exit(1);
}