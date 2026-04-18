<?php
/**
 * Production Environment Analysis Script
 * Analyzes /home/technadminy7/public_html for data migration to staging
 * Version: 1.0
 * Date: 2026-04-18
 */

echo "\n" . str_repeat("=", 80) . "\n";
echo "PRODUCTION ENVIRONMENT ANALYSIS\n";
echo "Generated: " . date('Y-m-d H:i:s') . "\n";
echo str_repeat("=", 80) . "\n\n";

$prodRoot = '/home/technadminy7/public_html';
$stagingRoot = '/home/beta/public_html';

// Section 1: Directory Structure
echo "1. DIRECTORY STRUCTURE COMPARISON\n";
echo str_repeat("-", 80) . "\n";

$dirs = ['pub/media/catalog/product', 'pub/media/wysiwyg', 'var/log', 'var/backup'];
foreach ($dirs as $dir) {
    $prodPath = $prodRoot . '/' . $dir;
    $stagingPath = $stagingRoot . '/' . $dir;
    
    if (is_dir($prodPath)) {
        $prodSize = exec("du -sh " . escapeshellarg($prodPath) . " 2>/dev/null | cut -f1");
        $prodFiles = exec("find " . escapeshellarg($prodPath) . " -type f 2>/dev/null | wc -l");
        echo "✓ Production $dir: $prodSize ($prodFiles files)\n";
    } else {
        echo "✗ Production $dir: NOT FOUND\n";
    }
    
    if (is_dir($stagingPath)) {
        $stagingSize = exec("du -sh " . escapeshellarg($stagingPath) . " 2>/dev/null | cut -f1");
        $stagingFiles = exec("find " . escapeshellarg($stagingPath) . " -type f 2>/dev/null | wc -l");
        echo "  Staging $dir: $stagingSize ($stagingFiles files)\n";
    } else {
        echo "  Staging $dir: NOT FOUND\n";
    }
    echo "\n";
}

// Section 2: Product Images Analysis
echo "\n2. PRODUCT IMAGES ANALYSIS\n";
echo str_repeat("-", 80) . "\n";

$prodImagesPath = $prodRoot . '/pub/media/catalog/product';
$stagingImagesPath = $stagingRoot . '/pub/media/catalog/product';

// Count image types
$imageTypes = ['jpg', 'jpeg', 'png', 'gif'];
foreach ($imageTypes as $type) {
    $prodCount = exec("find " . escapeshellarg($prodImagesPath) . " -type f -iname '*.$type' 2>/dev/null | wc -l");
    $stagingCount = exec("find " . escapeshellarg($stagingImagesPath) . " -type f -iname '*.$type' 2>/dev/null | wc -l");
    $diff = $prodCount - $stagingCount;
    echo ".$type images - Production: " . number_format($prodCount) . " | Staging: " . number_format($stagingCount) . " | Difference: " . number_format($diff) . "\n";
}

echo "\n";

// Section 3: Configuration Files
echo "\n3. CONFIGURATION FILES\n";
echo str_repeat("-", 80) . "\n";

$configFiles = [
    'app/etc/env.php',
    'app/etc/config.php',
    'composer.json',
    '.htaccess'
];

foreach ($configFiles as $file) {
    $prodFile = $prodRoot . '/' . $file;
    $stagingFile = $stagingRoot . '/' . $file;
    
    if (file_exists($prodFile)) {
        $prodSize = filesize($prodFile);
        $prodMod = date('Y-m-d H:i:s', filemtime($prodFile));
        echo "✓ $file (Production)\n";
        echo "  Size: " . number_format($prodSize) . " bytes | Modified: $prodMod\n";
    } else {
        echo "✗ $file (Production) - NOT FOUND\n";
    }
    
    if (file_exists($stagingFile)) {
        $stagingSize = filesize($stagingFile);
        $stagingMod = date('Y-m-d H:i:s', filemtime($stagingFile));
        echo "  Staging: " . number_format($stagingSize) . " bytes | Modified: $stagingMod\n";
    } else {
        echo "  Staging: NOT FOUND\n";
    }
    echo "\n";
}

// Section 4: Database Connection Check
echo "\n4. DATABASE CONNECTION CHECK\n";
echo str_repeat("-", 80) . "\n";

$prodEnvFile = $prodRoot . '/app/etc/env.php';
if (file_exists($prodEnvFile)) {
    $prodEnv = include $prodEnvFile;
    if (isset($prodEnv['db']['connection']['default'])) {
        $prodDb = $prodEnv['db']['connection']['default'];
        echo "Production Database:\n";
        echo "  Host: " . $prodDb['host'] . "\n";
        echo "  Database: " . $prodDb['dbname'] . "\n";
        echo "  Username: " . $prodDb['username'] . "\n";
        echo "\n";
    }
}

$stagingEnvFile = $stagingRoot . '/app/etc/env.php';
if (file_exists($stagingEnvFile)) {
    $stagingEnv = include $stagingEnvFile;
    if (isset($stagingEnv['db']['connection']['default'])) {
        $stagingDb = $stagingEnv['db']['connection']['default'];
        echo "Staging Database:\n";
        echo "  Host: " . $stagingDb['host'] . "\n";
        echo "  Database: " . $stagingDb['dbname'] . "\n";
        echo "  Username: " . $stagingDb['username'] . "\n";
        echo "\n";
    }
}

// Section 5: Custom Scripts & Modules
echo "\n5. CUSTOM SCRIPTS & MODULES\n";
echo str_repeat("-", 80) . "\n";

$prodScriptsDir = $prodRoot . '/scripts';
if (is_dir($prodScriptsDir)) {
    $scripts = exec("find " . escapeshellarg($prodScriptsDir) . " -maxdepth 1 -type f -name '*.php' -o -name '*.sh' 2>/dev/null | wc -l");
    echo "Production scripts directory: $scripts files\n";
    echo "Sample scripts:\n";
    exec("find " . escapeshellarg($prodScriptsDir) . " -maxdepth 1 -type f \( -name '*.php' -o -name '*.sh' \) 2>/dev/null | head -10", $scriptList);
    foreach ($scriptList as $script) {
        echo "  - " . basename($script) . "\n";
    }
} else {
    echo "Production scripts directory: NOT FOUND\n";
}

echo "\n";

// Section 6: Recommendations
echo "\n6. MIGRATION RECOMMENDATIONS\n";
echo str_repeat("=", 80) . "\n";

echo "\n✓ HIGH PRIORITY:\n";
echo "  1. Sync product images from production to staging (~9.3GB, 328K files)\n";
echo "  2. Review and migrate custom scripts from production\n";
echo "  3. Compare database content (products, categories, attributes)\n";

echo "\n✓ MEDIUM PRIORITY:\n";
echo "  4. Sync WYSIWYG media files (banners, icons, etc.)\n";
echo "  5. Review .htaccess customizations\n";
echo "  6. Check for custom modules in app/code/\n";

echo "\n✓ LOW PRIORITY:\n";
echo "  7. Compare configuration settings (app/etc/config.php)\n";
echo "  8. Review cron job configurations\n";
echo "  9. Check for custom themes\n";

echo "\n" . str_repeat("=", 80) . "\n";
echo "Analysis complete!\n";
echo str_repeat("=", 80) . "\n\n";
