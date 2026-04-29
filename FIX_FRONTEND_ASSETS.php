<?php
/**
 * Complete Frontend Asset Rebuild for Akeneo PIM
 * Fixes: module-registry.js, fos-routing, security-context errors
 */

echo "=== AKENEO FRONTEND ASSET REBUILD ===\n";
echo "Date: " . date('Y-m-d H:i:s') . "\n\n";

// Step 1: Check Akeneo version
echo "Step 1: Detecting Akeneo version...\n";
$composerJson = json_decode(file_get_contents('composer.json'), true);
$akeneoVersion = 'unknown';
foreach ($composerJson['require'] ?? [] as $package => $version) {
    if (strpos($package, 'akeneo/pim') !== false) {
        $akeneoVersion = $version;
        echo "  Found: $package @ $version\n";
        break;
    }
}

// Step 2: Clear all caches thoroughly
echo "\nStep 2: Clearing all caches...\n";
passthru('php bin/console cache:clear --env=prod --no-debug');
passthru('rm -rf var/cache/prod/*');

// Step 3: Regenerate JS routing
echo "\nStep 3: Regenerating JavaScript routing...\n";
passthru('php bin/console fos:js-routing:dump --format=json --target=public/js/fos_js_routes.json --env=prod');

// Step 4: Check if yarn/webpack is needed
echo "\nStep 4: Checking for webpack build requirement...\n";
if (file_exists('package.json') && file_exists('webpack.config.js')) {
    echo "  Webpack configuration found\n";
    echo "  Installing node dependencies...\n";
    passthru('yarn install --production=false 2>&1');
    
    echo "\n  Building webpack bundles...\n";
    passthru('yarn run webpack --mode=production 2>&1');
} else {
    echo "  No webpack config, skipping yarn build\n";
}

// Step 5: Reinstall assets with symlinks
echo "\nStep 5: Installing Akeneo assets...\n";
passthru('php bin/console pim:installer:assets --symlink --clean --env=prod');

// Step 6: Verify critical files
echo "\nStep 6: Verifying critical JavaScript files...\n";
$criticalPaths = [
    'public/js/require.min.js' => 'RequireJS loader',
    'public/js/fos_js_routes.json' => 'FOS JS routing config',
    'public/bundles/pimui/js/' => 'PIM UI JavaScript bundle',
    'public/bundles/fosjsrouting/' => 'FOS routing bundle',
];

$allGood = true;
foreach ($criticalPaths as $path => $desc) {
    $exists = file_exists($path) || is_dir($path);
    $status = $exists ? '✅' : '❌';
    echo "  $status $desc: $path\n";
    if (!$exists) $allGood = false;
}

// Step 7: Fix permissions
echo "\nStep 7: Fixing permissions...\n";
passthru('chmod -R 755 public/bundles 2>/dev/null');
passthru('chmod -R 755 public/js 2>/dev/null');
passthru('chmod -R 755 public/css 2>/dev/null');

// Step 8: Check for common issues
echo "\nStep 8: Diagnostic checks...\n";

// Check require.js config
$requireJsMain = 'public/js/require-config.js';
if (file_exists($requireJsMain)) {
    echo "  ✅ RequireJS main config exists\n";
    $content = file_get_contents($requireJsMain);
    if (strpos($content, 'module-registry') !== false) {
        echo "  ✅ module-registry referenced in config\n";
    } else {
        echo "  ⚠️  module-registry NOT in RequireJS config\n";
    }
} else {
    echo "  ❌ RequireJS main config missing: $requireJsMain\n";
}

// Check if modules are properly built
$moduleFiles = glob('public/bundles/pimui/js/module.js');
echo "  Found " . count($moduleFiles) . " module.js files\n";

// Step 9: Summary
echo "\n=== SUMMARY ===\n";
if ($allGood) {
    echo "✅ All critical assets are in place\n";
    echo "\nNEXT STEPS:\n";
    echo "1. Clear your browser cache completely (Ctrl+Shift+Delete)\n";
    echo "2. Hard reload the page (Ctrl+Shift+R or Cmd+Shift+R)\n";
    echo "3. Check browser console for any remaining errors\n";
} else {
    echo "⚠️  Some assets are missing\n";
    echo "\nTROUBLESHOOTING:\n";
    echo "1. The module-registry error suggests RequireJS configuration issues\n";
    echo "2. Run: yarn run webpack --mode=production\n";
    echo "3. If that fails, run: php bin/console pim:install --force --env=prod\n";
    echo "   (WARNING: This will reset the database)\n";
}

echo "\nFix completed: " . date('Y-m-d H:i:s') . "\n";
