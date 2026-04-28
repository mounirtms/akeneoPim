<?php
$pdo = new PDO('mysql:host=127.0.0.1;port=3307;dbname=akeneo_pim', 'akeneo_pim', 'akeneo_pim');
$tables = $pdo->query("SHOW TABLES")->fetchAll(PDO::FETCH_COLUMN);
$productTables = array_filter($tables, function($t) {
    return stripos($t, 'product') !== false && (stripos($t, 'value') !== false || stripos($t, 'attribute') !== false);
});
echo "Product/Value Related Tables:\n";
foreach ($productTables as $t) {
    echo "  - $t\n";
}
