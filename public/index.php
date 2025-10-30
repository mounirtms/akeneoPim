<?php

use App\Kernel;
use Pimcore\Bootstrap;

require_once dirname(__DIR__).'/vendor/autoload_runtime.php';

return function (array $context) {
    // Explicitly set environment to production
    $context['APP_ENV'] = 'prod';
    $context['APP_DEBUG'] = false;
    
    // Set the project root before bootstrapping
    Bootstrap::setProjectRoot();
    
    // Bootstrap Pimcore
    Bootstrap::bootstrap();
    
    $kernel = new Kernel($context['APP_ENV'], (bool) $context['APP_DEBUG']);
    
    // Initialize Pimcore with the kernel
    \Pimcore::setKernel($kernel);
    
    return $kernel;
};