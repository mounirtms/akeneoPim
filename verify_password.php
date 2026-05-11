<?php
// Verify if password hash is correct for mounir user
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
    
    // Get mounir user
    $stmt = $pdo->prepare("SELECT id, username, password, enabled, consecutive_authentication_failure_counter FROM oro_user WHERE username = :username");
    $stmt->execute(['username' => 'mounir']);
    $user = $stmt->fetch(PDO::FETCH_ASSOC);
    
    if (!$user) {
        echo "❌ User not found!\n";
        exit(1);
    }
    
    echo "✅ User: {$user['username']}\n";
    echo "   Enabled: " . ($user['enabled'] ? 'Yes' : 'No') . "\n";
    echo "   Failed login counter: {$user['consecutive_authentication_failure_counter']}\n";
    echo "   Password hash: " . substr($user['password'], 0, 30) . "...\n";
    
    // Test password verification
    $testPassword = '2026';
    
    if (password_verify($testPassword, $user['password'])) {
        echo "\n✅ Password '2026' VERIFIED successfully!\n";
        echo "   The password hash is correct.\n";
    } else {
        echo "\n❌ Password '2026' FAILED verification!\n";
        echo "   The password hash does NOT match.\n";
        echo "   This explains why login fails.\n";
        
        // Try to create correct hash
        echo "\n🔧 Creating new correct password hash...\n";
        $newHash = password_hash($testPassword, PASSWORD_BCRYPT, ['cost' => 13]);
        echo "   New hash: " . substr($newHash, 0, 30) . "...\n";
        
        // Update in database
        $updateStmt = $pdo->prepare("UPDATE oro_user SET password = :password WHERE username = :username");
        $updateStmt->execute([
            'password' => $newHash,
            'username' => 'mounir'
        ]);
        
        echo "✅ Password updated in database!\n";
        
        // Verify again
        if (password_verify($testPassword, $newHash)) {
            echo "✅ New password hash verified successfully!\n";
        }
    }
    
} catch (Exception $e) {
    echo "❌ Error: " . $e->getMessage() . "\n";
    exit(1);
}
