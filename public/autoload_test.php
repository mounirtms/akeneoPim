<?php

echo "Testing autoloader...\n";

// Try to include the autoloader
$autoloadPath = dirname(__DIR__) . '/vendor/autoload_runtime.php';

if (file_exists($autoloadPath)) {
    echo "Autoload file exists at: $autoloadPath\n";
    
    try {
        require_once $autoloadPath;
        echo "Autoloader included successfully!\n";
    } catch (Exception $e) {
        echo "Error including autoloader: " . $e->getMessage() . "\n";
    }
} else {
    echo "Autoload file does not exist at: $autoloadPath\n";
    echo "Contents of vendor directory:\n";
    print_r(scandir(dirname($autoloadPath)));
}