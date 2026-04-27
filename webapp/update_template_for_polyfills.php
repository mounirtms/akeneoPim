<?php
/**
 * Update index.html.twig to include process polyfill before vendor.min.js
 * Date: 2026-04-27
 */

$templateFile = __DIR__ . '/../vendor/akeneo/pim-community-dev/src/Akeneo/Platform/Bundle/UIBundle/Resources/views/index.html.twig';

if (!file_exists($templateFile)) {
    die("ERROR: Template file not found at $templateFile\n");
}

echo "Reading template file...\n";
$content = file_get_contents($templateFile);

// Update cache buster
$newCacheBuster = date('Ymd') . 'c'; // 20260427c
$content = preg_replace('/{% set cache_buster = "[^"]*" %}/', '{% set cache_buster = "' . $newCacheBuster . '" %}', $content);
echo "Updated cache buster to: $newCacheBuster\n";

// Check if process-polyfill is already included
if (strpos($content, 'process-polyfill.js') === false) {
    echo "Adding process polyfill before vendor.min.js...\n";
    
    // Add process polyfill before vendor.min.js
    $content = str_replace(
        '<script type="text/javascript" src="/dist/vendor.min.js',
        '        {# Process polyfill for Node.js globals used in webpack bundles #}' . "\n" .
        '        <script type="text/javascript" src="/dist/process-polyfill.js?v={{ cache_buster }}"></script>' . "\n\n" .
        '        <script type="text/javascript" src="/dist/vendor.min.js',
        $content
    );
    echo "✅ Added process polyfill to template\n";
} else {
    echo "✅ Process polyfill already in template\n";
}

// Backup original
$backupFile = $templateFile . '.backup.' . date('Ymd_His');
copy($templateFile, $backupFile);
echo "Backed up original to: $backupFile\n";

// Write updated template
file_put_contents($templateFile, $content);
echo "✅ Template updated successfully!\n";

echo "\nDone!\n";

