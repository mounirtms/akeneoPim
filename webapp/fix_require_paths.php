<?php
/**
 * Fix require-paths.js - Convert from Node.js module.exports to RequireJS config
 * Date: 2026-04-27
 */

$requirePathsFile = __DIR__ . '/../public/js/require-paths.js';

if (!file_exists($requirePathsFile)) {
    die("ERROR: require-paths.js not found at $requirePathsFile\n");
}

echo "Reading require-paths.js...\n";
$content = file_get_contents($requirePathsFile);

// Check if it has module.exports (Node.js syntax)
if (strpos($content, 'module.exports') !== false) {
    echo "Found Node.js syntax (module.exports), converting to RequireJS config...\n";
    
    // Extract the JSON array
    preg_match('/module\.exports\s*=\s*(\[.*\])/s', $content, $matches);
    
    if (isset($matches[1])) {
        $pathsArray = $matches[1];
        
        // Create proper RequireJS configuration
        $newContent = <<<REQUIREJS
/**
 * RequireJS paths configuration for Akeneo PIM
 * Auto-generated: {date}
 * 
 * This file configures RequireJS module paths for Akeneo bundles.
 * DO NOT EDIT MANUALLY - regenerate using: php bin/console pim:installer:dump-require-paths
 */

(function() {
    'use strict';
    
    // Bundle paths for RequireJS
    var bundlePaths = $pathsArray;
    
    // Base RequireJS configuration
    if (typeof require !== 'undefined' && typeof require.config === 'function') {
        require.config({
            waitSeconds: 30,
            baseUrl: '/bundles',
            paths: {
                // Core libraries (loaded via webpack externals)
                'jquery': '/dist/jquery.min',
                'underscore': '/dist/underscore.min',
                'backbone': '/dist/backbone.min',
                'react': '/dist/react.min',
                'react-dom': '/dist/react-dom.min',
                
                // FOS Routing
                'routing': '/bundles/fosjsrouting/js/router.min',
                
                // Oro/Akeneo core modules
                'oro/translator': '/bundles/orotranslation/js/translator',
                'pim/form-builder': '/bundles/pimui/js/form/common/index',
                'pim/form': '/bundles/pimui/js/form/index'
            },
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
        
        console.log('RequireJS configured with', bundlePaths.length, 'bundle paths');
    } else {
        console.warn('RequireJS not available - require.config not found');
    }
})();
REQUIREJS;
        
        $newContent = str_replace('{date}', date('Y-m-d H:i:s'), $newContent);
        
        // Backup original
        $backupFile = $requirePathsFile . '.backup.' . date('Ymd_His');
        copy($requirePathsFile, $backupFile);
        echo "Backed up original to: $backupFile\n";
        
        // Write fixed version
        file_put_contents($requirePathsFile, $newContent);
        echo "✅ Fixed require-paths.js successfully!\n";
        echo "Size: " . number_format(strlen($newContent)) . " bytes\n";
        
        // Set proper permissions
        chmod($requirePathsFile, 0644);
        
    } else {
        echo "ERROR: Could not extract paths array from module.exports\n";
        exit(1);
    }
    
} else {
    echo "✅ require-paths.js already has proper format (no module.exports found)\n";
}

echo "\nDone!\n";

