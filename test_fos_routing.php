#!/usr/bin/env php
<?php
/**
 * Test FOS Routing and SPA loading
 */

$baseUrl = 'https://pim.technostationery.com';

echo "=== FOS Routing & SPA Test ===\n\n";

// First, login to get session
$ch = curl_init();

// Get login page
curl_setopt_array($ch, [
    CURLOPT_URL => $baseUrl . '/user/login',
    CURLOPT_RETURNTRANSFER => true,
    CURLOPT_FOLLOWLOCATION => true,
    CURLOPT_SSL_VERIFYPEER => false,
    CURLOPT_COOKIEJAR => '/tmp/pim_test2.txt',
    CURLOPT_COOKIEFILE => '/tmp/pim_test2.txt',
]);
$response = curl_exec($ch);
preg_match('/name="_csrf_token"\s+value="([^"]+)"/', $response, $matches);
$csrfToken = $matches[1] ?? '';

// Submit login
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

// Follow redirect to /
curl_setopt_array($ch, [
    CURLOPT_URL => $baseUrl . '/',
    CURLOPT_POST => false,
    CURLOPT_HTTPGET => true,
]);
$spaShell = curl_exec($ch);

echo "1. SPA Shell Analysis:\n";
echo "   Total Size: " . strlen($spaShell) . " bytes\n\n";

// Extract the full HTML
$dom = new DOMDocument();
@$dom->loadHTML($spaShell);

echo "2. Script tags found:\n";
$scripts = $dom->getElementsByTagName('script');
foreach ($scripts as $script) {
    if ($script->hasAttribute('src')) {
        $src = $script->getAttribute('src');
        echo "   - $src\n";
    }
}

echo "\n3. Testing FOS Routing endpoint:\n";
curl_setopt_array($ch, [
    CURLOPT_URL => $baseUrl . '/js/routing.js?callback=fos.Router.setData',
    CURLOPT_POST => false,
    CURLOPT_HTTPGET => true,
    CURLOPT_HEADER => true,
]);
$fosResponse = curl_exec($ch);
$fosHttpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
$fosHeaderSize = curl_getinfo($ch, CURLINFO_HEADER_SIZE);
$fosHeaders = substr($fosResponse, 0, $fosHeaderSize);
$fosBody = substr($fosResponse, $fosHeaderSize);

echo "   HTTP Code: $fosHttpCode\n";
echo "   Response Size: " . strlen($fosBody) . " bytes\n";

if ($fosHttpCode == 200) {
    echo "   Content-Type: ";
    if (preg_match('/Content-Type:\s*([^\s]+)/', $fosHeaders, $m)) {
        echo $m[1] . "\n";
    }
    echo "   First 100 chars: " . substr($fosBody, 0, 100) . "\n";
}

echo "\n4. Testing main.min.js:\n";
curl_setopt_array($ch, [
    CURLOPT_URL => $baseUrl . '/dist/main.min.js',
    CURLOPT_POST => false,
    CURLOPT_HTTPGET => true,
    CURLOPT_HEADER => true,
]);
$mainResponse = curl_exec($ch);
$mainHttpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
$mainHeaderSize = curl_getinfo($ch, CURLINFO_HEADER_SIZE);
$mainBody = substr($mainResponse, $mainHeaderSize);

echo "   HTTP Code: $mainHttpCode\n";
echo "   Response Size: " . strlen($mainBody) . " bytes\n";

echo "\n5. Testing vendor.min.js:\n";
curl_setopt_array($ch, [
    CURLOPT_URL => $baseUrl . '/dist/vendor.min.js',
    CURLOPT_POST => false,
    CURLOPT_HTTPGET => true,
    CURLOPT_HEADER => true,
]);
$vendorResponse = curl_exec($ch);
$vendorHttpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
$vendorHeaderSize = curl_getinfo($ch, CURLINFO_HEADER_SIZE);
$vendorBody = substr($vendorResponse, $vendorHeaderSize);

echo "   HTTP Code: $vendorHttpCode\n";
echo "   Response Size: " . strlen($vendorBody) . " bytes\n";

curl_close($ch);

echo "\n=== Test Complete ===\n";
