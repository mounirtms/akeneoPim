#!/usr/bin/env php
<?php

/**
 * Script to update a product in Pimcore and synchronize the changes to Magento
 * 
 * This script will:
 * 1. Find a product in Pimcore by SKU
 * 2. Update some of its attributes
 * 3. Trigger synchronization to Magento
 */

// Bootstrap Pimcore properly
include_once __DIR__ . '/../../vendor/autoload.php';

\Pimcore\Bootstrap::setProjectRoot();
\Pimcore\Bootstrap::bootstrap();

// Initialize kernel
$kernel = \Pimcore\Bootstrap::kernel();
$app = new \Pimcore\Console\Application($kernel);
$app->setAutoExit(false);

echo "=== Pimcore Product Update and Magento Sync Tool ===\n\n";

// Get SKU from command line argument or prompt user
$sku = $argv[1] ?? null;
if (!$sku) {
    echo "Enter a product SKU to update: ";
    $sku = trim(fgets(STDIN));
}

if (!$sku) {
    die("No SKU provided. Exiting.\n");
}

echo "Looking for product with SKU: $sku\n";

try {
    // Find the product in Pimcore
    $db = \Pimcore\Db::get();
    
    // Check if product exists
    $query = "SELECT oo_id FROM object_query_Product WHERE sku = ?";
    $productId = $db->fetchOne($query, [$sku]);
    
    if (!$productId) {
        die("Product with SKU '$sku' not found in Pimcore.\n");
    }
    
    echo "Found product with ID: $productId\n";
    
    // Update product attributes directly in database
    $updateQuery = "
        UPDATE object_query_Product 
        SET name = ?, description = ?, shortDescription = ?, price = ?, status = ? 
        WHERE sku = ?
    ";
    
    $newName = "Updated Product Name - " . date('Y-m-d H:i:s');
    $newDescription = "This is an updated product description with detailed information.";
    $newShortDescription = "Updated short description.";
    $newPrice = rand(10, 100);
    $newStatus = 'published';
    
    $stmt = $db->prepare($updateQuery);
    $stmt->execute([
        $newName,
        $newDescription,
        $newShortDescription,
        $newPrice,
        $newStatus,
        $sku
    ]);
    
    echo "Updated product in Pimcore:\n";
    echo "- Name: $newName\n";
    echo "- Description: $newDescription\n";
    echo "- Short Description: $newShortDescription\n";
    echo "- Price: $newPrice\n";
    echo "- Status: $newStatus\n\n";
    
    // Now synchronize to Magento
    echo "Synchronizing to Magento...\n";
    
    // Magento database connection parameters
    $magentoConfig = [
        'host' => '127.0.0.1',
        'port' => '3307',
        'dbname' => 'beta_dBT8x12y22',
        'username' => 'root',
        'password' => 'YourNewStrongPassword'
    ];
    
    $magentoDsn = "mysql:host={$magentoConfig['host']};port={$magentoConfig['port']};dbname={$magentoConfig['dbname']}";
    $magentoDb = new PDO($magentoDsn, $magentoConfig['username'], $magentoConfig['password']);
    $magentoDb->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    
    // Check if product exists in Magento
    $stmt = $magentoDb->prepare("SELECT entity_id FROM catalog_product_entity WHERE sku = ?");
    $stmt->execute([$sku]);
    $magentoProduct = $stmt->fetch();
    
    if ($magentoProduct) {
        // Update existing product in Magento
        $entityId = $magentoProduct['entity_id'];
        
        echo "Updating existing product in Magento (Entity ID: $entityId)\n";
        
        // Update main product record
        $stmt = $magentoDb->prepare("
            UPDATE catalog_product_entity 
            SET updated_at = NOW() 
            WHERE entity_id = ?
        ");
        $stmt->execute([$entityId]);
        
        // Update attributes
        updateMagentoAttribute($magentoDb, $entityId, 'name', $newName, 'varchar');
        updateMagentoAttribute($magentoDb, $entityId, 'description', $newDescription, 'text');
        updateMagentoAttribute($magentoDb, $entityId, 'short_description', $newShortDescription, 'text');
        updateMagentoAttribute($magentoDb, $entityId, 'price', $newPrice, 'decimal');
        updateMagentoAttribute($magentoDb, $entityId, 'status', ($newStatus === 'published') ? 1 : 2, 'int');
        
        echo "Product updated successfully in Magento!\n";
    } else {
        // Create new product in Magento
        echo "Creating new product in Magento\n";
        
        $stmt = $magentoDb->prepare("
            INSERT INTO catalog_product_entity 
            (attribute_set_id, type_id, sku, has_options, required_options, created_at, updated_at) 
            VALUES (?, ?, ?, ?, ?, NOW(), NOW())
        ");
        $stmt->execute([4, 'simple', $sku, 0, 0]);
        $entityId = $magentoDb->lastInsertId();
        
        // Insert attributes
        insertMagentoAttribute($magentoDb, $entityId, 'name', $newName, 'varchar');
        insertMagentoAttribute($magentoDb, $entityId, 'description', $newDescription, 'text');
        insertMagentoAttribute($magentoDb, $entityId, 'short_description', $newShortDescription, 'text');
        insertMagentoAttribute($magentoDb, $entityId, 'price', $newPrice, 'decimal');
        insertMagentoAttribute($magentoDb, $entityId, 'status', ($newStatus === 'published') ? 1 : 2, 'int');
        
        echo "Product created successfully in Magento!\n";
    }
    
    echo "\n=== Update and Sync Completed Successfully ===\n";
    
} catch (Exception $e) {
    echo "Error: " . $e->getMessage() . "\n";
    exit(1);
}

/**
 * Update a Magento product attribute
 */
function updateMagentoAttribute($db, $entityId, $attributeCode, $value, $type) {
    // Get attribute ID
    $stmt = $db->prepare("SELECT attribute_id FROM eav_attribute WHERE attribute_code = ? AND entity_type_id = 4");
    $stmt->execute([$attributeCode]);
    $attribute = $stmt->fetch();
    
    if (!$attribute) {
        echo "Warning: Attribute '$attributeCode' not found in Magento\n";
        return;
    }
    
    $attributeId = $attribute['attribute_id'];
    $table = "catalog_product_entity_{$type}";
    
    // Delete existing value
    $stmt = $db->prepare("DELETE FROM {$table} WHERE attribute_id = ? AND entity_id = ?");
    $stmt->execute([$attributeId, $entityId]);
    
    // Insert new value
    if ($value !== null) {
        $stmt = $db->prepare("INSERT INTO {$table} (attribute_id, store_id, entity_id, value) VALUES (?, 0, ?, ?)");
        $stmt->execute([$attributeId, $entityId, $value]);
    }
}

/**
 * Insert a Magento product attribute
 */
function insertMagentoAttribute($db, $entityId, $attributeCode, $value, $type) {
    updateMagentoAttribute($db, $entityId, $attributeCode, $value, $type);
}