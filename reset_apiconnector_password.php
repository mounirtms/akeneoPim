<?php
/**
 * Reset API Connector Password
 * Sets a known password for the apiconnector user
 */

require __DIR__ . '/vendor/autoload.php';

use Symfony\Component\DependencyInjection\ContainerBuilder;
use Akeneo\UserManagement\Component\Model\User;

// Bootstrap Symfony Kernel
$_SERVER['APP_ENV'] = 'prod';
$_SERVER['APP_DEBUG'] = '0';

require_once __DIR__.'/config/bootstrap.php';
$kernel = new \Kernel($_SERVER['APP_ENV'], (bool) $_SERVER['APP_DEBUG']);
$kernel->boot();
$container = $kernel->getContainer();

echo "=== RESETTING API CONNECTOR PASSWORD ===\n\n";

try {
    // Get user repository and password encoder
    $userRepository = $container->get('pim_user.repository.user');
    $passwordEncoder = $container->get('security.password_encoder');
    $entityManager = $container->get('doctrine.orm.entity_manager');
    
    // Find apiconnector user
    $user = $userRepository->findOneBy(['username' => 'apiconnector']);
    
    if (!$user) {
        echo "❌ User 'apiconnector' not found!\n";
        exit(1);
    }
    
    echo "Found user: {$user->getUsername()}\n";
    echo "Email: {$user->getEmail()}\n";
    echo "Current status: " . ($user->isEnabled() ? 'Enabled' : 'Disabled') . "\n\n";
    
    // Set new password
    $newPassword = 'ApiConnector@2026!Secure';
    $encodedPassword = $passwordEncoder->encodePassword($user, $newPassword);
    
    $user->setPassword($encodedPassword);
    $user->setEnabled(true); // Ensure user is enabled
    
    // Save
    $entityManager->persist($user);
    $entityManager->flush();
    
    echo "✅ Password reset successfully!\n";
    echo "\nNew Credentials:\n";
    echo "   Username: apiconnector\n";
    echo "   Password: $newPassword\n";
    echo "   Email: {$user->getEmail()}\n";
    echo "   Status: Enabled\n\n";
    
    echo "You can now use these credentials for:\n";
    echo "- OAuth API authentication\n";
    echo "- Magento Akeneo Connector\n";
    echo "- Any other API integrations\n";
    
} catch (\Exception $e) {
    echo "❌ Error: " . $e->getMessage() . "\n";
    echo "Stack trace:\n" . $e->getTraceAsString() . "\n";
    exit(1);
}
