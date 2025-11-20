<?php

namespace AppBundle\Model\DataObject;

use Pimcore\Model\DataObject\ClassDefinition;

class BrandClass
{
    public static function create()
    {
        // Check if class already exists
        $class = ClassDefinition::getByName('Brand');
        if (!$class) {
            $class = new ClassDefinition();
        }
        $class->setName("Brand");
        $class->setDescription("Brand/Manufacturer data");
        
        // Base fields
        $panel = new ClassDefinition\Layout\Panel();
        $panel->setName("Base");
        
        // Name
        $name = new ClassDefinition\Data\Input();
        $name->setName("name");
        $name->setTitle("Brand Name");
        $name->setMandatory(true);
        $panel->addChild($name);
        
        // Logo
        $logo = new ClassDefinition\Data\Image();
        $logo->setName("logo");
        $logo->setTitle("Brand Logo");
        $panel->addChild($logo);
        
        // Description
        $description = new ClassDefinition\Data\Wysiwyg();
        $description->setName("description");
        $description->setTitle("Brand Description");
        $panel->addChild($description);
        
        // Website
        $website = new ClassDefinition\Data\Input();
        $website->setName("website");
        $website->setTitle("Website URL");
        $panel->addChild($website);
        
        $class->setLayoutDefinitions($panel);
        $class->save();
        
        return $class;
    }
}