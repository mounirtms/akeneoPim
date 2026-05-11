<?php
// Verify admin password and test authentication
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
    
    // Test admin password
    echo "🔍 Testing admin password...\n";
    $stmt = $pdo->prepare("SELECT username, password, enabled FROM oro_user WHERE username = :username");
    $stmt->execute(['username' => 'admin']);
    $admin = $stmt->fetch(PDO::FETCH_ASSOC);
    
    if (!$admin) {
        echo "❌ Admin user not found!\n";
        exit(1);
    }
    
    echo "✅ Admin user found\n";
    echo "   Enabled: " . ($admin['enabled'] ? 'Yes' : 'No') . "\n";
    
    $testPasswords = ['admin', 'Admin123', ''];
    foreach ($testPasswords as $testPwd) {
        if (password_verify($testPwd, $admin['password'])) {
            echo "✅ Admin password is: '$testPwd'\n";
            break;
        }
    }
    
    // Test mounir password
    echo "\n🔍 Testing mounir password...\n";
    $stmt->execute(['username' => 'mounir']);
    $mounir = $stmt->fetch(PDO::FETCH_ASSOC);
    
    if (!$mounir) {
        echo "❌ Mounir user not found!\n";
        exit(1);
    }
    
    echo "✅ Mounir user found\n";
    echo "   Enabled: " . ($mounir['enabled'] ? 'Yes' : 'No') . "\n";
    
    if (password_verify('2026', $mounir['password'])) {
        echo "✅ Mounir password '2026' is correct\n";
    } else {
        echo "❌ Mounir password '2026' is INCORRECT\n";
    }
    
    // Check for any session or security table issues
    echo "\n🔍 Checking security tables...\n";
    
    $tables = $pdo->query("SHOW TABLES LIKE '%session%'")->fetchAll(PDO::FETCH_COLUMN);
    echo "   Session tables: " . count($tables) . "\n";
    
    // Check user roles
    echo "\n🔍 Checking user roles...\n";
    $roleStmt = $pdo->query("
        SELECT u.username, GROUP_CONCAT(r.role) as roles 
        FROM oro_user u 
        LEFT JOIN oro_user_access_role uar ON u.id = uar.user_id 
        LEFT JOIN oro_access_role r ON uar.role_id = r.id 
        WHERE u.username IN ('admin', 'mounir')
        GROUP BY u.username
    ");
    
    while ($row = $roleStmt->fetch(PDO::FETCH_ASSOC)) {
        echo "   {$row['username']}: {$row['roles']}\n";
    }
    
} catch (Exception $e) {
    echo "❌ Error: " . $e->getMessage() . "\n";
    exit(1);
}
