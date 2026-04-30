<?php
/**
 * Phase 3: Elasticsearch Reindex and Data Verification
 * Checks Elasticsearch status and reindexes if needed
 */

echo "=========================================\n";
echo "PHASE 3: ELASTICSEARCH & DATA LOADING\n";
echo "Date: " . date('Y-m-d H:i:s') . "\n";
echo "=========================================\n\n";

// Check Elasticsearch connection
echo "1. Checking Elasticsearch Connection...\n";
$esHost = getenv('AKENEO_ELASTICSEARCH_HOST') ?: 'localhost';
$esPort = getenv('AKENEO_ELASTICSEARCH_PORT') ?: '9200';
$esUrl = "http://$esHost:$esPort";

echo "   Elasticsearch URL: $esUrl\n";

$ch = curl_init("$esUrl/_cluster/health");
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
curl_setopt($ch, CURLOPT_TIMEOUT, 5);
$response = curl_exec($ch);
$httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
curl_close($ch);

if ($httpCode === 200 && $response) {
    $health = json_decode($response, true);
    echo "   ✓ Elasticsearch is reachable\n";
    echo "   Cluster Name: " . $health['cluster_name'] . "\n";
    echo "   Status: " . $health['status'] . "\n";
    echo "   Number of Nodes: " . $health['number_of_nodes'] . "\n";
    echo "   Active Shards: " . $health['active_shards'] . "\n";
    echo "   Unassigned Shards: " . $health['unassigned_shards'] . "\n";
} else {
    echo "   ✗ Cannot connect to Elasticsearch\n";
    echo "   HTTP Code: $httpCode\n";
}

// Check indices
echo "\n2. Checking Elasticsearch Indices...\n";
$ch = curl_init("$esUrl/_cat/indices?format=json");
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
curl_setopt($ch, CURLOPT_TIMEOUT, 5);
$response = curl_exec($ch);
$httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
curl_close($ch);

if ($httpCode === 200 && $response) {
    $indices = json_decode($response, true);
    $akeneoIndices = array_filter($indices, function($index) {
        return strpos($index['index'], 'akeneo') !== false;
    });
    
    echo "   Found " . count($akeneoIndices) . " Akeneo indices:\n";
    foreach ($akeneoIndices as $index) {
        echo "      - {$index['index']}: {$index['docs.count']} docs, {$index['store.size']}\n";
    }
} else {
    echo "   ✗ Cannot retrieve indices\n";
}

// Check database product count
echo "\n3. Checking Database Product Count...\n";
try {
    $envFile = '/home/pim/public_html/.env';
    $envContent = file_get_contents($envFile);
    
    // Parse database credentials
    preg_match('/DATABASE_URL="mysql:\/\/([^:]+):([^@]+)@([^:]+):(\d+)\/([^"]+)"/', $envContent, $matches);
    
    if (count($matches) === 6) {
        $dbUser = $matches[1];
        $dbPass = $matches[2];
        $dbHost = $matches[3];
        $dbPort = $matches[4];
        $dbName = $matches[5];
        
        $dsn = "mysql:host=$dbHost;port=$dbPort;dbname=$dbName;charset=utf8mb4";
        $pdo = new PDO($dsn, $dbUser, $dbPass);
        $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
        
        echo "   ✓ Database connection successful\n";
        
        // Count products
        $stmt = $pdo->query("SELECT COUNT(*) as count FROM pim_catalog_product WHERE is_enabled = 1");
        $result = $stmt->fetch(PDO::FETCH_ASSOC);
        $enabledProducts = $result['count'];
        
        $stmt = $pdo->query("SELECT COUNT(*) as count FROM pim_catalog_product");
        $result = $stmt->fetch(PDO::FETCH_ASSOC);
        $totalProducts = $result['count'];
        
        echo "   ✓ Total products: $totalProducts\n";
        echo "   ✓ Enabled products: $enabledProducts\n";
        
        // Count categories
        $stmt = $pdo->query("SELECT COUNT(*) as count FROM pim_catalog_category");
        $result = $stmt->fetch(PDO::FETCH_ASSOC);
        $categories = $result['count'];
        echo "   ✓ Categories: $categories\n";
        
        // Count attributes
        $stmt = $pdo->query("SELECT COUNT(*) as count FROM pim_catalog_attribute");
        $result = $stmt->fetch(PDO::FETCH_ASSOC);
        $attributes = $result['count'];
        echo "   ✓ Attributes: $attributes\n";
        
        // Count families
        $stmt = $pdo->query("SELECT COUNT(*) as count FROM pim_catalog_family");
        $result = $stmt->fetch(PDO::FETCH_ASSOC);
        $families = $result['count'];
        echo "   ✓ Families: $families\n";
        
    } else {
        echo "   ✗ Could not parse database credentials\n";
    }
} catch (Exception $e) {
    echo "   ✗ Database error: " . $e->getMessage() . "\n";
}

// Recommendations
echo "\n4. Reindex Recommendations...\n";
echo "   To reindex Elasticsearch, run:\n";
echo "   cd /home/pim/public_html\n";
echo "   php bin/console akeneo:elasticsearch:reset-indexes --env=prod\n";
echo "   php bin/console pim:product:index --all --env=prod\n";
echo "   php bin/console pim:product-model:index --all --env=prod\n";
echo "\n";
echo "   This will:\n";
echo "   - Reset Elasticsearch indices\n";
echo "   - Reindex all products ($totalProducts products)\n";
echo "   - Reindex all product models\n";
echo "   - Ensure data is searchable and displays correctly\n";

echo "\n=========================================\n";
echo "PHASE 3 ANALYSIS COMPLETE\n";
echo "=========================================\n";

