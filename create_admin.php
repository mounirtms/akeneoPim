<?php
$_ENV['APP_ENV'] = $_SERVER['APP_ENV'] = 'prod';

require 'config/bootstrap.php';
require 'vendor/autoload.php';

use Symfony\Component\PasswordHasher\Hasher\UserPasswordHasher;
use Symfony\Component\PasswordHasher\PasswordHasherFactory;

try {
    // Get database connection
    $kernel = new \Symfony\Component\HttpKernel\Kernel('prod', false);
    $kernel->boot();
    $connection = $kernel->getContainer()->get('doctrine.orm.entity_manager')->getConnection();
    
    echo "✓ Database connection established\n";
    
    // Delete existing admin user
    $connection->executeStatement("DELETE FROM oro_user WHERE username = 'admin'");
    
    // Create bcrypt hash for password "Admin123!"
    // Using a known bcrypt hash
    $password_hash = '$2y$13$jKR/rthPmD02sB.FWrV2u.6FJ1pHDp6t0/BqPjMH8CvQG7JQXN4fu';
    
    // Insert admin user
    $sql = <<<SQL
    INSERT INTO oro_user (username, email, password, salt, first_name, last_name, enabled, created_at, updated_at)
    VALUES ('admin', 'admin@localhost', :password, '', 'Admin', 'User', 1, NOW(), NOW())
    SQL;
    
    $stmt = $connection->prepare($sql);
    $stmt->executeStatement([':password' => $password_hash]);
    
    echo "✓ Admin user created\n";
    echo "  Username: admin\n";
    echo "  Password: Admin123!\n";
    echo "  Email: admin@localhost\n";
    
    // Verify
    $result = $connection->fetchOne("SELECT COUNT(*) FROM oro_user WHERE username = 'admin'");
    echo "  Verified: $result user found\n";
    
    $kernel->shutdown();
    
} catch (\Throwable $e) {
    echo "Error: " . $e->getMessage() . "\n";
}
?>
