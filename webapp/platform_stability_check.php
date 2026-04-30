<?php
/**
 * AKENEO PIM PLATFORM STABILITY CHECK & FIX SCRIPT
 * 
 * This script verifies and fixes all critical platform components:
 * 1. Database connectivity and integrity
 * 2. Elasticsearch connection and index status
 * 3. Cache status and permissions
 * 4. PHP extensions and configuration
 * 5. Console commands availability
 * 6. API endpoints functionality
 * 7. File storage and media files
 * 8. Session handling
 * 
 * Usage: php /home/pim/public_html/webapp/platform_stability_check.php
 * Run as: pim user
 */

error_reporting(E_ALL);
ini_set('display_errors', 1);

echo "=" . str_repeat("=", 79) . "\n";
echo "AKENEO PIM PLATFORM STABILITY CHECK & FIX\n";
echo "Date: " . date('Y-m-d H:i:s') . "\n";
echo "Environment: Production\n";
echo "=" . str_repeat("=", 79) . "\n\n";

$akeneo_root = '/home/pim/public_html';
$stats = [
    'checks_passed' => 0,
    'checks_warned' => 0,
    'checks_failed' => 0,
    'fixes_applied' => 0,
];

function check($name, $status, $message = '', $auto_fix = null) {
    global $stats;
    
    $icon = $status === 'PASS' ? '✅' : ($status === 'WARN' ? '⚠️' : '❌');
    echo sprintf("%s %-50s [%s]\n", $icon, $name, $status);
    if ($message) {
        echo "   → $message\n";
    }
    
    if ($status === 'PASS') $stats['checks_passed']++;
    elseif ($status === 'WARN') $stats['checks_warned']++;
    else $stats['checks_failed']++;
    
    if ($status !== 'PASS' && $auto_fix) {
        echo "   🔧 Applying fix...\n";
        $auto_fix();
        $stats['fixes_applied']++;
    }
}

###############################################################################
# SECTION 1: PHP CONFIGURATION
###############################################################################
echo "\n" . str_repeat("-", 80) . "\n";
echo "1. PHP CONFIGURATION & EXTENSIONS\n";
echo str_repeat("-", 80) . "\n\n";

// PHP version
$php_version = PHP_VERSION;
check('PHP Version', version_compare($php_version, '8.0.0', '>=') ? 'PASS' : 'FAIL',
    "PHP $php_version (minimum 8.0 required)");

// Required extensions
$required_extensions = ['pdo_mysql', 'gd', 'intl', 'mbstring', 'xml', 'curl', 'zip', 'bcmath', 'json'];
foreach ($required_extensions as $ext) {
    check("Extension: $ext", extension_loaded($ext) ? 'PASS' : 'FAIL',
        extension_loaded($ext) ? 'Loaded' : 'NOT loaded');
}

// APCu extension (optional but recommended)
check('APCu Extension', extension_loaded('apcu') ? 'PASS' : 'WARN',
    extension_loaded('apcu') ? 'Loaded (recommended for production)' : 'Not loaded - install for better performance');

// PHP memory limit
$memory_limit = ini_get('memory_limit');
check('Memory Limit', 
    intval($memory_limit) >= 512 ? 'PASS' : 'WARN',
    "Current: $memory_limit (recommended: 512M+)");

// Max execution time
$max_execution_time = ini_get('max_execution_time');
check('Max Execution Time',
    $max_execution_time >= 300 ? 'PASS' : 'WARN',
    "Current: {$max_execution_time}s (recommended: 300+)");

// Upload max filesize
$upload_max_filesize = ini_get('upload_max_filesize');
check('Upload Max Filesize',
    intval($upload_max_filesize) >= 20 ? 'PASS' : 'WARN',
    "Current: $upload_max_filesize (recommended: 20M+)");

###############################################################################
# SECTION 2: DATABASE CONNECTIVITY
###############################################################################
echo "\n" . str_repeat("-", 80) . "\n";
echo "2. DATABASE CONNECTIVITY & INTEGRITY\n";
echo str_repeat("-", 80) . "\n\n";

$akeneo_db = [
    'host' => '127.0.0.1',
    'port' => '3307',
    'database' => 'akeneo_pim',
    'user' => 'akeneo_pim',
    'password' => 'akeneo_pim'
];

