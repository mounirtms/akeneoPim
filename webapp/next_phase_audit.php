<?php
/**
 * Next Phase Audit Script - Deep Analysis
 * Audits color attributes, complex values, and plans optimization phases
 */

echo "=== NEXT PHASE AUDIT - " . date('Y-m-d H:i:s') . " ===\n\n";

// Database connection
$db = new mysqli('127.0.0.1', 'root', 'YourNewStrongPassword', 'akeneo_pim', 3307);
if ($db->connect_error) {
    die("Connection failed: " . $db->connect_error);
}

// 1. Current System Status
echo "📊 CURRENT SYSTEM STATUS\n";
echo str_repeat("=", 80) . "\n";

$query = "SELECT 
    (SELECT COUNT(*) FROM pim_catalog_product WHERE enabled = 1) as total_products,
    (SELECT COUNT(DISTINCT product_id) FROM pim_catalog_completeness) as products_with_completeness,
    (SELECT COUNT(*) FROM pim_catalog_attribute) as total_attributes,
    (SELECT COUNT(*) FROM pim_catalog_attribute WHERE attribute_type = 'pim_catalog_simpleselect' OR attribute_type = 'pim_catalog_multiselect') as select_attributes,
    (SELECT COUNT(*) FROM pim_catalog_attribute_option) as total_options,
    (SELECT COUNT(*) FROM pim_catalog_family) as total_families";
$result = $db->query($query);
$status = $result->fetch_assoc();
foreach ($status as $key => $value) {
    echo "  " . str_pad($key, 35) . ": " . number_format($value) . "\n";
}

// 2. COLOR ATTRIBUTE DEEP ANALYSIS
echo "\n\n🎨 COLOR ATTRIBUTE ANALYSIS\n";
echo str_repeat("=", 80) . "\n";

// Color attribute details
$query = "SELECT a.id, a.code, a.attribute_type, a.is_localizable, a.is_scopable,
          COUNT(DISTINCT ao.id) as option_count
          FROM pim_catalog_attribute a
          LEFT JOIN pim_catalog_attribute_option ao ON a.id = ao.attribute_id
          WHERE a.code = 'color'
          GROUP BY a.id, a.code, a.attribute_type, a.is_localizable, a.is_scopable";
$result = $db->query($query);
$colorAttr = $result->fetch_assoc();

echo "Color Attribute Configuration:\n";
echo "  ID: " . $colorAttr['id'] . "\n";
echo "  Type: " . $colorAttr['attribute_type'] . "\n";
echo "  Localizable: " . ($colorAttr['is_localizable'] ? 'Yes' : 'No') . "\n";
echo "  Scopable: " . ($colorAttr['is_scopable'] ? 'Yes' : 'No') . "\n";
echo "  Total Options: " . $colorAttr['option_count'] . "\n\n";

// Color usage in products
$query = "SELECT 
    JSON_EXTRACT(raw_values, '$.color') as color_value,
    COUNT(*) as product_count
    FROM pim_catalog_product 
    WHERE enabled = 1 AND JSON_EXTRACT(raw_values, '$.color') IS NOT NULL
    GROUP BY color_value
    LIMIT 20";
$result = $db->query($query);
echo "Color Usage in Products (Top 20):\n";
$totalWithColor = 0;
while ($row = $result->fetch_assoc()) {
    $totalWithColor += $row['product_count'];
    echo "  " . substr($row['color_value'], 0, 50) . "... : " . $row['product_count'] . " products\n";
}
echo "  Total products with color: " . $totalWithColor . "\n\n";

// Color options with translations
$query = "SELECT ao.code, ao.sort_order,
          COUNT(DISTINCT aov.locale_code) as translation_count,
          GROUP_CONCAT(DISTINCT aov.locale_code) as locales,
          MAX(CASE WHEN aov.locale_code = 'en_US' THEN aov.value END) as en_label,
          MAX(CASE WHEN aov.locale_code = 'fr_FR' THEN aov.value END) as fr_label
          FROM pim_catalog_attribute_option ao
          JOIN pim_catalog_attribute a ON ao.attribute_id = a.id
          LEFT JOIN pim_catalog_attribute_option_value aov ON ao.id = aov.option_id
          WHERE a.code = 'color'
          GROUP BY ao.code, ao.sort_order
          ORDER BY ao.sort_order
          LIMIT 30";
$result = $db->query($query);
echo "Color Options Sample (First 30):\n";
$noEnglish = 0;
while ($row = $result->fetch_assoc()) {
    if (empty($row['en_label'])) $noEnglish++;
    echo "  " . str_pad($row['code'], 20) . " | ";
    echo "Translations: " . $row['translation_count'] . " | ";
    echo "EN: " . ($row['en_label'] ?? 'MISSING') . " | ";
    echo "FR: " . ($row['fr_label'] ?? 'N/A') . "\n";
}
echo "\n  ⚠️  Options missing English: " . $noEnglish . " out of " . $colorAttr['option_count'] . "\n";

