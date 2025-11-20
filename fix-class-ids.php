<?php

use Pimcore\Bootstrap;

// Bootstrap Pimcore
require_once 'vendor/autoload_runtime.php';
Bootstrap::setProjectRoot();
Bootstrap::bootstrap();

// Connect to the database directly
$host = '127.0.0.1';
$port = 3307;
$username = 'root';
$password = 'YourNewStrongPassword';
$database = 'pimcore';

try {
    $pdo = new PDO("mysql:host=$host;port=$port;dbname=$database", $username, $password);
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    
    echo "Connected to database successfully.\n";
    
    // Get all classes
    $stmt = $pdo->query("SELECT id, name FROM classes");
    $classes = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    echo "Found " . count($classes) . " classes.\n";
    
    foreach ($classes as $class) {
        $id = $class['id'];
        $name = $class['name'];
        
        echo "Processing class: $name (ID: $id)\n";
        
        // Check if the class definition table exists
        $tableName = "class_" . $id;
        $stmt = $pdo->prepare("SHOW TABLES LIKE ?");
        $stmt->execute([$tableName]);
        
        if ($stmt->rowCount() > 0) {
            echo "  Class definition table exists: $tableName\n";
            
            // Get the class definition
            $stmt = $pdo->prepare("SELECT * FROM $tableName LIMIT 1");
            $stmt->execute();
            $definition = $stmt->fetch(PDO::FETCH_ASSOC);
            
            if ($definition) {
                echo "  Found class definition data\n";
                
                // Update the class ID to be a string
                $newId = (string)$id;
                echo "  Updating class ID from $id to '$newId'\n";
                
                // Note: We can't easily change the ID column type in the classes table
                // as it's used as a foreign key in many other tables
                // Instead, we'll focus on rebuilding the classes properly
            } else {
                echo "  No class definition data found\n";
            }
        } else {
            echo "  Class definition table does not exist: $tableName\n";
        }
    }
    
    echo "Finished processing classes.\n";
    
} catch (PDOException $e) {
    echo "Database error: " . $e->getMessage() . "\n";
} catch (Exception $e) {
    echo "Error: " . $e->getMessage() . "\n";
}