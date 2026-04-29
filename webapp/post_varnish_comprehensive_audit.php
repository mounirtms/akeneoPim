<?php
/**
 * Comprehensive Post-Varnish Stability Audit
 * Date: 2026-04-29
 * Purpose: Analyze platform stability after Varnish implementation
 */

date_default_timezone_set('UTC');
echo "=== COMPREHENSIVE POST-VARNISH AUDIT ===\n";
echo "Date: " . date('Y-m-d H:i:s') . "\n";
echo "Server Time: " . shell_exec('date') . "\n";
echo str_repeat("=", 80) . "\n\n";

// Database connections
$akeneo_db = new mysqli('127.0.0.1', 'root', 'YourNewStrongPassword', 'akeneo_pim', 3307);
$magento_db = new mysqli('127.0.0.1', 'root', 'YourNewStrongPassword', 'beta_dBT8x12y22', 3307);

if ($akeneo_db->connect_error || $magento_db->connect_error) {
    die("Database connection failed!\n");
}

// 1. SYSTEM HEALTH OVERVIEW
echo "📊 1. SYSTEM HEALTH OVERVIEW\n";
echo str_repeat("-", 80) . "\n";

$uptime = shell_exec('uptime');
echo "System Uptime: " . trim($uptime) . "\n";

$load = sys_getloadavg();
echo "Load Average: " . implode(", ", $load) . "\n";

$disk_free = shell_exec("df -h /home | tail -1 | awk '{print $4}'");
echo "Disk Free: " . trim($disk_free) . "\n";

$memory = shell_exec("free -h | grep Mem | awk '{print $3\"/\"$2}'");
echo "Memory Usage: " . trim($memory) . "\n\n";

// 2. AKENEO DATABASE HEALTH
echo "🗄️  2. AKENEO DATABASE HEALTH\n";
echo str_repeat("-", 80) . "\n";