// 3. COMPLEX ATTRIBUTES ANALYSIS
echo "\n\n🔍 COMPLEX ATTRIBUTES ANALYSIS\n";
echo str_repeat("=", 80) . "\n";

$complexTypes = [
    'pim_catalog_price_collection' => 'Price',
    'pim_catalog_metric' => 'Metric',
    'pim_catalog_image' => 'Image',
    'pim_catalog_file' => 'File',
    'pim_catalog_multiselect' => 'Multi-Select',
    'pim_catalog_textarea' => 'Text Area'
];

foreach ($complexTypes as $type => $label) {
    $query = "SELECT code, is_localizable, is_scopable, is_required 
              FROM pim_catalog_attribute 
              WHERE attribute_type = '$type'";
    $result = $db->query($query);
    
    if ($result->num_rows > 0) {
        echo "\n" . $label . " Attributes (" . $result->num_rows . "):\n";
        while ($row = $result->fetch_assoc()) {
            echo "  • " . str_pad($row['code'], 25) . " | ";
            echo "Localizable: " . ($row['is_localizable'] ? 'Yes' : 'No') . " | ";
            echo "Scopable: " . ($row['is_scopable'] ? 'Yes' : 'No') . " | ";
            echo "Required: " . ($row['is_required'] ? 'Yes' : 'No') . "\n";
        }
    }
}

// 4. PRICE DATA INTEGRITY
echo "\n\n💰 PRICE DATA INTEGRITY\n";
echo str_repeat("=", 80) . "\n";

$query = "SELECT 
    COUNT(*) as total_products,
    SUM(CASE WHEN JSON_EXTRACT(raw_values, '$.price') IS NOT NULL THEN 1 ELSE 0 END) as with_price,
    SUM(CASE WHEN JSON_EXTRACT(raw_values, '$.price') IS NULL THEN 1 ELSE 0 END) as without_price
    FROM pim_catalog_product WHERE enabled = 1";
$result = $db->query($query);
$priceData = $result->fetch_assoc();

echo "Price Coverage:\n";
echo "  Total Products: " . number_format($priceData['total_products']) . "\n";
echo "  With Price: " . number_format($priceData['with_price']) . " (" . 
     round($priceData['with_price'] / $priceData['total_products'] * 100, 2) . "%)\n";
echo "  Without Price: " . number_format($priceData['without_price']) . " (" . 
     round($priceData['without_price'] / $priceData['total_products'] * 100, 2) . "%)\n";

// Sample price values
$query = "SELECT identifier, JSON_EXTRACT(raw_values, '$.price') as price_data
          FROM pim_catalog_product 
          WHERE enabled = 1 AND JSON_EXTRACT(raw_values, '$.price') IS NOT NULL
          LIMIT 5";
$result = $db->query($query);
echo "\nSample Price Data:\n";
while ($row = $result->fetch_assoc()) {
    echo "  SKU: " . $row['identifier'] . "\n";
    echo "    Price: " . substr($row['price_data'], 0, 150) . "...\n";
}

// 5. IMAGE/MEDIA INTEGRITY
echo "\n\n🖼️  IMAGE/MEDIA INTEGRITY\n";
echo str_repeat("=", 80) . "\n";

$query = "SELECT 
    COUNT(*) as total_products,
    SUM(CASE WHEN JSON_EXTRACT(raw_values, '$.image') IS NOT NULL THEN 1 ELSE 0 END) as with_image,
    SUM(CASE WHEN JSON_EXTRACT(raw_values, '$.gallery') IS NOT NULL THEN 1 ELSE 0 END) as with_gallery
    FROM pim_catalog_product WHERE enabled = 1";
$result = $db->query($query);
$mediaData = $result->fetch_assoc();

echo "Media Coverage:\n";
echo "  Products with Image: " . number_format($mediaData['with_image']) . " (" . 
     round($mediaData['with_image'] / $mediaData['total_products'] * 100, 2) . "%)\n";
echo "  Products with Gallery: " . number_format($mediaData['with_gallery']) . " (" . 
     round($mediaData['with_gallery'] / $mediaData['total_products'] * 100, 2) . "%)\n";

// 6. COMPLETENESS ANALYSIS
echo "\n\n✅ COMPLETENESS ANALYSIS\n";
echo str_repeat("=", 80) . "\n";

