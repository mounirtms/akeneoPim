<?php

echo "<h1>Pimcore Installation Test</h1>";

// Test 1: Check if required files exist
echo "<h2>File System Check</h2>";
$requiredFiles = [
    '../vendor/autoload.php',
    '../.env',
    '../config/packages/pimcore.yaml',
    '../public/index.php'
];

foreach ($requiredFiles as $file) {
    if (file_exists($file)) {
        echo "<span style='color: green;'>✓ $file exists</span><br>";
    } else {
        echo "<span style='color: red;'>✗ $file missing</span><br>";
    }
}

// Test 2: Check database connection
echo "<h2>Database Connection Check</h2>";
try {
    // Parse database configuration from .env file
    $envContent = file_get_contents('../.env');
    if (preg_match('/DATABASE_URL=(.*)/', $envContent, $matches)) {
        $dbUrl = trim($matches[1]);
        echo "<span style='color: green;'>✓ Database URL found: " . substr($dbUrl, 0, 50) . "...</span><br>";
        
        // Parse the database URL
        $parsedUrl = parse_url($dbUrl);
        if ($parsedUrl) {
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
            
            echo "<span style='color: green;'>✓ Database connection successful</span><br>";
            
            // Check if users table exists
            $stmt = $pdo->query("SHOW TABLES LIKE 'users'");
            if ($stmt->rowCount() > 0) {
                echo "<span style='color: green;'>✓ Users table exists</span><br>";
            } else {
                echo "<span style='color: red;'>✗ Users table not found</span><br>";
            }
        } else {
            echo "<span style='color: red;'>✗ Failed to parse database URL</span><br>";
        }
    } else {
        echo "<span style='color: red;'>✗ Database URL not found in .env file</span><br>";
    }
} catch (Exception $e) {
    echo "<span style='color: red;'>✗ Database connection failed: " . $e->getMessage() . "</span><br>";
}

echo "<h2>Next Steps</h2>";
echo "<p>If all checks pass, you should be able to access the Pimcore admin panel at: <a href='/admin'>/admin</a></p>";
echo "<p>Login with username: <strong>admin</strong> and password: <strong>admin</strong></p>";
echo "<p>Remember to change the password after first login!</p>";