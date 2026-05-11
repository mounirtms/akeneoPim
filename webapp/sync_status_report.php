<?php
/**
 * Akeneo-Magento Sync Status and Data Quality Report
 */

// Akeneo PIM Connection
$akeneoDb = new PDO("mysql:host=127.0.0.1;port=3307;dbname=akeneo_pim", 'root', 'YourNewStrongPassword');
$akeneoDb->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);

// Magento Connection
$magentoDb = new PDO("mysql:host=127.0.0.1;port=3307;dbname=beta_dBT8x12y22", 'beta_ntdbusr24', 'the-correct-password');
$magentoDb->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);

echo "========================================\n";
echo "AKENEO ↔ MAGENTO SYNC & DATA QUALITY\n";
echo "========================================\n";
echo "Generated: " . date('Y-m-d H:i:s') . "\n\n";

// AKENEO STATUS
echo "1. AKENEO PIM STATUS\n";
echo "   ------------------\n";

$stmt = $akeneoDb->query("SELECT COUNT(*) FROM pim_catalog_product WHERE is_enabled = 1");
$akeneoProducts = $stmt->fetchColumn();
echo "   Total products: $akeneoProducts\n";

$stmt = $akeneoDb->query("
    SELECT COUNT(DISTINCT p.id) 
    FROM pim_catalog_product p
    WHERE p.raw_values LIKE '%\"image\"%'
");
$akeneoWithImages = $stmt->fetchColumn();
echo "   Products with images: $akeneoWithImages (" . round($akeneoWithImages/$akeneoProducts*100, 1) . "%)\n";

$stmt = $akeneoDb->query("SELECT COUNT(*) FROM pim_catalog_category");
$akeneoCategories = $stmt->fetchColumn();
echo "   Total categories: $akeneoCategories\n";

$stmt = $akeneoDb->query("SELECT COUNT(*) FROM akeneo_file_storage_file_info");
$akeneoFiles = $stmt->fetchColumn();
echo "   Total image files: $akeneoFiles\n";

// MAGENTO STATUS
echo "\n2. MAGENTO STATUS\n";
echo "   --------------\n";

$stmt = $magentoDb->query("SELECT COUNT(*) FROM catalog_product_entity");
$magentoProducts = $stmt->fetchColumn();
echo "   Total products: $magentoProducts\n";

$stmt = $magentoDb->query("
    SELECT COUNT(DISTINCT mgve.entity_id)
    FROM catalog_product_entity_media_gallery_value_to_entity mgve
");
$magentoWithImages = $stmt->fetchColumn();
echo "   Products with images: $magentoWithImages (" . round($magentoWithImages/$magentoProducts*100, 1) . "%)\n";

$stmt = $magentoDb->query("SELECT COUNT(*) FROM catalog_category_entity WHERE level > 1");
$magentoCategories = $stmt->fetchColumn();
echo "   Total categories: $magentoCategories\n";

$stmt = $magentoDb->query("SELECT COUNT(*) FROM catalog_category_product");
$magentoCategoryLinks = $stmt->fetchColumn();
echo "   Product-category links: $magentoCategoryLinks\n";

// SYNC COMPARISON
echo "\n3. SYNC COMPARISON\n";
echo "   ---------------\n";

$productDiff = abs($akeneoProducts - $magentoProducts);
$productMatch = round(min($akeneoProducts, $magentoProducts) / max($akeneoProducts, $magentoProducts) * 100, 1);
echo "   Product sync: $productMatch%\n";
if ($productDiff > 0) {
    echo "   ⚠ Difference: $productDiff products\n";
} else {
    echo "   ✓ Products in sync\n";
}

$imageDiff = abs($akeneoWithImages - $magentoWithImages);
$imageMatch = round(min($akeneoWithImages, $magentoWithImages) / max($akeneoWithImages, $magentoWithImages) * 100, 1);
echo "   Image sync: $imageMatch%\n";
if ($imageDiff > 100) {
    echo "   ⚠ Difference: $imageDiff products with images\n";
} else {
    echo "   ✓ Images mostly in sync\n";
}

// DATA QUALITY
echo "\n4. DATA QUALITY (Magento)\n";
echo "   ----------------------\n";

$stmt = $magentoDb->query("
    SELECT COUNT(*) FROM catalog_product_entity cpe
    LEFT JOIN catalog_product_entity_varchar cpev ON cpe.entity_id = cpev.entity_id
    AND cpev.attribute_id = (SELECT attribute_id FROM eav_attribute WHERE attribute_code = 'name' AND entity_type_id = 4)
    WHERE cpev.value IS NULL OR cpev.value = ''
");
$noName = $stmt->fetchColumn();
echo "   Products without name: $noName\n";

$stmt = $magentoDb->query("
    SELECT COUNT(*) FROM catalog_product_entity cpe
    LEFT JOIN catalog_product_entity_text cpet ON cpe.entity_id = cpet.entity_id
    AND cpet.attribute_id = (SELECT attribute_id FROM eav_attribute WHERE attribute_code = 'description' AND entity_type_id = 4)
    WHERE cpet.value IS NULL OR cpet.value = ''
");
$noDescription = $stmt->fetchColumn();
echo "   Products without description: $noDescription\n";

$stmt = $magentoDb->query("
    SELECT COUNT(*) FROM catalog_product_entity cpe
    LEFT JOIN catalog_product_entity_decimal cped ON cpe.entity_id = cped.entity_id
    AND cped.attribute_id = (SELECT attribute_id FROM eav_attribute WHERE attribute_code = 'price' AND entity_type_id = 4)
    WHERE cped.value IS NULL OR cped.value = 0
");
$noPrice = $stmt->fetchColumn();
echo "   Products without price: $noPrice\n";

$stmt = $magentoDb->query("
    SELECT COUNT(*) FROM catalog_product_entity cpe
    LEFT JOIN catalog_category_product ccp ON cpe.entity_id = ccp.product_id
    WHERE ccp.category_id IS NULL
");
$noCategory = $stmt->fetchColumn();
echo "   Products without category: $noCategory\n";

// PRODUCT TYPES
echo "\n5. PRODUCT TYPES (Magento)\n";
echo "   -----------------------\n";

$stmt = $magentoDb->query("
    SELECT type_id, COUNT(*) as count
    FROM catalog_product_entity
    GROUP BY type_id
    ORDER BY count DESC
");
$types = $stmt->fetchAll(PDO::FETCH_ASSOC);
foreach ($types as $type) {
    $pct = round($type['count'] / $magentoProducts * 100, 1);
    echo "   " . str_pad($type['type_id'], 15) . ": " . $type['count'] . " ($pct%)\n";
}

// QUALITY SCORE
echo "\n6. OVERALL QUALITY SCORE\n";
echo "   ---------------------\n";

$score = 0;
$maxScore = 100;

// Product sync (20 points)
$score += ($productMatch / 100) * 20;

// Image sync (20 points)
$score += ($imageMatch / 100) * 20;

// Name completion (15 points)
$score += ((1 - $noName / $magentoProducts) * 15);

// Description completion (15 points)
$score += ((1 - $noDescription / $magentoProducts) * 15);

// Price completion (15 points)
$score += ((1 - $noPrice / $magentoProducts) * 15);

// Category assignment (15 points)
$score += ((1 - $noCategory / $magentoProducts) * 15);

$scoreRounded = round($score, 1);
echo "   Score: $scoreRounded / $maxScore\n";

if ($scoreRounded >= 90) {
    echo "   Grade: A (Excellent) ✓\n";
} elseif ($scoreRounded >= 80) {
    echo "   Grade: B (Good)\n";
} elseif ($scoreRounded >= 70) {
    echo "   Grade: C (Fair)\n";
} elseif ($scoreRounded >= 60) {
    echo "   Grade: D (Poor) ⚠\n";
} else {
    echo "   Grade: F (Critical) ✗\n";
}

// RECOMMENDATIONS
echo "\n7. RECOMMENDATIONS\n";
echo "   ---------------\n";

if ($productDiff > 0) {
    echo "   • Sync remaining $productDiff products\n";
}
if ($noName > 100) {
    echo "   • Add names to $noName products\n";
}
if ($noDescription > 100) {
    echo "   • Add descriptions to $noDescription products\n";
}
if ($noPrice > 0) {
    echo "   • Add prices to $noPrice products\n";
}
if ($noCategory > 0) {
    echo "   • Assign categories to $noCategory products\n";
}
if ($imageDiff > 100) {
    echo "   • Sync remaining $imageDiff product images\n";
}
if ($scoreRounded >= 80) {
    echo "   ✓ Platform is production-ready!\n";
}

echo "\n========================================\n";
echo "Report complete!\n";
echo "========================================\n";
