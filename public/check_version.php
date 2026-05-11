<?php

require_once '../vendor/autoload.php';

try {
    $version = \Pimcore\Version::getVersion();
    echo "Pimcore Version: " . $version . "\n";
    
    $majorVersion = \Pimcore\Version::getMajorVersion();
    echo "Major Version: " . $majorVersion . "\n";
} catch (Exception $e) {
    echo "Error getting version: " . $e->getMessage() . "\n";
}