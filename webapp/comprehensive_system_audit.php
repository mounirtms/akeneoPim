<?php
/**
 * Comprehensive System Audit - Post Emergency Fixes
 * Date: 2026-04-27
 * Audits all aspects: frontend, backend, data, integration, performance
 */

echo "═══════════════════════════════════════════════════════════════\n";
echo "   COMPREHENSIVE SYSTEM AUDIT - Akeneo PIM Production\n";
echo "   Date: " . date('Y-m-d H:i:s') . "\n";
echo "═══════════════════════════════════════════════════════════════\n\n";

$results = [];
$issues = [];
$recommendations = [];

// ============================================================
// SECTION 1: FRONTEND & ASSETS
// ============================================================
echo "┌─────────────────────────────────────────────────────────────┐\n";
echo "│ 1. FRONTEND & ASSETS AUDIT                                 │\n";
echo "└─────────────────────────────────────────────────────────────┘\n\n";

// 1.1 Cache Buster Version
$templateFile = __DIR__ . '/../vendor/akeneo/pim-community-dev/src/Akeneo/Platform/Bundle/UIBundle/Resources/views/index.html.twig';
$template = file_get_contents($templateFile);
preg_match('/{% set cache_buster = "([^"]*)" %}/', $template, $matches);
$cacheBuster = $matches[1] ?? 'NOT FOUND';
echo "Cache Buster Version: $cacheBuster\n";
$results['cache_buster'] = $cacheBuster;

// 1.2 require-paths.js
$requirePaths = __DIR__ . '/../public/js/require-paths.js';
if (file_exists($requirePaths)) {
    $size = filesize($requirePaths);
    $content = file_get_contents($requirePaths);
    $hasModuleExports = strpos($content, 'module.exports') !== false;
    $hasRequireConfig = strpos($content, 'require.config') !== false;
    
    echo "require-paths.js:\n";
    echo "  - Size: $size bytes\n";
    echo "  - Format: " . ($hasRequireConfig ? '✅ RequireJS' : '❌ Invalid') . "\n";
    echo "  - Node.js syntax: " . ($hasModuleExports ? '❌ Present (BAD)' : '✅ Clean') . "\n";
    
    $results['require_paths'] = [
        'size' => $size,
        'format' => $hasRequireConfig ? 'requirejs' : 'invalid',
        'nodejs_syntax' => $hasModuleExports
    ];
    
    if ($hasModuleExports) {
        $issues[] = "require-paths.js contains Node.js syntax (module.exports)";
        $recommendations[] = "Run: php webapp/fix_require_paths.php";
    }
} else {
    echo "require-paths.js: ❌ NOT FOUND\n";
    $issues[] = "require-paths.js missing";
}

// 1.3 jQuery symlink
$jquerySym = __DIR__ . '/../public/jquery.js';
echo "jQuery symlink: " . (is_link($jquerySym) ? '✅ EXISTS' : '❌ MISSING') . "\n";
$results['jquery_symlink'] = is_link($jquerySym);
if (!is_link($jquerySym)) {
    $issues[] = "jQuery symlink missing";
    $recommendations[] = "Run: ln -sf dist/jquery.min.js public/jquery.js";
}

// 1.4 process-polyfill.js
$processPolyfill = __DIR__ . '/../public/dist/process-polyfill.js';
$polyfillExists = file_exists($processPolyfill);
echo "process-polyfill.js: " . ($polyfillExists ? '✅ EXISTS' : '❌ MISSING') . "\n";
if ($polyfillExists) {
    echo "  - Size: " . filesize($processPolyfill) . " bytes\n";
}
$results['process_polyfill'] = $polyfillExists;

// 1.5 Template includes polyfill
$hasPolyfillInTemplate = strpos($template, 'process-polyfill.js') !== false;
echo "Template loads polyfill: " . ($hasPolyfillInTemplate ? '✅ YES' : '❌ NO') . "\n";
$results['template_polyfill'] = $hasPolyfillInTemplate;
if (!$hasPolyfillInTemplate) {
    $issues[] = "Template doesn't load process-polyfill.js";
    $recommendations[] = "Run: php webapp/update_template_for_polyfills.php";
}

