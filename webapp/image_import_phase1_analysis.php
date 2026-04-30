#!/usr/bin/env php
<?php
/**
 * Akeneo Image Import - Phase 1: Analysis
 * 
 * Analyzes Magento images and creates mapping for Akeneo import
 * This is a safe read-only analysis before any import
 */

$magentoImagePath = '/home/technadminy7/public_html/pub/media/catalog/product';
$akeneoDbHost = '127.0.0.1';
$akeneoDbPort = '3307';
$akeneoDbName = 'akeneo_pim';
$akeneoDbUser = 'akeneo_pim';
$akeneoDbPass = 'akeneo_pim';

echo "\n";
echo "=========================================\n";
echo "Akeneo Image Import - Analysis Phase\n";
echo "=========================================\n\n";

try {
    // Connect to Akeneo database
    $pdo = new PDO(
        "mysql:host=$akeneoDbHost;port=$akeneoDbPort;dbname=$akeneoDbName;charset=utf8mb4",
        $akeneoDbUser,
        $akeneoDbPass,
        [PDO::ERRMODE => PDO::ERRMODE_EXCEPTION]
    );
    
    echo "📊 STEP 1: Analyzing Magento Images\n";
    echo "-------------------------------------------\n";
    
    // Count total images
    $imageCount = exec("find $magentoImagePath -type f \\( -name '*.jpg' -o -name '*.jpeg' -o -name '*.png' -o -name '*.gif' \\) | wc -l");
    echo "Total images in Magento: " . number_format($imageCount) . "\n";
    
    // Get sample images
    $sampleImages = [];
    exec("find $magentoImagePath -type f -name '*.jpg' | head -10", $sampleImages);
    
    echo "\nSample image paths:\n";
    foreach (array_slice($sampleImages, 0, 3) as $img) {
        echo "  - " . basename($img) . "\n";
    }
    
    echo "\n📊 STEP 2: Analyzing Akeneo Products\n";
    echo "-------------------------------------------\n";
    
    // Get products without images
    $productsWithoutImages = $pdo->query("
        SELECT COUNT(*) 
        FROM pim_catalog_product p
        WHERE p.raw_values NOT LIKE '%\"image\"%'
        OR p.raw_values LIKE '%\"image\":%null%'
    ")->fetchColumn();
    
    $totalProducts = $pdo->query("SELECT COUNT(*) FROM pim_catalog_product")->fetchColumn();
    $productsWithImages = $totalProducts - $productsWithoutImages;
    
    echo "Total products: " . number_format($totalProducts) . "\n";
    echo "Products with images: " . number_format($productsWithImages) . " (" . 
        round(($productsWithImages/$totalProducts)*100, 1) . "%)\n";
    echo "Products without images: " . number_format($productsWithoutImages) . " (" . 
        round(($productsWithoutImages/$totalProducts)*100, 1) . "%)\n";
    
    echo "\n📊 STEP 3: Image Attribute Analysis\n";
    echo "-------------------------------------------\n";
    
    // Get image attributes
    $imageAttrs = $pdo->query("
        SELECT code, attribute_type 
        FROM pim_catalog_attribute 
        WHERE attribute_type = 'pim_catalog_image'
        ORDER BY code
    ")->fetchAll(PDO::FETCH_ASSOC);
    
    echo "Image attributes in Akeneo:\n";
    foreach ($imageAttrs as $attr) {
        echo "  - " . $attr['code'] . "\n";
    }
    
    echo "\n📊 STEP 4: Sample Product Analysis\n";
    echo "-------------------------------------------\n";
    
    // Get sample products with their identifiers
    $sampleProducts = $pdo->query("
        SELECT identifier, 
               CASE 
                   WHEN raw_values LIKE '%\"image\"%' THEN 'Has image attr'
                   ELSE 'No image attr'
               END as image_status
        FROM pim_catalog_product 
        LIMIT 5
    ")->fetchAll(PDO::FETCH_ASSOC);
    
    echo "Sample products:\n";
    foreach ($sampleProducts as $prod) {
        echo "  SKU: " . $prod['identifier'] . " - " . $prod['image_status'] . "\n";
    }
    
    echo "\n📊 STEP 5: Image Matching Strategy\n";
    echo "-------------------------------------------\n";
    
    echo "Strategy options:\n";
    echo "1. Direct match: SKU.jpg (e.g., 1140619022.jpg)\n";
    echo "2. Directory structure: first_char/second_char/SKU.jpg\n";
    echo "3. Pattern matching: Find images containing SKU\n";
    
    // Try to find images for sample products
    echo "\nTesting image matching for sample SKUs:\n";
    $testSkus = array_slice(array_column($sampleProducts, 'identifier'), 0, 3);
    
    foreach ($testSkus as $sku) {
        // Try direct match
        $found = exec("find $magentoImagePath -type f -name '$sku.jpg' 2>/dev/null | head -1");
        if ($found) {
            echo "  ✅ SKU $sku: Found direct match\n";
        } else {
            // Try pattern match
            $found = exec("find $magentoImagePath -type f -name '*$sku*.jpg' 2>/dev/null | head -1");
            if ($found) {
                echo "  ⚠️  SKU $sku: Found pattern match: " . basename($found) . "\n";
            } else {
                echo "  ❌ SKU $sku: No image found\n";
            }
        }
    }
    
    echo "\n📊 STEP 6: Storage Requirements\n";
    echo "-------------------------------------------\n";
    
    // Calculate storage requirements
    $totalSize = exec("du -sh $magentoImagePath 2>/dev/null | cut -f1");
    $avgSize = exec("find $magentoImagePath -type f -name '*.jpg' -exec ls -l {} \\; | awk '{sum+=\$5; count++} END {print int(sum/count)}' 2>/dev/null");
    
    echo "Total Magento image storage: $totalSize\n";
    echo "Average image size: " . number_format($avgSize) . " bytes (" . round($avgSize/1024, 2) . " KB)\n";
    
    // Check Akeneo storage space
    $akeneoStorage = exec("du -sh /home/pim/public_html/var/file_storage/catalog 2>/dev/null | cut -f1");
    echo "Current Akeneo storage: $akeneoStorage\n";
    
    echo "\n📊 STEP 7: Recommendations\n";
    echo "-------------------------------------------\n";
    
    $matchRate = round(($imageCount / $totalProducts), 1);
    
    if ($matchRate > 20) {
        echo "⚠️  WARNING: Very high image-to-product ratio ($matchRate:1)\n";
        echo "   Multiple images per product detected\n";
        echo "   Recommended: Import main product image only first\n\n";
    }
    
    echo "Recommended import strategy:\n";
    echo "1. Start with main 'image' attribute only\n";
    echo "2. Import 100 products as test batch\n";
    echo "3. Verify in Akeneo PIM\n";
    echo "4. Then proceed with full import\n";
    echo "5. Add other image types (thumbnail, etc.) later\n";
    
    echo "\n📊 STEP 8: Next Actions\n";
    echo "-------------------------------------------\n";
    
    echo "To proceed with import:\n";
    echo "1. Review this analysis\n";
    echo "2. Run: php image_import_phase2.php (will create mapping)\n";
    echo "3. Run: php image_import_phase3.php (will import images)\n";
    echo "4. Verify in Akeneo PIM\n";
    
    echo "\n=========================================\n";
    echo "Analysis Complete!\n";
    echo "=========================================\n\n";
    
    // Save analysis report
    $report = [
        'timestamp' => date('Y-m-d H:i:s'),
        'magento_images' => (int)$imageCount,
        'akeneo_products' => $totalProducts,
        'products_with_images' => $productsWithImages,
        'products_without_images' => $productsWithoutImages,
        'image_attributes' => count($imageAttrs),
        'storage_size' => $totalSize,
        'recommendations' => [
            'start_with_main_image_only',
            'test_batch_100_products',
            'verify_before_full_import'
        ]
    ];
    
    file_put_contents(__DIR__ . '/image_analysis_' . date('Ymd_His') . '.json', json_encode($report, JSON_PRETTY_PRINT));
    echo "📄 Analysis saved to: image_analysis_" . date('Ymd_His') . ".json\n\n";
    
} catch (Exception $e) {
    echo "❌ Error: " . $e->getMessage() . "\n\n";
    exit(1);
}
