<?php
/**
 * DISCOVER AKENEO DATABASE SCHEMA
 * Find correct table structure for product values
 */

$host = '127.0.0.1';
$port = 3307;
$database = 'akeneo_pim';
$username = 'akeneo_pim';
$password = 'akeneo_pim';

try {
    $dsn = "mysql:host=$host;port=$port;dbname=$database;charset=utf8mb4";
    $pdo = new PDO($dsn, $username, $password, [
        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC
    ]);
    echo "✓ Connected\n\n";
} catch (PDOException $e) {
    die("❌ Failed: " . $e->getMessage() . "\n");
}

// Find product-related tables
echo "=== PRODUCT TABLES ===\n";
$stmt = $pdo->query("SHOW TABLES LIKE '%product%'");
$tables = $stmt->fetchAll(PDO::FETCH_COLUMN);
foreach ($tables as $table) {
    echo "  $table\n";
}

// Find value-related tables
echo "\n=== VALUE TABLES ===\n";
$stmt = $pdo->query("SHOW TABLES LIKE '%value%'");
$tables = $stmt->fetchAll(PDO::FETCH_COLUMN);
foreach ($tables as $table) {
    echo "  $table\n";
}

// Find media/file tables
echo "\n=== MEDIA/FILE TABLES ===\n";
$stmt = $pdo->query("SHOW TABLES LIKE '%media%'");
$tables = $stmt->fetchAll(PDO::FETCH_COLUMN);
foreach ($tables as $table) {
    echo "  $table\n";
}

$stmt = $pdo->query("SHOW TABLES LIKE '%file%'");
$tables = $stmt->fetchAll(PDO::FETCH_COLUMN);
foreach ($tables as $table) {
    echo "  $table\n";
}

// Check product table structure
echo "\n=== PRODUCT TABLE STRUCTURE ===\n";
$stmt = $pdo->query("DESCRIBE pim_catalog_product");
$columns = $stmt->fetchAll();
foreach ($columns as $col) {
    echo "  {$col['Field']} ({$col['Type']})\n";
}

// Sample products
echo "\n=== SAMPLE PRODUCTS ===\n";
$stmt = $pdo->query("SELECT id, identifier, is_enabled FROM pim_catalog_product LIMIT 5");
$products = $stmt->fetchAll();
foreach ($products as $p) {
    echo "  ID: {$p['id']}, SKU: {$p['identifier']}, Enabled: {$p['is_enabled']}\n";
}

// Check if raw_values column exists
echo "\n=== CHECKING PRODUCT DATA STORAGE ===\n";
$stmt = $pdo->query("SHOW COLUMNS FROM pim_catalog_product LIKE '%value%'");
$valueColumns = $stmt->fetchAll();
if (!empty($valueColumns)) {
    echo "Found value columns in product table:\n";
    foreach ($valueColumns as $col) {
        echo "  {$col['Field']} ({$col['Type']})\n";
    }
} else {
    echo "No value columns in product table - checking separate value tables...\n";
}
