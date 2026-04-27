<?php
/**
 * Update .htaccess with proper cache headers
 */

$htaccess = __DIR__ . '/../public/.htaccess';
$content = file_get_contents($htaccess);

// Check if cache headers already added
if (strpos($content, 'Prevent caching of dynamic content') !== false) {
    echo "✅ Cache headers already configured\n";
    exit(0);
}

$cacheHeaders = <<<'HEADERS'

# ==============================================
# CACHE CONTROL HEADERS
# ==============================================

# Prevent caching of dynamic content
<FilesMatch "\.(html|htm|twig|php)$">
    Header set Cache-Control "no-store, no-cache, must-revalidate, max-age=0"
    Header set Pragma "no-cache"
    Header set Expires "0"
</FilesMatch>

# Cache static assets with long expiry
<FilesMatch "\.(js|css|jpg|jpeg|png|gif|svg|woff|woff2|ttf|eot|ico)$">
    Header set Cache-Control "public, max-age=31536000"
</FilesMatch>

# Versioned assets (with ?v= parameter) can be cached forever
<If "%{QUERY_STRING} =~ /v=/">
    Header set Cache-Control "public, max-age=31536000, immutable"
</If>

HEADERS;

// Backup
copy($htaccess, $htaccess . '.backup.' . time());

// Append headers
file_put_contents($htaccess, $content . $cacheHeaders);

echo "✅ Cache headers added to .htaccess\n";
echo "Backup created: " . $htaccess . ".backup." . time() . "\n";

