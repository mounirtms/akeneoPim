<?php
/**
 * Comprehensive Akeneo PIM System Health Check
 * Date: 2026-04-29
 */

echo "=== COMPREHENSIVE AKENEO PIM SYSTEM CHECK ===\n";
echo "Date: " . date('Y-m-d H:i:s') . "\n\n";

$host = 'localhost';
$db = 'pim';
$user = 'pim';
$pass = 'Mounter@2026!Secure';

try {
    $pdo = new PDO("mysql:host=$host;dbname=$db;charset=utf8mb4", $user, $pass);
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    echo "✅ Database connected\n\n";
    
    // 1. PRODUCT DATA CHECK
    echo "=== 1. PRODUCT DATA STATUS ===\n";
    $products = $pdo->query("SELECT COUNT(*) as cnt FROM pim_catalog_product WHERE is_enabled = 1")->fetch()['cnt'];
    $models = $pdo->query("SELECT COUNT(*) as cnt FROM pim_catalog_product_model")->fetch()['cnt'];
    echo "  Products (enabled): $products\n";
    echo "  Product Models: $models\n";
    
    // Check products with images
    $withImages = $pdo->query("
        SELECT COUNT(DISTINCT p.id) as cnt 
        FROM pim_catalog_product p
        JOIN pim_catalog_product_unique_data ud ON p.id = ud.product_id
        WHERE ud.attribute_id IN (
            SELECT id FROM pim_catalog_attribute WHERE code IN ('image', 'thumbnail', 'small_image')
        ) AND ud.raw_data IS NOT NULL AND ud.raw_data != 'null'
    ")->fetch()['cnt'];
    echo "  Products with images: $withImages (" . round($withImages/$products*100, 2) . "%)\n";
    
    // 2. CHANNEL & LOCALE CHECK
    echo "\n=== 2. CHANNELS & LOCALES ===\n";
    $channels = $pdo->query("SELECT code, label FROM pim_catalog_channel")->fetchAll(PDO::FETCH_ASSOC);
    echo "  Active Channels:\n";
    foreach ($channels as $ch) {
        $labels = json_decode($ch['label'], true);
        echo "    - " . $ch['code'] . " (" . ($labels['en_US'] ?? $labels['fr_FR'] ?? $ch['code']) . ")\n";
    }
    
    $locales = $pdo->query("SELECT code FROM pim_catalog_locale WHERE is_activated = 1")->fetchAll(PDO::FETCH_COLUMN);
    echo "  Active Locales: " . implode(", ", $locales) . "\n";
    
    // 3. COMPLETENESS CHECK
    echo "\n=== 3. PRODUCT COMPLETENESS ===\n";
    $completeProducts = $pdo->query("
        SELECT COUNT(*) as cnt FROM pim_catalog_product p
        WHERE NOT EXISTS (
            SELECT 1 FROM pim_catalog_attribute a
            JOIN pim_catalog_family_attribute fa ON a.id = fa.attribute_id
            WHERE fa.family_id = p.family_id
            AND a.is_required = 1
            AND NOT EXISTS (
                SELECT 1 FROM pim_catalog_product_unique_data ud
                WHERE ud.product_id = p.id AND ud.attribute_id = a.id
                AND ud.raw_data IS NOT NULL AND ud.raw_data != 'null'
            )
        )
    ")->fetch()['cnt'];
    echo "  Complete products: $completeProducts (" . round($completeProducts/$products*100, 2) . "%)\n";
    
    // 4. CHECK MAGENTO SYNC STATUS
    echo "\n=== 4. MAGENTO SYNC STATUS ===\n";
    $lastExport = $pdo->query("
        SELECT created_at, status, code 
        FROM akeneo_batch_job_execution 
        WHERE job_instance_id IN (
            SELECT id FROM akeneo_batch_job_instance WHERE code LIKE '%export%' OR code LIKE '%publish%'
        )
        ORDER BY created_at DESC LIMIT 1
    ")->fetch(PDO::FETCH_ASSOC);
    
    if ($lastExport) {
        echo "  Last export: " . $lastExport['created_at'] . "\n";
        echo "  Status: " . $lastExport['status'] . "\n";
        echo "  Job: " . $lastExport['code'] . "\n";
    } else {
        echo "  ⚠️  No export jobs found\n";
    }
    
    // 5. CHECK ELASTICSEARCH STATUS
    echo "\n=== 5. ELASTICSEARCH STATUS ===\n";
    $esHost = getenv('ELASTICSEARCH_HOST') ?: 'localhost:9200';
    $esUrl = "http://$esHost/_cluster/health";
    
    $ch = curl_init($esUrl);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_TIMEOUT, 5);
    $response = curl_exec($ch);
    $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    curl_close($ch);
    
    if ($httpCode == 200 && $response) {
        $health = json_decode($response, true);
        echo "  Cluster: " . ($health['cluster_name'] ?? 'unknown') . "\n";
        echo "  Status: " . ($health['status'] ?? 'unknown') . "\n";
        echo "  Nodes: " . ($health['number_of_nodes'] ?? '0') . "\n";
        
        // Check indices
        $indicesUrl = "http://$esHost/_cat/indices?format=json";
        $ch = curl_init($indicesUrl);
        curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
        curl_setopt($ch, CURLOPT_TIMEOUT, 5);
        $indicesResponse = curl_exec($ch);
        curl_close($ch);
        
        if ($indicesResponse) {
            $indices = json_decode($indicesResponse, true);
            echo "  Indices: " . count($indices) . "\n";
            echo "  Akeneo indices:\n";
            foreach ($indices as $idx) {
                if (strpos($idx['index'], 'akeneo') !== false || strpos($idx['index'], 'pim') !== false) {
                    echo "    - " . $idx['index'] . " (docs: " . $idx['docs.count'] . ", size: " . $idx['store.size'] . ")\n";
                }
            }
        }
    } else {
        echo "  ⚠️  Elasticsearch not responding (tried: $esUrl)\n";
    }
    
    // 6. FILE SYSTEM CHECK
    echo "\n=== 6. FILE SYSTEM STATUS ===\n";
    $mediaPath = 'public/media';
    $cachePath = 'var/cache/prod';
    
    if (is_dir($mediaPath)) {
        $mediaSize = shell_exec("du -sh $mediaPath 2>/dev/null | cut -f1");
        echo "  Media directory: $mediaPath ($mediaSize)\n";
    } else {
        echo "  ⚠️  Media directory not found: $mediaPath\n";
    }
    
    if (is_dir($cachePath)) {
        $cacheSize = shell_exec("du -sh $cachePath 2>/dev/null | cut -f1");
        echo "  Cache directory: $cachePath ($cacheSize)\n";
    }
    
    // 7. PENDING IMPORTS
    echo "\n=== 7. PENDING IMPORT FILES ===\n";
    $importFiles = [
        'Image Import' => '/home/pim/public_html/webapp/image_import_20260429_151054.csv',
        'SEO Metadata' => '/home/pim/public_html/webapp/metadata_exports/metadata_export_20260429_185245.csv'
    ];
    
    foreach ($importFiles as $name => $file) {
        if (file_exists($file)) {
            $size = filesize($file);
            $sizeHuman = round($size / 1024 / 1024, 2) . " MB";
            echo "  ✅ $name: $sizeHuman\n";
        } else {
            echo "  ❌ $name: NOT FOUND\n";
        }
    }
    
    // 8. MAGENTO CONNECTION CHECK
    echo "\n=== 8. MAGENTO FRONTEND CHECK ===\n";
    $magentoUrl = 'https://beta.technostationery.com';
    
    $ch = curl_init($magentoUrl);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_TIMEOUT, 10);
    curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, false);
    curl_setopt($ch, CURLOPT_FOLLOWLOCATION, true);
    $magentoResponse = curl_exec($ch);
    $magentoCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    curl_close($ch);
    
    echo "  Magento URL: $magentoUrl\n";
    echo "  HTTP Status: $magentoCode\n";
    if ($magentoCode == 200) {
        $productCount = preg_match_all('/product/i', $magentoResponse, $matches);
        echo "  Response contains 'product': $productCount times\n";
        echo "  ✅ Magento is responding\n";
    } else {
        echo "  ⚠️  Magento may not be accessible\n";
    }
    
    // 9. SUMMARY & RECOMMENDATIONS
    echo "\n=== 9. SUMMARY & RECOMMENDATIONS ===\n";
    
    $issues = [];
    $recommendations = [];
    
    if ($withImages < $products * 0.5) {
        $issues[] = "Low image coverage ($withImages/$products)";
        $recommendations[] = "Import product images from image_import_20260429_151054.csv";
    }
    
    if ($completeProducts < $products * 0.8) {
        $issues[] = "Product completeness below 80%";
        $recommendations[] = "Review required attributes and fill missing data";
    }
    
    if ($httpCode != 200) {
        $issues[] = "Elasticsearch not responding";
        $recommendations[] = "Check Elasticsearch service status and configuration";
    }
    
    if (count($issues) == 0) {
        echo "  ✅ No critical issues found\n";
    } else {
        echo "  ⚠️  Issues Found:\n";
        foreach ($issues as $issue) {
            echo "    - $issue\n";
        }
    }
    
    echo "\n  📋 Recommendations:\n";
    if (count($recommendations) == 0) {
        echo "    - System is healthy, proceed with Magento sync\n";
    } else {
        foreach ($recommendations as $rec) {
            echo "    - $rec\n";
        }
    }
    
    echo "\n  🚀 Next Steps:\n";
    echo "    1. Import product images (high priority)\n";
    echo "    2. Import SEO metadata (high priority)\n";
    echo "    3. Reindex Elasticsearch\n";
    echo "    4. Sync to Magento\n";
    echo "    5. Clear Magento cache\n";
    echo "    6. Verify frontend catalog display\n";
    
} catch (PDOException $e) {
    echo "❌ Database error: " . $e->getMessage() . "\n";
}

echo "\n=== CHECK COMPLETED ===\n";
echo "Date: " . date('Y-m-d H:i:s') . "\n";
