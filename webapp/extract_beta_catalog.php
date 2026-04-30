<?php
error_reporting(E_ALL);
ini_set('display_errors', 1);

$env = include '/home/beta/public_html/app/etc/env.php';
$db = $env['db']['connection']['default'];

$parts = explode(':', $db['host']);
$host = $parts[0];
$port = $parts[1] ?? 3306;

$pdo = new PDO("mysql:host=$host;port=$port;dbname={$db['dbname']}", $db['username'], $db['password']);
$pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);

echo "=== AKENEO CONNECTOR CONFIG ===\n";
$stmt = $pdo->query("SELECT path, value FROM core_config_data WHERE path LIKE 'akeneo_connector/%' ORDER BY path");
while ($row = $stmt->fetch(PDO::FETCH_ASSOC)) {
    // Mask sensitive values
    if (strpos($row['path'], 'password') !== false || strpos($row['path'], 'secret') !== false) {
        echo "{$row['path']}: ***masked***\n";
    } else {
        echo "{$row['path']}: {$row['value']}\n";
    }
}

echo "\n=== MAGENTO ATTRIBUTE SETS ===\n";
$stmt = $pdo->query("SELECT eas.attribute_set_id, eas.attribute_set_name, COUNT(eea.attribute_id) as attr_count 
    FROM eav_attribute_set eas 
    LEFT JOIN eav_entity_attribute eea ON eas.attribute_set_id = eea.attribute_set_id 
    WHERE eas.entity_type_id = 4 
    GROUP BY eas.attribute_set_id, eas.attribute_set_name 
    ORDER BY eas.attribute_set_name");
while ($row = $stmt->fetch(PDO::FETCH_ASSOC)) {
    echo "  [{$row['attribute_set_id']}] {$row['attribute_set_name']} ({$row['attr_count']} attrs)\n";
}

echo "\n=== MAGENTO PRODUCT ATTRIBUTES (custom) ===\n";
$stmt = $pdo->query("SELECT ea.attribute_code, ea.frontend_input, ea.backend_type, ea.is_required, 
    ea.is_user_defined, eav.value as label
    FROM eav_attribute ea 
    LEFT JOIN eav_attribute_label eav ON ea.attribute_id = eav.attribute_id AND eav.store_id = 0
    WHERE ea.entity_type_id = 4 AND ea.is_user_defined = 1 
    ORDER BY ea.attribute_code");
while ($row = $stmt->fetch(PDO::FETCH_ASSOC)) {
    echo "  {$row['attribute_code']}: {$row['frontend_input']} ({$row['backend_type']}) label='{$row['label']}' req={$row['is_required']}\n";
}

echo "\n=== MAGENTO CATEGORIES (top 3 levels) ===\n";
$stmt = $pdo->query("SELECT cce.entity_id, cce.parent_id, cce.level, cce.path, ccev.value as name 
    FROM catalog_category_entity cce 
    LEFT JOIN catalog_category_entity_varchar ccev ON cce.entity_id = ccev.entity_id 
        AND ccev.attribute_id = (SELECT attribute_id FROM eav_attribute WHERE attribute_code = 'name' AND entity_type_id = 3)
        AND ccev.store_id = 0
    WHERE cce.level <= 3
    ORDER BY cce.path");
while ($row = $stmt->fetch(PDO::FETCH_ASSOC)) {
    $indent = str_repeat('  ', $row['level']);
    echo "{$indent}[{$row['entity_id']}] {$row['name']} (level {$row['level']}, parent {$row['parent_id']})\n";
}

echo "\n=== PRODUCT COUNT ===\n";
$stmt = $pdo->query("SELECT type_id, COUNT(*) as cnt FROM catalog_product_entity GROUP BY type_id");
while ($row = $stmt->fetch(PDO::FETCH_ASSOC)) {
    echo "  {$row['type_id']}: {$row['cnt']} products\n";
}

echo "\n=== SAMPLE PRODUCTS (first 10) ===\n";
$stmt = $pdo->query("SELECT cpe.entity_id, cpe.sku, cpe.type_id, cpe.attribute_set_id, eas.attribute_set_name
    FROM catalog_product_entity cpe 
    JOIN eav_attribute_set eas ON cpe.attribute_set_id = eas.attribute_set_id
    ORDER BY cpe.entity_id LIMIT 10");
while ($row = $stmt->fetch(PDO::FETCH_ASSOC)) {
    echo "  SKU: {$row['sku']}, type: {$row['type_id']}, set: {$row['attribute_set_name']}\n";
}
