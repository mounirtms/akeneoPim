<?php
/**
 * Fix JavaScript Module Loading Errors in Akeneo PIM
 * Addresses: module-registry.js, fos-routing, security-context errors
 */

echo "=== AKENEO JAVASCRIPT MODULE ERROR FIXER ===\n";
echo "Date: " . date('Y-m-d H:i:s') . "\n\n";

// Step 1: Clear all caches
echo "Step 1: Clearing Akeneo caches...\n";
system('php bin/console cache:clear --env=prod --no-debug 2>&1');
system('php bin/console pim:installer:assets --env=prod 2>&1');

// Step 2: Regenerate RequireJS configuration
echo "\nStep 2: Regenerating RequireJS configuration...\n";
system('php bin/console fos:js-routing:dump --format=json --target=public/js/fos_js_routes.json --env=prod 2>&1');

// Step 3: Dump webpack encore assets
echo "\nStep 3: Building frontend assets...\n";
$webpackConfigExists = file_exists('webpack.config.js');
if ($webpackConfigExists) {
    echo "Webpack config found, building assets...\n";
    system('yarn install 2>&1');
    system('yarn run webpack --env.prod 2>&1');
} else {
    echo "No webpack config found, using built-in asset installer...\n";
}

// Step 4: Check and fix permissions
echo "\nStep 4: Fixing permissions...\n";
system('chmod -R 755 public/js 2>&1');
system('chmod -R 755 public/bundles 2>&1');
system('chmod -R 755 public/css 2>&1');

// Step 5: Verify critical JavaScript files exist
echo "\nStep 5: Verifying critical JavaScript files...\n";
$criticalFiles = [
    'public/js/require.min.js',
    'public/js/fos_js_routes.json',
    'public/bundles/pimui/js/index.js',
    'public/bundles/pimui/js/module-registry.js',
];

$missingFiles = [];
foreach ($criticalFiles as $file) {
    if (!file_exists($file)) {
        $missingFiles[] = $file;
        echo "  ❌ MISSING: $file\n";
    } else {
        echo "  ✅ EXISTS: $file\n";
    }
}

// Step 6: Database check - ensure user has proper access
echo "\nStep 6: Checking database configuration...\n";
try {
    $pdo = new PDO("mysql:host=localhost;dbname=pim;charset=utf8mb4", "pim", "Mounter@2026!Secure");
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    echo "  ✅ Database connection successful\n";
    
    // Check if oro_config table exists (stores JS routing config)
    $tables = $pdo->query("SHOW TABLES LIKE 'oro_config'")->fetchAll();
    if (count($tables) > 0) {
        echo "  ✅ Configuration tables exist\n";
    } else {
        echo "  ⚠️  Configuration tables missing, may need reinstall\n";
    }
} catch (PDOException $e) {
    echo "  ❌ Database error: " . $e->getMessage() . "\n";
}

// Step 7: Summary and recommendations
echo "\n=== SUMMARY ===\n";
if (count($missingFiles) > 0) {
    echo "⚠️  Missing files detected:\n";
    foreach ($missingFiles as $file) {
        echo "   - $file\n";
    }
    echo "\nRECOMMENDATION: Run asset installation:\n";
    echo "   php bin/console pim:installer:assets --symlink --clean --env=prod\n";
} else {
    echo "✅ All critical files present\n";
}

echo "\nNEXT STEPS:\n";
echo "1. Clear browser cache (Ctrl+Shift+Delete)\n";
echo "2. Reload Akeneo PIM page\n";
echo "3. Check browser console for remaining errors\n";
echo "4. If errors persist, run: php bin/console pim:install --force --env=prod\n";

echo "\nFix completed: " . date('Y-m-d H:i:s') . "\n";
