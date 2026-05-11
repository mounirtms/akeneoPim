<?php
// Simple bcrypt hash for 'admin'
$password = 'admin';
$hash = password_hash($password, PASSWORD_BCRYPT, ['cost' => 13]);

$dsn = "mysql:host=127.0.0.1;port=3307;dbname=akeneo_pim";
try {
    $pdo = new PDO($dsn, 'akeneo_pim', 'akeneo_pim', [
        PDO::MYSQL_ATTR_SSL_VERIFY_SERVER_CERT => false,
        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION
    ]);
    
    $stmt = $pdo->prepare("UPDATE oro_user SET password=? WHERE username='admin'");
    $stmt->execute([$hash]);
    
    echo "✅ Admin password reset successfully!\n";
    echo "Username: admin\n";
    echo "Password: admin\n";
    echo "Hash: " . substr($hash, 0, 40) . "...\n";
    
} catch (Exception $e) {
    echo "❌ Error: " . $e->getMessage() . "\n";
}
