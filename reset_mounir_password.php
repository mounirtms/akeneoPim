<?php
// Reset mounir password to 2026
require_once __DIR__ . '/vendor/autoload.php';

use Symfony\Component\PasswordHasher\Hasher\PasswordHasherFactory;
use Symfony\Component\PasswordHasher\Hasher\UserPasswordHasher;
use Symfony\Component\Security\Core\User\PasswordAuthenticatedUserInterface;

// Database connection
$dbHost = '127.0.0.1';
$dbPort = 3307;
$dbName = 'akeneo_pim';
$dbUser = 'akeneo_pim';
$dbPass = 'akeneo_pim';

try {
    $pdo = new PDO(
        "mysql:host=$dbHost;port=$dbPort;dbname=$dbName",
        $dbUser,
        $dbPass,
        [PDO::MYSQL_ATTR_SSL_VERIFY_SERVER_CERT => false]
    );
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    
    // Check if user exists
    $stmt = $pdo->prepare("SELECT id, username, email, salt FROM oro_user WHERE username = :username");
    $stmt->execute(['username' => 'mounir']);
    $user = $stmt->fetch(PDO::FETCH_ASSOC);
    
    if (!$user) {
        echo "❌ User 'mounir' not found!\n";
        exit(1);
    }
    
    echo "✅ User found: {$user['username']} ({$user['email']})\n";
    
    // Hash the password using Symfony's method
    $password = '2026';
    
    // Akeneo uses bcrypt for password hashing
    $hashedPassword = password_hash($password, PASSWORD_BCRYPT, ['cost' => 13]);
    
    echo "🔐 New password hash: " . substr($hashedPassword, 0, 30) . "...\n";
    
    // Generate a random salt (Akeneo may still use it for legacy reasons)
    $salt = bin2hex(random_bytes(32));
    
    // Update password in database
    $updateStmt = $pdo->prepare("UPDATE oro_user SET password = :password, salt = :salt WHERE username = :username");
    $updateStmt->execute([
        'password' => $hashedPassword,
        'salt' => $salt,
        'username' => 'mounir'
    ]);
    
    echo "✅ Password updated successfully!\n";
    echo "📋 Credentials: mounir / 2026\n";
    
    // Verify the password works
    if (password_verify($password, $hashedPassword)) {
        echo "✅ Password verification successful!\n";
    } else {
        echo "❌ Password verification failed!\n";
    }
    
} catch (PDOException $e) {
    echo "❌ Database error: " . $e->getMessage() . "\n";
    exit(1);
} catch (Exception $e) {
    echo "❌ Error: " . $e->getMessage() . "\n";
    exit(1);
}
