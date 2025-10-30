<?php
try {
    $pdo = new PDO('mysql:host=127.0.0.1;port=3307;dbname=pimcore;charset=utf8mb4', 'root', 'YourNewStrongPassword');
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    
    // Read the SQL file
    $sql = file_get_contents('vendor/pimcore/pimcore/bundles/InstallBundle/dump/install.sql');
    
    // Split the SQL into individual statements
    $statements = explode(';', $sql);
    
    foreach ($statements as $statement) {
        $statement = trim($statement);
        if (!empty($statement)) {
            try {
                $pdo->exec($statement);
            } catch (PDOException $e) {
                echo "Error executing statement: " . $e->getMessage() . "\n";
                echo "Statement: " . $statement . "\n\n";
            }
        }
    }
    
    echo "SQL file imported successfully.\n";
} catch (PDOException $e) {
    echo "Error: " . $e->getMessage() . "\n";
}
?>