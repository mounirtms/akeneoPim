<?php

require_once __DIR__ . '/../vendor/autoload.php';

$setup = new \Pimcore\Bundle\InstallBundle\SystemConfig\ConfigWriter();
$setup->writeConfig([
    'database' => [
        'params' => [
            'username' => 'root',
            'password' => 'YourNewStrongPassword',
            'dbname' => 'pimcore',
            'host' => '127.0.0.1',
            'port' => '3307',
            'adapter' => 'Pdo_Mysql'
        ]
    ]
]);