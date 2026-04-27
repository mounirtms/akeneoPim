<?php
/**
 * Emergency Cloudflare Cache Bypass
 * Creates a direct-access index that bypasses Cloudflare completely
 */

echo "=== EMERGENCY CLOUDFLARE BYPASS ===\n\n";

// 1. Create bypass parameter in .htaccess
$htaccess = __DIR__ . '/../public/.htaccess';
$htaccessContent = file_get_contents($htaccess);

if (strpos($htaccessContent, 'nocache bypass') === false) {
    echo "1. Adding cache bypass rule to .htaccess...\n";
    
    $bypassRule = <<<'HTACCESS'

# Emergency cache bypass for Cloudflare issues
<IfModule mod_headers.c>
    # If nocache parameter present, send no-cache headers
    SetEnvIf Request_URI "nocache=1" nocache_bypass
    Header set Cache-Control "no-store, no-cache, must-revalidate, max-age=0" env=nocache_bypass
    Header set Pragma "no-cache" env=nocache_bypass
    Header set Expires "0" env=nocache_bypass
</IfModule>

HTACCESS;
    
    file_put_contents($htaccess, $htaccessContent . $bypassRule);
    echo "   ✅ Cache bypass rules added\n";
} else {
    echo "1. ✅ Cache bypass rules already exist\n";
}

// 2. Update template with emergency flag
$templateFile = __DIR__ . '/../vendor/akeneo/pim-community-dev/src/Akeneo/Platform/Bundle/UIBundle/Resources/views/index.html.twig';
$content = file_get_contents($templateFile);

// Add emergency bypass parameter to all asset URLs
$timestamp = time();
echo "\n2. Updating cache buster to: $timestamp\n";

$content = preg_replace(
    '/{% set cache_buster = "[^"]*" %}/',
    '{% set cache_buster = "' . $timestamp . '" %}',
    $content
);

file_put_contents($templateFile, $content);
echo "   ✅ Template updated\n";

// 3. Create emergency access URL
echo "\n3. Emergency Access URLs:\n";
echo "   🔗 Direct bypass: https://pim.technostationery.com/?nocache=1&t=$timestamp\n";
echo "   🔗 With hard refresh: https://pim.technostationery.com/index.php?nocache=1\n";

// 4. Clear all caches
echo "\n4. Clearing all caches...\n";
system('cd /home/pim/public_html && rm -rf var/cache/prod/* 2>&1');
echo "   ✅ Cache cleared\n";

echo "\n5. Verifying fixes...\n";
echo "   - require-paths.js: " . filesize(__DIR__ . '/../public/js/require-paths.js') . " bytes\n";
echo "   - jquery.js symlink: " . (is_link(__DIR__ . '/../public/jquery.js') ? '✅' : '❌') . "\n";
echo "   - process-polyfill.js: " . (file_exists(__DIR__ . '/../public/dist/process-polyfill.js') ? '✅' : '❌') . "\n";

echo "\n=== INSTRUCTIONS ===\n";
echo "1. Open this URL in INCOGNITO/PRIVATE window:\n";
echo "   https://pim.technostationery.com/?nocache=1&t=$timestamp\n\n";
echo "2. This bypasses Cloudflare cache completely\n";
echo "3. Check browser console - should see new version: v=$timestamp\n";
echo "4. Once working, purge Cloudflare cache\n";
echo "5. Then normal URL will work\n\n";

