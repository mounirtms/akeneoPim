<?php

include_once __DIR__ . '/vendor/autoload.php';

\Pimcore\Bootstrap::setProjectRoot();
\Pimcore\Bootstrap::bootstrap();

echo "=== Fixing Dashboard Issues ===\n\n";

try {
    $db = \Pimcore\Db::get();
    
    // 1. Fix DataHub configuration activation
    echo "1. Checking DataHub configuration...\n";
    $stmt = $db->prepare("SELECT id, name, active, configuration FROM datahub_configurations WHERE name = ?");
    $stmt->execute(['products']);
    $config = $stmt->fetch();
    
    if ($config) {
        echo "   Found DataHub configuration: {$config['name']}\n";
        echo "   Active status: {$config['active']}\n";
        
        // Decode the configuration to check if it's valid
        $configData = json_decode($config['configuration'], true);
        if ($configData) {
            echo "   Configuration is valid JSON\n";
            
            // Ensure it's marked as active
            if ($config['active'] != 1) {
                echo "   Activating configuration...\n";
                $updateStmt = $db->prepare("UPDATE datahub_configurations SET active = 1 WHERE id = ?");
                $updateStmt->execute([$config['id']]);
                echo "   Configuration activated.\n";
            } else {
                echo "   Configuration is already active.\n";
            }
        } else {
            echo "   ERROR: Configuration is not valid JSON\n";
        }
    } else {
        echo "   ERROR: No DataHub configuration found\n";
    }
    
    // 2. Fix missing asset paths
    echo "\n2. Checking asset paths...\n";
    
    // Check if the assets directory exists
    $assetsDir = __DIR__ . '/public/var/assets';
    if (!is_dir($assetsDir)) {
        echo "   Creating assets directory: $assetsDir\n";
        mkdir($assetsDir, 0755, true);
    } else {
        echo "   Assets directory exists: $assetsDir\n";
    }
    
    // Check if the images/products directory exists
    $imagesDir = $assetsDir . '/images/products';
    if (!is_dir($imagesDir)) {
        echo "   Creating images/products directory: $imagesDir\n";
        mkdir($imagesDir, 0755, true);
    } else {
        echo "   Images/products directory exists: $imagesDir\n";
    }
    
    // 3. Rebuild classes to fix Product class loader issue
    echo "\n3. Rebuilding classes...\n";
    try {
        $process = new \Symfony\Component\Process\Process([
            './bin/console',
            'pimcore:deployment:classes-rebuild',
            '--create-classes'
        ]);
        $process->setWorkingDirectory(__DIR__);
        $process->setTimeout(300); // 5 minutes timeout
        $process->run();
        
        if ($process->isSuccessful()) {
            echo "   Classes rebuilt successfully.\n";
        } else {
            echo "   WARNING: Class rebuilding had issues:\n";
            echo "   " . $process->getErrorOutput() . "\n";
        }
    } catch (Exception $e) {
        echo "   ERROR during class rebuilding: " . $e->getMessage() . "\n";
    }
    
    // 4. Clear cache
    echo "\n4. Clearing cache...\n";
    try {
        $process = new \Symfony\Component\Process\Process([
            './bin/console',
            'cache:clear'
        ]);
        $process->setWorkingDirectory(__DIR__);
        $process->setTimeout(120); // 2 minutes timeout
        $process->run();
        
        if ($process->isSuccessful()) {
            echo "   Cache cleared successfully.\n";
        } else {
            echo "   WARNING: Cache clearing had issues:\n";
            echo "   " . $process->getErrorOutput() . "\n";
        }
    } catch (Exception $e) {
        echo "   ERROR during cache clearing: " . $e->getMessage() . "\n";
    }
    
    // 5. Fix permissions
    echo "\n5. Fixing permissions...\n";
    try {
        // Make sure var directory has correct permissions
        $process = new \Symfony\Component\Process\Process([
            'chmod',
            '-R',
            '775',
            'var'
        ]);
        $process->setWorkingDirectory(__DIR__);
        $process->run();
        
        $process = new \Symfony\Component\Process\Process([
            'chown',
            '-R',
            'pim:nobody',
            'var'
        ]);
        $process->setWorkingDirectory(__DIR__);
        $process->run();
        
        echo "   Permissions fixed.\n";
    } catch (Exception $e) {
        echo "   ERROR during permission fixing: " . $e->getMessage() . "\n";
    }
    
    echo "\n=== Fix Process Completed ===\n";
    echo "Please restart your web server to apply all changes.\n";
    
} catch (Exception $e) {
    echo "ERROR: " . $e->getMessage() . "\n";
    echo "TRACE: " . $e->getTraceAsString() . "\n";
}