$query = "SELECT 
    ch.code as channel,
    l.code as locale,
    COUNT(DISTINCT c.product_id) as products,
    ROUND(AVG(c.required_count), 2) as avg_required,
    ROUND(AVG(c.missing_count), 2) as avg_missing,
    SUM(CASE WHEN c.missing_count = 0 THEN 1 ELSE 0 END) as complete_products,
    SUM(CASE WHEN c.missing_count > 0 THEN 1 ELSE 0 END) as incomplete_products
    FROM pim_catalog_completeness c
    JOIN pim_catalog_channel ch ON c.channel_id = ch.id
    JOIN pim_catalog_locale l ON c.locale_id = l.id
    GROUP BY ch.code, l.code";
$result = $db->query($query);

echo "Completeness by Channel/Locale:\n";
while ($row = $result->fetch_assoc()) {
    $completenessRate = $row['products'] > 0 ? 
        round($row['complete_products'] / $row['products'] * 100, 2) : 0;
    echo "\n  " . strtoupper($row['channel']) . " - " . $row['locale'] . ":\n";
    echo "    Products: " . number_format($row['products']) . "\n";
    echo "    Avg Required Attrs: " . $row['avg_required'] . "\n";
    echo "    Avg Missing Attrs: " . $row['avg_missing'] . "\n";
    echo "    Complete: " . number_format($row['complete_products']) . " (" . $completenessRate . "%)\n";
    echo "    Incomplete: " . number_format($row['incomplete_products']) . "\n";
}

// 7. ATTRIBUTE GROUPS UTILIZATION
echo "\n\n📦 ATTRIBUTE GROUPS UTILIZATION\n";
echo str_repeat("=", 80) . "\n";

$query = "SELECT ag.code, ag.sort_order,
          COUNT(DISTINCT a.id) as attribute_count,
          MAX(CASE WHEN agt.locale = 'en_US' THEN agt.label END) as en_label,
          MAX(CASE WHEN agt.locale = 'fr_FR' THEN agt.label END) as fr_label
          FROM pim_catalog_attribute_group ag
          LEFT JOIN pim_catalog_attribute a ON ag.id = a.group_id
          LEFT JOIN pim_catalog_attribute_group_translation agt ON ag.id = agt.foreign_key
          GROUP BY ag.code, ag.sort_order
          ORDER BY ag.sort_order";
$result = $db->query($query);

echo "Attribute Groups:\n";
$emptyGroups = [];
while ($row = $result->fetch_assoc()) {
    echo "  " . str_pad($row['code'], 25) . " | ";
    echo "Attrs: " . str_pad($row['attribute_count'], 3) . " | ";
    echo "EN: " . ($row['en_label'] ?? 'N/A') . " | ";
    echo "FR: " . ($row['fr_label'] ?? 'N/A') . "\n";
    
    if ($row['attribute_count'] == 0) {
        $emptyGroups[] = $row['code'];
    }
}
if (!empty($emptyGroups)) {
    echo "\n  ⚠️  Empty Groups (can be removed): " . implode(', ', $emptyGroups) . "\n";
}

// 8. RECOMMENDATIONS
echo "\n\n💡 PHASE 3 RECOMMENDATIONS\n";
echo str_repeat("=", 80) . "\n";

$recommendations = [
    "P0 - CRITICAL" => [],
    "P1 - HIGH" => [],
    "P2 - MEDIUM" => [],
    "P3 - LOW" => []
];

// Check color issues
if ($colorAttr['option_count'] > 100) {
    $recommendations["P1 - HIGH"][] = "Reduce color options from " . $colorAttr['option_count'] . " to 50-100 standard colors";
}
if ($noEnglish > 0) {
    $recommendations["P1 - HIGH"][] = "Add English translations for " . $noEnglish . " color options";
}
if ($totalWithColor == 0) {
    $recommendations["P2 - MEDIUM"][] = "No products using color attribute - consider removing or data import needed";
}

// Check price/media
if ($priceData['without_price'] > 0) {
    $recommendations["P0 - CRITICAL"][] = $priceData['without_price'] . " products missing price data";
}
if (($mediaData['with_image'] / $mediaData['total_products']) < 0.95) {
    $recommendations["P1 - HIGH"][] = "Only " . round($mediaData['with_image'] / $mediaData['total_products'] * 100, 1) . "% have images - target >95%";
}

// Check empty groups
if (!empty($emptyGroups)) {
    $recommendations["P3 - LOW"][] = "Remove empty attribute groups: " . implode(', ', $emptyGroups);
}

foreach ($recommendations as $priority => $items) {
    if (!empty($items)) {
        echo "\n" . $priority . ":\n";
        foreach ($items as $item) {
            echo "  • " . $item . "\n";
        }
    }
}

echo "\n\n" . str_repeat("=", 80) . "\n";
echo "Audit completed at " . date('Y-m-d H:i:s') . "\n";
echo "Log saved to: logs/next_phase_audit_" . date('Ymd_His') . ".log\n";

$db->close();
