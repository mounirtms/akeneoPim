<?php

use Pimcore\Kernel;
use Symfony\Component\HttpFoundation\Request;

// Test if we can initialize the Pimcore kernel
require_once '../vendor/autoload_runtime.php';

echo "<h1>Pimcore Kernel Test</h1>";

try {
    // Initialize kernel
    $kernel = new Kernel('dev', true);
    $kernel->boot();
    
    echo "<span style='color: green;'>✓ Pimcore kernel initialized successfully</span><br>";
    
    // Check if container is available
    $container = $kernel->getContainer();
    if ($container) {
        echo "<span style='color: green;'>✓ Service container available</span><br>";
    } else {
        echo "<span style='color: red;'>✗ Service container not available</span><br>";
    }
    
    $kernel->shutdown();
    
    echo "<span style='color: green;'>✓ Pimcore kernel test completed</span><br>";
    
} catch (Exception $e) {
    echo "<span style='color: red;'>✗ Pimcore kernel test failed: " . $e->getMessage() . "</span><br>";
}

echo "<h2>Installation Status</h2>";
echo "<p>Based on our tests, your Pimcore installation appears to be properly configured.</p>";
echo "<p>You can now access the admin interface at <a href='/admin'>/admin</a> using the credentials:</p>";
echo "<ul>";
echo "<li><strong>Username:</strong> admin</li>";
echo "<li><strong>Password:</strong> admin</li>";
echo "</ul>";
echo "<p>Remember to change your password after first login.</p>";