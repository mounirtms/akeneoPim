#!/usr/bin/env php
<?php

/**
 * Advanced Magento-Pimcore Synchronization Service
 * 
 * This script provides a more robust synchronization mechanism between Pimcore and Magento
 * with better error handling, logging, and configurability.
 */

// Bootstrap Pimcore
include_once __DIR__ . '/../../vendor/autoload.php';

use Pimcore\Bootstrap;
use Pimcore\Model\DataObject\Product;
use Pimcore\Model\DataObject\Category as PimcoreCategory;
use Monolog\Logger;
use Monolog\Handler\StreamHandler;

Bootstrap::setProjectRoot();
Bootstrap::bootstrap();

// Load configuration
$config = yaml_parse_file(__DIR__ . '/../../config/magento_sync.yaml');

// Setup logging
$logFile = $config['logging']['file'] ?? __DIR__ . '/../../var/log/magento_sync.log';
$logger = new Logger('magento_sync');
$logger->pushHandler(new StreamHandler($logFile, Logger::INFO));

$logger->info('Starting Magento-Pimcore synchronization service');

try {
    // Database connections
    $pimcoreDb = \Pimcore\Db::get();
    
    // Magento database connection
    $magentoConfig = $config['magento']['database'];
    $magentoDsn = "mysql:host={$magentoConfig['host']};port={$magentoConfig['port']};dbname={$magentoConfig['name']}";
    $mlogger = new PDO($magentoDsn, $magentoConfig['username'], $magentoConfig['password']);
    $mlogger->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    
    $logger->info('Database connections established successfully');
    
    // Sync products if enabled
    if ($config['sync']['products']) {
        syncProducts($pimcoreDb, $mlogger, $config, $logger);
    }
    
    // Sync categories if enabled
    if ($config['sync']['categories']) {
        syncCategories($pimcoreDb, $mlogger, $config, $logger);
    }
    
    $logger->info('Synchronization completed successfully');
    echo "Synchronization completed. Check {$logFile} for details.\n";
    
} catch (Exception $e) {
    $logger->error('Synchronization failed: ' . $e->getMessage());
    echo "Error: " . $e->getMessage() . "\n";
    exit(1);
}

/**
 * Synchronize products from Pimcore to Magento
 */
function syncProducts($pimcoreDb, $magentoDb, $config, $logger) {
    $logger->info('Starting product synchronization');
    
    // Create product listing with conditions
    $productList = new Product\Listing();
    
    // Apply condition for published products if configured
    if (!empty($config['sync']['product']['only_published'])) {
        $productList->setCondition("status = 'published'");
    }
    
    $products = $productList->load();
    $logger->info('Found ' . count($products) . ' products to sync');
    
    $inserted = 0;
    $updated = 0;
    $errors = 0;
    
    foreach ($products as $product) {
        try {
            // Prepare product data for Magento
            $sku = $product->getSku();
            
            if (empty($sku)) {
                $logger->warning("Skipping product with empty SKU (ID: {$product->getId()})");
                $errors++;
                continue;
            }
            
            $name = $product->getName();
            $price = $product->getPrice() ?: 0;
            $description = $product->getDescription();
            $shortDescription = $product->getShortDescription();
            $status = ($product->getStatus() === 'published') ? 1 : 2; // 1 = Enabled, 2 = Disabled
            $weight = $product->getWeight() ?: 0;
            
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
                
                // Update individual attributes
                updateProductAttribute($magentoDb, $entityId, 'name', $name, 'varchar');
                updateProductAttribute($magentoDb, $entityId, 'price', $price, 'decimal');
                updateProductAttribute($magentoDb, $entityId, 'status', $status, 'int');
                updateProductAttribute($magentoDb, $entityId, 'description', $description, 'text');
                updateProductAttribute($magentoDb, $entityId, 'short_description', $shortDescription, 'text');
                updateProductAttribute($magentoDb, $entityId, 'weight', $weight, 'decimal');
                
                $updated++;
                $logger->debug("Updated product: {$sku}");
            } else {
                // Insert new product
                $stmt = $magentoDb->prepare("
                    INSERT INTO catalog_product_entity 
                    (attribute_set_id, type_id, sku, has_options, required_options, created_at, updated_at) 
                    VALUES (?, ?, ?, ?, ?, NOW(), NOW())
                ");
                $stmt->execute([4, 'simple', $sku, 0, 0]);
                $entityId = $magentoDb->lastInsertId();
                
                // Insert attributes
                insertProductAttribute($magentoDb, $entityId, 'name', $name, 'varchar');
                insertProductAttribute($magentoDb, $entityId, 'price', $price, 'decimal');
                insertProductAttribute($magentoDb, $entityId, 'status', $status, 'int');
                insertProductAttribute($magentoDb, $entityId, 'description', $description, 'text');
                insertProductAttribute($magentoDb, $entityId, 'short_description', $shortDescription, 'text');
                insertProductAttribute($magentoDb, $entityId, 'weight', $weight, 'decimal');
                
                $inserted++;
                $logger->debug("Inserted product: {$sku}");
            }
        } catch (Exception $e) {
            $errors++;
            $logger->error("Error syncing product (SKU: {$product->getSku()}): " . $e->getMessage());
        }
    }
    
    $logger->info("Product synchronization completed - Inserted: $inserted, Updated: $updated, Errors: $errors");
}

