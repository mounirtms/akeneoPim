#!/usr/bin/env php
<?php
/**
 * Generate require-paths.js from all requirejs.yml files
 * Run: php /home/pim/public_html/webapp/generate_require_paths.php
 */

$rootDir = '/home/pim/public_html/vendor/akeneo/pim-community-dev';
$outputFile = '/home/pim/public_html/public/js/require-paths.js';

// Find all requirejs.yml files
$ymlFiles = [];
$iterator = new RecursiveIteratorIterator(
    new RecursiveDirectoryIterator($rootDir, RecursiveDirectoryIterator::SKIP_DOTS),
    RecursiveIteratorIterator::SELF_FIRST
);

foreach ($iterator as $file) {
    if ($file->getFilename() === 'requirejs.yml') {
        $ymlFiles[] = $file->getPathname();
    }
}

echo "Found " . count($ymlFiles) . " requirejs.yml files\n";

// Simple YAML parser for paths section
$allPaths = [];
foreach ($ymlFiles as $file) {
    $content = file_get_contents($file);
    $inPaths = false;
    
    $lines = explode("\n", $content);
    foreach ($lines as $line) {
        if (trim($line) === 'paths:') {
            $inPaths = true;
            continue;
        }
        
        if ($inPaths) {
            // Check if we're still in paths section (indented with 4 spaces)
            if (preg_match('/^    ([\w\/\.-]+):\s+(.+)$/', $line, $matches)) {
                $key = trim($matches[1]);
                $value = trim($matches[2]);
                $allPaths[$key] = $value;
            } elseif (preg_match('/^  [^\s]/', $line) && trim($line) !== '') {
                // Back to 2-space indent, we're out of paths section
                $inPaths = false;
            }
        }
    }
}

echo "Extracted " . count($allPaths) . " path mappings\n";

// Generate require-paths.js
$jsonPaths = json_encode($allPaths, JSON_UNESCAPED_SLASHES | JSON_PRETTY_PRINT);

$jsContent = <<<JS
/**
 * RequireJS paths configuration for Akeneo PIM
 * Auto-generated: {date}
 * Total mappings: {count}
 * 
 * This file configures RequireJS module paths for all Akeneo bundles.
 */

(function() {
    'use strict';
    
    if (typeof require !== 'undefined' && typeof require.config === 'function') {
        require.config({
            waitSeconds: 60,
            baseUrl: '/bundles',
            paths: {json_paths},
            shim: {
                'underscore': {
                    exports: '_'
                },
                'backbone': {
                    deps: ['underscore', 'jquery'],
                    exports: 'Backbone'
                }
            }
        });
    }
})();
JS;

$jsContent = str_replace('{date}', date('Y-m-d H:i:s'), $jsContent);
$jsContent = str_replace('{count}', count($allPaths), $jsContent);
$jsContent = str_replace('{json_paths}', $jsonPaths, $jsContent);

if (file_put_contents($outputFile, $jsContent)) {
    echo "Successfully wrote require-paths.js to $outputFile\n";
} else {
    echo "ERROR: Could not write to $outputFile\n";
    exit(1);
}
