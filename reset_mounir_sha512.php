<?php
// Reset mounir password using Akeneo's SHA512 encoding (not bcrypt!)
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
    $stmt = $pdo->prepare("SELECT id, username, password, salt FROM oro_user WHERE username = :username");
    $stmt->execute(['username' => 'mounir']);
    $user = $stmt->fetch(PDO::FETCH_ASSOC);
    
    if (!$user) {
        echo "❌ User 'mounir' not found!\n";
        exit(1);
    }
    
    echo "✅ User found: {$user['username']}\n";
    echo "   Current password: " . substr($user['password'], 0, 30) . "...\n";
    echo "   Current salt: " . substr($user['salt'], 0, 20) . "...\n";
    
    // Akeneo uses SHA512 with salt, not bcrypt!
    // Format: hash('sha512', $password.$salt)
    $newPassword = '2026';
    $salt = $user['salt']; // Keep existing salt
    
    // Generate SHA512 hash with salt (Akeneo format)
    $hashedPassword = hash('sha512', $newPassword . '{' . $salt . '}');
    
    echo "\n🔐 Creating SHA512 password hash...\n";
    echo "   New hash: " . substr($hashedPassword, 0, 30) . "...\n";
    
    // Update password in database
    $updateStmt = $pdo->prepare("UPDATE oro_user SET password = :password WHERE username = :username");
    $updateStmt->execute([
        'password' => $hashedPassword,
        'username' => 'mounir'
    ]);
    
    echo "✅ Password updated successfully!\n";
    echo "📋 Credentials: mounir / 2026\n";
    
    // Verify the password works with SHA512
    $verifyHash = hash('sha512', $newPassword . '{' . $salt . '}');
    if ($verifyHash === $hashedPassword) {
        echo "✅ SHA512 hash verification successful!\n";
    } else {
        echo "❌ SHA512 hash verification failed!\n";
    }
    
    // Reset auth failure counter
    $pdo->prepare("UPDATE oro_user SET consecutive_authentication_failure_counter = 0, authentication_failure_reset_date = NULL WHERE username = :username")
        ->execute(['username' => 'mounir']);
    
    echo "✅ Auth failure counter reset!\n";
    
} catch (PDOException $e) {
    echo "❌ Database error: " . $e->getMessage() . "\n";
    exit(1);
} catch (Exception $e) {
    echo "❌ Error: " . $e->getMessage() . "\n";
    exit(1);
}