// 1.6 Translation files
$transDir = __DIR__ . '/../public/js/translation/';
$transFiles = glob($transDir . '*.js');
$transCount = count($transFiles);
echo "Translation files: $transCount\n";
$enUsExists = file_exists($transDir . 'en_US.js');
echo "  - en_US.js: " . ($enUsExists ? '✅ EXISTS' : '❌ MISSING') . "\n";
$results['translations'] = $transCount;

// 1.7 .htaccess cache headers
$htaccess = __DIR__ . '/../public/.htaccess';
$htContent = file_get_contents($htaccess);
$hasCacheHeaders = strpos($htContent, 'CACHE CONTROL HEADERS') !== false;
echo ".htaccess cache headers: " . ($hasCacheHeaders ? '✅ CONFIGURED' : '❌ MISSING') . "\n";
$results['htaccess_headers'] = $hasCacheHeaders;

echo "\n";

// ============================================================
// SECTION 2: DATABASE & DATA
// ============================================================
echo "┌─────────────────────────────────────────────────────────────┐\n";
echo "│ 2. DATABASE & DATA AUDIT                                   │\n";
echo "└─────────────────────────────────────────────────────────────┘\n\n";

try {
    $pdo = new PDO('mysql:host=127.0.0.1;port=3307;dbname=akeneo_pim', 'akeneo_pim', 'akeneo_pim');
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    echo "Database Connection: ✅ OK\n\n";
    
    // 2.1 Products
    $productCount = $pdo->query('SELECT COUNT(*) FROM pim_catalog_product')->fetchColumn();
    echo "Products: $productCount\n";
    $results['products'] = $productCount;
    
    $enabledCount = $pdo->query("SELECT COUNT(*) FROM pim_catalog_product WHERE is_enabled = 1")->fetchColumn();
    echo "  - Enabled: $enabledCount (" . round($enabledCount/$productCount*100, 1) . "%)\n";
    
    // 2.2 Categories
    $categoryCount = $pdo->query('SELECT COUNT(*) FROM pim_catalog_category')->fetchColumn();
    echo "Categories: $categoryCount\n";
    $results['categories'] = $categoryCount;
    
    if ($categoryCount != 166) {
        $issues[] = "Category count mismatch (expected 166, got $categoryCount)";
    }
    
    // 2.3 Attributes
    $attributeCount = $pdo->query('SELECT COUNT(*) FROM pim_catalog_attribute')->fetchColumn();
    echo "Attributes: $attributeCount\n";
    $results['attributes'] = $attributeCount;
    
    // Attribute types
    $attrTypes = $pdo->query('SELECT type, COUNT(*) as cnt FROM pim_catalog_attribute GROUP BY type ORDER BY cnt DESC')->fetchAll(PDO::FETCH_ASSOC);
    echo "  - Types:\n";
    foreach ($attrTypes as $type) {
        echo "    • {$type['type']}: {$type['cnt']}\n";
    }
    
    // 2.4 Attribute Groups
    $groupCount = $pdo->query('SELECT COUNT(*) FROM pim_catalog_attribute_group')->fetchColumn();
    echo "Attribute Groups: $groupCount\n";
    $results['attribute_groups'] = $groupCount;
    
    // Check general group size
    $generalGroup = $pdo->query("SELECT ag.code, COUNT(a.id) as attr_count 
                                  FROM pim_catalog_attribute_group ag
                                  LEFT JOIN pim_catalog_attribute a ON a.group_id = ag.id
                                  WHERE ag.code = 'general'
                                  GROUP BY ag.id")->fetch(PDO::FETCH_ASSOC);
    
    if ($generalGroup && $generalGroup['attr_count'] > 50) {
        echo "  - ⚠️  General group has {$generalGroup['attr_count']} attributes (too many)\n";
        $issues[] = "General attribute group is overloaded ({$generalGroup['attr_count']} attributes)";
        $recommendations[] = "Reorganize attributes into specific groups";
    }
    
    // 2.5 Families
    $familyCount = $pdo->query('SELECT COUNT(*) FROM pim_catalog_family')->fetchColumn();
    echo "Families: $familyCount\n";
    $results['families'] = $familyCount;
    
    // 2.6 Channels
    $channelCount = $pdo->query('SELECT COUNT(*) FROM pim_catalog_channel')->fetchColumn();
    echo "Channels: $channelCount\n";
    $results['channels'] = $channelCount;
    
    // List channels
    $channels = $pdo->query('SELECT code, label FROM pim_catalog_channel')->fetchAll(PDO::FETCH_ASSOC);
    echo "  - Configured:\n";
    foreach ($channels as $ch) {
        echo "    • {$ch['code']}: {$ch['label']}\n";
    }
    
    // 2.7 Locales
    $localeCount = $pdo->query('SELECT COUNT(*) FROM pim_catalog_locale WHERE is_activated = 1')->fetchColumn();
    echo "Active Locales: $localeCount\n";
    $results['locales'] = $localeCount;
    
} catch (PDOException $e) {
    echo "Database Connection: ❌ FAILED\n";
    echo "Error: " . $e->getMessage() . "\n";
    $issues[] = "Database connection failed: " . $e->getMessage();
}

echo "\n";

// ============================================================
// SECTION 3: ELASTICSEARCH
// ============================================================
echo "┌─────────────────────────────────────────────────────────────┐\n";
echo "│ 3. ELASTICSEARCH AUDIT                                     │\n";
echo "└─────────────────────────────────────────────────────────────┘\n\n";

$esHealth = @file_get_contents('http://127.0.0.1:9200/_cluster/health');
if ($esHealth) {
    $health = json_decode($esHealth, true);
    echo "Cluster Status: " . strtoupper($health['status']) . "\n";
    echo "Nodes: {$health['number_of_nodes']}\n";
    echo "Active Shards: {$health['active_shards']}\n";
    $results['elasticsearch'] = $health;
    
    // Check product index
    $productCount = @file_get_contents('http://127.0.0.1:9200/akeneo_pim_product/_count');
    if ($productCount) {
        $count = json_decode($productCount, true);
        echo "Indexed Products: {$count['count']}\n";
        $results['es_products'] = $count['count'];
        
        if (isset($results['products']) && $count['count'] != $results['products']) {
            $diff = abs($count['count'] - $results['products']);
            echo "  - ⚠️  Mismatch with database: $diff products difference\n";
            $issues[] = "Elasticsearch index out of sync (ES: {$count['count']}, DB: {$results['products']})";
            $recommendations[] = "Run: php bin/console akeneo:elasticsearch:reset-indexes --env=prod";
        }
    }
} else {
    echo "Elasticsearch: ❌ NOT REACHABLE\n";
    $issues[] = "Elasticsearch not reachable at 127.0.0.1:9200";
    $recommendations[] = "Check if Elasticsearch service is running";
}

echo "\n";

// ============================================================
// SECTION 4: MAGENTO INTEGRATION
// ============================================================
echo "┌─────────────────────────────────────────────────────────────┐\n";
echo "│ 4. MAGENTO INTEGRATION AUDIT                               │\n";
echo "└─────────────────────────────────────────────────────────────┘\n\n";

// Check if Magento credentials exist
$magentoCredsFile = __DIR__ . '/magento_credentials.txt';
if (file_exists($magentoCredsFile)) {
    echo "Magento Credentials: ✅ CONFIGURED\n";
    
    // Try to ping Magento
    $magentoUrl = 'https://beta.technostationery.com';
    $ch = curl_init($magentoUrl);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_TIMEOUT, 5);
    curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, false);
    $response = curl_exec($ch);
    $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    curl_close($ch);
    
    echo "Magento Site Status: " . ($httpCode == 200 ? '✅ ONLINE' : "⚠️  HTTP $httpCode") . "\n";
    echo "  - URL: $magentoUrl\n";
    $results['magento_status'] = $httpCode;
} else {
    echo "Magento Credentials: ⚠️  NOT FOUND\n";
}

