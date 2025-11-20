<?php

use Pimcore\Model\DataObject;

echo "Creating a comprehensive product with all attributes...\n";

try {
    // Create a comprehensive test product
    $product = new DataObject\Product();
    $product->setParentId(1); // Root folder
    $product->setKey('comprehensive-test-product');
    $product->setSku('COMPREHENSIVE-TEST-001');
    $product->setTitle('Comprehensive Test Product', 'en');
    $product->setDescription('<p>This is a comprehensive test product with all possible attributes.</p>', 'en');
    $product->setShortDescription('A short description of the comprehensive test product.', 'en');
    $product->setWeight(1.5);
    $product->setPrice(199.99);
    $product->setSpecialPrice(149.99);
    $product->setVisibility('Catalog, Search');
    $product->setTaxClass('Taxable Goods');
    $product->setUrlKey('comprehensive-test-product');
    $product->setMetaTitle('Comprehensive Test Product - Best Product Ever');
    $product->setMetaDescription('This is a comprehensive test product with all possible attributes for testing purposes.');
    $product->setMetaKeywords('test, product, comprehensive, pimcore, magento');
    $product->setQuantity(100);
    $product->setStockStatus('In Stock');
    $product->setManageStock(true);
    $product->setMinSaleQty(1);
    $product->setMaxSaleQty(10);
    $product->setPublished(true);
    
    // Save the product
    $product->save();
    
    echo "Comprehensive test product created successfully with ID: " . $product->getId() . "\n";
    
    // Try to retrieve and display the product
    $retrievedProduct = DataObject\Product::getById($product->getId());
    if ($retrievedProduct) {
        echo "Product retrieved successfully!\n";
        echo "SKU: " . $retrievedProduct->getSku() . "\n";
        echo "Title: " . $retrievedProduct->getTitle('en') . "\n";
        echo "Price: " . $retrievedProduct->getPrice() . "\n";
    }
    
} catch (Exception $e) {
    echo "Error creating comprehensive test product: " . $e->getMessage() . "\n";
    exit(1);
}