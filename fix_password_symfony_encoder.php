<?php
// Test password encoding with actual Symfony encoder
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
    
    // Get mounir user
    $stmt = $pdo->prepare("SELECT username, password, salt FROM oro_user WHERE username = :username");
    $stmt->execute(['username' => 'mounir']);
    $user = $stmt->fetch(PDO::FETCH_ASSOC);
    
    if (!$user) {
        echo "❌ User not found!\n";
        exit(1);
    }
    
    echo "✅ User: {$user['username']}\n";
    echo "   Password hash: " . substr($user['password'], 0, 30) . "...\n";
    echo "   Salt: " . substr($user['salt'], 0, 30) . "...\n";
    
    // Test with Symfony's MessageDigestPasswordEncoder (sha512)
    $encoder = new MessageDigestPasswordEncoder('sha512', true, 5000);
    
    $testPassword = '2026';
    
    echo "\n🔍 Testing password encoding methods:\n";
    
    // Method 1: Standard Symfony encoding
    $encoded1 = $encoder->encodePassword($testPassword, $user['salt']);
    echo "\n1. Symfony MessageDigestPasswordEncoder:\n";
    echo "   Encoded: " . substr($encoded1, 0, 30) . "...\n";
    echo "   Match: " . ($encoded1 === $user['password'] ? '✅ YES' : '❌ NO') . "\n";
    
    // Method 2: Plain SHA512 with salt in braces
    $encoded2 = hash('sha512', $testPassword . '{' . $user['salt'] . '}');
    echo "\n2. Plain SHA512 with {salt}:\n";
    echo "   Encoded: " . substr($encoded2, 0, 30) . "...\n";
    echo "   Match: " . ($encoded2 === $user['password'] ? '✅ YES' : '❌ NO') . "\n";
    
    // Method 3: SHA512 without braces
    $encoded3 = hash('sha512', $testPassword . $user['salt']);
    echo "\n3. Plain SHA512 without braces:\n";
    echo "   Encoded: " . substr($encoded3, 0, 30) . "...\n";
    echo "   Match: " . ($encoded3 === $user['password'] ? '✅ YES' : '❌ NO') . "\n";
    
    // Try to find which method matches
    echo "\n🔧 CORRECT ENCODING:\n";
    
    if ($encoded1 === $user['password']) {
        echo "   ✅ Use Symfony MessageDigestPasswordEncoder\n";
        $correctMethod = 1;
    } elseif ($encoded2 === $user['password']) {
        echo "   ✅ Use SHA512 with {salt}\n";
        $correctMethod = 2;
    } elseif ($encoded3 === $user['password']) {
        echo "   ✅ Use SHA512 without braces\n";
        $correctMethod = 3;
    } else {
        echo "   ❌ NONE OF THE METHODS MATCH!\n";
        echo "   Need to re-encode password...\n";
        $correctMethod = 0;
    }
    
    // If no match, update with Symfony encoder
    if ($correctMethod === 0) {
        echo "\n🔐 Updating password with Symfony encoder...\n";
        $newHash = $encoder->encodePassword($testPassword, $user['salt']);
        
        $updateStmt = $pdo->prepare("UPDATE oro_user SET password = :password WHERE username = :username");
        $updateStmt->execute([
            'password' => $newHash,
            'username' => 'mounir'
        ]);
        
        echo "   ✅ Password updated!\n";
        echo "   New hash: " . substr($newHash, 0, 30) . "...\n";
    }
    
    // Also update admin
    echo "\n📋 Updating admin user...\n";
    $stmt->execute(['username' => 'admin']);
    $admin = $stmt->fetch(PDO::FETCH_ASSOC);
    
    if ($admin) {
        $adminHash = $encoder->encodePassword('admin', $admin['salt']);
        $updateStmt->execute([
            'password' => $adminHash,
            'username' => 'admin'
        ]);
        echo "   ✅ Admin password updated with Symfony encoder\n";
    }
    
    // Reset failure counters
    $pdo->exec("UPDATE oro_user SET consecutive_authentication_failure_counter = 0, authentication_failure_reset_date = NULL WHERE username IN ('admin', 'mounir')");
    
    echo "\n✅ ALL PASSWORDS UPDATED WITH CORRECT SYMFONY ENCODING\n";
    echo "📋 Credentials: mounir / 2026, admin / admin\n";
    
} catch (Exception $e) {
    echo "❌ Error: " . $e->getMessage() . "\n";
    exit(1);
}
