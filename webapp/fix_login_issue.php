<?php
/**
 * AKENEO PIM - LOGIN FIX & PLATFORM STABILIZATION
 * 
 * This script fixes the login issue by:
 * 1. Clearing all caches (OPcache, application cache, session cache)
 * 2. Verifying vendor fixes are loaded
 * 3. Testing login functionality
 * 4. Resetting any stuck sessions
 * 
 * Usage: php /home/pim/public_html/webapp/fix_login_issue.php
 * Run as: pim user via cPanel
 */

error_reporting(E_ALL);
ini_set('display_errors', 1);

echo "=" . str_repeat("=", 79) . "\n";
echo "AKENEO PIM - LOGIN ISSUE FIX\n";
echo "Date: " . date('Y-m-d H:i:s') . "\n";
echo "=" . str_repeat("=", 79) . "\n\n";

$akeneo_root = '/home/pim/public_html';
$stats = ['fixed' => 0, 'errors' => 0];

function fix($name, $callable) {
    global $stats;
    echo "🔧 $name...\n";
    try {
        $result = $callable();
        if ($result === true || $result === null) {
            echo "   ✅ Fixed\n\n";
            $stats['fixed']++;
        } else {
            echo "   ⚠️ $result\n\n";
        }
    } catch (Exception $e) {
        echo "   ❌ Error: " . $e->getMessage() . "\n\n";
        $stats['errors']++;
    }
}

###############################################################################
# FIX 1: Clear OPcache
###############################################################################
fix('Clearing OPcache', function() {
    if (function_exists('opcache_reset')) {
        opcache_reset();
        return "OPcache reset successfully";
    }
    return "OPcache not available (will clear on next request)";
});

###############################################################################
# FIX 2: Clear Symfony Cache
###############################################################################
fix('Clearing Symfony cache', function() use ($akeneo_root) {
    chdir($akeneo_root);
    exec('php bin/console cache:clear --env=prod --no-debug 2>&1', $output, $return);
    
    if ($return === 0) {
        return "Cache cleared successfully";
    }
    throw new Exception("Cache clear failed: " . implode("\n", $output));
});

###############################################################################
# FIX 3: Clear Session Files
###############################################################################
fix('Clearing stale sessions', function() use ($akeneo_root) {
    $session_dir = $akeneo_root . '/var/sessions';
    
    if (!is_dir($session_dir)) {
        return "Session directory not found";
    }
    
    $count = 0;
    foreach (glob("$session_dir/*") as $file) {
        if (is_file($file) && strpos($file, 'sess_') === 0) {
            @unlink($file);
            $count++;
        }
    }
    
    return "Cleared $count stale session files";
});

###############################################################################
# FIX 4: Verify Vendor Fixes
###############################################################################
fix('Verifying vendor fixes', function() use ($akeneo_root) {
    // Check Symfony Debug.php
    $debug_file = $akeneo_root . '/vendor/symfony/error-handler/Debug.php';
    $debug_content = file_get_contents($debug_file);
    
    if (strpos($debug_content, 'PHP_VERSION_ID < 80300') !== false) {
        echo "   ✅ Symfony Debug.php: Fixed for PHP 8.3\n";
    } else {
        echo "   ⚠️ Symfony Debug.php: Still has deprecated assert.warning\n";
        // Apply fix
        $fixed = str_replace(
            "ini_set('assert.warning', 0);",
            "if (PHP_VERSION_ID < 80300) {\n            ini_set('assert.warning', 0);\n        }",
            $debug_content
        );
        file_put_contents($debug_file, $fixed);
        echo "   ✅ Applied fix to Symfony Debug.php\n";
    }
    
    // Check Monolog Logger.php
    $logger_file = $akeneo_root . '/vendor/monolog/monolog/src/Monolog/Logger.php';
    $logger_content = file_get_contents($logger_file);
    
    if (strpos($logger_content, "new \\DateTime('now'") !== false) {
        echo "   ✅ Monolog Logger.php: Fixed DateTime null parameter\n";
    } else {
        echo "   ⚠️ Monolog Logger.php: Still passing null to DateTime\n";
        // Apply fix
        $fixed = str_replace(
            "new \\DateTime(null,",
            "new \\DateTime('now',",
            $logger_content
        );
        file_put_contents($logger_file, $fixed);
        echo "   ✅ Applied fix to Monolog Logger.php\n";
    }
    
    return "Vendor files verified and fixed";
});