// Check last sync (if log exists)
$syncLogDir = __DIR__ . '/logs/';
$syncLogs = glob($syncLogDir . 'magento_sync_*.log');
if (!empty($syncLogs)) {
    rsort($syncLogs);
    $lastLog = $syncLogs[0];
    $lastModified = filemtime($lastLog);
    $hoursAgo = round((time() - $lastModified) / 3600, 1);
    echo "Last Sync: " . date('Y-m-d H:i:s', $lastModified) . " ($hoursAgo hours ago)\n";
    $results['last_sync'] = date('Y-m-d H:i:s', $lastModified);
    
    if ($hoursAgo > 24) {
        $issues[] = "Magento sync hasn't run in $hoursAgo hours";
        $recommendations[] = "Check sync cron job and run manual sync if needed";
    }
}

echo "\n";

// ============================================================
// SECTION 5: SYSTEM HEALTH
// ============================================================
echo "┌─────────────────────────────────────────────────────────────┐\n";
echo "│ 5. SYSTEM HEALTH & PERFORMANCE                             │\n";
echo "└─────────────────────────────────────────────────────────────┘\n\n";

// 5.1 Cache status
$cacheDir = __DIR__ . '/../var/cache/prod/';
$cacheSize = 0;
if (is_dir($cacheDir)) {
    $output = shell_exec("du -sh $cacheDir 2>/dev/null");
    if ($output) {
        preg_match('/^([^\s]+)/', $output, $matches);
        $cacheSize = $matches[1] ?? '0';
    }
}
echo "Cache Size: $cacheSize\n";
$results['cache_size'] = $cacheSize;

