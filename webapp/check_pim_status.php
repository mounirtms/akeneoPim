<?php
require_once __DIR__ . '/../vendor/autoload.php';

use Symfony\Component\Dotenv\Dotenv;

$dotenv = new Dotenv();
$dotenv->load(__DIR__ . '/../.env');

$host = $_ENV['APP_DATABASE_HOST'];
$port = $_ENV['APP_DATABASE_PORT'];
$dbname = $_ENV['APP_DATABASE_NAME'];
$user = $_ENV['APP_DATABASE_USER'];
$pass = $_ENV['APP_DATABASE_PASSWORD'];

try {
    $dsn = "mysql:host=$host;port=$port;dbname=$dbname";
    $pdo = new PDO($dsn, $user, $pass, [
        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
        PDO::MYSQL_ATTR_SSL_VERIFY_SERVER_CERT => false
    ]);
    
    echo "=== DATABASE CONNECTION SUCCESSFUL ===\n\n";
    
    $queries = [
        'Categories' => 'SELECT COUNT(*) FROM pim_catalog_category',
        'Attribute Groups' => 'SELECT COUNT(*) FROM pim_catalog_attribute_group',
        'Attributes' => 'SELECT COUNT(*) FROM pim_catalog_attribute',
        'Families' => 'SELECT COUNT(*) FROM pim_catalog_family',
        'Channels' => 'SELECT COUNT(*) FROM pim_catalog_channel',
        'Locales' => 'SELECT COUNT(*) FROM pim_catalog_locale',
        'Products' => 'SELECT COUNT(*) FROM pim_catalog_product'
    ];
    
    echo "=== DATA COUNTS ===\n";
    foreach ($queries as $label => $query) {
        $stmt = $pdo->query($query);
        $count = $stmt->fetchColumn();
        printf("%-20s: %d\n", $label, $count);
    }
    
    echo "\n=== SAMPLE CATEGORIES (first 5) ===\n";
    $stmt = $pdo->query('SELECT code, parent_id FROM pim_catalog_category LIMIT 5');
    while ($row = $stmt->fetch(PDO::FETCH_ASSOC)) {
        echo "  - {$row['code']} (parent: {$row['parent_id']})\n";
    }
    
    echo "\n=== SAMPLE ATTRIBUTE GROUPS (first 5) ===\n";
    $stmt = $pdo->query('SELECT code FROM pim_catalog_attribute_group LIMIT 5');
    while ($row = $stmt->fetch(PDO::FETCH_ASSOC)) {
        echo "  - {$row['code']}\n";
    }
    
    echo "\n=== SAMPLE ATTRIBUTES (first 5) ===\n";
    $stmt = $pdo->query('SELECT code, attribute_type FROM pim_catalog_attribute LIMIT 5');
    while ($row = $stmt->fetch(PDO::FETCH_ASSOC)) {
        echo "  - {$row['code']} ({$row['attribute_type']})\n";
    }
    
    echo "\n=== MARIADB VERSION ===\n";
    $stmt = $pdo->query('SELECT VERSION()');
    echo $stmt->fetchColumn() . "\n";
    
} catch (Exception $e) {
    echo "ERROR: " . $e->getMessage() . "\n";
    exit(1);
}
