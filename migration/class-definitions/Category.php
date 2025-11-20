<?php

namespace AppBundle\Model\DataObject;

use Pimcore\Model\DataObject\ClassDefinition;

class CategoryClass
{
    public static function create()
    {
        // Check if class already exists
        $class = ClassDefinition::getByName('Category');
        if (!$class) {
            $class = new ClassDefinition();
        }
        $class->setName("Category");
        $class->setDescription("Product category hierarchy");
        
        // Base fields
        $panel = new ClassDefinition\Layout\Panel();
        $panel->setName("Base");
        
        // Localized fields container
        $localizedFields = new ClassDefinition\Data\Localizedfields();
        $localizedFields->setName("localizedfields");
        $localizedFields->setTitle("Localized Fields");
        
        // Name field (localized)
        $name = new ClassDefinition\Data\Input();
        $name->setName("name");
        $name->setTitle("Category Name");
        $name->setMandatory(true);
        $localizedFields->addChild($name);
        
        // Add localized fields to panel
        $panel->addChild($localizedFields);
        
        // Parent category
        $parentCategory = new ClassDefinition\Data\ManyToOneRelation();
        $parentCategory->setName("parentCategory");
        $parentCategory->setTitle("Parent Category");
        $parentCategory->setClasses(["Category"]);
        $panel->addChild($parentCategory);
        
        // Magento ID (for sync)
        $magentoId = new ClassDefinition\Data\Numeric();
        $magentoId->setName("magentoId");
        $magentoId->setTitle("Magento Category ID");
        $panel->addChild($magentoId);
        
        // Sort order
        $sortOrder = new ClassDefinition\Data\Numeric();
        $sortOrder->setName("sortOrder");
        $sortOrder->setTitle("Sort Order");
        $panel->addChild($sortOrder);
        
        // Description
        $description = new ClassDefinition\Data\Wysiwyg();
        $description->setName("description");
        $description->setTitle("Description");
        $panel->addChild($description);
        
        // Image
        $image = new ClassDefinition\Data\Image();
        $image->setName("image");
        $image->setTitle("Category Image");
        $panel->addChild($image);
        
        $class->setLayoutDefinitions($panel);
        $class->save();
        
        return $class;
    }
}