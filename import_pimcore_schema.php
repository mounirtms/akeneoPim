<?php
try {
    $pdo = new PDO('mysql:host=127.0.0.1;port=3307;dbname=pimcore;charset=utf8mb4', 'root', 'YourNewStrongPassword');
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    
    // Read the SQL file
    $sql = file_get_contents('vendor/pimcore/pimcore/bundles/InstallBundle/dump/install.sql');
    
    // Split the SQL into individual statements
    $statements = explode(';', $sql);
    
    $successCount = 0;
    $errorCount = 0;
    
    foreach ($statements as $statement) {
        $statement = trim($statement);
        if (!empty($statement)) {
            try {
                $pdo->exec($statement);
                $successCount++;
            } catch (PDOException $e) {
                $errorCount++;
                // Skip errors for now, as some statements might fail due to dependencies
            }
        }
    }
    
    echo "SQL import completed. Successful statements: $successCount, Errors: $errorCount\n";
    
    // Now try to run the statements that failed due to dependencies
    foreach ($statements as $statement) {
        $statement = trim($statement);
        if (!empty($statement)) {
            try {
                $pdo->exec($statement);
            } catch (PDOException $e) {
                // Ignore errors on second pass
            }
        }
    }
    
    echo "Second pass completed.\n";
} catch (PDOException $e) {
    echo "Error: " . $e->getMessage() . "\n";
}
?>