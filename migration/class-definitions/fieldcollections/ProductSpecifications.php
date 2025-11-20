<?php

namespace AppBundle\Model\DataObject\Fieldcollection;

use Pimcore\Model\DataObject\Fieldcollection\Definition;

class ProductSpecifications
{
    public static function create()
    {
        // Check if fieldcollection already exists
        $fc = Definition::getByKey('ProductSpecifications');
        if (!$fc) {
            $fc = new Definition();
            $fc->setKey('ProductSpecifications');
        }
        
        $fc->setTitle('Product Specifications');
        // Field collections don't have setDescription method
        
        // Create layout panel
        $panel = new \Pimcore\Model\DataObject\ClassDefinition\Layout\Panel();
        $panel->setName('Product Specifications');
        
        // Specification name
        $specName = new \Pimcore\Model\DataObject\ClassDefinition\Data\Input();
        $specName->setName('specName');
        $specName->setTitle('Specification Name');
        $specName->setMandatory(true);
        $panel->addChild($specName);
        
        // Specification value
        $specValue = new \Pimcore\Model\DataObject\ClassDefinition\Data\Input();
        $specValue->setName('specValue');
        $specValue->setTitle('Specification Value');
        $specValue->setMandatory(true);
        $panel->addChild($specValue);
        
        // Measurement unit
        $unit = new \Pimcore\Model\DataObject\ClassDefinition\Data\Input();
        $unit->setName('unit');
        $unit->setTitle('Unit');
        $panel->addChild($unit);
        
        $fc->setLayoutDefinitions($panel);
        $fc->save();
        
        return $fc;
    }
}