<?php
// Reset both admin and mounir passwords to SHA512 format
require_once __DIR__ . '/vendor/autoload.php';

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
    
    $users = [
        ['username' => 'admin', 'password' => 'admin'],
        ['username' => 'mounir', 'password' => '2026']
    ];
    
    foreach ($users as $userData) {
        $username = $userData['username'];
        $password = $userData['password'];
        
        // Get user
        $stmt = $pdo->prepare("SELECT id, username, salt FROM oro_user WHERE username = :username");
        $stmt->execute(['username' => $username]);
        $user = $stmt->fetch(PDO::FETCH_ASSOC);
        
        if (!$user) {
            echo "❌ User '$username' not found!\n";
            continue;
        }
        
        echo "\n✅ Processing user: {$username}\n";
        
        // Generate SHA512 hash with salt (Akeneo format)
        $hashedPassword = hash('sha512', $password . '{' . $user['salt'] . '}');
        
        echo "   Password: {$password}\n";
        echo "   Hash: " . substr($hashedPassword, 0, 30) . "...\n";
        
        // Update password
        $updateStmt = $pdo->prepare("UPDATE oro_user SET password = :password, consecutive_authentication_failure_counter = 0, authentication_failure_reset_date = NULL WHERE username = :username");
        $updateStmt->execute([
            'password' => $hashedPassword,
            'username' => $username
        ]);
        
        echo "   ✅ Password updated to SHA512 format\n";
        echo "   ✅ Auth failure counter reset\n";
    }
    
    echo "\n" . str_repeat('=', 80) . "\n";
    echo "✅ ALL PASSWORDS UPDATED SUCCESSFULLY!\n";
    echo str_repeat('=', 80) . "\n";
    echo "\n📋 CREDENTIALS:\n";
    echo "   admin / admin\n";
    echo "   mounir / 2026\n";
    echo "\n🔐 Encoding: SHA512 (Akeneo standard)\n";
    
} catch (Exception $e) {
    echo "❌ Error: " . $e->getMessage() . "\n";
    exit(1);
}
