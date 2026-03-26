<?php

namespace AppBundle\Model\DataObject\Objectbrick;

use Pimcore\Model\DataObject\Objectbrick\Definition;

class SeoMetadata
{
    public static function create()
    {
        // Check if objectbrick already exists
        $ob = Definition::getByKey('SeoMetadata');
        if (!$ob) {
            $ob = new Definition();
            $ob->setKey('SeoMetadata');
        }
        
        $ob->setTitle('SEO Metadata');
        // Object bricks don't have setDescription method
        $ob->setParentClass('');
        
        // Set which classes can use this brick
        $ob->setClassDefinitions([
            [
                'classname' => 'Product',
                'fieldname' => 'localizedfields'
            ],
            [
                'classname' => 'Category',
                'fieldname' => 'localizedfields'
            ]
        ]);
        
        // Create layout panel
        $panel = new \Pimcore\Model\DataObject\ClassDefinition\Layout\Panel();
        $panel->setName('SEO Metadata');
        
        // Meta title
        $metaTitle = new \Pimcore\Model\DataObject\ClassDefinition\Data\Input();
        $metaTitle->setName('metaTitle');
        $metaTitle->setTitle('Meta Title');
        $metaTitle->setMandatory(false);
        $panel->addChild($metaTitle);
        
        // Meta description
        $metaDescription = new \Pimcore\Model\DataObject\ClassDefinition\Data\Textarea();
        $metaDescription->setName('metaDescription');
        $metaDescription->setTitle('Meta Description');
        $metaDescription->setMandatory(false);
        $metaDescription->setHeight(100);
        $panel->addChild($metaDescription);
        
        // Meta keywords
        $metaKeywords = new \Pimcore\Model\DataObject\ClassDefinition\Data\Input();
        $metaKeywords->setName('metaKeywords');
        $metaKeywords->setTitle('Meta Keywords');
        $metaKeywords->setMandatory(false);
        $panel->addChild($metaKeywords);
        
        // Open Graph image
        $ogImage = new \Pimcore\Model\DataObject\ClassDefinition\Data\Image();
        $ogImage->setName('ogImage');
        $ogImage->setTitle('Open Graph Image');
        $ogImage->setMandatory(false);
        $panel->addChild($ogImage);
        
        $ob->setLayoutDefinitions($panel);
        $ob->save();
        
        return $ob;
    }
}