<?php
// New password
$password = 'ApiConnector@2026!Secure';
$encoded = hash('sha512', $password);

echo "=== API CONNECTOR PASSWORD UPDATE ===\n\n";

$host = '127.0.0.1';
$port = 3307;
$db = 'akeneo_pim';
$user = 'akeneo_pim';
$pass = 'akeneo_pim';

try {
    $dsn = "mysql:host=$host;port=$port;dbname=$db";
    $pdo = new PDO($dsn, $user, $pass);
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    
    // Update password with empty salt
    $stmt = $pdo->prepare("UPDATE oro_user SET password = ?, salt = '' WHERE username = 'apiconnector'");
    $stmt->execute([$encoded]);
    
    if ($stmt->rowCount() > 0) {
        echo "✅ Password updated successfully for user 'apiconnector'\n\n";
        echo "Credentials:\n";
        echo "  Username: apiconnector\n";
        echo "  Password: $password\n";
        echo "  Email: apiconnector@pim.technostationery.com\n";
    } else {
        echo "❌ User not found\n";
        exit(1);
    }
} catch (PDOException $e) {
    echo "❌ Error: " . $e->getMessage() . "\n";
    exit(1);
}
