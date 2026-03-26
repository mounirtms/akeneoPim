<?php

use Pimcore\Db;

include_once __DIR__ . '/vendor/autoload.php';

\Pimcore\Bootstrap::setProjectRoot();
\Pimcore\Bootstrap::bootstrap();

try {
    echo "Creating product directly in database...\n";
    
    $db = Db::get();
    
    // Insert into objects table
    $key = 'db-product-' . time();
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
        'o_classId' => 'PR',
        'o_className' => 'Product'
    ];
    
    echo "Inserting into objects table...\n";
    $db->insert('objects', $data);
    $objectId = $db->lastInsertId();
    
    echo "Object created with ID: $objectId\n";
    
    // Insert into object_store_PR table
    $productData = [
        'oo_id' => $objectId,
        'sku' => 'DB-SKU-' . time()
    ];
    
    echo "Inserting into object_store_PR table...\n";
    $db->insert('object_store_PR', $productData);
    
    echo "SUCCESS: Product created with ID $objectId\n";
    
} catch (Exception $e) {
    echo "ERROR: " . $e->getMessage() . "\n";
    echo "Trace: " . $e->getTraceAsString() . "\n";
}