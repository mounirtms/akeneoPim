<?php
require 'vendor/autoload.php';

use Symfony\Component\Console\Application;
use Symfony\Component\DependencyInjection\ContainerBuilder;

// Set environment
putenv('APP_ENV=prod');

// Create the app
$app = new Application();

// Simple admin creation via SQL
echo "Creating admin user via SQL...\n";

$pdo = new PDO('mysql:host=127.0.0.1;port=3307;dbname=akeneo_pim', 'akeneo_pim', 'AkeneoP1M2024!');

// Delete existing admin if any
$pdo->exec("DELETE FROM oro_user WHERE username = 'admin'");

// Insert new admin user
// Password: Admin123! (hashed with bcrypt)
// Using a known hash for password: Admin123!
$password_hash = '$2y$13$YDaQbI6aPL2xTRrHTLtPtOf7JBKXmKWqcuN3iCqsXVVR72t8zQ25K'; // bcrypt hash of 'Admin123!'

$sql = <<<SQL
INSERT INTO oro_user (username, email, password, first_name, last_name, enabled, created_at, updated_at)
VALUES (
    'admin',
    'admin@localhost',
    '$password_hash',
    'Admin',
    'User',
    1,
    NOW(),
    NOW()
)
SQL;

try {
    $pdo->exec($sql);
    echo "✓ Admin user created successfully\n";
    echo "  Username: admin\n";
    echo "  Password: Admin123!\n";
    echo "  Email: admin@localhost\n";
} catch (Exception $e) {
    echo "✗ Error: " . $e->getMessage() . "\n";
}
?>
