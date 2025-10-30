<?php
require_once dirname(__DIR__).'/vendor/autoload_runtime.php';

echo 'APP_ENV: ' . $_ENV['APP_ENV'] ?? 'Not set';
echo PHP_EOL;
echo 'Environment from kernel: ' . $_SERVER['APP_ENV'] ?? 'Not set';

