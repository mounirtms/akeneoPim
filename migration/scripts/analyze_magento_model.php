<?php

require_once __DIR__ . '/../../vendor/autoload.php';

use Migration\Database\MagentoConnection;

// Initialize connection
$magento = new MagentoConnection();

echo "Analyzing Magento data model...\n\n";

// Get attribute sets
echo "Attribute Sets:\n";
echo "==============\n";
$attributeSets = $magento->getAttributeSets();
foreach ($attributeSets as $set) {
    echo sprintf("- %s (ID: %d)\n", $set['attribute_set_name'], $set['attribute_set_id']);
}
echo "\n";

// Get product attributes
echo "Product Attributes:\n";
echo "==================\n";
$attributes = $magento->getProductAttributes();
foreach ($attributes as $attr) {
    echo sprintf(
        "- %s:\n  Type: %s\n  Input: %s\n  Required: %s\n  Global: %s\n  Searchable: %s\n  Filterable: %s\n",
        $attr['attribute_code'],
        $attr['backend_type'],
        $attr['frontend_input'],
        $attr['is_required'] ? 'Yes' : 'No',
        $attr['is_global'] ? 'Yes' : 'No',
        $attr['is_searchable'] ? 'Yes' : 'No',
        $attr['is_filterable'] ? 'Yes' : 'No'
    );
}
echo "\n";

// Get category structure
echo "Category Structure:\n";
echo "==================\n";
$categories = $magento->getCategories();
$tree = [];
foreach ($categories as $cat) {
    if (!isset($tree[$cat['parent_id']])) {
        $tree[$cat['parent_id']] = [];
    }
    $tree[$cat['parent_id']][] = $cat;
}

function printCategoryTree($tree, $parentId = 0, $level = 0)
{
    if (!isset($tree[$parentId])) {
        return;
    }
    
    foreach ($tree[$parentId] as $category) {
        echo str_repeat("  ", $level) . "- " . $category['name'] . " (ID: " . $category['entity_id'] . ")\n";
        printCategoryTree($tree, $category['entity_id'], $level + 1);
    }
}

printCategoryTree($tree);
echo "\n";

// Sample some products
echo "Sample Products:\n";
echo "===============\n";
$products = $magento->getProducts(5);
foreach ($products as $product) {
    echo sprintf("Product: %s (SKU: %s)\n", $product['name'], $product['sku']);
    
    // Get categories
    $categories = $magento->getProductCategories($product['entity_id']);
    echo "Categories: " . implode(", ", $categories) . "\n";
    
    // Get images
    $images = $magento->getProductImages($product['entity_id']);
    echo "Images:\n";
    foreach ($images as $image) {
        echo sprintf("- %s (Position: %d)\n", $image['file'], $image['position']);
    }
    echo "\n";
}

// Generate summary report
$report = [
    'attribute_sets' => count($attributeSets),
    'attributes' => count($attributes),
    'categories' => count($categories),
    'sample_products' => count($products)
];

echo "Summary:\n";
echo "========\n";
echo sprintf(
    "Found %d attribute sets, %d attributes, %d categories\n",
    $report['attribute_sets'],
    $report['attributes'],
    $report['categories']
);