/**
 * Synchronize categories from Pimcore to Magento
 */
function syncCategories($pimcoreDb, $magentoDb, $config, $logger) {
    $logger->info('Starting category synchronization');
    
    // Fetch all categories from Pimcore
    $categoryList = new PimcoreCategory\Listing();
    $categories = $categoryList->load();
    $logger->info('Found ' . count($categories) . ' categories to sync');
    
    $inserted = 0;
    $updated = 0;
    $errors = 0;
    
    foreach ($categories as $category) {
        try {
            $categoryId = $category->getId();
            $name = $category->getName();
            $description = $category->getDescription();
            
            // Skip root categories (with IDs <= 2) as they should exist in Magento
            if ($categoryId <= 2) {
                continue;
            }
            
            // Check if category exists in Magento
            $stmt = $magentoDb->prepare("SELECT entity_id FROM catalog_category_entity WHERE entity_id = ?");
            $stmt->execute([$categoryId]);
            $existingCategory = $stmt->fetch();
            
            if ($existingCategory) {
                // Update existing category
                $stmt = $magentoDb->prepare("
                    UPDATE catalog_category_entity 
                    SET updated_at = NOW() 
                    WHERE entity_id = ?
                ");
                $stmt->execute([$categoryId]);
                
                // Update attributes
                updateCategoryAttribute($magentoDb, $categoryId, 'name', $name, 'varchar');
                updateCategoryAttribute($magentoDb, $categoryId, 'description', $description, 'text');
                
                $updated++;
                $logger->debug("Updated category: {$name} (ID: {$categoryId})");
            } else {
                // Insert new category
                // Note: In a production environment, you would need to properly handle parent-child relationships
                $stmt = $magentoDb->prepare("
                    INSERT INTO catalog_category_entity 
                    (entity_id, attribute_set_id, parent_id, created_at, updated_at, path, position, level, children_count) 
                    VALUES (?, ?, ?, NOW(), NOW(), ?, ?, ?, ?)
                ");
                
                // Simplified values for demonstration
                $stmt->execute([
                    $categoryId,
                    3, // Default category attribute set
                    2, // Parent category ID
                    "1/2/{$categoryId}", // Path
                    1, // Position
                    2, // Level
                    0  // Children count
                ]);
                
                // Insert attributes
                insertCategoryAttribute($magentoDb, $categoryId, 'name', $name, 'varchar');
                insertCategoryAttribute($magentoDb, $categoryId, 'description', $description, 'text');
                
                $inserted++;
                $logger->debug("Inserted category: {$name} (ID: {$categoryId})");
            }
        } catch (Exception $e) {
            $errors++;
            $logger->error("Error syncing category (ID: {$category->getId()}): " . $e->getMessage());
        }
    }
    
    $logger->info("Category synchronization completed - Inserted: $inserted, Updated: $updated, Errors: $errors");
}

/**
 * Update a product attribute in Magento
 */
function updateProductAttribute($db, $entityId, $attributeCode, $value, $type) {
    // Get attribute ID (in a real implementation, you would cache these)
    $stmt = $db->prepare("SELECT attribute_id FROM eav_attribute WHERE attribute_code = ? AND entity_type_id = 4");
    $stmt->execute([$attributeCode]);
    $attribute = $stmt->fetch();
    
    if (!$attribute) {
        return; // Attribute not found
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
 * Insert a product attribute in Magento
 */
function insertProductAttribute($db, $entityId, $attributeCode, $value, $type) {
    updateProductAttribute($db, $entityId, $attributeCode, $value, $type);
}

/**
 * Update a category attribute in Magento
 */
function updateCategoryAttribute($db, $entityId, $attributeCode, $value, $type) {
    // Get attribute ID (in a real implementation, you would cache these)
    $stmt = $db->prepare("SELECT attribute_id FROM eav_attribute WHERE attribute_code = ? AND entity_type_id = 3");
    $stmt->execute([$attributeCode]);
    $attribute = $stmt->fetch();
    
    if (!$attribute) {
        return; // Attribute not found
    }
    
    $attributeId = $attribute['attribute_id'];
    $table = "catalog_category_entity_{$type}";
    
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
 * Insert a category attribute in Magento
 */
function insertCategoryAttribute($db, $entityId, $attributeCode, $value, $type) {
    updateCategoryAttribute($db, $entityId, $attributeCode, $value, $type);
}