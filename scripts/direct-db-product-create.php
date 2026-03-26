<?php

use Pimcore\Db;

include_once __DIR__ . '/../vendor/autoload.php';

\Pimcore\Bootstrap::setProjectRoot();
\Pimcore\Bootstrap::bootstrap();

echo "Creating product directly in database...\n";

try {
    $db = Db::get();
    
    // Check if the objects table exists
    $objectsTableExists = $db->fetchOne("SHOW TABLES LIKE 'objects'");
    if (!$objectsTableExists) {
        echo "ERROR: objects table does not exist\n";
        exit(1);
    }
    
    // Check if the object_store_PR table exists (Product class)
    $productTableExists = $db->fetchOne("SHOW TABLES LIKE 'object_store_PR'");
    if (!$productTableExists) {
        echo "ERROR: object_store_PR table does not exist\n";
        exit(1);
    }
    
    // Insert into objects table
    $key = 'test-product-' . time();
    $data = [
        'o_parentId' => 1,
        'o_type' => 'object',
        'o_key' => $key,
        'o_path' => '/',
        'o_index' => 0,
        'o_published' => 1,
        'o_creationDate' => time(),
        'o_modificationDate' => time(),
        'o_userOwner' => 1,
        'o_userModification' => 1,
        'o_classId' => 'PR', // Product class ID
        'o_className' => 'Product'
    ];
    
    $db->insert('objects', $data);
    $objectId = $db->lastInsertId();
    
    echo "Object created with ID: $objectId\n";
    
    // Insert into object_store_PR table (Product class)
    $productData = [
        'oo_id' => $objectId,
        'sku' => 'SKU-' . time()
    ];
    
    $db->insert('object_store_PR', $productData);
    
    echo "Product data stored successfully\n";
    echo "SUCCESS: Product created with ID $objectId\n";
    
} catch (Exception $e) {
    echo "Error: " . $e->getMessage() . "\n";
    echo "Trace: " . $e->getTraceAsString() . "\n";
}