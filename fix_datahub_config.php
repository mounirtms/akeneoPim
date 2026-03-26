<?php

// Script to check and fix DataHub configuration

include_once __DIR__ . '/vendor/autoload.php';

\Pimcore\Bootstrap::setProjectRoot();
\Pimcore\Bootstrap::bootstrap();

echo "=== DataHub Configuration Check and Fix ===\n\n";

try {
    // Get database connection
    $db = \Pimcore\Db::get();
    
    // Check if DataHub configuration exists
    echo "Checking DataHub configurations...\n";
    $stmt = $db->prepare("SELECT id, name, type, active, configuration FROM datahub_configurations");
    $stmt->execute();
    $configs = $stmt->fetchAll();
    
    if (empty($configs)) {
        echo "No DataHub configurations found.\n";
    } else {
        echo "Found " . count($configs) . " DataHub configuration(s):\n";
        foreach ($configs as $config) {
            echo "- ID: " . $config['id'] . ", Name: " . $config['name'] . ", Type: " . $config['type'] . ", Active: " . $config['active'] . "\n";
            
            // Try to decode the configuration
            $configData = json_decode($config['configuration'], true);
            if ($configData) {
                echo "  Configuration:\n";
                echo "    Type: " . ($configData['general']['type'] ?? 'N/A') . "\n";
                echo "    Name: " . ($configData['general']['name'] ?? 'N/A') . "\n";
                echo "    Description: " . ($configData['general']['description'] ?? 'N/A') . "\n";
                echo "    Active: " . ($configData['general']['active'] ?? 'N/A') . "\n";
                
                // Make sure it's active
                if (!$config['active'] || !$configData['general']['active']) {
                    echo "  Activating configuration...\n";
                    
                    // Update database to activate
                    $configData['general']['active'] = true;
                    $updatedConfig = json_encode($configData);
                    
                    $updateStmt = $db->prepare("UPDATE datahub_configurations SET active = 1, configuration = ? WHERE id = ?");
                    $updateStmt->execute([$updatedConfig, $config['id']]);
                    
                    echo "  Configuration activated.\n";
                }
            } else {
                echo "  Failed to decode configuration.\n";
            }
        }
    }
    
    // Try to migrate legacy configurations
    echo "\nMigrating legacy DataHub configurations...\n";
    $process = new \Symfony\Component\Process\Process(['./bin/console', 'datahub:configuration:migrate-legacy-config']);
    $process->setWorkingDirectory(__DIR__);
    $process->run();
    
    if (!$process->isSuccessful()) {
        echo "Warning: Migration failed: " . $process->getErrorOutput() . "\n";
    } else {
        echo "Migration completed successfully.\n";
        echo $process->getOutput() . "\n";
    }
    
    // Clear cache
    echo "\nClearing cache...\n";
    $process = new \Symfony\Component\Process\Process(['./bin/console', 'cache:clear']);
    $process->setWorkingDirectory(__DIR__);
    $process->run();
    
    if (!$process->isSuccessful()) {
        echo "Warning: Cache clearing failed: " . $process->getErrorOutput() . "\n";
    } else {
        echo "Cache cleared successfully.\n";
    }
    
    // Warm up cache
    echo "\nWarming up cache...\n";
    $process = new \Symfony\Component\Process\Process(['./bin/console', 'cache:warmup']);
    $process->setWorkingDirectory(__DIR__);
    $process->run();
    
    if (!$process->isSuccessful()) {
        echo "Warning: Cache warming failed: " . $process->getErrorOutput() . "\n";
    } else {
        echo "Cache warmed up successfully.\n";
    }
    
    echo "\n=== DataHub Configuration Check and Fix Completed ===\n";
    
} catch (Exception $e) {
    echo "Error: " . $e->getMessage() . "\n";
}