<?php
/**
 * Comprehensive Fix Script - Apply all optimizations and fixes
 */

echo "================================================================================\n";
echo "COMPREHENSIVE FIX SCRIPT - Akeneo PIM 6.0\n";
echo "================================================================================\n\n";

// 1. Clear OPcache
echo "📍 Step 1: Clearing OPcache...\n";
if (function_exists('opcache_reset')) {
    opcache_reset();
    echo "✓ OPcache cleared\n\n";
} else {
    echo "⚠️  OPcache not available\n\n";
}

// 2. Clear Symfony cache
echo "📍 Step 2: Clearing Symfony cache...\n";
$cacheDir = __DIR__ . '/var/cache';
$dirs = ['prod', 'dev'];
foreach ($dirs as $env) {
    $path = $cacheDir . '/' . $env;
    if (is_dir($path)) {
        system("rm -rf $path/*");
        echo "✓ Cleared cache for environment: $env\n";
    }
}
echo "\n";

// 3. Verify extensions.json
echo "📍 Step 3: Verifying extensions.json...\n";
$extensionsFile = __DIR__ . '/public/js/extensions.json';
if (file_exists($extensionsFile)) {
    $data = json_decode(file_get_contents($extensionsFile), true);
    if ($data && isset($data['extensions'])) {
        echo "✓ extensions.json loaded: " . count($data['extensions']) . " extensions\n";
        echo "✓ pim-app extension: " . (isset($data['extensions']['pim-app']) ? 'EXISTS' : 'MISSING') . "\n";
    }
} else {
    echo "⚠️  extensions.json not found\n";
}
echo "\n";

// 4. Check database connection
echo "📍 Step 4: Checking database connection...\n";
$dbConfig = [
    'host' => getenv('APP_DATABASE_HOST') ?: '127.0.0.1',
    'port' => getenv('APP_DATABASE_PORT') ?: '3307',
    'name' => getenv('APP_DATABASE_NAME') ?: 'akeneo_pim',
    'user' => getenv('APP_DATABASE_USER') ?: 'akeneo_pim',
    'pass' => getenv('APP_DATABASE_PASSWORD') ?: 'akeneo_pim'
];

try {
    $dsn = "mysql:host={$dbConfig['host']};port={$dbConfig['port']};dbname={$dbConfig['name']}";
    $pdo = new PDO($dsn, $dbConfig['user'], $dbConfig['pass']);
    echo "✓ Database connection successful\n";
    
    // Check for admin user
    $stmt = $pdo->query("SELECT username, email, enabled FROM oro_user WHERE username='admin' LIMIT 1");
    $admin = $stmt->fetch(PDO::FETCH_ASSOC);
    if ($admin) {
        echo "✓ Admin user found: {$admin['username']} ({$admin['email']})\n";
        echo "  Enabled: " . ($admin['enabled'] ? 'YES' : 'NO') . "\n";
    } else {
        echo "⚠️  Admin user not found\n";
    }
} catch (PDOException $e) {
    echo "❌ Database error: " . $e->getMessage() . "\n";
}
echo "\n";

// 5. Generate cache warmup
echo "📍 Step 5: Warming up cache...\n";
system("cd " . __DIR__ . " && php bin/console cache:warmup --env=prod 2>&1 | head -5");
echo "\n";

echo "================================================================================\n";
echo "FIX SCRIPT COMPLETE\n";
echo "================================================================================\n";
