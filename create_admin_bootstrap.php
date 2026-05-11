<?php
require_once __DIR__ . '/vendor/autoload.php';

use Akeneo\Tool\SystemBundle\Kernel;
use Symfony\Component\Doctrine\DependencyInjection\CompilerPass\DoctrineOrmCompilerPass;

$kernel = new Kernel('prod', false);
$kernel->boot();
$container = $kernel->getContainer();

$connection = $container->get('doctrine')->getConnection();

// Password hash
$password = 'Admin123!';
$passwordHash = password_hash($password, PASSWORD_BCRYPT, ['cost' => 13]);

$username = 'admin';
$email = 'admin@pim.technostationery.com';

try {
    // Insert user
    $sql = "INSERT INTO oro_user 
           (username, email, first_name, last_name, password, salt, enabled, ui_locale_id, timezone, createdAt, updatedAt) 
           VALUES (?, ?, ?, ?, ?, '', 1, 1, 'UTC', NOW(), NOW())";
    
    $stmt = $connection->prepare($sql);
    $result = $stmt->executeQuery([$username, $email, 'Admin', 'User', $passwordHash]);
    
    echo "✓ Admin user created successfully!\n";
    echo "  Username: admin\n";
    echo "  Email: admin@pim.technostationery.com\n";
    echo "  Password: Admin123! (temporary - MUST change on first login)\n\n";
    
    // Get user ID
    $userSql = "SELECT id FROM oro_user WHERE username = ?";
    $stmt = $connection->prepare($userSql);
    $result = $stmt->executeQuery([$username]);
    $user = $result->fetchAssociative();
    
    if ($user) {
        $userId = $user['id'];
        
        // Get role ID
        $roleSql = "SELECT id FROM oro_access_role WHERE role = 'ROLE_ADMINISTRATOR'";
        $stmt = $connection->prepare($roleSql);
        $result = $stmt->executeQuery();
        $role = $result->fetchAssociative();
        
        if ($role) {
            // Grant role
            $grantSql = "INSERT INTO oro_user_access_role (user_id, role_id) VALUES (?, ?)";
            $stmt = $connection->prepare($grantSql);
            $stmt->executeQuery([$userId, $role['id']]);
            
            echo "✓ Verification:\n";
            echo "  ID: $userId\n";
            echo "  Username: $username\n";
            echo "  Email: $email\n";
            echo "  Role: ROLE_ADMINISTRATOR assigned\n";
        }
    }
    
} catch (Exception $e) {
    echo "✗ Error: " . $e->getMessage() . "\n";
    exit(1);
}
