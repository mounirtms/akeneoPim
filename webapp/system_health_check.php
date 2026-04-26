<?php
/**
 * Comprehensive Akeneo PIM Health Check
 * Tests all critical system components
 */

$startTime = microtime(true);

echo "=== AKENEO PIM COMPREHENSIVE HEALTH CHECK ===\n";
echo "Date: " . date('Y-m-d H:i:s') . "\n\n";

$results = [];
$totalTests = 0;
$passedTests = 0;

// Test 1: Database Connection
echo "[1/10] Testing Database Connection...\n";
$totalTests++;
try {
    $pdo = new PDO("mysql:host=127.0.0.1;port=3307;dbname=akeneo_pim", "akeneo_pim", "akeneo_pim");
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    echo "  ✅ Database connection successful\n";
    $passedTests++;
    $results['database'] = 'PASS';
} catch (PDOException $e) {
    echo "  ❌ Database connection failed: " . $e->getMessage() . "\n";
    $results['database'] = 'FAIL';
}
echo "\n";

// Test 2: Product Count
echo "[2/10] Verifying Product Count...\n";
$totalTests++;
try {
    $stmt = $pdo->query("SELECT COUNT(*) FROM pim_catalog_product WHERE is_enabled = 1");
    $productCount = $stmt->fetchColumn();
    echo "  Products: $productCount\n";
    if ($productCount == 9538) {
        echo "  ✅ Product count matches expected (9,538)\n";
        $passedTests++;
        $results['product_count'] = 'PASS';
    } else {
        echo "  ⚠️  Product count mismatch (expected 9,538, got $productCount)\n";
        $results['product_count'] = 'WARN';
    }
} catch (PDOException $e) {
    echo "  ❌ Failed to query products: " . $e->getMessage() . "\n";
    $results['product_count'] = 'FAIL';
}
echo "\n";

// Test 3: Elasticsearch Connection
echo "[3/10] Testing Elasticsearch Connection...\n";
$totalTests++;
$ch = curl_init('http://localhost:9200/_cluster/health');
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
$response = curl_exec($ch);
$httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
curl_close($ch);

if ($httpCode == 200) {
    $health = json_decode($response, true);
    echo "  Status: " . $health['status'] . "\n";
    echo "  Active Shards: " . $health['active_shards'] . "\n";
    echo "  ✅ Elasticsearch is accessible\n";
    $passedTests++;
    $results['elasticsearch'] = 'PASS';
} else {
    echo "  ❌ Elasticsearch connection failed\n";
    $results['elasticsearch'] = 'FAIL';
}
echo "\n";

// Test 4: Elasticsearch Product Index
echo "[4/10] Checking Elasticsearch Product Index...\n";
$totalTests++;
$ch = curl_init('http://localhost:9200/akeneo_pim_product_and_product_model/_count');
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
$response = curl_exec($ch);
$data = json_decode($response, true);

if (isset($data['count'])) {
    $esCount = $data['count'];
    echo "  Indexed Products: $esCount\n";
    if ($esCount == 9538) {
        echo "  ✅ All products indexed in Elasticsearch\n";
        $passedTests++;
        $results['elasticsearch_index'] = 'PASS';
    } else {
        echo "  ⚠️  Index count mismatch (expected 9,538, got $esCount)\n";
        $results['elasticsearch_index'] = 'WARN';
    }
} else {
    echo "  ❌ Failed to query Elasticsearch index\n";
    $results['elasticsearch_index'] = 'FAIL';
}
echo "\n";

// Test 5: Categories
echo "[5/10] Checking Categories...\n";
$totalTests++;
try {
    $stmt = $pdo->query("SELECT COUNT(*) FROM pim_catalog_category");
    $categoryCount = $stmt->fetchColumn();
    echo "  Categories: $categoryCount\n";
    if ($categoryCount >= 166) {
        echo "  ✅ Category count validated\n";
        $passedTests++;
        $results['categories'] = 'PASS';
    } else {
        echo "  ⚠️  Category count low (expected 166+, got $categoryCount)\n";
        $results['categories'] = 'WARN';
    }
} catch (PDOException $e) {
    echo "  ❌ Failed to query categories\n";
    $results['categories'] = 'FAIL';
}
echo "\n";

