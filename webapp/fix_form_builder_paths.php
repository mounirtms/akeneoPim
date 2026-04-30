<?php
/**
 * Fix pim/form-builder Path Issues
 * Investigates and fixes the 404 error for pim/form-builder module
 */

echo "=== FIXING PIM/FORM-BUILDER PATH ISSUES ===\n\n";

// Step 1: Find where form-builder is actually located
echo "1. Searching for form-builder related files...\n";
$searchPaths = [
    '/home/pim/public_html/vendor/akeneo/pim-community-dev/src/Akeneo/Platform/Bundle/UIBundle/Resources/public/js',
    '/home/pim/public_html/public/bundles/pimui/js',
    '/home/pim/public_html/public/bundles/pimui',
];

$foundFiles = [];
foreach ($searchPaths as $searchPath) {
    if (!is_dir($searchPath)) continue;
    
    $iterator = new RecursiveIteratorIterator(
        new RecursiveDirectoryIterator($searchPath, RecursiveDirectoryIterator::SKIP_DOTS),
        RecursiveIteratorIterator::SELF_FIRST
    );
    
    foreach ($iterator as $file) {
        if ($file->isFile() && strpos($file->getFilename(), 'form') !== false && $file->getExtension() === 'js') {
            $foundFiles[] = $file->getPathname();
            if (count($foundFiles) >= 50) break 2;  // Limit to first 50
        }
    }
}

echo "   Found " . count($foundFiles) . " form-related files\n";
if (count($foundFiles) > 0) {
    echo "   Sample files:\n";
    foreach (array_slice($foundFiles, 0, 10) as $file) {
        $relativePath = str_replace('/home/pim/public_html/', '', $file);
        echo "      - $relativePath\n";
    }
}

// Step 2: Check module-registry.js for form-builder mapping
echo "\n2. Checking module-registry.js for form-builder mapping...\n";
$registryPath = '/home/pim/public_html/public/js/module-registry.js';
if (file_exists($registryPath)) {
    $content = file_get_contents($registryPath);
    
    // Search for form-builder related entries
    if (preg_match_all('/["\']([^"\']*form[^"\']*)["\']:\s*["\']([^"\']+)["\']/i', $content, $matches, PREG_SET_ORDER)) {
        echo "   Found " . count($matches) . " form-related module mappings:\n";
        foreach (array_slice($matches, 0, 15) as $match) {
            echo "      '{$match[1]}' => '{$match[2]}'\n";
        }
    } else {
        echo "   ✗ No form-related mappings found\n";
    }
    
    // Check for specific 'pim/form-builder'
    if (strpos($content, 'pim/form-builder') !== false) {
        echo "   ✓ 'pim/form-builder' mapping exists\n";
        
        // Extract the mapping
        if (preg_match('/"pim\/form-builder":\s*"([^"]+)"/', $content, $match)) {
            echo "   → Maps to: {$match[1]}\n";
            
            // Check if the target exists
            $targetPath = '/home/pim/public_html/public/bundles/' . $match[1] . '.js';
            if (file_exists($targetPath)) {
                echo "   ✓ Target file exists: $targetPath\n";
            } else {
                echo "   ✗ Target file missing: $targetPath\n";
            }
        }
    } else {
        echo "   ✗ 'pim/form-builder' mapping NOT found\n";
    }
} else {
    echo "   ✗ module-registry.js not found\n";
}

// Step 3: Check require-paths.js configuration
echo "\n3. Checking require-paths.js for pim path configuration...\n";
$requirePath = '/home/pim/public_html/public/js/require-paths.js';
if (file_exists($requirePath)) {
    $content = file_get_contents($requirePath);
    
    if (preg_match('/["\']pim["\']\s*:\s*["\']([^"\']+)["\']/', $content, $match)) {
        echo "   ✓ 'pim' path configured: {$match[1]}\n";
    } else {
        echo "   ✗ 'pim' path not configured\n";
    }
    
    // Check for pimui path
    if (preg_match('/["\']pimui["\']\s*:\s*["\']([^"\']+)["\']/', $content, $match)) {
        echo "   ✓ 'pimui' path configured: {$match[1]}\n";
    } else {
        echo "   ✗ 'pimui' path not configured\n";
    }
} else {
    echo "   ✗ require-paths.js not found\n";
}

// Step 4: Check actual pimui bundle structure
echo "\n4. Checking pimui bundle structure...\n";
$pimuiBundlePath = '/home/pim/public_html/public/bundles/pimui';
if (is_dir($pimuiBundlePath)) {
    echo "   ✓ pimui bundle exists: $pimuiBundlePath\n";
    
    // Check if it's a symlink
    if (is_link($pimuiBundlePath)) {
        $target = readlink($pimuiBundlePath);
        echo "   ✓ Symlink points to: $target\n";
    }
    
    // List key directories
    $keyDirs = ['js', 'js/form', 'js/common'];
    foreach ($keyDirs as $dir) {
        $fullPath = "$pimuiBundlePath/$dir";
        if (is_dir($fullPath)) {
            $count = count(glob("$fullPath/*.js"));
            echo "   ✓ $dir/ exists ($count JS files)\n";
        } else {
            echo "   ✗ $dir/ missing\n";
        }
    }
} else {
    echo "   ✗ pimui bundle not found\n";
}

// Step 5: Generate fix recommendations
echo "\n5. Fix Recommendations:\n";

$requireContent = file_exists($requirePath) ? file_get_contents($requirePath) : '';
$registryContent = file_exists($registryPath) ? file_get_contents($registryPath) : '';

$fixes = [];

// Check if pim path is properly configured
if (strpos($requireContent, "'pim'") === false && strpos($requireContent, '"pim"') === false) {
    $fixes[] = "Add 'pim' path to require-paths.js pointing to 'bundles/pimui/js'";
}

// Check if form-builder exists in registry
if (strpos($registryContent, 'pim/form-builder') === false) {
    $fixes[] = "Add 'pim/form-builder' mapping to module-registry.js";
}

// Check if form-builder.js actually exists
$formBuilderPaths = [
    '/home/pim/public_html/public/bundles/pimui/js/form-builder.js',
    '/home/pim/public_html/public/bundles/pimui/js/form/builder.js',
    '/home/pim/public_html/vendor/akeneo/pim-community-dev/src/Akeneo/Platform/Bundle/UIBundle/Resources/public/js/form-builder.js',
];

$formBuilderExists = false;
foreach ($formBuilderPaths as $path) {
    if (file_exists($path)) {
        $formBuilderExists = true;
        echo "   ✓ form-builder found at: " . str_replace('/home/pim/public_html/', '', $path) . "\n";
        break;
    }
}

if (!$formBuilderExists) {
    echo "   ✗ form-builder.js not found in expected locations\n";
    $fixes[] = "Regenerate Akeneo assets to create missing form-builder.js";
}

if (count($fixes) > 0) {
    echo "\n   Recommended fixes:\n";
    foreach ($fixes as $i => $fix) {
        echo "   " . ($i + 1) . ". $fix\n";
    }
} else {
    echo "   ✓ No obvious issues detected (may be a RequireJS configuration problem)\n";
}

echo "\n=== ANALYSIS COMPLETE ===\n";

