<?php
require __DIR__.'/config/bootstrap.php';
use Symfony\Component\PasswordHasher\Hasher\PasswordHasherFactory;

$factory = new PasswordHasherFactory([
    'common' => ['algorithm' => 'auto'],
]);
$passwordHasher = $factory->getPasswordHasher('common');
$hash = $passwordHasher->hash('admin');

$dsn = "mysql:host=127.0.0.1;port=3307;dbname=akeneo_pim";
$pdo = new PDO($dsn, 'akeneo_pim', 'akeneo_pim', [
    PDO::MYSQL_ATTR_SSL_VERIFY_SERVER_CERT => false
]);

$stmt = $pdo->prepare("UPDATE oro_user SET password=?, salt=NULL WHERE username='admin'");
$stmt->execute([$hash]);

echo "Admin password reset to 'admin'\n";
echo "Password hash: " . substr($hash, 0, 50) . "...\n";
