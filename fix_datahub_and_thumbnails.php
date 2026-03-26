<?php

// Fix DataHub configuration and rebuild classes

include_once __DIR__ . '/vendor/autoload.php';

\Pimcore\Bootstrap::setProjectRoot();
\Pimcore\Bootstrap::bootstrap();

echo "=== Fixing DataHub Configuration and Rebuilding Classes ===\n\n";

try {
    // First, let's clear the cache
    echo "Clearing cache...\n";
    $process = new \Symfony\Component\Process\Process(['./bin/console', 'cache:clear', '--no-warmup']);
    $process->setWorkingDirectory(__DIR__);
    $process->run();
    
    if (!$process->isSuccessful()) {
        echo "Warning: Cache clearing failed: " . $process->getErrorOutput() . "\n";
    } else {
        echo "Cache cleared successfully.\n";
    }
    
    // Rebuild classes
    echo "Rebuilding classes...\n";
    $process = new \Symfony\Component\Process\Process(['./bin/console', 'pimcore:deployment:classes-rebuild', '--create-classes']);
    $process->setWorkingDirectory(__DIR__);
    $process->run();
    
    if (!$process->isSuccessful()) {
        echo "Warning: Class rebuilding failed: " . $process->getErrorOutput() . "\n";
    } else {
        echo "Classes rebuilt successfully.\n";
    }
    
    // Activate DataHub configuration
    echo "Activating DataHub configuration...\n";
    $db = \Pimcore\Db::get();
    
    // Make sure the DataHub configuration is active
    $stmt = $db->prepare("UPDATE datahub_configurations SET active = 1 WHERE name = 'products'");
    $stmt->execute();
    
    echo "DataHub configuration activated.\n";
    
    // Check if we can access the DataHub bundle
    echo "Checking DataHub bundle...\n";
    $process = new \Symfony\Component\Process\Process(['./bin/console', 'pimcore:bundle:list']);
    $process->setWorkingDirectory(__DIR__);
    $process->run();
    
    if ($process->isSuccessful()) {
        $output = $process->getOutput();
        if (strpos($output, 'PimcoreDataHubBundle') !== false) {
            echo "DataHub bundle is installed.\n";
        } else {
            echo "DataHub bundle not found in the list.\n";
        }
    } else {
        echo "Failed to check bundles: " . $process->getErrorOutput() . "\n";
    }
    
    // Try to install the DataHub bundle if it's not installed
    echo "Installing DataHub bundle...\n";
    $process = new \Symfony\Component\Process\Process(['./bin/console', 'pimcore:bundle:install', 'PimcoreDataHubBundle']);
    $process->setWorkingDirectory(__DIR__);
    $process->run();
    
    if (!$process->isSuccessful()) {
        echo "Warning: Bundle installation failed (may already be installed): " . $process->getErrorOutput() . "\n";
    } else {
        echo "DataHub bundle installed successfully.\n";
    }
    
    // Warm up the cache
    echo "Warming up cache...\n";
    $process = new \Symfony\Component\Process\Process(['./bin/console', 'cache:warmup']);
    $process->setWorkingDirectory(__DIR__);
    $process->run();
    
    if (!$process->isSuccessful()) {
        echo "Warning: Cache warmup failed: " . $process->getErrorOutput() . "\n";
    } else {
        echo "Cache warmed up successfully.\n";
    }
    
    echo "\n=== Fix Process Completed ===\n";
    echo "Please check if DataHub endpoint is now accessible.\n";
    
} catch (Exception $e) {
    echo "Error during fix process: " . $e->getMessage() . "\n";
}