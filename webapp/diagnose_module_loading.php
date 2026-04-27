<?php
/**
 * Diagnose Module Loading Issues
 */

echo "=== MODULE LOADING DIAGNOSTIC ===\n\n";

// 1. Check what modules are actually available in pimui/js
echo "1. Available modules in pimui/js:\n";
$pimuiPath = '/home/pim/public_html/public/bundles/pimui/js';
if (is_dir($pimuiPath)) {
    // Find all .js files
    $iterator = new RecursiveIteratorIterator(
        new RecursiveDirectoryIterator($pimuiPath, RecursiveDirectoryIterator::SKIP_DOTS),
        RecursiveIteratorIterator::SELF_FIRST
    );
    
    $modules = [];
    foreach ($iterator as $file) {
        if ($file->isFile() && $file->getExtension() === 'js') {
            $relativePath = str_replace($pimuiPath . '/', '', $file->getPathname());
            $relativePath = str_replace('.js', '', $relativePath);
            
            // Check if it's form-related
            if (stripos($relativePath, 'form') !== false) {
                $modules[] = $relativePath;
            }
        }
    }
    
    echo "   Found " . count($modules) . " form-related modules:\n";
    foreach (array_slice($modules, 0, 20) as $module) {
        echo "      pimui/js/$module\n";
    }
}

// 2. Check for form-builder specifically
echo "\n2. Searching for form-builder or form/builder:\n";
$patterns = ['form-builder', 'form/builder', 'formbuilder'];
foreach ($patterns as $pattern) {
    $path1 = "/home/pim/public_html/public/bundles/pimui/js/$pattern.js";
    $path2 = str_replace('-', '/', $path1);
    
    if (file_exists($path1)) {
        echo "   ✓ Found: $path1\n";
    } elseif (file_exists($path2)) {
        echo "   ✓ Found: $path2\n";
    } else {
        echo "   ✗ Not found: $pattern\n";
    }
}

// 3. Check what pim/* modules exist
echo "\n3. Sample pim/* modules that should be accessible:\n";
$commonModules = [
    'form/builder',
    'form/common/index',
    'form/common/edit-form',
    'form/common/save-form',
    'controller/form',
    'view/base',
];

foreach ($commonModules as $module) {
    $fullPath = "/home/pim/public_html/public/bundles/pimui/js/$module.js";
    if (file_exists($fullPath)) {
        $size = filesize($fullPath);
        echo "   ✓ pim/$module exists (" . number_format($size) . " bytes)\n";
    } else {
        echo "   ✗ pim/$module missing\n";
    }
}

// 4. Suggest RequireJS map configuration
echo "\n4. RequireJS Configuration Recommendation:\n";
echo "   Add to require-paths.js:\n";
echo "   paths: {\n";
echo "       'pim': 'pimui/js',\n";
echo "       'oro': 'oroui/js',\n";
echo "       'pimui': 'pimui/js'\n";
echo "   }\n";

echo "\n5. Module Loading Strategy:\n";
echo "   Option A: Use direct paths\n";
echo "      require(['pimui/js/form/builder'], function(builder) {...});\n";
echo "   \n";
echo "   Option B: Use pim alias (RECOMMENDED)\n";
echo "      require(['pim/form/builder'], function(builder) {...});\n";
echo "      // Maps to: /bundles/pimui/js/form/builder.js\n";

echo "\n=== DIAGNOSTIC COMPLETE ===\n";

