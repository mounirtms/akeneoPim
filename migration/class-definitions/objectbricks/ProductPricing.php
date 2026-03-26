<?php

namespace AppBundle\Model\DataObject\Objectbrick;

use Pimcore\Model\DataObject\Objectbrick\Definition;

class ProductPricing
{
    public static function create()
    {
        // Check if objectbrick already exists
        $ob = Definition::getByKey('ProductPricing');
        if (!$ob) {
            $ob = new Definition();
            $ob->setKey('ProductPricing');
        }
        
        $ob->setTitle('Product Pricing');
        // Object bricks don't have setDescription method
        $ob->setParentClass('');
        
        // Set which classes can use this brick
        $ob->setClassDefinitions([
            [
                'classname' => 'Product',
                'fieldname' => 'localizedfields'
            ]
        ]);
        
        // Create layout panel
        $panel = new \Pimcore\Model\DataObject\ClassDefinition\Layout\Panel();
        $panel->setName('Product Pricing');
        
        // Base price
        $basePrice = new \Pimcore\Model\DataObject\ClassDefinition\Data\Numeric();
        $basePrice->setName('basePrice');
        $basePrice->setTitle('Base Price');
        $basePrice->setMandatory(true);
        $basePrice->setInteger(false);
        $basePrice->setDecimalPrecision(2);
        $panel->addChild($basePrice);
        
        // Special price
        $specialPrice = new \Pimcore\Model\DataObject\ClassDefinition\Data\Numeric();
        $specialPrice->setName('specialPrice');
        $specialPrice->setTitle('Special Price');
        $specialPrice->setMandatory(false);
        $specialPrice->setInteger(false);
        $specialPrice->setDecimalPrecision(2);
        $panel->addChild($specialPrice);
        
        // Special price from date
        $specialPriceFrom = new \Pimcore\Model\DataObject\ClassDefinition\Data\Datetime();
        $specialPriceFrom->setName('specialPriceFrom');
        $specialPriceFrom->setTitle('Special Price From');
        $specialPriceFrom->setMandatory(false);
        $panel->addChild($specialPriceFrom);
        
        // Special price to date
        $specialPriceTo = new \Pimcore\Model\DataObject\ClassDefinition\Data\Datetime();
        $specialPriceTo->setName('specialPriceTo');
        $specialPriceTo->setTitle('Special Price To');
        $specialPriceTo->setMandatory(false);
        $panel->addChild($specialPriceTo);
        
        // Cost
        $cost = new \Pimcore\Model\DataObject\ClassDefinition\Data\Numeric();
        $cost->setName('cost');
        $cost->setTitle('Cost');
        $cost->setMandatory(false);
        $cost->setInteger(false);
        $cost->setDecimalPrecision(2);
        $panel->addChild($cost);
        
        // Tier prices (as a field collection)
        $tierPrices = new \Pimcore\Model\DataObject\ClassDefinition\Data\Fieldcollections();
        $tierPrices->setName('tierPrices');
        $tierPrices->setTitle('Tier Prices');
        $tierPrices->setAllowedTypes(['TierPrice']);
        $panel->addChild($tierPrices);
        
        $ob->setLayoutDefinitions($panel);
        $ob->save();
        
        return $ob;
    }
}