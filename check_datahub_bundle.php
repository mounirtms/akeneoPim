<?php

include_once __DIR__ . '/vendor/autoload.php';

\Pimcore\Bootstrap::setProjectRoot();
\Pimcore\Bootstrap::bootstrap();

echo "=== Checking DataHub Bundle Status ===\n\n";

try {
    // Check if DataHub bundle is installed and active
    $kernel = \Pimcore::getKernel();
    
    echo "1. Checking if DataHub bundle class exists...\n";
    if (class_exists('\Pimcore\Bundle\DataHubBundle\PimcoreDataHubBundle')) {
        echo "   DataHub bundle class exists\n";
    } else {
        echo "   ERROR: DataHub bundle class does not exist\n";
    }
    
    echo "\n2. Checking if bundle is registered...\n";
    $bundles = $kernel->getBundles();
    $datahubFound = false;
    
    foreach ($bundles as $bundle) {
        $bundleClass = get_class($bundle);
        echo "   Found bundle: " . $bundleClass . "\n";
        if (strpos($bundleClass, 'DataHub') !== false) {
            $datahubFound = true;
        }
    }
    
    if ($datahubFound) {
        echo "   DataHub bundle is registered\n";
    } else {
        echo "   WARNING: DataHub bundle is not registered\n";
    }
    
    echo "\n3. Checking bundles file...\n";
    $bundlesFile = __DIR__ . '/config/bundles.php';
    if (file_exists($bundlesFile)) {
        $bundlesConfig = include $bundlesFile;
        if (isset($bundlesConfig['Pimcore\\Bundle\\DataHubBundle\\PimcoreDataHubBundle'])) {
            echo "   DataHub bundle is configured in bundles.php\n";
            echo "   Status: " . ($bundlesConfig['Pimcore\\Bundle\\DataHubBundle\\PimcoreDataHubBundle'] ? 'enabled' : 'disabled') . "\n";
        } else {
            echo "   DataHub bundle is NOT configured in bundles.php\n";
        }
    } else {
        echo "   bundles.php file not found\n";
    }
    
    echo "\n=== Check Completed ===\n";
    
} catch (Exception $e) {
    echo "ERROR: " . $e->getMessage() . "\n";
}