// 5.2 Log files
$logFile = __DIR__ . '/../var/logs/prod.log';
if (file_exists($logFile)) {
    $logSize = filesize($logFile);
    $logSizeMB = round($logSize / 1048576, 2);
    echo "Production Log: {$logSizeMB}MB\n";
    
    // Check for errors in last 100 lines
    $lastLines = shell_exec("tail -100 $logFile 2>/dev/null");
    $errorCount = substr_count($lastLines, '[ERROR]');
    $criticalCount = substr_count($lastLines, '[CRITICAL]');
    
    if ($errorCount > 0 || $criticalCount > 0) {
        echo "  - Recent errors: $errorCount ERROR, $criticalCount CRITICAL\n";
        if ($criticalCount > 0) {
            $issues[] = "$criticalCount CRITICAL errors in recent logs";
        }
    } else {
        echo "  - ✅ No recent errors\n";
    }
}

// 5.3 Disk space
$diskSpace = disk_free_space('/home/pim');
$diskSpaceGB = round($diskSpace / 1073741824, 2);
echo "Free Disk Space: {$diskSpaceGB}GB\n";
$results['disk_space_gb'] = $diskSpaceGB;

if ($diskSpaceGB < 5) {
    $issues[] = "Low disk space: {$diskSpaceGB}GB remaining";
    $recommendations[] = "Clean up old logs and cache files";
}

// 5.4 PHP version
$phpVersion = phpversion();
echo "PHP Version: $phpVersion\n";
$results['php_version'] = $phpVersion;

// 5.5 Memory limit
$memoryLimit = ini_get('memory_limit');
echo "PHP Memory Limit: $memoryLimit\n";
$results['memory_limit'] = $memoryLimit;

echo "\n";

// ============================================================
// SECTION 6: CONFIGURATION
// ============================================================
echo "┌─────────────────────────────────────────────────────────────┐\n";
echo "│ 6. CONFIGURATION AUDIT                                     │\n";
echo "└─────────────────────────────────────────────────────────────┘\n\n";

