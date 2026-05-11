<?php
// Use Symfony's encoder with correct configuration
require_once __DIR__ . '/vendor/autoload.php';

use Symfony\Component\Security\Core\Encoder\MessageDigestPasswordEncoder;

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
    
    // Symfony's MessageDigestPasswordEncoder with sha512
    // Default iterations is 5000, encodeHashAsBase64 is true
    $encoder = new MessageDigestPasswordEncoder('sha512', true, 5000);
    
    $users = [
        ['username' => 'mounir', 'password' => '2026'],
        ['username' => 'admin', 'password' => 'admin']
    ];
    
    echo "🔐 ENCODING PASSWORDS WITH SYMFONY MessageDigestPasswordEncoder\n";
    echo str_repeat('=', 80) . "\n";
    
    foreach ($users as $userData) {
        $username = $userData['password'];
        $password = $userData['password'];
        
        // Get user salt
        $stmt = $pdo->prepare("SELECT id, username, salt FROM oro_user WHERE username = :username");
        $stmt->execute(['username' => $userData['username']]);
        $user = $stmt->fetch(PDO::FETCH_ASSOC);
        
        if (!$user) {
            echo "❌ User '{$userData['username']}' not found!\n";
            continue;
        }
        
        echo "\n📋 User: {$user['username']}\n";
        echo "   Salt: " . substr($user['salt'], 0, 20) . "...\n";
        
        // Encode with Symfony's encoder
        $encodedPassword = $encoder->encodePassword($password, $user['salt']);
        
        echo "   Password: {$password}\n";
        echo "   Encoded: " . substr($encodedPassword, 0, 30) . "...\n";
        echo "   Length: " . strlen($encodedPassword) . "\n";
        
        // Update in database
        $updateStmt = $pdo->prepare(
            "UPDATE oro_user SET 
                password = :password,
                consecutive_authentication_failure_counter = 0,
                authentication_failure_reset_date = NULL 
             WHERE username = :username"
        );
        
        $updateStmt->execute([
            'password' => $encodedPassword,
            'username' => $user['username']
        ]);
        
        echo "   ✅ Password updated in database\n";
        
        // Verify encoding
        $isValid = $encoder->isPasswordValid($encodedPassword, $password, $user['salt']);
        echo "   Verification: " . ($isValid ? '✅ VALID' : '❌ INVALID') . "\n";
    }
    
    echo "\n" . str_repeat('=', 80) . "\n";
    echo "✅ ALL PASSWORDS UPDATED SUCCESSFULLY\n";
    echo "\n📋 CREDENTIALS:\n";
    echo "   admin / admin\n";
    echo "   mounir / 2026\n";
    echo "\n🔐 Encoding: Symfony MessageDigestPasswordEncoder (sha512, base64, 5000 iterations)\n";
    
} catch (Exception $e) {
    echo "❌ Error: " . $e->getMessage() . "\n";
    echo $e->getTraceAsString() . "\n";
    exit(1);
}
