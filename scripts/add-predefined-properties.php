<?php

// Script to add predefined properties to Pimcore

require_once __DIR__ . '/vendor/autoload.php';

use Pimcore\Bootstrap;
use Pimcore\Model\Property\Predefined;

// Initialize Pimcore
Bootstrap::setProjectRoot();
Bootstrap::bootstrap();

// Create predefined properties
$properties = [
    [
        'name' => 'title',
        'description' => 'SEO Title',
        'key' => 'title',
        'type' => 'input',
        'data' => '',
        'config' => '',
        'ctype' => 'document',
        'inheritable' => true,
        'locked' => false
    ],
    [
        'name' => 'description',
        'description' => 'SEO Description',
        'key' => 'description',
        'type' => 'textarea',
        'data' => '',
        'config' => '',
        'ctype' => 'document',
        'inheritable' => true,
        'locked' => false
    ],
    [
        'name' => 'keywords',
        'description' => 'SEO Keywords',
        'key' => 'keywords',
        'type' => 'input',
        'data' => '',
        'config' => '',
        'ctype' => 'document',
        'inheritable' => true,
        'locked' => false
    ],
    [
        'name' => 'canonicalUrl',
        'description' => 'Canonical URL',
        'key' => 'canonicalUrl',
        'type' => 'input',
        'data' => '',
        'config' => '',
        'ctype' => 'document',
        'inheritable' => true,
        'locked' => false
    ],
    [
        'name' => 'ogTitle',
        'description' => 'Open Graph Title',
        'key' => 'ogTitle',
        'type' => 'input',
        'data' => '',
        'config' => '',
        'ctype' => 'document',
        'inheritable' => true,
        'locked' => false
    ],
    [
        'name' => 'ogDescription',
        'description' => 'Open Graph Description',
        'key' => 'ogDescription',
        'type' => 'textarea',
        'data' => '',
        'config' => '',
        'ctype' => 'document',
        'inheritable' => true,
        'locked' => false
    ],
    [
        'name' => 'ogImage',
        'description' => 'Open Graph Image',
        'key' => 'ogImage',
        'type' => 'asset',
        'data' => '',
        'config' => '',
        'ctype' => 'document',
        'inheritable' => true,
        'locked' => false
    ]
];

echo "Adding predefined properties...\n";

foreach ($properties as $propertyData) {
    // Check if property already exists
    $existingProperty = Predefined::getByKey($propertyData['key']);
    
    if ($existingProperty) {
        echo "Property '{$propertyData['key']}' already exists, skipping...\n";
        continue;
    }
    
    // Create new property
    $property = new Predefined();
    $property->setName($propertyData['name']);
    $property->setDescription($propertyData['description']);
    $property->setKey($propertyData['key']);
    $property->setType($propertyData['type']);
    $property->setData($propertyData['data']);
    $property->setConfig($propertyData['config']);
    $property->setCtype($propertyData['ctype']);
    $property->setInheritable($propertyData['inheritable']);
    $property->setLocked($propertyData['locked']);
    
    try {
        $property->save();
        echo "Property '{$propertyData['key']}' added successfully.\n";
    } catch (Exception $e) {
        echo "Error adding property '{$propertyData['key']}': " . $e->getMessage() . "\n";
    }
}

echo "Predefined properties setup completed.\n";