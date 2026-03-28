<?php
$env = include '/home/beta/public_html/app/etc/env.php';
$db = $env['db']['connection']['default'];
$parts = explode(':', $db['host']);
$pdo = new PDO("mysql:host={$parts[0]};port={$parts[1]};dbname={$db['dbname']}", $db['username'], $db['password']);

echo "=== ALL CATEGORIES (levels 2-4 under Default Category) ===\n";
$stmt = $pdo->query("SELECT cce.entity_id, cce.parent_id, cce.level, cce.position, ccev.value as name
    FROM catalog_category_entity cce 
    LEFT JOIN catalog_category_entity_varchar ccev ON cce.entity_id = ccev.entity_id 
        AND ccev.attribute_id = (SELECT attribute_id FROM eav_attribute WHERE attribute_code = 'name' AND entity_type_id = 3)
        AND ccev.store_id = 0
    WHERE cce.path LIKE '1/2/%' AND cce.level BETWEEN 2 AND 5
    ORDER BY cce.level, cce.position");
while ($row = $stmt->fetch(PDO::FETCH_ASSOC)) {
    $indent = str_repeat('  ', $row['level'] - 1);
    echo "{$indent}[{$row['entity_id']}] {$row['name']}\n";
}

echo "\n=== SELECT ATTRIBUTE OPTIONS (color, size, format, etc) ===\n";
$attrs = ['color', 'size', 'format', 'capacity', 'diameter', 'thickness', 'type', 'dimension', 'manufacturer', 'mgs_brand'];
foreach ($attrs as $attrCode) {
    $stmt = $pdo->prepare("SELECT eao.option_id, eaov.value 
        FROM eav_attribute ea 
        JOIN eav_attribute_option eao ON ea.attribute_id = eao.attribute_id 
        LEFT JOIN eav_attribute_option_value eaov ON eao.option_id = eaov.option_id AND eaov.store_id = 0
        WHERE ea.attribute_code = ? AND ea.entity_type_id = 4 
        ORDER BY eao.sort_order LIMIT 20");
    $stmt->execute([$attrCode]);
    $options = $stmt->fetchAll(PDO::FETCH_ASSOC);
    if ($options) {
        echo "  $attrCode: " . implode(', ', array_column($options, 'value')) . " (" . count($options) . " options)\n";
    }
}

echo "\n=== SYSTEM ATTRIBUTES USED ===\n";
$stmt = $pdo->query("SELECT ea.attribute_code, ea.frontend_input, ea.backend_type
    FROM eav_attribute ea 
    WHERE ea.entity_type_id = 4 AND ea.is_user_defined = 0 AND ea.frontend_input != ''
    ORDER BY ea.attribute_code");
while ($row = $stmt->fetch(PDO::FETCH_ASSOC)) {
    echo "  {$row['attribute_code']}: {$row['frontend_input']}\n";
}

echo "\n=== CONFIGURABLE PRODUCT SUPER ATTRIBUTES ===\n";
$stmt = $pdo->query("SELECT ea.attribute_code, COUNT(DISTINCT cpsa.product_id) as product_count
    FROM catalog_product_super_attribute cpsa
    JOIN eav_attribute ea ON cpsa.attribute_id = ea.attribute_id
    GROUP BY ea.attribute_code ORDER BY product_count DESC LIMIT 10");
while ($row = $stmt->fetch(PDO::FETCH_ASSOC)) {
    echo "  {$row['attribute_code']}: used in {$row['product_count']} configurable products\n";
}
