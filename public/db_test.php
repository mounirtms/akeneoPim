<?php

// Test database connection
echo "<h1>Database Connection Test</h1>";

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
    
    echo "<p>Database URL found: " . substr($dbUrl, 0, 50) . "...</p>";
    
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
    
    echo "<p style='color: green;'><strong>✓ Database connection successful!</strong></p>";
    
    // Check if users table exists
    $stmt = $pdo->query("SHOW TABLES LIKE 'users'");
    if ($stmt->rowCount() > 0) {
        echo "<p style='color: green;'><strong>✓ Users table exists!</strong></p>";
        
        // Check how many users exist
        $stmt = $pdo->query("SELECT COUNT(*) as count FROM users");
        $row = $stmt->fetch(PDO::FETCH_ASSOC);
        echo "<p>Number of users in database: " . $row['count'] . "</p>";
        
        if ($row['count'] > 0) {
            // Show user information
            $stmt = $pdo->query("SELECT id, name, email, admin FROM users");
            echo "<h2>Users:</h2><ul>";
            while ($user = $stmt->fetch(PDO::FETCH_ASSOC)) {
                echo "<li>ID: " . $user['id'] . ", Name: " . $user['name'] . ", Email: " . $user['email'] . ", Admin: " . ($user['admin'] ? 'Yes' : 'No') . "</li>";
            }
            echo "</ul>";
        }
    } else {
        echo "<p style='color: red;'><strong>✗ Users table not found!</strong></p>";
    }
    
    // List some tables
    echo "<h2>Database Tables:</h2>";
    $stmt = $pdo->query("SHOW TABLES");
    echo "<ul>";
    $count = 0;
    while ($row = $stmt->fetch(PDO::FETCH_NUM) && $count < 20) {
        echo "<li>" . $row[0] . "</li>";
        $count++;
    }
    if ($count >= 20) {
        echo "<li>... and more</li>";
    }
    echo "</ul>";
    
} catch (Exception $e) {
    echo "<p style='color: red;'><strong>✗ Database connection failed:</strong> " . $e->getMessage() . "</p>";
}

echo "<h2>Next Steps</h2>";
echo "<p>If the database connection is working and tables exist, you should be able to access your Pimcore installation at <a href='/'>the main page</a> and <a href='/admin'>the admin panel</a>.</p>";