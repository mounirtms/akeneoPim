#!/usr/bin/env php
<?php
/**
 * Test to check if the SPA actually loads and initializes properly
 */

$baseUrl = 'https://pim.technostationery.com';

// Login first
$ch = curl_init();
curl_setopt_array($ch, [
    CURLOPT_URL => $baseUrl . '/user/login',
    CURLOPT_RETURNTRANSFER => true,
    CURLOPT_FOLLOWLOCATION => true,
    CURLOPT_SSL_VERIFYPEER => false,
    CURLOPT_COOKIEJAR => '/tmp/pim_test_final.txt',
    CURLOPT_COOKIEFILE => '/tmp/pim_test_final.txt',
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

// Access the root path
curl_setopt_array($ch, [
    CURLOPT_URL => $baseUrl . '/',
    CURLOPT_POST => false,
    CURLOPT_HTTPGET => true,
]);
$spaShell = curl_exec($ch);

echo "=== SPA Shell Full Analysis ===\n\n";

echo "Complete HTML output (length: " . strlen($spaShell) . "):\n";
echo str_repeat('-', 80) . "\n";
echo $spaShell;
echo "\n" . str_repeat('-', 80) . "\n";

// Check if it's actually the Twig template or something else
if (strpos($spaShell, 'oro_config_value') !== false) {
    echo "\n✓ Twig template is being processed (oro_config_value found)\n";
} else {
    echo "\n✗ Twig template may not be rendering properly\n";
}

if (strpos($spaShell, '{{') !== false || strpos($spaShell, '}}') !== false) {
    echo "✗ UNRENDERED Twig syntax found!\n";
} else {
    echo "✓ All Twig syntax has been rendered\n";
}

curl_close($ch);
