<?php
/**
 * Fixed Comprehensive Platform Stability Audit
 * Date: 2026-04-29
 */

ini_set('display_errors', 1);
error_reporting(E_ALL);

$timestamp = date('Y-m-d H:i:s');
$logFile = __DIR__ . '/logs/stability_audit_' . date('Ymd_His') . '.log';

function logMessage($message, $logFile) {
    echo $message . PHP_EOL;
    file_put_contents($logFile, $message . PHP_EOL, FILE_APPEND);
}

logMessage("=== COMPREHENSIVE STABILITY AUDIT - $timestamp ===\n", $logFile);

try {
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

    // 1. SYSTEM HEALTH
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

    $loadStatus = $loadAvg[0] < 4 ? '✅ HEALTHY' : ($loadAvg[0] < 8 ? '⚠️ WARNING' : '🔴 CRITICAL');
    logMessage("Load Status: $loadStatus", $logFile);
    logMessage("", $logFile);

    // 2. DATABASE HEALTH
    logMessage("🗄️ DATABASE HEALTH & INTEGRITY", $logFile);
    logMessage(str_repeat("-", 80), $logFile);

    $dbSize = $akeneoDB->query("
        SELECT 
            ROUND(SUM(data_length + index_length) / 1024 / 1024, 2) as size_mb,
            COUNT(*) as table_count
        FROM information_schema.TABLES 
        WHERE table_schema = 'akeneo_pim'
    ")->fetch(PDO::FETCH_ASSOC);

    logMessage("Akeneo DB Size: {$dbSize['size_mb']} MB across {$dbSize['table_count']} tables", $logFile);

    $connections = $akeneoDB->query("SHOW STATUS LIKE 'Threads_connected'")->fetch(PDO::FETCH_ASSOC);
    $maxConnections = $akeneoDB->query("SHOW VARIABLES LIKE 'max_connections'")->fetch(PDO::FETCH_ASSOC);
    logMessage("DB Connections: {$connections['Value']} / {$maxConnections['Value']}", $logFile);

    $slowQueries = $akeneoDB->query("SHOW STATUS LIKE 'Slow_queries'")->fetch(PDO::FETCH_ASSOC);
    logMessage("Slow Queries: {$slowQueries['Value']}", $logFile);
    logMessage("", $logFile);

    // 3. AKENEO PLATFORM STATUS
    logMessage("🏭 AKENEO PLATFORM STATUS", $logFile);
    logMessage(str_repeat("-", 80), $logFile);

    $platformStats = $akeneoDB->query("
        SELECT 
            (SELECT COUNT(*) FROM pim_catalog_product) as total_products,
            (SELECT COUNT(*) FROM pim_catalog_attribute) as total_attributes,
            (SELECT COUNT(*) FROM pim_catalog_family) as total_families,
            (SELECT COUNT(*) FROM pim_catalog_channel) as total_channels
    ")->fetch(PDO::FETCH_ASSOC);

    foreach ($platformStats as $key => $value) {
        logMessage(ucwords(str_replace('_', ' ', $key)) . ": $value", $logFile);
    }
    logMessage("", $logFile);

    // 4. VARNISH CACHE
    logMessage("🚀 VARNISH CACHE PERFORMANCE", $logFile);
    logMessage(str_repeat("-", 80), $logFile);

    $varnishStats = shell_exec('varnishstat -1 2>/dev/null');
    if ($varnishStats) {
        preg_match('/MAIN\.cache_hit\s+(\d+)/', $varnishStats, $hits);
        preg_match('/MAIN\.cache_miss\s+(\d+)/', $varnishStats, $misses);
        
        $cacheHits = isset($hits[1]) ? $hits[1] : 0;
        $cacheMisses = isset($misses[1]) ? $misses[1] : 0;
        $totalRequests = $cacheHits + $cacheMisses;
        $hitRate = $totalRequests > 0 ? ($cacheHits / $totalRequests * 100) : 0;
        
        logMessage("Cache Hits: $cacheHits", $logFile);
        logMessage("Cache Misses: $cacheMisses", $logFile);
        logMessage("Hit Rate: " . round($hitRate, 2) . "%", $logFile);
        
        $varnishHealth = $hitRate >= 80 ? '✅ EXCELLENT' : ($hitRate >= 60 ? '⚠️ GOOD' : '🔴 NEEDS OPTIMIZATION');
        logMessage("Varnish Health: $varnishHealth", $logFile);
    } else {
        logMessage("Varnish Status: ⚠️ Not accessible", $logFile);
    }
    logMessage("", $logFile);

    // 5. ERROR LOG ANALYSIS
    logMessage("🚨 ERROR LOG ANALYSIS (Last 24 Hours)", $logFile);
    logMessage(str_repeat("-", 80), $logFile);

    $logPath = '/home/pim/public_html/var/logs/prod.log';
    if (file_exists($logPath)) {
        $logContent = shell_exec("tail -2000 '$logPath' 2>/dev/null");
        
        $criticalCount = substr_count($logContent, '[CRITICAL]');
        $errorCount = substr_count($logContent, '[ERROR]');
        $warningCount = substr_count($logContent, '[WARNING]');
        
        logMessage("Critical Errors: $criticalCount", $logFile);
        logMessage("Errors: $errorCount", $logFile);
        logMessage("Warnings: $warningCount", $logFile);
        
        $errorHealth = $criticalCount == 0 && $errorCount < 50 ? '✅ HEALTHY' : ($criticalCount > 0 || $errorCount > 100 ? '🔴 CRITICAL' : '⚠️ WARNING');
        logMessage("Error Log Health: $errorHealth", $logFile);
    }
    logMessage("", $logFile);

    // 6. MAGENTO SYNC
    logMessage("🔄 MAGENTO SYNC STATUS", $logFile);
    logMessage(str_repeat("-", 80), $logFile);

    $syncStats = $magentoDB->query("
        SELECT 
            (SELECT COUNT(*) FROM catalog_product_entity) as magento_products,
            (SELECT COUNT(*) FROM cataloginventory_stock_status WHERE stock_status = 1) as in_stock_products
    ")->fetch(PDO::FETCH_ASSOC);

    $akeneoProdCount = $platformStats['total_products'];
    $syncRatio = $akeneoProdCount > 0 ? ($syncStats['magento_products'] / $akeneoProdCount * 100) : 0;

    logMessage("Akeneo Products: $akeneoProdCount", $logFile);
    logMessage("Magento Products: {$syncStats['magento_products']}", $logFile);
    logMessage("Sync Ratio: " . round($syncRatio, 2) . "%", $logFile);
    logMessage("In Stock: {$syncStats['in_stock_products']}", $logFile);

    $syncHealth = abs($syncRatio - 100) < 1 ? '✅ PERFECT SYNC' : '⚠️ MINOR DRIFT';
    logMessage("Sync Health: $syncHealth", $logFile);
    logMessage("", $logFile);

    // 7. WEB SERVICES
    logMessage("🌐 WEB SERVER STATUS", $logFile);
    logMessage(str_repeat("-", 80), $logFile);

    $services = [
        'Apache' => shell_exec('systemctl is-active httpd 2>/dev/null'),
        'Nginx' => shell_exec('systemctl is-active nginx 2>/dev/null'),
        'PHP-FPM' => shell_exec('systemctl is-active php-fpm 2>/dev/null'),
        'Elasticsearch' => shell_exec('systemctl is-active elasticsearch 2>/dev/null'),
        'Varnish' => shell_exec('systemctl is-active varnish 2>/dev/null')
    ];

    foreach ($services as $service => $status) {
        $status = trim($status);
        $icon = $status === 'active' ? '✅' : '❌';
        logMessage("$service: $icon " . strtoupper($status), $logFile);
    }
    logMessage("", $logFile);

    // 8. PERFORMANCE METRICS
    logMessage("⚡ PERFORMANCE METRICS", $logFile);
    logMessage(str_repeat("-", 80), $logFile);

    $perfStats = $akeneoDB->query("
        SHOW GLOBAL STATUS WHERE Variable_name IN ('Questions', 'Uptime', 'Threads_running')
    ")->fetchAll(PDO::FETCH_KEY_PAIR);

    $qps = $perfStats['Questions'] / $perfStats['Uptime'];
    logMessage("Database Queries/sec: " . round($qps, 2), $logFile);
    logMessage("Active Threads: {$perfStats['Threads_running']}", $logFile);

    $dbHealth = $qps < 100 ? '✅ OPTIMAL' : ($qps < 500 ? '⚠️ MODERATE' : '🔴 HIGH LOAD');
    logMessage("Database Load: $dbHealth", $logFile);
    logMessage("", $logFile);

    // 9. CRITICAL ISSUES
    logMessage("🎯 CRITICAL ISSUES & RECOMMENDATIONS", $logFile);
    logMessage(str_repeat("=", 80), $logFile);

    $issues = [];
    $recommendations = [];

    if ($loadAvg[0] > 8) {
        $issues[] = "HIGH SYSTEM LOAD: {$loadAvg[0]} (target < 4.0)";
        $recommendations[] = "P0: Enable PHP-FPM for 30-40% load reduction";
        $recommendations[] = "P0: Consolidate web servers (stop either Apache or Nginx)";
        $recommendations[] = "P1: Optimize MariaDB buffer pool settings";
    }

    if (isset($hitRate) && $hitRate < 60) {
        $issues[] = "LOW VARNISH HIT RATE: " . round($hitRate, 2) . "% (target > 80%)";
        $recommendations[] = "P1: Review Varnish VCL configuration";
        $recommendations[] = "P1: Increase cache TTL for static assets";
    }

    if ($services['PHP-FPM'] !== 'active') {
        $issues[] = "PHP-FPM INACTIVE: Major performance degradation";
        $recommendations[] = "P0: URGENT - Enable PHP-FPM immediately";
    }

    if ($criticalCount > 0) {
        $issues[] = "CRITICAL ERRORS: $criticalCount in production logs";
        $recommendations[] = "P0: Review and fix critical errors";
    }

    if (empty($issues)) {
        logMessage("✅ NO CRITICAL ISSUES DETECTED", $logFile);
        logMessage("Platform is stable and performing well!", $logFile);
    } else {
        logMessage("🔴 CRITICAL ISSUES: " . count($issues), $logFile);
        foreach ($issues as $idx => $issue) {
            logMessage(($idx + 1) . ". $issue", $logFile);
        }
        
        logMessage("\n📋 PRIORITY RECOMMENDATIONS:", $logFile);
        foreach ($recommendations as $idx => $rec) {
            logMessage(($idx + 1) . ". $rec", $logFile);
        }
    }

    // 10. OVERALL HEALTH SCORE
    logMessage("\n" . str_repeat("=", 80), $logFile);
    
    $healthScore = 100;
    if ($loadAvg[0] > 8) $healthScore -= 30;
    elseif ($loadAvg[0] > 4) $healthScore -= 15;
    
    if (isset($hitRate) && $hitRate < 60) $healthScore -= 15;
    if ($services['PHP-FPM'] !== 'active') $healthScore -= 25;
    if ($criticalCount > 0) $healthScore -= 20;
    if ($errorCount > 100) $healthScore -= 10;
    
    $grade = $healthScore >= 90 ? 'A+' : ($healthScore >= 80 ? 'A' : ($healthScore >= 70 ? 'B' : ($healthScore >= 60 ? 'C' : 'F')));
    
    logMessage("OVERALL PLATFORM HEALTH: {$healthScore}/100 (Grade: $grade)", $logFile);
    
    if ($healthScore >= 80) {
        logMessage("Status: ✅ PRODUCTION READY", $logFile);
    } elseif ($healthScore >= 60) {
        logMessage("Status: ⚠️ NEEDS OPTIMIZATION", $logFile);
    } else {
        logMessage("Status: 🔴 REQUIRES IMMEDIATE ATTENTION", $logFile);
    }

    logMessage("\n=== AUDIT COMPLETE ===", $logFile);
    logMessage("Report saved to: $logFile", $logFile);

} catch (Exception $e) {
    logMessage("ERROR: " . $e->getMessage(), $logFile);
    logMessage("Stack trace: " . $e->getTraceAsString(), $logFile);
}
