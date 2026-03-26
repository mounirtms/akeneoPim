<?php

use Pimcore\Bootstrap;
use Pimcore\Model\DataObject\ClassDefinition;

include_once __DIR__ . '/vendor/autoload.php';

Bootstrap::setProjectRoot();
Bootstrap::bootstrap();

echo "Listing available classes...\n";

try {
    $list = new ClassDefinition\Listing();
    $classes = $list->load();
    
    echo "Found " . count($classes) . " classes:\n";
    
    foreach ($classes as $class) {
        echo "- " . $class->getName() . " (ID: " . $class->getId() . ")\n";
    }
    
    echo "Done.\n";
    
} catch (Exception $e) {
    echo "ERROR: " . $e->getMessage() . "\n";
}