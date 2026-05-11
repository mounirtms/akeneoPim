<?php
// Akeneo uses SHA512 encoding for passwords
$password = 'admin';
$salt = base64_encode(random_bytes(32)); // Generate new salt
$encoded = hash('sha512', $password . '{' . $salt . '}');

$dsn = "mysql:host=127.0.0.1;port=3307;dbname=akeneo_pim";
try {
    $pdo = new PDO($dsn, 'akeneo_pim', 'akeneo_pim', [
        PDO::MYSQL_ATTR_SSL_VERIFY_SERVER_CERT => false,
        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION
    ]);
    
    // Update with SHA512 hash and salt
    $stmt = $pdo->prepare("UPDATE oro_user SET password=?, salt=? WHERE username='admin'");
    $stmt->execute([$encoded, $salt]);
    
    echo "✅ Admin password reset with SHA512 encoding!\n";
    echo "Username: admin\n";
    echo "Password: admin\n";
    echo "Salt: " . substr($salt, 0, 20) . "...\n";
    echo "Hash: " . substr($encoded, 0, 40) . "...\n";
    
} catch (Exception $e) {
    echo "❌ Error: " . $e->getMessage() . "\n";
}
