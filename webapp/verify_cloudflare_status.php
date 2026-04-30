<?php
/**
 * Verify Cloudflare Status and Asset Loading
 * Checks if new cache buster is being served
 */

echo "=== CLOUDFLARE STATUS VERIFICATION ===\n\n";

// Check current cache buster in template
$templatePath = '/home/pim/public_html/vendor/akeneo/pim-community-dev/src/Akeneo/Platform/Bundle/UIBundle/Resources/views/index.html.twig';
echo "1. Current Cache Buster in Template:\n";
if (file_exists($templatePath)) {
    $content = file_get_contents($templatePath);
    if (preg_match('/cache_buster\s*=\s*["\']([^"\']+)["\']/', $content, $matches)) {
        $cacheBuster = $matches[1];
        echo "   ✓ Cache Buster: $cacheBuster\n";
        
        // Check if it's timestamp-based
        if (is_numeric($cacheBuster)) {
            $date = date('Y-m-d H:i:s', (int)$cacheBuster);
            echo "   ✓ Type: Timestamp-based\n";
            echo "   ✓ Generated: $date\n";
        } else {
            echo "   ✓ Type: Version string\n";
        }
    } else {
        echo "   ✗ Cache buster not found\n";
    }
} else {
    echo "   ✗ Template not found\n";
}

// Check require-paths.js
echo "\n2. RequireJS Configuration:\n";
$requirePath = '/home/pim/public_html/public/js/require-paths.js';
if (file_exists($requirePath)) {
    $size = filesize($requirePath);
    $content = file_get_contents($requirePath);
    echo "   ✓ File exists: $requirePath\n";
    echo "   ✓ Size: $size bytes\n";
    
    // Check for Node.js syntax
    if (strpos($content, 'module.exports') !== false) {
        echo "   ✗ WARNING: Contains Node.js syntax (module.exports)\n";
    } else {
        echo "   ✓ No Node.js syntax detected\n";
    }
    
    // Check for RequireJS syntax
    if (strpos($content, 'require.config') !== false) {
        echo "   ✓ Contains RequireJS configuration\n";
    } else {
        echo "   ✗ Missing RequireJS configuration\n";
    }
} else {
    echo "   ✗ File not found\n";
}

// Check process-polyfill.js
echo "\n3. Process Polyfill:\n";
$polyfillPath = '/home/pim/public_html/public/dist/process-polyfill.js';
if (file_exists($polyfillPath)) {
    $size = filesize($polyfillPath);
    echo "   ✓ File exists: $polyfillPath\n";
    echo "   ✓ Size: $size bytes\n";
} else {
    echo "   ✗ File not found\n";
}

// Check jquery.js symlink
echo "\n4. jQuery Symlink:\n";
$jqueryPath = '/home/pim/public_html/public/jquery.js';
if (file_exists($jqueryPath)) {
    if (is_link($jqueryPath)) {
        $target = readlink($jqueryPath);
        echo "   ✓ Symlink exists: $jqueryPath\n";
        echo "   ✓ Points to: $target\n";
        
        // Check if target exists
        $targetPath = dirname($jqueryPath) . '/' . $target;
        if (file_exists($targetPath)) {
            echo "   ✓ Target file exists\n";
        } else {
            echo "   ✗ Target file missing\n";
        }
    } else {
        echo "   ✓ File exists (not a symlink)\n";
    }
} else {
    echo "   ✗ File not found\n";
}

// Check .htaccess cache headers
echo "\n5. .htaccess Cache Headers:\n";
$htaccessPath = '/home/pim/public_html/public/.htaccess';
if (file_exists($htaccessPath)) {
    $content = file_get_contents($htaccessPath);
    echo "   ✓ File exists: $htaccessPath\n";
    
    if (strpos($content, 'Header set Cache-Control') !== false) {
        echo "   ✓ Cache-Control headers configured\n";
    } else {
        echo "   ✗ Cache-Control headers missing\n";
    }
    
    if (strpos($content, 'nocache') !== false) {
        echo "   ✓ Emergency bypass configured\n";
    } else {
        echo "   ✗ Emergency bypass missing\n";
    }
} else {
    echo "   ✗ File not found\n";
}

// Check analytics configuration
echo "\n6. Analytics Configuration:\n";
$analyticsPath = '/home/pim/public_html/config/packages/akeneo_analytics.yaml';
if (file_exists($analyticsPath)) {
    $content = file_get_contents($analyticsPath);
    echo "   ✓ File exists: $analyticsPath\n";
    
    if (strpos($content, 'enabled: false') !== false) {
        echo "   ✓ Analytics disabled\n";
    } elseif (strpos($content, 'enabled: true') !== false) {
        echo "   ✗ Analytics enabled (should be disabled)\n";
    } else {
        echo "   ? Analytics status unclear\n";
    }
} else {
    echo "   ✗ File not found\n";
}

// Generate test URLs
echo "\n7. Test URLs:\n";
$timestamp = time();
$domain = 'https://pim.technostationery.com';
echo "   Normal URL: $domain\n";
echo "   Emergency Bypass: $domain/?nocache=1&t=$timestamp\n";
echo "   Cache Purge URL: $domain/index.php?nocache=1\n";

// Check if we can determine the frontend status
echo "\n8. Frontend Status Summary:\n";
$issues = [];
$checks = [];

if (!file_exists($requirePath) || strpos(file_get_contents($requirePath), 'module.exports') !== false) {
    $issues[] = 'RequireJS configuration has issues';
} else {
    $checks[] = 'RequireJS configuration OK';
}

if (!file_exists($polyfillPath)) {
    $issues[] = 'Process polyfill missing';
} else {
    $checks[] = 'Process polyfill present';
}

if (!file_exists($jqueryPath)) {
    $issues[] = 'jQuery file/symlink missing';
} else {
    $checks[] = 'jQuery file present';
}

if (count($issues) === 0) {
    echo "   ✓ Status: READY FOR TESTING\n";
    echo "   ✓ All server-side fixes in place\n";
    echo "   → Next: Test emergency bypass URL in incognito\n";
    echo "   → Then: Purge Cloudflare cache\n";
    echo "   → Finally: Verify normal URL\n";
} else {
    echo "   ✗ Status: ISSUES FOUND\n";
    foreach ($issues as $issue) {
        echo "      - $issue\n";
    }
}

echo "\n=== VERIFICATION COMPLETE ===\n";
echo "Report generated: " . date('Y-m-d H:i:s') . "\n";