// 6.1 Environment
$envFile = __DIR__ . '/../.env';
if (file_exists($envFile)) {
    $env = file_get_contents($envFile);
    preg_match('/APP_ENV=(\w+)/', $env, $matches);
    $appEnv = $matches[1] ?? 'unknown';
    
    preg_match('/APP_DEBUG=(\w+)/', $env, $matches);
    $appDebug = $matches[1] ?? 'unknown';
    
    echo "Environment: APP_ENV=$appEnv, APP_DEBUG=$appDebug\n";
    $results['app_env'] = $appEnv;
    $results['app_debug'] = $appDebug;
    
    if ($appEnv != 'prod') {
        $issues[] = "APP_ENV is not 'prod' (currently: $appEnv)";
    }
    if ($appDebug != '0') {
        $issues[] = "APP_DEBUG is enabled (should be 0 in production)";
    }
}

// 6.2 Analytics config
$analyticsConfig = __DIR__ . '/../config/packages/akeneo_analytics.yaml';
if (file_exists($analyticsConfig)) {
    $config = file_get_contents($analyticsConfig);
    $analyticsEnabled = strpos($config, 'is_enabled: false') === false;
    echo "Analytics: " . ($analyticsEnabled ? '⚠️  ENABLED' : '✅ DISABLED') . "\n";
    $results['analytics_enabled'] = $analyticsEnabled;
} else {
    echo "Analytics: ⚠️  CONFIG NOT FOUND\n";
}

echo "\n";

// ============================================================
// SUMMARY
// ============================================================
echo "═══════════════════════════════════════════════════════════════\n";
echo "   AUDIT SUMMARY\n";
echo "═══════════════════════════════════════════════════════════════\n\n";

echo "Total Issues Found: " . count($issues) . "\n";
echo "Recommendations: " . count($recommendations) . "\n\n";

if (!empty($issues)) {
    echo "🔴 ISSUES:\n";
    foreach ($issues as $i => $issue) {
        echo "  " . ($i+1) . ". $issue\n";
    }
    echo "\n";
}

if (!empty($recommendations)) {
    echo "💡 RECOMMENDATIONS:\n";
    foreach ($recommendations as $i => $rec) {
        echo "  " . ($i+1) . ". $rec\n";
    }
    echo "\n";
}

// Overall status
$criticalIssues = 0;
foreach ($issues as $issue) {
    if (stripos($issue, 'critical') !== false || stripos($issue, 'missing') !== false) {
        $criticalIssues++;
    }
}

if ($criticalIssues == 0 && count($issues) == 0) {
    echo "✅ OVERALL STATUS: EXCELLENT - No issues found\n";
    $overallGrade = 'A+';
} elseif ($criticalIssues == 0 && count($issues) <= 3) {
    echo "✅ OVERALL STATUS: GOOD - Minor issues only\n";
    $overallGrade = 'A';
} elseif ($criticalIssues <= 2) {
    echo "⚠️  OVERALL STATUS: FAIR - Some issues need attention\n";
    $overallGrade = 'B';
} else {
    echo "🔴 OVERALL STATUS: POOR - Critical issues need immediate attention\n";
    $overallGrade = 'C';
}

echo "Grade: $overallGrade\n\n";

// Save results to JSON
$auditReport = [
    'date' => date('Y-m-d H:i:s'),
    'grade' => $overallGrade,
    'results' => $results,
    'issues' => $issues,
    'recommendations' => $recommendations
];

$reportFile = __DIR__ . '/logs/system_audit_' . date('Ymd_His') . '.json';
file_put_contents($reportFile, json_encode($auditReport, JSON_PRETTY_PRINT));
echo "📄 Full report saved: $reportFile\n\n";

echo "═══════════════════════════════════════════════════════════════\n";
echo "   Audit Complete\n";
echo "═══════════════════════════════════════════════════════════════\n";

