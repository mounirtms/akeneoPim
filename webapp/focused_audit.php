<?php
/**
 * Focused Next Phase Audit
 */

$db = new mysqli('127.0.0.1', 'root', 'YourNewStrongPassword', 'akeneo_pim', 3307);
if ($db->connect_error) die("Connection failed: " . $db->connect_error);

echo "=== FOCUSED AUDIT - " . date('Y-m-d H:i:s') . " ===\n\n";

// 1. COLOR ATTRIBUTE ANALYSIS
echo "🎨 COLOR ATTRIBUTE\n" . str_repeat("=", 70) . "\n";
$result = $db->query("SELECT a.id, a.code, COUNT(DISTINCT ao.id) as options
    FROM pim_catalog_attribute a
    LEFT JOIN pim_catalog_attribute_option ao ON a.id = ao.attribute_id
    WHERE a.code = 'color' GROUP BY a.id, a.code");
$color = $result->fetch_assoc();
echo "Total Options: " . $color['options'] . "\n";

// Color usage
$result = $db->query("SELECT COUNT(*) as cnt FROM pim_catalog_product 
    WHERE enabled = 1 AND JSON_EXTRACT(raw_values, '$.color') IS NOT NULL");
$usage = $result->fetch_assoc();
echo "Products Using Color: " . $usage['cnt'] . "\n";

// Missing English translations
$result = $db->query("SELECT COUNT(DISTINCT ao.id) as missing
    FROM pim_catalog_attribute_option ao
    JOIN pim_catalog_attribute a ON ao.attribute_id = a.id
    LEFT JOIN pim_catalog_attribute_option_value aov ON ao.id = aov.option_id AND aov.locale_code = 'en_US'
    WHERE a.code = 'color' AND aov.id IS NULL");
$missing = $result->fetch_assoc();
echo "Options Missing English: " . $missing['missing'] . " of " . $color['options'] . "\n";

// 2. COMPLETENESS STATUS
echo "\n✅ COMPLETENESS\n" . str_repeat("=", 70) . "\n";
$result = $db->query("SELECT 
    ch.code, l.code as locale,
    COUNT(DISTINCT c.product_id) as products,
    ROUND(AVG(c.required_count), 2) as avg_req,
    ROUND(AVG(c.missing_count), 2) as avg_miss,
    SUM(CASE WHEN c.missing_count = 0 THEN 1 ELSE 0 END) as complete
    FROM pim_catalog_completeness c
    JOIN pim_catalog_channel ch ON c.channel_id = ch.id
    JOIN pim_catalog_locale l ON c.locale_id = l.id
    GROUP BY ch.code, l.code");

while ($row = $result->fetch_assoc()) {
    $pct = $row['products'] > 0 ? round($row['complete']/$row['products']*100, 1) : 0;
    echo sprintf("%s-%s: %s products, %.1f%% complete (avg %s req, %s miss)\n",
        strtoupper($row['code']), $row['locale'], 
        number_format($row['products']), $pct,
        $row['avg_req'], $row['avg_miss']);
}

// 3. PRICE DATA
echo "\n💰 PRICE DATA\n" . str_repeat("=", 70) . "\n";
$result = $db->query("SELECT 
    COUNT(*) as total,
    SUM(CASE WHEN JSON_EXTRACT(raw_values, '$.price') IS NOT NULL THEN 1 ELSE 0 END) as with_price
    FROM pim_catalog_product WHERE enabled = 1");
$price = $result->fetch_assoc();
$pct = round($price['with_price']/$price['total']*100, 2);
echo "Products: " . number_format($price['total']) . "\n";
echo "With Price: " . number_format($price['with_price']) . " ($pct%)\n";
echo "Missing: " . number_format($price['total'] - $price['with_price']) . "\n";

// 4. IMAGE DATA
echo "\n🖼️  IMAGE DATA\n" . str_repeat("=", 70) . "\n";
$result = $db->query("SELECT 
    COUNT(*) as total,
    SUM(CASE WHEN JSON_EXTRACT(raw_values, '$.image') IS NOT NULL THEN 1 ELSE 0 END) as with_image,
    SUM(CASE WHEN JSON_EXTRACT(raw_values, '$.gallery') IS NOT NULL THEN 1 ELSE 0 END) as with_gallery
    FROM pim_catalog_product WHERE enabled = 1");
$media = $result->fetch_assoc();
echo "With Image: " . number_format($media['with_image']) . " (" . 
    round($media['with_image']/$media['total']*100, 1) . "%)\n";
echo "With Gallery: " . number_format($media['with_gallery']) . " (" . 
    round($media['with_gallery']/$media['total']*100, 1) . "%)\n";

// 5. WEIGHT DATA
echo "\n⚖️  WEIGHT DATA\n" . str_repeat("=", 70) . "\n";
$result = $db->query("SELECT 
    COUNT(*) as total,
    SUM(CASE WHEN JSON_EXTRACT(raw_values, '$.weight') IS NOT NULL THEN 1 ELSE 0 END) as with_weight
    FROM pim_catalog_product WHERE enabled = 1");
$weight = $result->fetch_assoc();
$pct = round($weight['with_weight']/$weight['total']*100, 2);
echo "With Weight: " . number_format($weight['with_weight']) . " ($pct%)\n";
echo "Missing: " . number_format($weight['total'] - $weight['with_weight']) . "\n";

// 6. ENGLISH CONTENT
echo "\n🌐 ENGLISH CONTENT\n" . str_repeat("=", 70) . "\n";
$result = $db->query("SELECT 
    COUNT(*) as total,
    SUM(CASE WHEN JSON_CONTAINS_PATH(raw_values, 'one', '$.name[*]') AND 
        JSON_SEARCH(JSON_EXTRACT(raw_values, '$.name[*].locale'), 'one', 'en_US') IS NOT NULL THEN 1 ELSE 0 END) as with_en_name
    FROM pim_catalog_product WHERE enabled = 1");
$en = $result->fetch_assoc();
$pct = round($en['with_en_name']/$en['total']*100, 2);
echo "Products with EN Name: " . number_format($en['with_en_name']) . " ($pct%)\n";
echo "Missing EN Name: " . number_format($en['total'] - $en['with_en_name']) . "\n";

// 7. COMPLEX ATTRIBUTES
echo "\n🔍 COMPLEX ATTRIBUTES\n" . str_repeat("=", 70) . "\n";
$types = ['pim_catalog_price_collection', 'pim_catalog_metric', 'pim_catalog_image', 
          'pim_catalog_multiselect', 'pim_catalog_textarea'];
foreach ($types as $type) {
    $result = $db->query("SELECT COUNT(*) as cnt FROM pim_catalog_attribute WHERE attribute_type = '$type'");
    $row = $result->fetch_assoc();
    echo str_pad(str_replace('pim_catalog_', '', $type), 25) . ": " . $row['cnt'] . " attributes\n";
}

// 8. ATTRIBUTE GROUPS
echo "\n📦 ATTRIBUTE GROUPS\n" . str_repeat("=", 70) . "\n";
$result = $db->query("SELECT ag.code, COUNT(DISTINCT a.id) as attr_count
    FROM pim_catalog_attribute_group ag
    LEFT JOIN pim_catalog_attribute a ON ag.id = a.group_id
    GROUP BY ag.code ORDER BY attr_count DESC");
$empty = [];
while ($row = $result->fetch_assoc()) {
    echo str_pad($row['code'], 30) . ": " . $row['attr_count'] . " attributes\n";
    if ($row['attr_count'] == 0) $empty[] = $row['code'];
}
if ($empty) echo "\n⚠️  Empty groups: " . implode(', ', $empty) . "\n";

// 9. RECOMMENDATIONS
echo "\n\n💡 RECOMMENDATIONS\n" . str_repeat("=", 70) . "\n";
$recs = [];
if ($color['options'] > 100) $recs[] = "P1: Consolidate " . $color['options'] . " color options to 50-100";
if ($missing['missing'] > 0) $recs[] = "P1: Add English translations for " . $missing['missing'] . " color options";
if ($usage['cnt'] == 0) $recs[] = "P2: Color attribute unused - review data import";
if ($price['total'] - $price['with_price'] > 0) $recs[] = "P0: Fix " . ($price['total'] - $price['with_price']) . " products missing price";
if ($media['with_image']/$media['total'] < 0.95) $recs[] = "P1: Improve image coverage from " . round($media['with_image']/$media['total']*100, 1) . "% to >95%";
if ($weight['with_weight']/$weight['total'] < 0.95) $recs[] = "P1: Add weight for " . ($weight['total'] - $weight['with_weight']) . " products";
if ($en['with_en_name'] == 0) $recs[] = "P0: CRITICAL - Translate all products to English";
if ($empty) $recs[] = "P3: Remove empty groups: " . implode(', ', $empty);

foreach ($recs as $i => $rec) echo ($i+1) . ". " . $rec . "\n";

echo "\n" . str_repeat("=", 70) . "\n";
echo "Audit completed at " . date('Y-m-d H:i:s') . "\n";
$db->close();
