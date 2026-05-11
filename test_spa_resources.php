#!/usr/bin/env php
<?php
/**
 * Test loading all SPA resources and check for errors
 */

$baseUrl = 'https://pim.technostationery.com';

echo "=== Complete SPA Resource Loading Test ===\n\n";

// Login
$ch = curl_init();
curl_setopt_array($ch, [
    CURLOPT_URL => $baseUrl . '/user/login',
    CURLOPT_RETURNTRANSFER => true,
    CURLOPT_FOLLOWLOCATION => true,
    CURLOPT_SSL_VERIFYPEER => false,
    CURLOPT_COOKIEJAR => '/tmp/pim_resources_test.txt',
    CURLOPT_COOKIEFILE => '/tmp/pim_resources_test.txt',
]);
$response = curl_exec($ch);
preg_match('/name="_csrf_token"\s+value="([^"]+)"/', $response, $matches);
$csrfToken = $matches[1] ?? '';

curl_setopt_array($ch, [
    CURLOPT_URL => $baseUrl . '/user/login-check',
    CURLOPT_POST => true,
    CURLOPT_POSTFIELDS => http_build_query([
        '_username' => 'admin',
        '_password' => 'PimAdmin2026!',
        '_csrf_token' => $csrfToken
    ]),
]);
$response = curl_exec($ch);

// Get SPA shell
curl_setopt_array($ch, [
    CURLOPT_URL => $baseUrl . '/',
    CURLOPT_POST => false,
    CURLOPT_HTTPGET => true,
]);
$spaShell = curl_exec($ch);

// Extract all script sources
preg_match_all('/src="([^"]+)"/', $spaShell, $scriptMatches);
$scripts = $scriptMatches[1];

// Extract CSS sources
preg_match_all('/href="([^"]+)"/', $spaShell, $cssMatches);
$cssFiles = $cssMatches[1];

echo "Testing all resources:\n\n";

$allOk = true;

foreach ($scripts as $script) {
    $url = $baseUrl . $script;
    curl_setopt_array($ch, [
        CURLOPT_URL => $url,
        CURLOPT_POST => false,
        CURLOPT_HTTPGET => true,
        CURLOPT_HEADER => true,
        CURLOPT_FOLLOWLOCATION => true,
    ]);
    $response = curl_exec($ch);
    $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    $size = curl_getinfo($ch, CURLINFO_SIZE_DOWNLOAD);
    
    $status = $httpCode == 200 ? '✓' : '✗';
    echo "$status $script\n";
    echo "  HTTP: $httpCode, Size: " . number_format($size) . " bytes\n";
    
    if ($httpCode != 200) {
        $allOk = false;
    }
}

echo "\nAll resources loaded successfully: " . ($allOk ? 'YES' : 'NO') . "\n";

curl_close($ch);
