<?php
$pdo = new PDO('mysql:host=127.0.0.1;port=3307;dbname=akeneo_pim', 'akeneo_pim', 'akeneo_pim');
$tables = $pdo->query("SHOW TABLES LIKE 'pim_catalog_%'")->fetchAll(PDO::FETCH_COLUMN);
echo "Akeneo Catalog Tables:\n\n";
$groups = ['product' => [], 'attribute' => [], 'family' => [], 'category' => [], 'other' => []];
foreach ($tables as $t) {
    if (stripos($t, 'product') !== false) $groups['product'][] = $t;
    elseif (stripos($t, 'attribute') !== false) $groups['attribute'][] = $t;
    elseif (stripos($t, 'family') !== false) $groups['family'][] = $t;
    elseif (stripos($t, 'category') !== false) $groups['category'][] = $t;
    else $groups['other'][] = $t;
}
foreach ($groups as $group => $items) {
    if (!empty($items)) {
        echo strtoupper($group) . " TABLES:\n";
        foreach ($items as $item) echo "  - $item\n";
        echo "\n";
    }
}
