#!/usr/bin/env php
<?php

/**
 * Script to synchronize Pimcore products and categories with Magento
 * 
 * This script connects to both Pimcore and Magento databases and synchronizes:
 * 1. Product data from Pimcore to Magento
 * 2. Category data from Pimcore to Magento
 */

// Bootstrap Pimcore
include_once __DIR__ . '/../../vendor/autoload.php';

use Pimcore\Bootstrap;
use Pimcore\Model\DataObject\Product;
use Pimcore\Model\DataObject\Category as PimcoreCategory;

Bootstrap::setProjectRoot();
Bootstrap::bootstrap();

// Database connections
$pimcoreDb = \Pimcore\Db::get();

// Magento database connection parameters
$magentoConfig = [
    'host' => '127.0.0.1',
    'port' => '3307',
    'dbname' => 'beta_dBT8x12y22',
    'username' => 'root',
    'password' => 'YourNewStrongPassword'
];

try {
    $magentoDsn = "mysql:host={$magentoConfig['host']};port={$magentoConfig['port']};dbname={$magentoConfig['dbname']}";
    $magentoDb = new PDO($magentoDsn, $magentoConfig['username'], $magentoConfig['password']);
    $magentoDb->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
} catch (PDOException $e) {
    die("Connection failed to Magento database: " . $e->getMessage());
}

echo "Starting synchronization of Pimcore products and categories to Magento...\n";

// Sync products
syncProducts($pimcoreDb, $magentoDb);

// Sync categories
syncCategories($pimcoreDb, $magentoDb);

echo "Synchronization completed.\n";

/**
 * Synchronize products from Pimcore to Magento
 */