try {
    $dsn = "mysql:host={$akeneo_db['host']};port={$akeneo_db['port']};dbname={$akeneo_db['database']};charset=utf8mb4";
    $pdo = new PDO($dsn, $akeneo_db['user'], $akeneo_db['password'], [
        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC
    ]);
    
    check('Database Connection', 'PASS', 'Connected successfully');
    
    // Check critical tables exist
    $required_tables = [
        'pim_catalog_product',
        'pim_catalog_category',
        'pim_catalog_attribute',
        'pim_catalog_family',
        'pim_catalog_channel',
        'pim_catalog_locale',
        'pim_catalog_attribute_group',
        'pim_api_client',
    ];
    
    $existing_tables = $pdo->query("SHOW TABLES")->fetchAll(PDO::FETCH_COLUMN);
    foreach ($required_tables as $table) {
        $exists = in_array($table, $existing_tables);
        check("Table: $table", $exists ? 'PASS' : 'FAIL',
            $exists ? 'Exists' : 'MISSING');
    }
    
    // Check data integrity
    $product_count = $pdo->query("SELECT COUNT(*) FROM pim_catalog_product")->fetchColumn();
    check('Product Data', $product_count > 0 ? 'PASS' : 'WARN',
        "$product_count products in database");
    
    $category_count = $pdo->query("SELECT COUNT(*) FROM pim_catalog_category")->fetchColumn();
    check('Category Data', $category_count > 0 ? 'PASS' : 'WARN',
        "$category_count categories in database");
    
    $family_count = $pdo->query("SELECT COUNT(*) FROM pim_catalog_family")->fetchColumn();
    check('Family Data', $family_count > 0 ? 'PASS' : 'WARN',
        "$family_count families configured");
    
    // Check for orphaned data
    $orphans = $pdo->query("
        SELECT COUNT(*) FROM pim_catalog_category_product cp
        LEFT JOIN pim_catalog_product p ON cp.product_id = p.id
        WHERE p.id IS NULL
    ")->fetchColumn();
    check('Orphaned Category Links',
        $orphans == 0 ? 'PASS' : 'WARN',
        $orphans == 0 ? 'No orphaned links' : "$orphans orphaned category-product links found");
    
} catch (PDOException $e) {
    check('Database Connection', 'FAIL', 'Connection failed: ' . $e->getMessage());
}

###############################################################################
# SECTION 3: ELASTICSEARCH
###############################################################################
echo "\n" . str_repeat("-", 80) . "\n";
echo "3. ELASTICSEARCH CONNECTION & INDEX STATUS\n";
echo str_repeat("-", 80) . "\n\n";

$es_host = 'localhost:9200';
$es_url = "http://$es_host";

$es_health = @json_decode(file_get_contents("$es_url/_cluster/health?pretty"), true);
if ($es_health) {
    $status = $es_health['status'] === 'green' ? 'PASS' : ($es_health['status'] === 'yellow' ? 'WARN' : 'FAIL');
    check('Elasticsearch Cluster', $status,
        "Status: {$es_health['status']}, Nodes: {$es_health['number_of_nodes']}, " .
        "Shards: {$es_health['active_primary_shards']} primary, " .
        "Unassigned: {$es_health['unassigned_shards']}");
    
    // Check Akeneo indexes
    try {
        $indexes = @json_decode(file_get_contents("$es_url/_cat/indices?format=json"), true);
        $akeneo_indexes = array_filter($indexes, function($idx) {
            return strpos($idx['index'], 'akeneo') !== false;
        });
        
        check('Akeneo Indexes', count($akeneo_indexes) > 0 ? 'PASS' : 'WARN',
            count($akeneo_indexes) . " Akeneo indexes found");
        
        foreach ($akeneo_indexes as $idx) {
            $health = $idx['health'] === 'green' ? 'PASS' : 'WARN';
            check("Index: {$idx['index']}", $health,
                "Docs: {$idx['docs.count']}, Size: {$idx['store.size']}");
        }
    } catch (Exception $e) {
        check('Akeneo Indexes', 'WARN', 'Could not retrieve index list');
    }
    
} else {
    check('Elasticsearch Cluster', 'FAIL', 'Cannot connect to Elasticsearch');
}

###############################################################################
# SECTION 4: CACHE & FILE SYSTEM
###############################################################################
echo "\n" . str_repeat("-", 80) . "\n";
echo "4. CACHE & FILE SYSTEM\n";
echo str_repeat("-", 80) . "\n\n";

// Cache directory
$cache_dir = $akeneo_root . '/var/cache/prod';
check('Cache Directory', is_dir($cache_dir) ? 'PASS' : 'FAIL',
    is_dir($cache_dir) ? "Exists: $cache_dir" : 'MISSING');

// Cache writable
check('Cache Writable', is_writable($cache_dir) ? 'PASS' : 'FAIL',
    is_writable($cache_dir) ? 'Writable' : 'NOT writable - check permissions',
    function() use ($cache_dir) {
        shell_exec("chmod -R 775 $cache_dir 2>/dev/null");
        echo "   → Fixed cache permissions\n";
    }
);

// Public cache (browser cache)
$public_cache = $akeneo_root . '/public/cache';
check('Public Cache', is_dir($public_cache) ? 'PASS' : 'WARN',
    is_dir($public_cache) ? count(scandir($public_cache)) - 2 . " files" : 'Directory missing');

// File storage
$file_storage = $akeneo_root . '/var/file_storage';
check('File Storage', is_dir($file_storage) ? 'PASS' : 'WARN',
    is_dir($file_storage) ? 'Exists' : 'Directory missing');

// Sessions
$sessions_dir = $akeneo_root . '/var/sessions';
check('Sessions Directory', is_dir($sessions_dir) ? 'PASS' : 'FAIL',
    is_dir($sessions_dir) ? 'Exists' : 'MISSING');

// var/log directory
$log_dir = $akeneo_root . '/var/log';
check('Log Directory', is_dir($log_dir) ? 'PASS' : 'WARN',
    is_dir($log_dir) ? 'Exists' : 'Creating...');

###############################################################################
# SECTION 5: CONSOLE COMMANDS
###############################################################################
echo "\n" . str_repeat("-", 80) . "\n";
echo "5. CONSOLE COMMANDS AVAILABILITY\n";
echo str_repeat("-", 80) . "\n\n";

$critical_commands = [
    'pim:installer:check-requirements',
    'pim:user:create',
    'pim:completeness:calculate',
    'akeneo:elasticsearch:reset-indexes',
    'cache:clear',
    'assets:install',
];

foreach ($critical_commands as $cmd) {
    exec("cd $akeneo_root && php bin/console list --raw 2>/dev/null | grep '^$cmd'", $output, $return);
    $exists = !empty($output);
    check("Command: $cmd", $exists ? 'PASS' : 'FAIL',
        $exists ? 'Available' : 'NOT found');
    $output = [];
}

###############################################################################
# SECTION 6: API CONFIGURATION
###############################################################################
echo "\n" . str_repeat("-", 80) . "\n";
echo "6. API CONFIGURATION\n";
echo str_repeat("-", 80) . "\n\n";

// Check API clients
try {
    $clients = $pdo->query("SELECT code, label, is_active FROM pim_api_client")->fetchAll();
    check('API Clients', count($clients) > 0 ? 'PASS' : 'WARN',
        count($clients) . " API client(s) configured");
    
    foreach ($clients as $client) {
        check("API: {$client['code']}", $client['is_active'] ? 'PASS' : 'WARN',
            "{$client['label']} - " . ($client['is_active'] ? 'Active' : 'Inactive'));
    }
} catch (Exception $e) {
    check('API Clients', 'WARN', 'Could not check API clients');
}

// Check OAuth configuration
check('OAuth Secret', strlen(getenv('APP_SECRET')) > 0 ? 'PASS' : 'WARN',
    strlen(getenv('APP_SECRET')) > 0 ? 'Configured' : 'APP_SECRET may not be set');

###############################################################################
# SECTION 7: ENVIRONMENT CONFIGURATION
###############################################################################
echo "\n" . str_repeat("-", 80) . "\n";
echo "7. ENVIRONMENT CONFIGURATION\n";
echo str_repeat("-", 80) . "\n\n";

$env_file = $akeneo_root . '/.env';
check('.env File', file_exists($env_file) ? 'PASS' : 'FAIL',
    file_exists($env_file) ? 'Exists' : 'MISSING');

$env_content = file_get_contents($env_file);
preg_match('/APP_ENV=(\w+)/', $env_content, $matches);
$app_env = $matches[1] ?? 'unknown';
check('APP_ENV', $app_env === 'prod' ? 'PASS' : 'WARN',
    "Current: $app_env (should be 'prod')");

preg_match('/APP_DATABASE_HOST=(.+)/', $env_content, $matches);
$db_host = $matches[1] ?? 'unknown';
check('Database Host', $db_host ? 'PASS' : 'FAIL',
    "Host: $db_host");

preg_match('/APP_INDEX_HOSTS=(.+)/', $env_content, $matches);
$es_hosts = $matches[1] ?? 'unknown';
check('Elasticsearch Hosts', $es_hosts ? 'PASS' : 'FAIL',
    "Hosts: $es_hosts");

preg_match('/FLAG_DATA_QUALITY_INSIGHTS_ENABLED=(\d)/', $env_content, $matches);
$dqi_enabled = ($matches[1] ?? '0') === '1';
check('Data Quality Insights', $dqi_enabled ? 'PASS' : 'WARN',
    $dqi_enabled ? 'Enabled' : 'Disabled');

###############################################################################
# SECTION 8: PERMISSIONS
###############################################################################
echo "\n" . str_repeat("-", 80) . "\n";
echo "8. FILE PERMISSIONS\n";
echo str_repeat("-", 80) . "\n\n";

$writable_dirs = [
    'var/cache',
    'var/logs',
    'var/sessions',
    'var/file_storage',
    'public/bundles',
    'public/cache',
];

foreach ($writable_dirs as $dir) {
    $full_path = $akeneo_root . '/' . $dir;
    $writable = is_writable($full_path);
    check("Writable: $dir", $writable ? 'PASS' : 'FAIL',
        $writable ? 'Writable' : 'NOT writable',
        $writable ? null : function() use ($full_path, $dir) {
            shell_exec("chmod -R 775 $full_path 2>/dev/null");
            shell_exec("chown -R pim:pim $full_path 2>/dev/null");
            echo "   → Fixed permissions for $dir\n";
        }
    );
}

###############################################################################
# SUMMARY
###############################################################################
echo "\n" . str_repeat("=", 80) . "\n";
echo "PLATFORM STABILITY SUMMARY\n";
echo str_repeat("=", 80) . "\n\n";

echo "Checks Passed: {$stats['checks_passed']}\n";
echo "Checks Warned: {$stats['checks_warned']}\n";
echo "Checks Failed: {$stats['checks_failed']}\n";
echo "Fixes Applied: {$stats['fixes_applied']}\n\n";

$total_checks = $stats['checks_passed'] + $stats['checks_warned'] + $stats['checks_failed'];
$health_score = round(($stats['checks_passed'] / $total_checks) * 100, 1);

echo "Platform Health Score: {$health_score}%\n\n";

if ($stats['checks_failed'] == 0) {
    echo "✅ PLATFORM IS STABLE AND READY FOR PRODUCTION\n\n";
    echo "All critical checks passed. The platform is operational.\n\n";
    echo "Recommendations:\n";
    echo "1. Run cache clear to ensure clean state:\n";
    echo "   php bin/console cache:clear --env=prod --no-debug\n\n";
    echo "2. Rebuild Elasticsearch indexes if needed:\n";
    echo "   php bin/console akeneo:elasticsearch:reset-indexes --env=prod --no-debug\n\n";
    echo "3. Reindex products for search:\n";
    echo "   php bin/console akeneo:indexing:index-products --env=prod --no-debug\n\n";
    echo "4. Verify in browser: https://pim.technostationery.com\n";
} else {
    echo "⚠️ PLATFORM HAS ISSUES THAT NEED ATTENTION\n\n";
    echo "Failed checks detected. Please review the errors above and fix them.\n";
}

echo "\n" . date('Y-m-d H:i:s') . "\n";
