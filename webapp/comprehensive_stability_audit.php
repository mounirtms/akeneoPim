<?php
/**
 * Comprehensive Platform Stability Audit
 * Date: 2026-04-29
 * Purpose: Deep stability analysis post-Varnish with actionable recommendations
 */

ini_set('display_errors', 1);
error_reporting(E_ALL);

$timestamp = date('Y-m-d H:i:s');
$logFile = __DIR__ . '/logs/comprehensive_stability_' . date('Ymd_His') . '.log';

function logMessage($message, $logFile) {
    echo $message . PHP_EOL;
    file_put_contents($logFile, $message . PHP_EOL, FILE_APPEND);
}

logMessage("=== COMPREHENSIVE STABILITY AUDIT - $timestamp ===\n", $logFile);

// Database connections
$akeneoDB = new PDO(
    'mysql:host=127.0.0.1;port=3307;dbname=akeneo_pim',
    'root',
    'YourNewStrongPassword',
    [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]
);

$magentoDB = new PDO(
    'mysql:host=127.0.0.1;port=3307;dbname=beta_dBT8x12y22',
    'root',
    'YourNewStrongPassword',
    [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]
);

// 1. SYSTEM HEALTH CHECK
logMessage("📊 SYSTEM HEALTH METRICS", $logFile);
logMessage(str_repeat("-", 80), $logFile);

$uptime = shell_exec('uptime');
$loadAvg = sys_getloadavg();
$diskFree = disk_free_space('/home/pim') / (1024**3);
$diskTotal = disk_total_space('/home/pim') / (1024**3);
$memInfo = shell_exec("free -h | grep Mem");

logMessage("System Uptime: " . trim($uptime), $logFile);
logMessage("Load Average: 1min={$loadAvg[0]}, 5min={$loadAvg[1]}, 15min={$loadAvg[2]}", $logFile);
logMessage("Disk Space: " . round($diskFree, 2) . " GB free of " . round($diskTotal, 2) . " GB", $logFile);
logMessage("Memory: $memInfo", $logFile);

// Load average health assessment
$loadStatus = $loadAvg[0] < 4 ? '✅ HEALTHY' : ($loadAvg[0] < 8 ? '⚠️ WARNING' : '🔴 CRITICAL');
logMessage("Load Status: $loadStatus", $logFile);
logMessage("", $logFile);

// 2. DATABASE HEALTH & INTEGRITY
logMessage("🗄️ DATABASE HEALTH & INTEGRITY", $logFile);
logMessage(str_repeat("-", 80), $logFile);