$result = $akeneo_db->query("SELECT 
    (SELECT COUNT(*) FROM pim_catalog_product WHERE is_enabled = 1) as products,
    (SELECT COUNT(*) FROM pim_catalog_attribute) as attributes,
    (SELECT COUNT(*) FROM pim_catalog_family) as families,
    (SELECT COUNT(*) FROM pim_catalog_channel) as channels,
    (SELECT COUNT(DISTINCT product_id) FROM pim_catalog_completeness) as completeness_tracked");
$health = $result->fetch_assoc();

foreach ($health as $key => $value) {
    echo "  " . str_pad(ucwords(str_replace('_', ' ', $key)) . ":", 30) . number_format($value) . "\n";
}

// Data quality
$result = $akeneo_db->query("SELECT 
    COUNT(*) as total,
    SUM(CASE WHEN JSON_EXTRACT(raw_values, '$.price') IS NOT NULL THEN 1 ELSE 0 END) as with_price,
    SUM(CASE WHEN JSON_EXTRACT(raw_values, '$.weight') IS NOT NULL THEN 1 ELSE 0 END) as with_weight,
    SUM(CASE WHEN JSON_EXTRACT(raw_values, '$.image') IS NOT NULL THEN 1 ELSE 0 END) as with_image
    FROM pim_catalog_product WHERE is_enabled = 1");
$quality = $result->fetch_assoc();

echo "\nData Quality:\n";
echo "  Price Coverage:  " . $quality['with_price'] . "/" . $quality['total'] . 
     " (" . round($quality['with_price']/$quality['total']*100, 1) . "%)\n";
echo "  Weight Coverage: " . $quality['with_weight'] . "/" . $quality['total'] . 
     " (" . round($quality['with_weight']/$quality['total']*100, 1) . "%)\n";
echo "  Image Coverage:  " . $quality['with_image'] . "/" . $quality['total'] . 
     " (" . round($quality['with_image']/$quality['total']*100, 1) . "%)\n\n";

// 3. MAGENTO DATABASE HEALTH
echo "🛒 3. MAGENTO DATABASE HEALTH\n";
echo str_repeat("-", 80) . "\n";

$result = $magento_db->query("SELECT COUNT(*) as count FROM catalog_product_entity");
$mag_products = $result->fetch_assoc()['count'];

$result = $magento_db->query("SELECT COUNT(*) as count FROM catalog_category_product");
$mag_cat_products = $result->fetch_assoc()['count'];

$result = $magento_db->query("SELECT COUNT(*) as count FROM cataloginventory_stock_item WHERE qty > 0");
$mag_stock = $result->fetch_assoc()['count'];

echo "  Total Products: " . number_format($mag_products) . "\n";
echo "  Product-Category Relations: " . number_format($mag_cat_products) . "\n";
echo "  Products with Stock: " . number_format($mag_stock) . "\n";
echo "  Sync Status: " . ($mag_products == $health['products'] ? "✅ Perfect" : "⚠️  Mismatch") . "\n\n";

// 4. PRODUCTION LOG ANALYSIS
echo "📋 4. PRODUCTION LOG ANALYSIS (Last 24 Hours)\n";
echo str_repeat("-", 80) . "\n";

$log_file = '/home/pim/public_html/var/logs/prod.log';
$errors = shell_exec("tail -1000 $log_file | grep -c ERROR");
$critical = shell_exec("tail -1000 $log_file | grep -c CRITICAL");
$warnings = shell_exec("tail -1000 $log_file | grep -c WARNING");

echo "  ERROR entries: " . trim($errors) . "\n";
echo "  CRITICAL entries: " . trim($critical) . "\n";
echo "  WARNING entries: " . trim($warnings) . "\n";

// Recent error types
echo "\nRecent Error Types:\n";
$recent_errors = shell_exec("tail -100 $log_file | grep ERROR | cut -d':' -f3 | sort | uniq -c | sort -rn | head -5");
echo $recent_errors;
echo "\n";

// 5. VARNISH CACHE STATUS
echo "🚀 5. VARNISH CACHE STATUS\n";
echo str_repeat("-", 80) . "\n";

$varnish_status = shell_exec("systemctl is-active varnish 2>/dev/null || echo 'not_installed'");
echo "  Varnish Service: " . trim($varnish_status) . "\n";

if (trim($varnish_status) == 'active') {
    $varnish_stats = shell_exec("varnishstat -1 2>/dev/null | grep -E '(cache_hit|cache_miss)' | head -5");
    if ($varnish_stats) {
        echo "\nCache Statistics:\n" . $varnish_stats;
    }
}
echo "\n";

// 6. WEB SERVER STATUS
echo "🌐 6. WEB SERVER STATUS\n";
echo str_repeat("-", 80) . "\n";

$nginx_status = shell_exec("systemctl is-active nginx 2>/dev/null || echo 'not_running'");
$apache_status = shell_exec("systemctl is-active httpd 2>/dev/null || systemctl is-active apache2 2>/dev/null || echo 'not_running'");

echo "  Nginx: " . trim($nginx_status) . "\n";
echo "  Apache: " . trim($apache_status) . "\n";

// Check for listening ports
$ports = shell_exec("netstat -tuln | grep -E ':(80|443|3000|6081|8080)' | awk '{print $4}' | cut -d: -f2 | sort -u");
echo "\nListening Ports:\n" . $ports;
echo "\n";

// 7. PHP-FPM STATUS
echo "🐘 7. PHP-FPM STATUS\n";
echo str_repeat("-", 80) . "\n";

$php_version = shell_exec("php -v | head -1");
echo "  PHP Version: " . trim($php_version) . "\n";

$fpm_status = shell_exec("systemctl is-active php-fpm 2>/dev/null || systemctl is-active php*-fpm 2>/dev/null | head -1");
echo "  PHP-FPM Service: " . trim($fpm_status ?: 'not_found') . "\n";

$fpm_pools = shell_exec("ps aux | grep '[p]hp-fpm: pool' | wc -l");
echo "  Active PHP-FPM Pools: " . trim($fpm_pools) . "\n\n";

// 8. CACHE SYSTEM STATUS
echo "💾 8. CACHE SYSTEM STATUS\n";
echo str_repeat("-", 80) . "\n";

$akeneo_cache_dir = '/home/pim/public_html/var/cache';
$cache_size = shell_exec("du -sh $akeneo_cache_dir 2>/dev/null | cut -f1");
echo "  Akeneo Cache Size: " . trim($cache_size ?: 'N/A') . "\n";

$cache_mtime = shell_exec("stat -c %y $akeneo_cache_dir/prod 2>/dev/null | cut -d' ' -f1");
echo "  Last Cache Clear: " . trim($cache_mtime ?: 'Unknown') . "\n\n";

// 9. ELASTICSEARCH STATUS
echo "🔍 9. ELASTICSEARCH STATUS\n";
echo str_repeat("-", 80) . "\n";

$es_status = shell_exec("systemctl is-active elasticsearch 2>/dev/null || echo 'not_installed'");
echo "  Elasticsearch Service: " . trim($es_status) . "\n";

if (trim($es_status) == 'active') {
    $es_health = shell_exec("curl -s http://localhost:9200/_cluster/health 2>/dev/null | jq -r '.status' 2>/dev/null || echo 'unknown'");
    echo "  Cluster Health: " . trim($es_health) . "\n";
}
echo "\n";

// 10. COMPLETENESS STATUS
echo "✅ 10. COMPLETENESS STATUS\n";
echo str_repeat("-", 80) . "\n";

$result = $akeneo_db->query("SELECT 
    ch.code as channel,
    l.code as locale,
    COUNT(DISTINCT c.product_id) as products,
    ROUND(AVG(c.required_count), 2) as avg_required,
    ROUND(AVG(c.missing_count), 2) as avg_missing,
    SUM(CASE WHEN c.missing_count = 0 THEN 1 ELSE 0 END) as complete
    FROM pim_catalog_completeness c
    JOIN pim_catalog_channel ch ON c.channel_id = ch.id
    JOIN pim_catalog_locale l ON c.locale_id = l.id
    GROUP BY ch.code, l.code
    ORDER BY ch.code, l.code");

while ($row = $result->fetch_assoc()) {
    $pct = $row['products'] > 0 ? round($row['complete']/$row['products']*100, 1) : 0;
    echo "  " . strtoupper($row['channel']) . " (" . $row['locale'] . "): ";
    echo $pct . "% complete (" . $row['complete'] . "/" . $row['products'] . ") ";
    echo "| Avg missing: " . $row['avg_missing'] . "\n";
}
echo "\n";

// 11. RECENT CHANGES (Git)
echo "📝 11. RECENT CHANGES (Last 2 Days)\n";
echo str_repeat("-", 80) . "\n";

$git_log = shell_exec("cd /home/pim/public_html/webapp && git log --since='2 days ago' --oneline | head -10");
if ($git_log) {
    echo $git_log;
} else {
    echo "  No recent commits\n";
}
echo "\n";

// 12. FILE PERMISSIONS
echo "🔐 12. CRITICAL FILE PERMISSIONS\n";
echo str_repeat("-", 80) . "\n";

$critical_dirs = [
    '/home/pim/public_html/var/cache' => 'Cache directory',
    '/home/pim/public_html/var/logs' => 'Logs directory',
    '/home/pim/public_html/public/media' => 'Media directory'
];

foreach ($critical_dirs as $dir => $desc) {
    if (file_exists($dir)) {
        $perms = substr(sprintf('%o', fileperms($dir)), -4);
        $owner = posix_getpwuid(fileowner($dir))['name'];
        echo "  $desc: $perms ($owner)\n";
    } else {
        echo "  $desc: ⚠️  Not found\n";
    }
}
echo "\n";

// 13. MISSING ISSUES DETECTION
echo "🔍 13. MISSING ISSUES DETECTION\n";
echo str_repeat("-", 80) . "\n";

$issues = [];

// Check favicon
if (!file_exists('/home/pim/public_html/public/favicon.ico')) {
    $issues[] = "Missing favicon.ico file";
}

// Check translation files
$trans_dir = '/home/pim/public_html/public/js/translation';
if (!is_dir($trans_dir)) {
    $issues[] = "Translation directory missing";
}

// Check for 404 errors in logs
$favicon_404s = (int)shell_exec("tail -100 $log_file | grep -c 'favicon.ico'");
if ($favicon_404s > 0) {
    $issues[] = "Favicon 404 errors: $favicon_404s occurrences";
}

$translation_404s = (int)shell_exec("tail -100 $log_file | grep -c 'translation.*404'");
if ($translation_404s > 0) {
    $issues[] = "Translation file 404 errors: $translation_404s occurrences";
}

// Check database connections
$result = $akeneo_db->query("SHOW STATUS LIKE 'Threads_connected'");
$threads = $result->fetch_assoc()['Value'];
if ($threads > 50) {
    $issues[] = "High database connections: $threads active";
}

if (empty($issues)) {
    echo "  ✅ No critical issues detected\n";
} else {
    foreach ($issues as $issue) {
        echo "  ⚠️  $issue\n";
    }
}
echo "\n";

// 14. PERFORMANCE METRICS
echo "⚡ 14. PERFORMANCE METRICS\n";
echo str_repeat("-", 80) . "\n";

// Database query performance
$result = $akeneo_db->query("SHOW GLOBAL STATUS LIKE 'Questions'");
$questions = (int)$result->fetch_assoc()['Value'];

$result = $akeneo_db->query("SHOW GLOBAL STATUS LIKE 'Uptime'");
$db_uptime = (int)$result->fetch_assoc()['Value'];

if ($db_uptime > 0) {
    $qps = round($questions / $db_uptime, 2);
    echo "  Database Queries per Second: $qps\n";
}

// Slow query log
$slow_queries = shell_exec("grep -c 'Query_time' /var/log/mysql/slow.log 2>/dev/null || echo 0");
echo "  Slow Queries (last run): " . trim($slow_queries) . "\n\n";

// 15. RECOMMENDATIONS
echo "💡 15. RECOMMENDATIONS\n";
echo str_repeat("-", 80) . "\n";

$recommendations = [];

if ($favicon_404s > 0) {
    $recommendations[] = "P2: Add favicon.ico to public directory";
}

if ($translation_404s > 0) {
    $recommendations[] = "P2: Fix translation file routing";
}

if ($quality['with_image'] < $quality['total'] * 0.95) {
    $missing_images = $quality['total'] - $quality['with_image'];
    $recommendations[] = "P1: Add images for $missing_images products";
}

if ($quality['with_weight'] < $quality['total'] * 0.95) {
    $missing_weight = $quality['total'] - $quality['with_weight'];
    $recommendations[] = "P1: Add weight for $missing_weight products";
}

if ($threads > 30) {
    $recommendations[] = "P2: Monitor database connection pool";
}

$load_avg = $load[0];
if ($load_avg > 10) {
    $recommendations[] = "P1: High system load detected: $load_avg";
}

if (empty($recommendations)) {
    echo "  ✅ No immediate actions required\n";
} else {
    foreach ($recommendations as $i => $rec) {
        echo "  " . ($i + 1) . ". $rec\n";
    }
}

echo "\n" . str_repeat("=", 80) . "\n";
echo "Audit completed at " . date('Y-m-d H:i:s') . "\n";
echo "Report saved to: logs/post_varnish_audit_" . date('Ymd_His') . ".log\n";

$akeneo_db->close();
$magento_db->close();
