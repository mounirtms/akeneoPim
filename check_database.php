<?php
require __DIR__.'/config/bootstrap.php';

use Doctrine\DBAL\DriverManager;

$container = require __DIR__.'/config/bootstrap.php';
$conn = $container->get('doctrine.dbal.default_connection');

echo "=== DATABASE DATA CHECK ===\n\n";

$queries = [
    'Categories' => 'SELECT COUNT(*) as count FROM pim_catalog_category',
    'Attribute Groups' => 'SELECT COUNT(*) as count FROM pim_catalog_attribute_group',
    'Attributes' => 'SELECT COUNT(*) as count FROM pim_catalog_attribute',
    'Families' => 'SELECT COUNT(*) as count FROM pim_catalog_family',
    'Products' => 'SELECT COUNT(*) as count FROM pim_catalog_product',
    'Channels' => 'SELECT COUNT(*) as count FROM pim_catalog_channel',
    'Locales' => 'SELECT COUNT(*) as count FROM pim_catalog_locale',
    'Users' => 'SELECT COUNT(*) as count FROM oro_user'
];

foreach ($queries as $entity => $query) {
    try {
        $result = $conn->fetchOne($query);
        printf("%-20s: %d\n", $entity, $result);
    } catch (\Exception $e) {
        printf("%-20s: ERROR - %s\n", $entity, $e->getMessage());
    }
}

echo "\n=== CHECKING SPECIFIC DATA ===\n";
// Check category tree
$categories = $conn->fetchAllAssociative("SELECT code, parent_id FROM pim_catalog_category LIMIT 10");
echo "\nCategories (first 10):\n";
foreach ($categories as $cat) {
    echo "  - {$cat['code']} (parent: {$cat['parent_id']})\n";
}