function syncProducts($pimcoreDb, $magentoDb) {
    echo "Syncing products...\n";
    
    // Fetch all products from Pimcore
    $productList = new Product\Listing();
    $productList->setCondition("status = 'published'");
    $products = $productList->load();
    
    $inserted = 0;
    $updated = 0;
    
    foreach ($products as $product) {
        // Prepare product data for Magento
        $sku = $product->getSku();
        $name = $product->getName();
        $price = $product->getPrice() ?: 0;
        $description = $product->getDescription();
        $shortDescription = $product->getShortDescription();
        $status = ($product->getStatus() === 'published') ? 1 : 0;
        
        // Check if product exists in Magento
        $stmt = $magentoDb->prepare("SELECT entity_id FROM catalog_product_entity WHERE sku = ?");
        $stmt->execute([$sku]);
        $existingProduct = $stmt->fetch();
        
        if ($existingProduct) {
            // Update existing product
            $entityId = $existingProduct['entity_id'];
            
            // Update main product attributes
            $stmt = $magentoDb->prepare("
                UPDATE catalog_product_entity 
                SET updated_at = NOW() 
                WHERE entity_id = ?
            ");
            $stmt->execute([$entityId]);
            
            // Update name (varchar attribute)
            updateTextAttribute($magentoDb, $entityId, 'name', $name, 73);
            
            // Update price (decimal attribute)
            updateDecimalAttribute($magentoDb, $entityId, 'price', $price, 77);
            
            // Update status (int attribute)
            updateIntAttribute($magentoDb, $entityId, 'status', $status, 93);
            
            // Update description (text attribute)
            updateTextAreaAttribute($magentoDb, $entityId, 'description', $description, 74);
            
            // Update short description (text attribute)
            updateTextAreaAttribute($magentoDb, $entityId, 'short_description', $shortDescription, 75);
            
            $updated++;
        } else {
            // Insert new product
            $stmt = $magentoDb->prepare("
                INSERT INTO catalog_product_entity 
                (attribute_set_id, type_id, sku, has_options, required_options, created_at, updated_at) 
                VALUES (?, ?, ?, ?, ?, NOW(), NOW())
            ");
            $stmt->execute([4, 'simple', $sku, 0, 0]);
            $entityId = $magentoDb->lastInsertId();
            
            // Insert name (varchar attribute)
            insertTextAttribute($magentoDb, $entityId, 'name', $name, 73);
            
            // Insert price (decimal attribute)
            insertDecimalAttribute($magentoDb, $entityId, 'price', $price, 77);
            
            // Insert status (int attribute)
            insertIntAttribute($magentoDb, $entityId, 'status', $status, 93);
            
            // Insert description (text attribute)
            insertTextAreaAttribute($magentoDb, $entityId, 'description', $description, 74);
            
            // Insert short description (text attribute)
            insertTextAreaAttribute($magentoDb, $entityId, 'short_description', $shortDescription, 75);
            
            $inserted++;
        }
    }
    
    echo "Products synced - Inserted: $inserted, Updated: $updated\n";
}

/**
 * Synchronize categories from Pimcore to Magento
 */
function syncCategories($pimcoreDb, $magentoDb) {
    echo "Syncing categories...\n";
    
    // Fetch all categories from Pimcore
    $categoryList = new PimcoreCategory\Listing();
    $categories = $categoryList->load();
    
    $inserted = 0;
    $updated = 0;
    
    foreach ($categories as $category) {
        $categoryId = $category->getId();
        $name = $category->getName();
        $description = $category->getDescription();
        
        // Check if category exists in Magento
        $stmt = $magentoDb->prepare("SELECT entity_id FROM catalog_category_entity WHERE entity_id = ?");
        $stmt->execute([$categoryId]);
        $existingCategory = $stmt->fetch();
        
        if ($existingCategory) {
            // Update existing category
            // For simplicity, we're just updating the timestamp
            $stmt = $magentoDb->prepare("
                UPDATE catalog_category_entity 
                SET updated_at = NOW() 
                WHERE entity_id = ?
            ");
            $stmt->execute([$categoryId]);
            
            // Update name (varchar attribute)
            updateCategoryTextAttribute($magentoDb, $categoryId, 'name', $name, 45);
            
            // Update description (text attribute)
            updateCategoryTextAreaAttribute($magentoDb, $categoryId, 'description', $description, 46);
            
            $updated++;
        } else {
            // Insert new category
            // We'll use a simplified insertion for demonstration purposes
            // In a real-world scenario, you would need to handle parent-child relationships
            
            // For root category (ID = 1) and default category (ID = 2) already exist in Magento
            if ($categoryId > 2) {
                $stmt = $magentoDb->prepare("
                    INSERT INTO catalog_category_entity 
                    (entity_id, attribute_set_id, parent_id, created_at, updated_at, path, position, level, children_count) 
                    VALUES (?, ?, ?, NOW(), NOW(), ?, ?, ?, ?)
                ");
                
                // This is a simplified approach - in reality, you'd need to determine these values properly
                $stmt->execute([
                    $categoryId, 
                    3, // Default attribute set for categories
                    2, // Parent category ID (assuming 2 is default)
                    "1/2/$categoryId", // Path
                    1, // Position
                    2, // Level
                    0  // Children count
                ]);
                
                // Insert name (varchar attribute)
                insertCategoryTextAttribute($magentoDb, $categoryId, 'name', $name, 45);
                
                // Insert description (text attribute)
                insertCategoryTextAreaAttribute($magentoDb, $categoryId, 'description', $description, 46);
                
                $inserted++;
            }
        }
    }
    
    echo "Categories synced - Inserted: $inserted, Updated: $updated\n";
}

// Helper functions for product attributes
function updateTextAttribute($db, $entityId, $attributeCode, $value, $attributeId) {
    $stmt = $db->prepare("
        INSERT INTO catalog_product_entity_varchar (attribute_id, store_id, entity_id, value) 
        VALUES (?, 0, ?, ?) 
        ON DUPLICATE KEY UPDATE value = VALUES(value)
    ");
    $stmt->execute([$attributeId, $entityId, $value]);
}

function updateDecimalAttribute($db, $entityId, $attributeCode, $value, $attributeId) {
    $stmt = $db->prepare("
        INSERT INTO catalog_product_entity_decimal (attribute_id, store_id, entity_id, value) 
        VALUES (?, 0, ?, ?) 
        ON DUPLICATE KEY UPDATE value = VALUES(value)
    ");
    $stmt->execute([$attributeId, $entityId, $value]);
}

function updateIntAttribute($db, $entityId, $attributeCode, $value, $attributeId) {
    $stmt = $db->prepare("
        INSERT INTO catalog_product_entity_int (attribute_id, store_id, entity_id, value) 
        VALUES (?, 0, ?, ?) 
        ON DUPLICATE KEY UPDATE value = VALUES(value)
    ");
    $stmt->execute([$attributeId, $entityId, $value]);
}

function updateTextAreaAttribute($db, $entityId, $attributeCode, $value, $attributeId) {
    $stmt = $db->prepare("
        INSERT INTO catalog_product_entity_text (attribute_id, store_id, entity_id, value) 
        VALUES (?, 0, ?, ?) 
        ON DUPLICATE KEY UPDATE value = VALUES(value)
    ");
    $stmt->execute([$attributeId, $entityId, $value]);
}

function insertTextAttribute($db, $entityId, $attributeCode, $value, $attributeId) {
    $stmt = $db->prepare("
        INSERT INTO catalog_product_entity_varchar (attribute_id, store_id, entity_id, value) 
        VALUES (?, 0, ?, ?)
    ");
    $stmt->execute([$attributeId, $entityId, $value]);
}

function insertDecimalAttribute($db, $entityId, $attributeCode, $value, $attributeId) {
    $stmt = $db->prepare("
        INSERT INTO catalog_product_entity_decimal (attribute_id, store_id, entity_id, value) 
        VALUES (?, 0, ?, ?)
    ");
    $stmt->execute([$attributeId, $entityId, $value]);
}

function insertIntAttribute($db, $entityId, $attributeCode, $value, $attributeId) {
    $stmt = $db->prepare("
        INSERT INTO catalog_product_entity_int (attribute_id, store_id, entity_id, value) 
        VALUES (?, 0, ?, ?)
    ");
    $stmt->execute([$attributeId, $entityId, $value]);
}

function insertTextAreaAttribute($db, $entityId, $attributeCode, $value, $attributeId) {
    $stmt = $db->prepare("
        INSERT INTO catalog_product_entity_text (attribute_id, store_id, entity_id, value) 
        VALUES (?, 0, ?, ?)
    ");
    $stmt->execute([$attributeId, $entityId, $value]);
}

// Helper functions for category attributes
function updateCategoryTextAttribute($db, $entityId, $attributeCode, $value, $attributeId) {
    $stmt = $db->prepare("
        INSERT INTO catalog_category_entity_varchar (attribute_id, store_id, entity_id, value) 
        VALUES (?, 0, ?, ?) 
        ON DUPLICATE KEY UPDATE value = VALUES(value)
    ");
    $stmt->execute([$attributeId, $entityId, $value]);
}

function updateCategoryTextAreaAttribute($db, $entityId, $attributeCode, $value, $attributeId) {
    $stmt = $db->prepare("
        INSERT INTO catalog_category_entity_text (attribute_id, store_id, entity_id, value) 
        VALUES (?, 0, ?, ?) 
        ON DUPLICATE KEY UPDATE value = VALUES(value)
    ");
    $stmt->execute([$attributeId, $entityId, $value]);
}

function insertCategoryTextAttribute($db, $entityId, $attributeCode, $value, $attributeId) {
    $stmt = $db->prepare("
        INSERT INTO catalog_category_entity_varchar (attribute_id, store_id, entity_id, value) 
        VALUES (?, 0, ?, ?)
    ");
    $stmt->execute([$attributeId, $entityId, $value]);
}

function insertCategoryTextAreaAttribute($db, $entityId, $attributeCode, $value, $attributeId) {
    $stmt = $db->prepare("
        INSERT INTO catalog_category_entity_text (attribute_id, store_id, entity_id, value) 
        VALUES (?, 0, ?, ?)
    ");
    $stmt->execute([$attributeId, $entityId, $value]);
}