<?php
/**
 * Rebuild product unique data from Elasticsearch to database
 * Fix enrichment tracking and catalog visibility
 */

require __DIR__ . '/vendor/autoload.php';

use Doctrine\DBAL\DriverManager;

// Database connection
$dbConfig = [
    'driver' => 'pdo_mysql',
    'host' => '127.0.0.1',
    'port' => 3307,
    'dbname' => 'akeneo_pim',
    'user' => 'root',
    'password' => 'YourNewStrongPassword',
    'charset' => 'utf8mb4',
    'defaultTableOptions' => [
        'charset' => 'utf8mb4',
        'collate' => 'utf8mb4_unicode_ci',
    ],
];

$conn = DriverManager::getConnection($dbConfig);

// Ensure UTF-8 connection
$conn->executeStatement("SET NAMES utf8mb4 COLLATE utf8mb4_unicode_ci");
$conn->executeStatement("SET CHARACTER SET utf8mb4");

echo "=== Akeneo Catalog Rebuild Script ===\n";
echo "Date: " . date('Y-m-d H:i:s') . "\n\n";

// 1. Check Elasticsearch connection
$esUrl = 'localhost:9200';
$esIndex = 'techno_stationery_product_1_v89';

echo "Step 1: Checking Elasticsearch...\n";
$esResponse = file_get_contents("http://{$esUrl}/_cat/indices?v");
if ($esResponse === false) {
    die("ERROR: Cannot connect to Elasticsearch at {$esUrl}\n");
}
echo "✓ Elasticsearch is accessible\n\n";

// 2. Get all products from Elasticsearch
echo "Step 2: Fetching products from Elasticsearch...\n";
$allProducts = [];
$from = 0;
$batchSize = 1000;

do {
    $url = "http://{$esUrl}/{$esIndex}/_search?size={$batchSize}&from={$from}";
    $response = json_decode(file_get_contents($url), true);
    
    if (!isset($response['hits']['hits'])) {
        break;
    }
    
    foreach ($response['hits']['hits'] as $hit) {
        $allProducts[] = $hit['_source'];
    }
    
    $from += $batchSize;
    echo "  Fetched " . count($allProducts) . " products...\n";
} while (count($response['hits']['hits']) == $batchSize);

echo "✓ Total products fetched: " . count($allProducts) . "\n\n";

// 3. Get attribute IDs
echo "Step 3: Getting attribute mapping...\n";
$attributes = $conn->fetchAllAssociative("SELECT id, code FROM pim_catalog_attribute WHERE code IN ('name', 'description', 'image', 'sku')");
$attributeMap = [];
foreach ($attributes as $attr) {
    $attributeMap[$attr['code']] = $attr['id'];
}
echo "✓ Attributes loaded: " . implode(', ', array_keys($attributeMap)) . "\n\n";

// 4. Get product IDs from database
echo "Step 4: Loading product IDs from database...\n";
$products = $conn->fetchAllAssociative("SELECT id, identifier FROM pim_catalog_product");
$productMap = [];
foreach ($products as $product) {
    $productMap[$product['identifier']] = $product['id'];
}
echo "✓ Products in database: " . count($productMap) . "\n\n";

// 5. Clear existing unique data
echo "Step 5: Clearing existing product unique data...\n";
$deleted = $conn->executeStatement("DELETE FROM pim_catalog_product_unique_data");
echo "✓ Deleted {$deleted} old records\n\n";

// 6. Insert product values
echo "Step 6: Inserting product values...\n";
$inserted = 0;
$skipped = 0;

$conn->beginTransaction();
try {
    $stmt = $conn->prepare("INSERT IGNORE INTO pim_catalog_product_unique_data (product_id, attribute_id, raw_data) VALUES (?, ?, ?)");
    
    foreach ($allProducts as $productData) {
        $sku = $productData['sku'] ?? null;
        if (!$sku || !isset($productMap[$sku])) {
            $skipped++;
            continue;
        }
        
        $productId = $productMap[$sku];
        
        // Insert name (French - default locale)
        if (isset($productData['name']) && isset($attributeMap['name'])) {
            $name = mb_substr($productData['name'], 0, 255, 'UTF-8');
            $stmt->executeStatement([$productId, $attributeMap['name'], $name]);
            $inserted++;
        }
        
        // Insert description
        if (isset($productData['description']) && isset($attributeMap['description'])) {
            $desc = mb_substr($productData['description'], 0, 255, 'UTF-8');
            $stmt->executeStatement([$productId, $attributeMap['description'], $desc]);
            $inserted++;
        }
        
        // Insert SKU
        if (isset($productData['sku']) && isset($attributeMap['sku'])) {
            $stmt->executeStatement([$productId, $attributeMap['sku'], $productData['sku']]);
            $inserted++;
        }
    }
    
    $conn->commit();
    echo "✓ Inserted {$inserted} values, skipped {$skipped} products\n\n";
    
} catch (Exception $e) {
    $conn->rollBack();
    die("ERROR: " . $e->getMessage() . "\n");
}

// 7. Verify
echo "Step 7: Verification...\n";
$count = $conn->fetchOne("SELECT COUNT(*) FROM pim_catalog_product_unique_data");
echo "✓ Product unique data records: {$count}\n";

$nameCount = $conn->fetchOne("SELECT COUNT(*) FROM pim_catalog_product_unique_data pv JOIN pim_catalog_attribute a ON pv.attribute_id = a.id WHERE a.code = 'name'");
echo "✓ Products with names: {$nameCount}\n";

$descCount = $conn->fetchOne("SELECT COUNT(*) FROM pim_catalog_product_unique_data pv JOIN pim_catalog_attribute a ON pv.attribute_id = a.id WHERE a.code = 'description'");
echo "✓ Products with descriptions: {$descCount}\n\n";

echo "=== Rebuild Complete ===\n";
echo "Next steps:\n";
echo "1. Run: php bin/console pim:completeness:calculate --env=prod\n";
echo "2. Refresh Data Quality Insights from PIM UI\n";
echo "3. Check product enrichment in dashboard\n";
