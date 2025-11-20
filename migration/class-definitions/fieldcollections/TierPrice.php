<?php

namespace AppBundle\Model\DataObject\Fieldcollection;

use Pimcore\Model\DataObject\Fieldcollection\Definition;

class TierPrice
{
    public static function create()
    {
        // Check if fieldcollection already exists
        $fc = Definition::getByKey('TierPrice');
        if (!$fc) {
            $fc = new Definition();
            $fc->setKey('TierPrice');
        }
        
        $fc->setTitle('Tier Price');
        // Field collections don't have setDescription method
        
        // Create layout panel
        $panel = new \Pimcore\Model\DataObject\ClassDefinition\Layout\Panel();
        $panel->setName('Tier Price');
        
        // Quantity
        $quantity = new \Pimcore\Model\DataObject\ClassDefinition\Data\Numeric();
        $quantity->setName('quantity');
        $quantity->setTitle('Quantity');
        $quantity->setMandatory(true);
        $quantity->setInteger(true);
        $panel->addChild($quantity);
        
        // Price
        $price = new \Pimcore\Model\DataObject\ClassDefinition\Data\Numeric();
        $price->setName('price');
        $price->setTitle('Price');
        $price->setMandatory(true);
        $price->setInteger(false);
        $price->setDecimalPrecision(2);
        $panel->addChild($price);
        
        // Customer group (optional)
        $customerGroup = new \Pimcore\Model\DataObject\ClassDefinition\Data\Input();
        $customerGroup->setName('customerGroup');
        $customerGroup->setTitle('Customer Group');
        $customerGroup->setMandatory(false);
        $panel->addChild($customerGroup);
        
        $fc->setLayoutDefinitions($panel);
        $fc->save();
        
        return $fc;
    }
}