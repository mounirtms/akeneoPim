<?php
/**
 * Elasticsearch Performance Benchmark
 */

echo "=== ELASTICSEARCH PERFORMANCE BENCHMARK ===\n\n";

$tests = [];

// Test 1: Simple Count Query
echo "[1/5] Testing count query...\n";
$start = microtime(true);
$ch = curl_init('http://localhost:9200/akeneo_pim_product_and_product_model/_count');
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
curl_exec($ch);
curl_close($ch);
$duration = (microtime(true) - $start) * 1000;
echo "  Duration: {$duration}ms\n";
$tests['count_query'] = $duration;

// Test 2: Search Query (10 results)
echo "\n[2/5] Testing search query (10 results)...\n";
$start = microtime(true);
$ch = curl_init('http://localhost:9200/akeneo_pim_product_and_product_model/_search?size=10');
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
curl_exec($ch);
curl_close($ch);
$duration = (microtime(true) - $start) * 1000;
echo "  Duration: {$duration}ms\n";
$tests['search_10'] = $duration;

// Test 3: Search Query (100 results)
echo "\n[3/5] Testing search query (100 results)...\n";
$start = microtime(true);
$ch = curl_init('http://localhost:9200/akeneo_pim_product_and_product_model/_search?size=100');
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
curl_exec($ch);
curl_close($ch);
$duration = (microtime(true) - $start) * 1000;
echo "  Duration: {$duration}ms\n";
$tests['search_100'] = $duration;

// Test 4: Filtered Search
echo "\n[4/5] Testing filtered search...\n";
$query = json_encode([
    'query' => [
        'bool' => [
            'must' => [
                ['term' => ['enabled' => true]]
            ]
        ]
    ],
    'size' => 50
]);

$start = microtime(true);
$ch = curl_init('http://localhost:9200/akeneo_pim_product_and_product_model/_search');
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
curl_setopt($ch, CURLOPT_POST, true);
curl_setopt($ch, CURLOPT_POSTFIELDS, $query);
curl_setopt($ch, CURLOPT_HTTPHEADER, ['Content-Type: application/json']);
curl_exec($ch);
curl_close($ch);
$duration = (microtime(true) - $start) * 1000;
echo "  Duration: {$duration}ms\n";
$tests['filtered_search'] = $duration;

// Test 5: Aggregation Query
echo "\n[5/5] Testing aggregation query...\n";
$query = json_encode([
    'size' => 0,
    'aggs' => [
        'families' => [
            'terms' => [
                'field' => 'family.code',
                'size' => 20
            ]
        ]
    ]
]);

$start = microtime(true);
$ch = curl_init('http://localhost:9200/akeneo_pim_product_and_product_model/_search');
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
curl_setopt($ch, CURLOPT_POST, true);
curl_setopt($ch, CURLOPT_POSTFIELDS, $query);
curl_setopt($ch, CURLOPT_HTTPHEADER, ['Content-Type: application/json']);
curl_exec($ch);
curl_close($ch);
$duration = (microtime(true) - $start) * 1000;
echo "  Duration: {$duration}ms\n";
$tests['aggregation'] = $duration;

// Summary
echo "\n=== PERFORMANCE SUMMARY ===\n";
$avgDuration = array_sum($tests) / count($tests);
echo "Average Query Time: " . round($avgDuration, 2) . "ms\n\n";

foreach ($tests as $name => $duration) {
    $status = $duration < 100 ? '✅' : ($duration < 500 ? '⚠️' : '❌');
    $label = ucfirst(str_replace('_', ' ', $name));
    echo "$status $label: " . round($duration, 2) . "ms\n";
}

echo "\n";
if ($avgDuration < 100) {
    echo "✅ EXCELLENT PERFORMANCE\n";
} elseif ($avgDuration < 500) {
    echo "⚠️  ACCEPTABLE PERFORMANCE\n";
} else {
    echo "❌ PERFORMANCE NEEDS OPTIMIZATION\n";
}
