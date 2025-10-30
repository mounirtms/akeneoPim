<?php

echo "<h1>PHP Configuration Test</h1>";

// Test 1: Check PHP version
echo "<h2>PHP Version</h2>";
echo "<p>PHP Version: " . phpversion() . "</p>";

// Test 2: Check if required extensions are loaded
echo "<h2>Required Extensions</h2>";
$requiredExtensions = ['pdo', 'pdo_mysql', 'mysqli', 'curl', 'gd', 'intl', 'json', 'mbstring', 'openssl', 'zip'];
foreach ($requiredExtensions as $ext) {
    if (extension_loaded($ext)) {
        echo "<p style='color: green;'>✓ $ext: Loaded</p>";
    } else {
        echo "<p style='color: red;'>✗ $ext: Not loaded</p>";
    }
}

// Test 3: Check file permissions
echo "<h2>File Permissions</h2>";
$filesToCheck = [
    '../vendor/autoload_runtime.php',
    '../.env',
    'index.php'
];

foreach ($filesToCheck as $file) {
    $fullPath = __DIR__ . '/' . $file;
    if (file_exists($fullPath)) {
        $perms = fileperms($fullPath);
        $readable = is_readable($fullPath) ? 'Readable' : 'Not readable';
        $writable = is_writable($fullPath) ? 'Writable' : 'Not writable';
        echo "<p style='color: green;'>✓ $file: $readable, $writable</p>";
    } else {
        echo "<p style='color: red;'>✗ $file: Not found</p>";
    }
}

// Test 4: Check directory permissions
echo "<h2>Directory Permissions</h2>";
$dirsToCheck = ['../var', '../vendor', '.'];

foreach ($dirsToCheck as $dir) {
    $fullPath = __DIR__ . '/' . $dir;
    if (is_dir($fullPath)) {
        $readable = is_readable($fullPath) ? 'Readable' : 'Not readable';
        $writable = is_writable($fullPath) ? 'Writable' : 'Not writable';
        echo "<p style='color: green;'>✓ $dir: $readable, $writable</p>";
    } else {
        echo "<p style='color: red;'>✗ $dir: Not found</p>";
    }
}

echo "<h2>Environment Variables</h2>";
echo "<p>APP_ENV: " . ($_SERVER['APP_ENV'] ?? 'Not set') . "</p>";
echo "<p>APP_DEBUG: " . ($_SERVER['APP_DEBUG'] ?? 'Not set') . "</p>";

echo "<h2>Database Configuration</h2>";
$envFile = file_get_contents(__DIR__ . '/../.env');
if (preg_match('/DATABASE_URL=(.*)/', $envFile, $matches)) {
    echo "<p>Database URL found: " . substr($matches[1], 0, 50) . "...</p>";
} else {
    echo "<p style='color: red;'>✗ Database URL not found in .env file</p>";
}