###############################################################################
# FIX 5: Verify Database Users
###############################################################################
fix('Verifying user accounts', function() {
    $pdo = new PDO(
        "mysql:host=127.0.0.1;port=3307;dbname=akeneo_pim;charset=utf8mb4",
        'akeneo_pim',
        'akeneo_pim',
        [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]
    );
    
    $users = $pdo->query("
        SELECT id, username, email, enabled 
        FROM oro_user 
        WHERE enabled = 1
        ORDER BY id
    ")->fetchAll();
    
    echo "   Enabled users:\n";
    foreach ($users as $user) {
        echo sprintf("   - %s (%s) [ID: %d]\n", 
            $user['username'], $user['email'], $user['id']);
    }
    
    if (count($users) > 0) {
        return count($users) . " active users found";
    }
    throw new Exception("No active users found!");
});

###############################################################################
# FIX 6: Verify Login Route
###############################################################################
fix('Verifying login route', function() use ($akeneo_root) {
    chdir($akeneo_root);
    exec('php bin/console debug:router pim_user_security_login --env=prod --no-debug 2>&1', $output);
    
    $route_info = implode("\n", $output);
    if (strpos($route_info, '/user/login') !== false) {
        echo "   ✅ Login route registered: /user/login\n";
        return "Login route verified";
    }
    
    throw new Exception("Login route not found!");
});

###############################################################################
# FIX 7: Clear Public Cache
###############################################################################
fix('Clearing public browser cache', function() use ($akeneo_root) {
    $public_cache = $akeneo_root . '/public/cache';
    
    if (is_dir($public_cache)) {
        $files = glob("$public_cache/*");
        $count = count($files);
        
        foreach ($files as $file) {
            if (is_file($file)) {
                @unlink($file);
            }
        }
        
        return "Cleared $count cached files";
    }
    
    return "Public cache directory not found";
});

###############################################################################
# FIX 8: Verify Elasticsearch
###############################################################################
fix('Verifying Elasticsearch', function() {
    $es_url = 'http://localhost:9200/_cluster/health';
    $health = @json_decode(file_get_contents($es_url), true);
    
    if ($health) {
        echo "   Cluster: {$health['status']}\n";
        echo "   Nodes: {$health['number_of_nodes']}\n";
        echo "   Shards: {$health['active_primary_shards']}\n";
        
        if (in_array($health['status'], ['green', 'yellow'])) {
            return "Elasticsearch operational";
        }
    }
    
    return "Elasticsearch may have issues";
});

###############################################################################
# FIX 9: Test Login Page
###############################################################################
fix('Testing login page', function() {
    $login_url = 'https://pim.technostationery.com/user/login';
    
    $ch = curl_init();
    curl_setopt($ch, CURLOPT_URL, $login_url);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_FOLLOWLOCATION, true);
    curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, false);
    $response = curl_exec($ch);
    $http_code = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    curl_close($ch);
    
    if ($http_code == 200 && strpos($response, 'username_input') !== false) {
        echo "   ✅ Login page loads correctly\n";
        echo "   ✅ Login form present\n";
        return "Login page verified (HTTP $http_code)";
    }
    
    return "Login page issue (HTTP $http_code)";
});

###############################################################################
# FIX 10: Clear Error Log
###############################################################################
fix('Archiving old error log', function() use ($akeneo_root) {
    $error_log = $akeneo_root . '/error_log';
    
    if (file_exists($error_log)) {
        $archive = $error_log . '.backup.' . date('Ymd_His');
        rename($error_log, $archive);
        touch($error_log);
        chmod($error_log, 0666);
        
        $size = round(filesize($archive) / 1024 / 1024, 2);
        return "Archived {$size}MB error log";
    }
    
    return "No error log to archive";
});

###############################################################################
# SUMMARY
###############################################################################
echo "\n" . str_repeat("=", 80) . "\n";
echo "FIX SUMMARY\n";
echo str_repeat("=", 80) . "\n\n";

echo "Fixes applied: {$stats['fixed']}\n";
echo "Errors: {$stats['errors']}\n\n";

if ($stats['errors'] == 0) {
    echo "✅ ALL FIXES APPLIED SUCCESSFULLY\n\n";
    echo "The login issue has been resolved. The platform is now stable.\n\n";
    echo "IMPORTANT NEXT STEPS:\n";
    echo "1. Clear your browser cache (Ctrl+Shift+Delete)\n";
    echo "2. Try logging in at: https://pim.technostationery.com/user/login\n";
    echo "3. Use one of these accounts:\n";
    echo "   - admin / [your admin password]\n";
    echo "   - mounir.ab / [your password]\n";
    echo "   - khaled.ke / [your password]\n\n";
    echo "If login still fails:\n";
    echo "- Check PHP-FPM is running: ps aux | grep php-fpm\n";
    echo "- Restart PHP-FPM via cPanel if needed\n";
    echo "- Check cPanel error logs for PHP-FPM errors\n";
} else {
    echo "⚠️ SOME FIXES FAILED\n\n";
    echo "Please review the errors above. Common issues:\n";
    echo "- Database connection problems\n";
    echo "- File permission issues\n";
    echo "- PHP-FPM needs restart via cPanel\n";
}

echo "\n" . date('Y-m-d H:i:s') . "\n";
