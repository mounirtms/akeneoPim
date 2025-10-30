<?php
try {
    $pdo = new PDO('mysql:host=127.0.0.1;port=3307', 'root', 'YourNewStrongPassword');
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    
    $sql = "CREATE DATABASE IF NOT EXISTS pimcore CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci";
    $pdo->exec($sql);
    
    echo "Database 'pimcore' created successfully with utf8mb4 charset.\n";
} catch (PDOException $e) {
    echo "Error: " . $e->getMessage() . "\n";
}
?>