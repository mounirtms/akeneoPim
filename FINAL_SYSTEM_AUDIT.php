<?php
/**
 * Final Comprehensive Akeneo PIM System Audit
 * Date: 2026-04-30
 */

echo "=== FINAL COMPREHENSIVE AKENEO PIM SYSTEM AUDIT ===\n";
echo "Date: " . date('Y-m-d H:i:s') . "\n\n";

$host = '127.0.0.1';
$port = '3307';
$db = 'akeneo_pim';
$user = 'akeneo_pim';
$pass = 'akeneo_pim';

try {
    $pdo = new PDO("mysql:host=$host;port=$port;dbname=$db;charset=utf8mb4", $user, $pass);
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    echo "✅ Database connected (port: $port)\n\n";
    
    // 1. PRODUCT DATA STATUS
    echo "=== 1. PRODUCT DATA STATUS ===\n";
    $products = $pdo->query("SELECT COUNT(*) as cnt FROM pim_catalog_product WHERE is_enabled = 1")->fetch()['cnt'];
    $totalProducts = $pdo->query("SELECT COUNT(*) as cnt FROM pim_catalog_product")->fetch()['cnt'];
    $models = $pdo->query("SELECT COUNT(*) as cnt FROM pim_catalog_product_model")->fetch()['cnt'];
    
    echo "  Total products: $totalProducts\n";
    echo "  Enabled products: $products (" . round($products/$totalProducts*100, 2) . "%)\n";
    echo "  Product models: $models\n";
    
    // Count products with images in raw_values
    $withImagesQuery = "SELECT COUNT(DISTINCT p.id) as cnt 
        FROM pim_catalog_product p 
        WHERE p.raw_values LIKE '%image%' 
        AND p.raw_values NOT LIKE '%\"image\":null%'
        AND p.is_enabled = 1";
    $withImages = $pdo->query($withImagesQuery)->fetch()['cnt'];
    echo "  Products with image data: $withImages (" . round($withImages/$products*100, 2) . "%)\n";
    
    // 2. CHANNELS & LOCALES
    echo "\n=== 2. CHANNELS & LOCALES ===\n";
    $channels = $pdo->query("SELECT code, labels FROM pim_catalog_channel")->fetchAll(PDO::FETCH_ASSOC);
    echo "  Active channels:\n";
    foreach ($channels as $ch) {
        $labels = json_decode($ch['labels'], true);
        $label = $labels['en_US'] ?? $labels['fr_FR'] ?? $ch['code'];
        echo "    - {$ch['code']} ($label)\n";
    }
    
    $locales = $pdo->query("SELECT code FROM pim_catalog_locale WHERE is_activated = 1")->fetchAll(PDO::FETCH_COLUMN);
    echo "  Active locales (" . count($locales) . "): " . implode(", ", $locales) . "\n";
    
    // 3. CATEGORIES
    echo "\n=== 3. CATEGORY STRUCTURE ===\n";
    $categories = $pdo->query("SELECT COUNT(*) as cnt FROM pim_catalog_category")->fetch()['cnt'];
    $categoriesWithProducts = $pdo->query("
        SELECT COUNT(DISTINCT c.id) as cnt 
        FROM pim_catalog_category c
        JOIN pim_catalog_category_product cp ON c.id = cp.category_id
    ")->fetch()['cnt'];
    echo "  Total categories: $categories\n";
    echo "  Categories with products: $categoriesWithProducts\n";
    
    // Top categories
    $topCats = $pdo->query("
        SELECT c.code, c.labels, COUNT(cp.product_id) as product_count
        FROM pim_catalog_category c
        LEFT JOIN pim_catalog_category_product cp ON c.id = cp.category_id
        GROUP BY c.id
        ORDER BY product_count DESC
        LIMIT 5
    ")->fetchAll(PDO::FETCH_ASSOC);
    
    echo "  Top 5 categories by product count:\n";
    foreach ($topCats as $cat) {
        $labels = json_decode($cat['labels'], true);
        $label = $labels['fr_FR'] ?? $labels['en_US'] ?? $cat['code'];
        echo "    - $label: {$cat['product_count']} products\n";
    }
    
    // 4. ELASTICSEARCH STATUS
    echo "\n=== 4. ELASTICSEARCH STATUS ===\n";
    $esHost = getenv('ELASTICSEARCH_URL') ?: 'localhost:9200';
    $esUrl = "http://$esHost";
    
    // Try cluster health
    $ch = curl_init("$esUrl/_cluster/health");
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_TIMEOUT, 5);
    $response = curl_exec($ch);
    $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    curl_close($ch);
    
    if ($httpCode == 200 && $response) {
        $health = json_decode($response, true);
        echo "  ✅ Elasticsearch is running\n";
        echo "  Cluster: " . ($health['cluster_name'] ?? 'unknown') . "\n";
        echo "  Status: " . ($health['status'] ?? 'unknown') . "\n";
        echo "  Nodes: " . ($health['number_of_nodes'] ?? 0) . "\n";
        
        // Get indices
        $ch = curl_init("$esUrl/_cat/indices?format=json");
        curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
        curl_setopt($ch, CURLOPT_TIMEOUT, 5);
        $indicesResp = curl_exec($ch);
        curl_close($ch);
        
        if ($indicesResp) {
            $indices = json_decode($indicesResp, true);
            $akeneoIndices = array_filter($indices, function($idx) {
                return strpos($idx['index'], 'akeneo') !== false || strpos($idx['index'], 'pim') !== false;
            });
            
            echo "  Akeneo indices: " . count($akeneoIndices) . "\n";
            foreach ($akeneoIndices as $idx) {
                echo "    - {$idx['index']}: {$idx['docs.count']} docs ({$idx['store.size']})\n";
            }
        }
    } else {
        echo "  ⚠️  Elasticsearch not responding at $esUrl\n";
        echo "  HTTP Code: $httpCode\n";
    }
    
    // 5. FILE SYSTEM
    echo "\n=== 5. FILE SYSTEM STATUS ===\n";
    $paths = [
        'Media' => 'public/media',
        'Cache' => 'var/cache/prod',
        'Images' => 'public/media/product_images'
    ];
    
    foreach ($paths as $name => $path) {
        if (is_dir($path)) {
            $size = trim(shell_exec("du -sh $path 2>/dev/null | cut -f1") ?? '0');
            $files = trim(shell_exec("find $path -type f 2>/dev/null | wc -l") ?? '0');
            echo "  $name: $size ($files files)\n";
        } else {
            echo "  $name: ❌ Not found ($path)\n";
        }
    }
    
    // 6. PENDING IMPORTS
    echo "\n=== 6. PENDING IMPORT FILES ===\n";
    $imports = [
        'Image Import CSV' => '/home/pim/public_html/webapp/image_import_20260429_151054.csv',
        'SEO Metadata CSV' => '/home/pim/public_html/webapp/metadata_exports/metadata_export_20260429_185245.csv'
    ];
    
    $readyForImport = true;
    foreach ($imports as $name => $file) {
        if (file_exists($file)) {
            $sizeMB = round(filesize($file) / 1024 / 1024, 2);
            $lines = trim(shell_exec("wc -l < $file 2>/dev/null") ?? '0');
            echo "  ✅ $name: {$sizeMB}MB ($lines lines)\n";
        } else {
            echo "  ❌ $name: NOT FOUND\n";
            $readyForImport = false;
        }
    }
    
    // 7. MAGENTO CONNECTION
    echo "\n=== 7. MAGENTO FRONTEND STATUS ===\n";
    $magentoUrl = 'https://beta.technostationery.com';
    
    $ch = curl_init($magentoUrl);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_TIMEOUT, 10);
    curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, false);
    curl_setopt($ch, CURLOPT_FOLLOWLOCATION, true);
    $magentoResp = curl_exec($ch);
    $magentoCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    curl_close($ch);
    
    echo "  URL: $magentoUrl\n";
    echo "  HTTP Status: $magentoCode\n";
    
    if ($magentoCode == 200) {
        echo "  ✅ Magento is accessible\n";
        
        // Check for products on homepage
        if (preg_match('/product/i', $magentoResp)) {
            echo "  ✅ Homepage mentions products\n";
        }
    } else {
        echo "  ⚠️  Magento may not be fully accessible\n";
    }
    
    // 8. LAST EXPORT/SYNC
    echo "\n=== 8. LAST EXPORT/SYNC STATUS ===\n";
    $lastJobs = $pdo->query("
        SELECT ji.code, je.status, je.start_time, je.end_time
        FROM akeneo_batch_job_execution je
        JOIN akeneo_batch_job_instance ji ON je.job_instance_id = ji.id
        WHERE ji.code LIKE '%export%' OR ji.code LIKE '%publish%'
        ORDER BY je.start_time DESC
        LIMIT 3
    ")->fetchAll(PDO::FETCH_ASSOC);
    
    if (count($lastJobs) > 0) {
        foreach ($lastJobs as $job) {
            echo "  - {$job['code']}: {$job['status']} (started: {$job['start_time']})\n";
        }
    } else {
        echo "  ⚠️  No export/publish jobs found in history\n";
    }
    
    // 9. CRITICAL ISSUES & RECOMMENDATIONS
    echo "\n=== 9. CRITICAL ANALYSIS ===\n";
    
    $critical = [];
    $warnings = [];
    $recommendations = [];
    
    // Check image coverage
    $imagePercentage = round($withImages/$products*100, 2);
    if ($imagePercentage < 50) {
        $critical[] = "Very low image coverage ($imagePercentage%)";
        $recommendations[] = "URGENT: Import product images immediately";
    } elseif ($imagePercentage < 80) {
        $warnings[] = "Image coverage below target ($imagePercentage%)";
        $recommendations[] = "Import remaining product images";
    }
    
    // Check Elasticsearch
    if ($httpCode != 200) {
        $critical[] = "Elasticsearch not responding";
        $recommendations[] = "URGENT: Check and restart Elasticsearch service";
    }
    
    // Check Magento
    if ($magentoCode != 200) {
        $warnings[] = "Magento frontend not fully accessible";
        $recommendations[] = "Verify Magento installation and configuration";
    }
    
    // Check import files
    if (!$readyForImport) {
        $warnings[] = "Some import files are missing";
        $recommendations[] = "Regenerate missing import files";
    }
    
    // Display results
    if (count($critical) > 0) {
        echo "  🔴 CRITICAL ISSUES:\n";
        foreach ($critical as $issue) {
            echo "    - $issue\n";
        }
    }
    
    if (count($warnings) > 0) {
        echo "  ⚠️  WARNINGS:\n";
        foreach ($warnings as $warning) {
            echo "    - $warning\n";
        }
    }
    
    if (count($critical) == 0 && count($warnings) == 0) {
        echo "  ✅ No critical issues found\n";
    }
    
    echo "\n  📋 RECOMMENDATIONS:\n";
    if (count($recommendations) > 0) {
        foreach ($recommendations as $i => $rec) {
            echo "    " . ($i+1) . ". $rec\n";
        }
    } else {
        echo "    - System is healthy, ready for production\n";
    }
    
    // 10. ACTION PLAN
    echo "\n=== 10. IMMEDIATE ACTION PLAN ===\n";
    echo "  Phase 1: Data Finalization (Now)\n";
    echo "    ☐ Import product images (9,399 products)\n";
    echo "    ☐ Import SEO metadata (9,538 products)\n";
    echo "    ☐ Recalculate product completeness\n";
    echo "\n";
    echo "  Phase 2: Elasticsearch Optimization (After imports)\n";
    echo "    ☐ Check Elasticsearch service status\n";
    echo "    ☐ Reindex all product data\n";
    echo "    ☐ Optimize index settings\n";
    echo "    ☐ Test search performance\n";
    echo "\n";
    echo "  Phase 3: Magento Sync (After reindex)\n";
    echo "    ☐ Run full product export to Magento\n";
    echo "    ☐ Clear Magento cache\n";
    echo "    ☐ Reindex Magento catalog\n";
    echo "    ☐ Regenerate product images in Magento\n";
    echo "\n";
    echo "  Phase 4: Frontend Validation (Final)\n";
    echo "    ☐ Test category pages\n";
    echo "    ☐ Test product detail pages\n";
    echo "    ☐ Test search functionality\n";
    echo "    ☐ Verify image loading\n";
    echo "    ☐ Check page load times\n";
    echo "\n";
    
    echo "  Estimated Time: 4-6 hours total\n";
    
} catch (PDOException $e) {
    echo "❌ Database error: " . $e->getMessage() . "\n";
}

echo "\n=== AUDIT COMPLETED ===\n";
echo "Date: " . date('Y-m-d H:i:s') . "\n";
