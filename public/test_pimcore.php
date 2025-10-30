<?php

// Simple test script to verify Pimcore installation
echo "<h1>Pimcore Installation Test</h1>";

// Test database connection
echo "<h2>Database Connection Test</h2>";
try {
    // Parse database configuration from .env file
    $envContent = file_get_contents(__DIR__ . '/../.env');
    $dbUrl = null;
    if (preg_match('/DATABASE_URL=(.*)/', $envContent, $matches)) {
        $dbUrl = trim($matches[1]);
    }
    
    if (!$dbUrl) {
        throw new Exception("Database URL not found in .env file");
    }
    
    echo "Database URL found: $dbUrl<br>";
    
    // Parse the database URL
    $parsedUrl = parse_url($dbUrl);
    if (!$parsedUrl) {
        throw new Exception("Failed to parse database URL");
    }
    
    $dbHost = $parsedUrl['host'] ?? 'localhost';
    $dbPort = $parsedUrl['port'] ?? '3306';
    $dbName = substr($parsedUrl['path'], 1); // Remove leading slash
    $dbUser = $parsedUrl['user'] ?? 'root';
    $dbPass = $parsedUrl['pass'] ?? '';
    
    // Connect to database
    $dsn = "mysql:host=$dbHost;port=$dbPort;dbname=$dbName;charset=utf8mb4";
    $pdo = new PDO($dsn, $dbUser, $dbPass, [
        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION
    ]);
    
    echo "<span style='color: green;'>✓ Database connection successful!</span><br>";
    
    // Check if users table exists
    $stmt = $pdo->query("SHOW TABLES LIKE 'users'");
    if ($stmt->rowCount() > 0) {
        echo "<span style='color: green;'>✓ Users table exists!</span><br>";
        
        // Check if admin user exists
        $stmt = $pdo->query("SELECT id, name, admin FROM users WHERE name = 'admin'");
        if ($row = $stmt->fetch(PDO::FETCH_ASSOC)) {
            echo "<span style='color: green;'>✓ Admin user exists (ID: {$row['id']})!</span><br>";
        } else {
            echo "<span style='color: red;'>✗ Admin user not found!</span><br>";
        }
    } else {
        echo "<span style='color: red;'>✗ Users table not found!</span><br>";
    }
    
} catch (Exception $e) {
    echo "<span style='color: red;'>✗ Database connection failed: " . $e->getMessage() . "</span><br>";
}

// Test if required directories exist
echo "<h2>Directory Structure Test</h2>";
$requiredDirs = ['public', 'var', 'vendor'];
foreach ($requiredDirs as $dir) {
    if (is_dir(__DIR__ . "/../$dir")) {
        echo "<span style='color: green;'>✓ $dir directory exists</span><br>";
    } else {
        echo "<span style='color: red;'>✗ $dir directory missing</span><br>";
    }
}

// Test if required files exist
echo "<h2>Required Files Test</h2>";
$requiredFiles = ['public/index.php', 'vendor/autoload.php'];
foreach ($requiredFiles as $file) {
    if (file_exists(__DIR__ . "/../$file")) {
        echo "<span style='color: green;'>✓ $file exists</span><br>";
    } else {
        echo "<span style='color: red;'>✗ $file missing</span><br>";
    }
}

echo "<h2>Next Steps</h2>";
echo "<p>If all tests pass, you should be able to access the Pimcore admin panel at: <a href='/admin'>/admin</a></p>";
echo "<p>Login with username: <strong>admin</strong> and password: <strong>admin</strong></p>";
echo "<p>Remember to change the password after first login!</p>";