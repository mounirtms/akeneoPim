#!/usr/bin/env php
<?php

require_once __DIR__ . '/vendor/autoload.php';

use Pimcore\Console\Application;
use Symfony\Component\Console\Input\ArgvInput;
use Symfony\Component\Console\Output\ConsoleOutput;

// Create the application
$app = new Application();
$app->setAutoExit(false);

// Create input and output
$input = new ArgvInput(['', 'pimcore:run-script', '--script=' . __DIR__ . '/setup_classes_script.php']);
$output = new ConsoleOutput();

// Run the application
exit($app->run($input, $output));