// Akeneo database size and table stats
$akeneoDB->exec("USE akeneo_pim");
$dbSize = $akeneoDB->query("
    SELECT 
        ROUND(SUM(data_length + index_length) / 1024 / 1024, 2) as size_mb,
        COUNT(*) as table_count
    FROM information_schema.TABLES 
    WHERE table_schema = 'akeneo_pim'
")->fetch(PDO::FETCH_ASSOC);

logMessage("Akeneo DB Size: {$dbSize['size_mb']} MB across {$dbSize['table_count']} tables", $logFile);

// Check for table corruption
$corruptTables = $akeneoDB->query("
    SELECT TABLE_NAME 
    FROM information_schema.TABLES 
    WHERE table_schema = 'akeneo_pim' 
    AND ENGINE IS NULL
")->fetchAll(PDO::FETCH_COLUMN);

if (empty($corruptTables)) {
    logMessage("Table Integrity: ✅ All tables healthy", $logFile);
} else {
    logMessage("Table Integrity: 🔴 CORRUPT TABLES: " . implode(', ', $corruptTables), $logFile);
}

// Connection pool status
$connections = $akeneoDB->query("SHOW STATUS LIKE 'Threads_connected'")->fetch(PDO::FETCH_ASSOC);
$maxConnections = $akeneoDB->query("SHOW VARIABLES LIKE 'max_connections'")->fetch(PDO::FETCH_ASSOC);
logMessage("DB Connections: {$connections['Value']} / {$maxConnections['Value']}", $logFile);

// Slow query analysis
$slowQueries = $akeneoDB->query("SHOW STATUS LIKE 'Slow_queries'")->fetch(PDO::FETCH_ASSOC);
logMessage("Slow Queries (24h): {$slowQueries['Value']}", $logFile);
logMessage("", $logFile);

// 3. AKENEO PLATFORM STATUS
logMessage("🏭 AKENEO PLATFORM STATUS", $logFile);
logMessage(str_repeat("-", 80), $logFile);

$platformStats = $akeneoDB->query("
    SELECT 
        (SELECT COUNT(*) FROM pim_catalog_product) as total_products,
        (SELECT COUNT(*) FROM pim_catalog_attribute) as total_attributes,
        (SELECT COUNT(*) FROM pim_catalog_family) as total_families,
        (SELECT COUNT(*) FROM pim_catalog_channel) as total_channels,
        (SELECT COUNT(*) FROM pim_catalog_category) as total_categories,
        (SELECT COUNT(*) FROM pim_catalog_attribute_option) as total_options
")->fetch(PDO::FETCH_ASSOC);

foreach ($platformStats as $key => $value) {
    logMessage(ucwords(str_replace('_', ' ', $key)) . ": $value", $logFile);
}

// Data quality metrics
$dataQuality = $akeneoDB->query("
    SELECT
        COUNT(DISTINCT p.identifier) as products_with_data,
        COUNT(DISTINCT CASE WHEN pv.locale = 'en_US' THEN p.id END) as english_content,
        COUNT(DISTINCT CASE WHEN pv.locale = 'fr_FR' THEN p.id END) as french_content
    FROM pim_catalog_product p
    LEFT JOIN pim_catalog_product_unique_data pv ON p.id = pv.product_id
")->fetch(PDO::FETCH_ASSOC);

logMessage("\nData Quality Metrics:", $logFile);
logMessage("Products with Data: {$dataQuality['products_with_data']}", $logFile);
logMessage("English Content Coverage: {$dataQuality['english_content']} products", $logFile);
logMessage("French Content Coverage: {$dataQuality['french_content']} products", $logFile);
logMessage("", $logFile);

// 4. VARNISH CACHE ANALYSIS
logMessage("🚀 VARNISH CACHE PERFORMANCE", $logFile);
logMessage(str_repeat("-", 80), $logFile);

$varnishStats = shell_exec('varnishstat -1 2>/dev/null');
if ($varnishStats) {
    preg_match('/MAIN\.cache_hit\s+(\d+)/', $varnishStats, $hits);
    preg_match('/MAIN\.cache_miss\s+(\d+)/', $varnishStats, $misses);
    preg_match('/MAIN\.client_req\s+(\d+)/', $varnishStats, $requests);
    
    $cacheHits = isset($hits[1]) ? $hits[1] : 0;
    $cacheMisses = isset($misses[1]) ? $misses[1] : 0;
    $totalRequests = isset($requests[1]) ? $requests[1] : 0;
    $hitRate = $totalRequests > 0 ? ($cacheHits / $totalRequests * 100) : 0;
    
    logMessage("Total Requests: $totalRequests", $logFile);
    logMessage("Cache Hits: $cacheHits", $logFile);
    logMessage("Cache Misses: $cacheMisses", $logFile);
    logMessage("Hit Rate: " . round($hitRate, 2) . "%", $logFile);
    
    $varnishHealth = $hitRate >= 80 ? '✅ EXCELLENT' : ($hitRate >= 60 ? '⚠️ GOOD' : '🔴 NEEDS OPTIMIZATION');
    logMessage("Varnish Health: $varnishHealth", $logFile);
} else {
    logMessage("Varnish Status: ⚠️ Not accessible or not running", $logFile);
}
logMessage("", $logFile);

// 5. ERROR LOG ANALYSIS (Last 24 hours)
logMessage("🚨 ERROR LOG ANALYSIS (Last 24 Hours)", $logFile);
logMessage(str_repeat("-", 80), $logFile);

$logPath = '/home/pim/public_html/var/logs/prod.log';
if (file_exists($logPath)) {
    $logContent = shell_exec("tail -5000 '$logPath' 2>/dev/null");
    
    $criticalCount = substr_count($logContent, '[CRITICAL]');
    $errorCount = substr_count($logContent, '[ERROR]');
    $warningCount = substr_count($logContent, '[WARNING]');
    
    logMessage("Critical Errors: $criticalCount", $logFile);
    logMessage("Errors: $errorCount", $logFile);
    logMessage("Warnings: $warningCount", $logFile);
    
    // Extract unique error patterns
    preg_match_all('/\[(ERROR|CRITICAL)\] (.{100})/', $logContent, $errorPatterns);
    $uniqueErrors = array_unique(array_slice($errorPatterns[2], 0, 10));
    
    logMessage("\nTop Error Patterns:", $logFile);
    foreach ($uniqueErrors as $idx => $error) {
        logMessage(($idx + 1) . ". " . trim($error) . "...", $logFile);
    }
    
    $errorHealth = $criticalCount == 0 && $errorCount < 50 ? '✅ HEALTHY' : ($criticalCount > 0 || $errorCount > 100 ? '🔴 CRITICAL' : '⚠️ WARNING');
    logMessage("\nError Log Health: $errorHealth", $logFile);
} else {
    logMessage("Production log not found at: $logPath", $logFile);
}
logMessage("", $logFile);

// 6. MAGENTO SYNC STATUS
logMessage("🔄 MAGENTO SYNC STATUS", $logFile);
logMessage(str_repeat("-", 80), $logFile);

$syncStats = $magentoDB->query("
    SELECT 
        (SELECT COUNT(*) FROM catalog_product_entity) as magento_products,
        (SELECT COUNT(*) FROM catalog_category_product) as category_assignments,
        (SELECT COUNT(*) FROM cataloginventory_stock_status WHERE stock_status = 1) as in_stock_products
")->fetch(PDO::FETCH_ASSOC);

$akeneoProdCount = $platformStats['total_products'];
$syncRatio = $akeneoProdCount > 0 ? ($syncStats['magento_products'] / $akeneoProdCount * 100) : 0;

logMessage("Akeneo Products: $akeneoProdCount", $logFile);
logMessage("Magento Products: {$syncStats['magento_products']}", $logFile);
logMessage("Sync Ratio: " . round($syncRatio, 2) . "%", $logFile);
logMessage("Category Assignments: {$syncStats['category_assignments']}", $logFile);
logMessage("In Stock Products: {$syncStats['in_stock_products']}", $logFile);

$syncHealth = abs($syncRatio - 100) < 1 ? '✅ PERFECT SYNC' : ($syncRatio > 95 ? '⚠️ MINOR DRIFT' : '🔴 SYNC ISSUES');
logMessage("Sync Health: $syncHealth", $logFile);
logMessage("", $logFile);

// 7. WEB SERVER STATUS
logMessage("🌐 WEB SERVER STATUS", $logFile);
logMessage(str_repeat("-", 80), $logFile);

$services = [
    'Apache' => 'systemctl is-active httpd 2>/dev/null',
    'Nginx' => 'systemctl is-active nginx 2>/dev/null',
    'PHP-FPM' => 'systemctl is-active php-fpm 2>/dev/null',
    'Elasticsearch' => 'systemctl is-active elasticsearch 2>/dev/null',
    'Varnish' => 'systemctl is-active varnish 2>/dev/null'
];

foreach ($services as $service => $command) {
    $status = trim(shell_exec($command));
    $icon = $status === 'active' ? '✅' : '❌';
    logMessage("$service: $icon " . strtoupper($status), $logFile);
}

// Check open ports
$openPorts = shell_exec("netstat -tuln | grep LISTEN | awk '{print $4}' | grep -E ':(80|443|8080|9200|6081)' | sort -u");
logMessage("\nOpen Ports:", $logFile);
logMessage(trim($openPorts), $logFile);
logMessage("", $logFile);

// 8. CACHE STATUS
logMessage("💾 CACHE STATUS", $logFile);
logMessage(str_repeat("-", 80), $logFile);

$cacheDir = '/home/pim/public_html/var/cache';
$cacheSize = shell_exec("du -sh '$cacheDir' 2>/dev/null | awk '{print $1}'");
$cacheModified = shell_exec("stat -c %y '$cacheDir' 2>/dev/null");

logMessage("Cache Directory: $cacheDir", $logFile);
logMessage("Cache Size: " . trim($cacheSize), $logFile);
logMessage("Last Modified: " . trim($cacheModified), $logFile);

// Check if cache is stale (> 7 days old)
$cacheAge = time() - filemtime($cacheDir);
$cacheDays = floor($cacheAge / 86400);
$cacheHealth = $cacheDays < 7 ? '✅ FRESH' : '⚠️ STALE';
logMessage("Cache Age: $cacheDays days - $cacheHealth", $logFile);
logMessage("", $logFile);

// 9. PERFORMANCE METRICS
logMessage("⚡ PERFORMANCE METRICS", $logFile);
logMessage(str_repeat("-", 80), $logFile);

$perfStats = $akeneoDB->query("SHOW GLOBAL STATUS WHERE Variable_name IN ('Questions', 'Uptime', 'Threads_running', 'Slow_queries')")->fetchAll(PDO::FETCH_KEY_PAIR);

$qps = $perfStats['Questions'] / $perfStats['Uptime'];
logMessage("Database Queries/sec: " . round($qps, 2), $logFile);
logMessage("Active Threads: {$perfStats['Threads_running']}", $logFile);
logMessage("Slow Queries: {$perfStats['Slow_queries']}", $logFile);

$dbHealth = $qps < 100 ? '✅ OPTIMAL' : ($qps < 500 ? '⚠️ MODERATE' : '🔴 HIGH LOAD');
logMessage("Database Load: $dbHealth", $logFile);
logMessage("", $logFile);

// 10. CRITICAL ISSUES SUMMARY
logMessage("🎯 CRITICAL ISSUES & RECOMMENDATIONS", $logFile);
logMessage(str_repeat("=", 80), $logFile);

$issues = [];
$recommendations = [];

// Check load average
if ($loadAvg[0] > 8) {
    $issues[] = "HIGH SYSTEM LOAD: {$loadAvg[0]} (target < 4.0)";
    $recommendations[] = "Investigate CPU-intensive processes with 'top' and 'htop'";
    $recommendations[] = "Consider enabling PHP-FPM and optimizing worker processes";
}

// Check Varnish
if (isset($hitRate) && $hitRate < 60) {
    $issues[] = "LOW VARNISH HIT RATE: " . round($hitRate, 2) . "% (target > 80%)";
    $recommendations[] = "Review Varnish VCL configuration (/etc/varnish/default.vcl)";
    $recommendations[] = "Increase TTL for static assets and cacheable pages";
}

// Check error logs
if ($criticalCount > 0) {
    $issues[] = "CRITICAL ERRORS IN LOGS: $criticalCount errors found";
    $recommendations[] = "Review and fix critical errors in /home/pim/public_html/var/logs/prod.log";
}

// Check cache age
if ($cacheDays > 7) {
    $issues[] = "STALE CACHE: Cache is $cacheDays days old";
    $recommendations[] = "Clear Akeneo cache: bin/console cache:clear --env=prod";
}

// Check PHP-FPM
if ($services['PHP-FPM'] !== 'active') {
    $issues[] = "PHP-FPM NOT ACTIVE: Performance may be degraded";
    $recommendations[] = "Enable and configure PHP-FPM for better performance";
}

if (empty($issues)) {
    logMessage("✅ NO CRITICAL ISSUES DETECTED", $logFile);
    logMessage("Platform is stable and performing well!", $logFile);
} else {
    logMessage("🔴 CRITICAL ISSUES DETECTED: " . count($issues), $logFile);
    foreach ($issues as $idx => $issue) {
        logMessage(($idx + 1) . ". $issue", $logFile);
    }
    
    logMessage("\n📋 RECOMMENDATIONS:", $logFile);
    foreach ($recommendations as $idx => $rec) {
        logMessage(($idx + 1) . ". $rec", $logFile);
    }
}

logMessage("\n=== AUDIT COMPLETE ===", $logFile);
logMessage("Report saved to: $logFile", $logFile);
