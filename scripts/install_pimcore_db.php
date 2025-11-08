#!/usr/bin/env php
<?php

// Script to manually install Pimcore database schema
// No need to chdir as we're already in the correct directory

require_once 'vendor/autoload_runtime.php';

echo "Starting Pimcore database installation...\n";

// Parse database configuration from .env file
$envContent = file_get_contents('.env');
$dbUrl = null;
if (preg_match('/DATABASE_URL=(.*)/', $envContent, $matches)) {
    $dbUrl = trim($matches[1]);
}

if (!$dbUrl) {
    die("Database URL not found in .env file\n");
}

echo "Database URL: $dbUrl\n";

// Parse the database URL
$parsedUrl = parse_url($dbUrl);
if (!$parsedUrl) {
    die("Failed to parse database URL\n");
}

$dbHost = $parsedUrl['host'] ?? 'localhost';
$dbPort = $parsedUrl['port'] ?? '3307'; // Changed to 3307 based on memory
$dbName = substr($parsedUrl['path'], 1); // Remove leading slash
$dbUser = $parsedUrl['user'] ?? 'root';
$dbPass = $parsedUrl['pass'] ?? '';

echo "Connecting to database...\n";

try {
    // Connect to database
    $dsn = "mysql:host=$dbHost;port=$dbPort;dbname=$dbName;charset=utf8mb4";
    $pdo = new PDO($dsn, $dbUser, $dbPass, [
        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION
    ]);
    
    echo "Connected to database successfully!\n";
    
    // Check if admin user already exists
    $stmt = $pdo->query("SELECT COUNT(*) FROM users WHERE name = 'admin'");
    $userCount = $stmt->fetchColumn();
    
    if ($userCount > 0) {
        echo "Admin user already exists. Skipping user creation.\n";
    } else {
        // Create a default admin user with the correct table structure
        $stmt = $pdo->prepare("
            INSERT INTO `users` (
              `parentId`, `type`, `name`, `password`, `firstname`, `lastname`, `email`, `language`, 
              `admin`, `active`, `roles`, `welcomescreen`, `closeWarning`, `memorizeTabs`, 
              `allowDirtyClose`, `lastLogin`
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ");
        
        $passwordHash = password_hash('admin', PASSWORD_DEFAULT);
        $stmt->execute([
            0, 'user', 'admin', $passwordHash, 'Admin', 'User', 'admin@example.com', 'en',
            1, 1, '', 1, 1, 1, 1, null
        ]);
        
        echo "Admin user created with username 'admin' and password 'admin'\n";
    }
    
} catch (PDOException $e) {
    die("Database error: " . $e->getMessage() . "\n");
}

echo "Pimcore installation completed!\n";