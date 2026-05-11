<?php
require_once '/home/pim/public_html/vendor/autoload.php';

use Symfony\Component\Console\Application;
use Symfony\Bundle\FrameworkBundle\Console\Application as SymfonyApplication;

// Bootstrap Akeneo kernel
$kernel = new \Akeneo\Tool\SystemBundle\Kernel('prod', false);
$kernel->boot();

$container = $kernel->getContainer();
$em = $container->get('doctrine.orm.entity_manager');
$connection = $em->getConnection();

// Generate password hash (bcrypt cost 13)
$password = 'Admin123!';
$passwordHash = password_hash($password, PASSWORD_BCRYPT, ['cost' => 13]);

$username = 'admin';
$email = 'admin@pim.technostationery.com';

try {
    // Insert user directly
    $sql = "INSERT INTO oro_user (username, email, first_name, last_name, password, is_active, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?, 1, NOW(), NOW())
            ON DUPLICATE KEY UPDATE password = VALUES(password), updated_at = NOW()";
    
    $stmt = $connection->prepare($sql);
    $stmt->executeQuery([$username, $email, 'Admin', 'User', $passwordHash]);
    
    // Get user ID
    $userSql = "SELECT id FROM oro_user WHERE username = ?";
    $stmt = $connection->prepare($userSql);
    $result = $stmt->executeQuery([$username]);
    $user = $result->fetchAssociative();
    
    if ($user) {
        $userId = $user['id'];
        
        // Get ROLE_ADMINISTRATOR ID
        $roleSql = "SELECT id FROM oro_access_role WHERE role = 'ROLE_ADMINISTRATOR'";
        $stmt = $connection->prepare($roleSql);
        $result = $stmt->executeQuery();
        $role = $result->fetchAssociative();
        
        if ($role) {
            $roleId = $role['id'];
            
            // Grant role to user
            $grantSql = "INSERT INTO oro_user_access_role (user_id, role_id) VALUES (?, ?)
                        ON DUPLICATE KEY UPDATE role_id = role_id";
            $stmt = $connection->prepare($grantSql);
            $stmt->executeQuery([$userId, $roleId]);
            
            echo "✓ Admin user created successfully!\n";
            echo "  Username: $username\n";
            echo "  Email: $email\n";
            echo "  Password: $password (temporary - MUST change on first login)\n\n";
            
            // Verify
            $verifySql = "SELECT id, username, email, first_name, last_name, is_active FROM oro_user WHERE username = ?";
            $stmt = $connection->prepare($verifySql);
            $result = $stmt->executeQuery([$username]);
            $verified = $result->fetchAssociative();
            
            if ($verified) {
                echo "✓ Verification:\n";
                echo "  ID: {$verified['id']}\n";
                echo "  Username: {$verified['username']}\n";
                echo "  Email: {$verified['email']}\n";
                echo "  Active: " . ($verified['is_active'] ? 'Yes' : 'No') . "\n";
            }
        }
    }
} catch (Exception $e) {
    echo "✗ Error: " . $e->getMessage() . "\n";
    exit(1);
}
