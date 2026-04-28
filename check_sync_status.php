<?php
$akeneo = new PDO('mysql:host=127.0.0.1;port=3307;dbname=akeneo_pim', 'akeneo_pim', 'akeneo_pim');
$magento = new PDO('mysql:host=127.0.0.1;port=3307;dbname=beta_dBT8x12y22', 'beta_ntdbusr24', 'the-correct-password');

echo "=== SYNC STATUS CHECK ===\n\n";
$akProducts = $akeneo->query('SELECT COUNT(*) FROM pim_catalog_product WHERE enabled=1')->fetchColumn();
$akCategories = $akeneo->query('SELECT COUNT(*) FROM pim_catalog_category')->fetchColumn();

$mgProducts = $magento->query('SELECT COUNT(*) FROM catalog_product_entity')->fetchColumn();
$mgCategories = $magento->query('SELECT COUNT(*) FROM catalog_category_entity')->fetchColumn();
$mgEnabled = $magento->query('SELECT COUNT(*) FROM catalog_product_entity_int WHERE attribute_id=97 AND value=1')->fetchColumn();

echo "Akeneo Products: $akProducts (enabled)\n";
echo "Akeneo Categories: $akCategories\n\n";
echo "Magento Products: $mgProducts\n";
echo "Magento Products Enabled: $mgEnabled\n";
echo "Magento Categories: $mgCategories\n\n";

if ($akProducts == $mgProducts && $akProducts == $mgEnabled) {
    echo "✅ SYNCED - All products match\n";
} else {
    echo "⚠️ NOT SYNCED - Need to run full sync\n";
}