// Test 6: Attributes
echo "[6/10] Checking Attributes...\n";
$totalTests++;
try {
    $stmt = $pdo->query("SELECT COUNT(*) FROM pim_catalog_attribute");
    $attrCount = $stmt->fetchColumn();
    echo "  Attributes: $attrCount\n";
    if ($attrCount >= 112) {
        echo "  ✅ Attribute count validated\n";
        $passedTests++;
        $results['attributes'] = 'PASS';
    } else {
        echo "  ⚠️  Attribute count low\n";
        $results['attributes'] = 'WARN';
    }
} catch (PDOException $e) {
    echo "  ❌ Failed to query attributes\n";
    $results['attributes'] = 'FAIL';
}
echo "\n";

// Test 7: Families
echo "[7/10] Checking Families...\n";
$totalTests++;
try {
    $stmt = $pdo->query("SELECT COUNT(*) FROM pim_catalog_family");
    $familyCount = $stmt->fetchColumn();
    echo "  Families: $familyCount\n";
    if ($familyCount >= 18) {
        echo "  ✅ Family count validated\n";
        $passedTests++;
        $results['families'] = 'PASS';
    } else {
        echo "  ⚠️  Family count low\n";
        $results['families'] = 'WARN';
    }
} catch (PDOException $e) {
    echo "  ❌ Failed to query families\n";
    $results['families'] = 'FAIL';
}
echo "\n";

// Test 8: Channels
echo "[8/10] Checking Channels...\n";
$totalTests++;
try {
    $stmt = $pdo->query("SELECT code, label FROM pim_catalog_channel");
    $channels = $stmt->fetchAll(PDO::FETCH_ASSOC);
    echo "  Channels: " . count($channels) . "\n";
    foreach ($channels as $channel) {
        echo "    - {$channel['code']}: {$channel['label']}\n";
    }
    if (count($channels) >= 3) {
        echo "  ✅ Channels validated\n";
        $passedTests++;
        $results['channels'] = 'PASS';
    } else {
        echo "  ⚠️  Channel count low\n";
        $results['channels'] = 'WARN';
    }
} catch (PDOException $e) {
    echo "  ❌ Failed to query channels\n";
    $results['channels'] = 'FAIL';
}
echo "\n";

// Test 9: API Accessibility
echo "[9/10] Testing API Accessibility...\n";
$totalTests++;
$ch = curl_init('https://pim.technostationery.com/api/rest/v1/');
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
curl_setopt($ch, CURLOPT_NOBODY, true);
curl_exec($ch);
$httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
curl_close($ch);

if ($httpCode == 401) { // 401 is expected (requires auth)
    echo "  ✅ API endpoint accessible (auth required as expected)\n";
    $passedTests++;
    $results['api'] = 'PASS';
} else {
    echo "  ⚠️  Unexpected API response: HTTP $httpCode\n";
    $results['api'] = 'WARN';
}
echo "\n";

// Test 10: OAuth Clients
echo "[10/10] Checking OAuth Clients...\n";
$totalTests++;
try {
    $stmt = $pdo->query("SELECT COUNT(*) FROM pim_api_client");
    $clientCount = $stmt->fetchColumn();
    echo "  OAuth Clients: $clientCount\n";
    if ($clientCount >= 4) {
        echo "  ✅ OAuth clients configured\n";
        $passedTests++;
        $results['oauth'] = 'PASS';
    } else {
        echo "  ⚠️  OAuth client count low\n";
        $results['oauth'] = 'WARN';
    }
} catch (PDOException $e) {
    echo "  ❌ Failed to query OAuth clients\n";
    $results['oauth'] = 'FAIL';
}
echo "\n";

// Summary
$endTime = microtime(true);
$duration = round($endTime - $startTime, 2);

echo "=== HEALTH CHECK SUMMARY ===\n";
echo "Tests Passed: $passedTests / $totalTests\n";
echo "Success Rate: " . round(($passedTests / $totalTests) * 100, 1) . "%\n";
echo "Duration: {$duration}s\n\n";

echo "Component Status:\n";
foreach ($results as $component => $status) {
    $icon = $status == 'PASS' ? '✅' : ($status == 'WARN' ? '⚠️' : '❌');
    echo "  $icon " . ucfirst(str_replace('_', ' ', $component)) . ": $status\n";
}

echo "\n";
if ($passedTests == $totalTests) {
    echo "✅ ALL SYSTEMS OPERATIONAL\n";
    exit(0);
} elseif ($passedTests >= $totalTests * 0.8) {
    echo "⚠️  SYSTEM OPERATIONAL WITH WARNINGS\n";
    exit(0);
} else {
    echo "❌ SYSTEM ISSUES DETECTED\n";
    exit(1);
}
