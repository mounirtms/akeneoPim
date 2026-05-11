<?php
// Direct authentication test using Symfony components
require_once __DIR__ . '/vendor/autoload.php';

use Symfony\Component\Dotenv\Dotenv;

// Load environment
$dotenv = new Dotenv();
$dotenv->bootEnv(__DIR__ . '/.env');

// Boot Symfony kernel
require_once __DIR__ . '/config/bootstrap.php';

$kernel = new \Kernel($_SERVER['APP_ENV'], (bool) $_SERVER['APP_DEBUG']);
$kernel->boot();

$container = $kernel->getContainer();

echo "🔍 DIRECT SYMFONY AUTHENTICATION TEST\n";
echo str_repeat('=', 80) . "\n";

try {
    // Get password encoder
    $encoderFactory = $container->get('security.encoder_factory');
    
    // Get user provider
    $userProvider = $container->get('pim_user.provider.user');
    
    // Test admin
    echo "\n📋 Testing admin user...\n";
    try {
        $adminUser = $userProvider->loadUserByUsername('admin');
        echo "   ✅ User loaded: {$adminUser->getUsername()}\n";
        echo "   Email: {$adminUser->getEmail()}\n";
        echo "   Enabled: " . ($adminUser->isEnabled() ? 'Yes' : 'No') . "\n";
        
        $encoder = $encoderFactory->getEncoder($adminUser);
        echo "   Encoder class: " . get_class($encoder) . "\n";
        
        $testPassword = 'admin';
        $isValid = $encoder->isPasswordValid($adminUser->getPassword(), $testPassword, $adminUser->getSalt());
        
        if ($isValid) {
            echo "   ✅ Password 'admin' is VALID!\n";
        } else {
            echo "   ❌ Password 'admin' is INVALID!\n";
            
            // Debug: show stored hash
            echo "   Stored hash: " . substr($adminUser->getPassword(), 0, 30) . "...\n";
            echo "   Salt: " . substr($adminUser->getSalt(), 0, 20) . "...\n";
            
            // Try encoding the password
            $encoded = $encoder->encodePassword($testPassword, $adminUser->getSalt());
            echo "   Expected hash: " . substr($encoded, 0, 30) . "...\n";
            
            if ($encoded === $adminUser->getPassword()) {
                echo "   ✅ Hash matches when encoded!\n";
            } else {
                echo "   ❌ Hash does NOT match!\n";
            }
        }
    } catch (Exception $e) {
        echo "   ❌ Error loading admin: {$e->getMessage()}\n";
    }
    
    // Test mounir
    echo "\n📋 Testing mounir user...\n";
    try {
        $mounirUser = $userProvider->loadUserByUsername('mounir');
        echo "   ✅ User loaded: {$mounirUser->getUsername()}\n";
        echo "   Email: {$mounirUser->getEmail()}\n";
        echo "   Enabled: " . ($mounirUser->isEnabled() ? 'Yes' : 'No') . "\n";
        
        $encoder = $encoderFactory->getEncoder($mounirUser);
        
        $testPassword = '2026';
        $isValid = $encoder->isPasswordValid($mounirUser->getPassword(), $testPassword, $mounirUser->getSalt());
        
        if ($isValid) {
            echo "   ✅ Password '2026' is VALID!\n";
        } else {
            echo "   ❌ Password '2026' is INVALID!\n";
            
            // Debug
            echo "   Stored hash: " . substr($mounirUser->getPassword(), 0, 30) . "...\n";
            echo "   Salt: " . substr($mounirUser->getSalt(), 0, 20) . "...\n";
            
            $encoded = $encoder->encodePassword($testPassword, $mounirUser->getSalt());
            echo "   Expected hash: " . substr($encoded, 0, 30) . "...\n";
            
            if ($encoded === $mounirUser->getPassword()) {
                echo "   ✅ Hash matches when encoded!\n";
            } else {
                echo "   ❌ Hash does NOT match!\n";
            }
        }
    } catch (Exception $e) {
        echo "   ❌ Error loading mounir: {$e->getMessage()}\n";
    }
    
    echo "\n" . str_repeat('=', 80) . "\n";
    echo "✓ Direct authentication test complete\n";
    echo str_repeat('=', 80) . "\n";
    
} catch (Exception $e) {
    echo "\n❌ Fatal error: {$e->getMessage()}\n";
    echo $e->getTraceAsString() . "\n";
}
