<?php
require_once 'vendor/autoload_runtime.php';

use Pimcore\Bootstrap;

// Set the project root
$_SERVER['PIMCORE_PROJECT_ROOT'] = $_ENV['PIMCORE_PROJECT_ROOT'] = __DIR__;

// Bootstrap Pimcore
Bootstrap::setProjectRoot();
Bootstrap::bootstrap();

// Create kernel
$kernel = Bootstrap::kernel();
$kernel->boot();

try {
    // Check if admin user already exists
    $user = \Pimcore\Model\User::getByName('admin');
    
    if (!$user) {
        // Create admin user
        $user = new \Pimcore\Model\User();
        $user->setParentId(0);
        $user->setUsername('admin');
        $user->setPassword('admin123'); // This will be hashed automatically
        $user->setFirstname('Admin');
        $user->setLastname('User');
        $user->setEmail('admin@pimcore.local');
        $user->setAdmin(true);
        $user->setActive(true);
        $user->save();
        
        echo "Admin user created successfully.\n";
    } else {
        echo "Admin user already exists.\n";
    }
} catch (Exception $e) {
    echo "Error creating admin user: " . $e->getMessage() . "\n";
}

$kernel->shutdown();
?>