#!/usr/bin/env php
<?php
/**
 * Check and reindex Akeneo data in Elasticsearch
 * Run: php /home/pim/public_html/webapp/reindex_elasticsearch.php
 */

set_time_limit(0);

require_once __DIR__ . '/../vendor/autoload.php';

$rootDir = __DIR__ . '/../';
$container = null;

echo "=== AKENEO ELASTICSEARCH REINDEX ===\n\n";

// Bootstrap Symfony kernel
$kernel = new AppKernel('prod', false);
$kernel->boot();
$container = $kernel->getContainer();

echo "Symfony container initialized\n";

// Get Elasticsearch service
$indexName = $container->getParameter('akeneo_pim_product_and_product_model_index_name');
echo "Index name: $indexName\n";

// List available indexer services
echo "\nChecking available indexers...\n";

$services = [
    'akeneo_elasticsearch.search_indexer' => 'Product Search Indexer',
    'akeneo_elasticsearch.product_and_product_model.search_indexer' => 'Product & Product Model Indexer',
];

foreach ($services as $serviceId => $name) {
    if ($container->has($serviceId)) {
        echo "✓ Found: $name ($serviceId)\n";
    } else {
        echo "✗ Not found: $serviceId\n";
    }
}

echo "\nDone.\n";
