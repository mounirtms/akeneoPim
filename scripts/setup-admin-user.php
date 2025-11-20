<?php

use Pimcore\Console\Application;
use Pimcore\Model\User;
use Symfony\Component\Console\Input\ArgvInput;
use Symfony\Component\Console\Output\ConsoleOutput;

include __DIR__ . '/../vendor/autoload.php';

\Pimcore\Bootstrap::setProjectRoot();
\Pimcore\Bootstrap::bootstrap();

$application = new Application(\Pimcore::getKernel());
$application->setAutoExit(false);

echo "Setting up admin user...\n";

try {
    $user = User::getByName('admin');
    
    if (!$user) {
        echo "Creating admin user...\n";
        $user = User::create([
            'parentId' => 0,
            'username' => 'admin',
            'password' => 'f3j3f6E4d1O6G1C2',
            'active' => true,
            'admin' => true
        ]);
    } else {
        echo "Updating existing admin user...\n";
        $user->setPassword('f3j3f6E4d1O6G1C2');
        $user->setActive(true);
        $user->setAdmin(true);
    }
    
    // Set all permissions
    $user->setAllAclToAllowed();
    $user->setPermissions('all');
    $user->save();
    
    echo "✅ Admin user configured successfully!\n";
    echo "Username: admin\n";
    echo "Password: f3j3f6E4d1O6G1C2\n";
    echo "Admin: Yes\n";
    echo "Permissions: All granted\n";
    
} catch (Exception $e) {
    echo "❌ Error: " . $e->getMessage() . "\n";
}
