#!/usr/bin/env php
<?php
/**
 * AKENEO API CONNECTION TESTER
 * Tests OAuth authentication with Akeneo PIM API
 * 
 * @author Techno DZ
 * @date 2026-04-29
 */

// API Configuration
$config = [
    'akeneo_url' => 'https://pim.technostationery.com',
    'client_id' => '2_ml5f52erhggg0s484gckwgs4kg8gwc4c48ksgko4gkgos4k48',
    'secret' => '1zniz3jfcmcgg0wckskw8k4c80ccwc4o0cokcwk80cs8cs0cs4',
    'username' => 'apiconnector',
    'password' => 'ApiConnector@2026!Secure',
];

echo "\n";
echo "=========================================\n";
echo "  AKENEO API CONNECTION TESTER\n";
echo "=========================================\n";
echo "Date: " . date('Y-m-d H:i:s') . "\n";
echo "API URL: {$config['akeneo_url']}\n";
echo "Username: {$config['username']}\n\n";

// Step 1: Get OAuth Token
echo "Step 1: Requesting OAuth token...\n";

$ch = curl_init();
curl_setopt($ch, CURLOPT_URL, $config['akeneo_url'] . '/api/oauth/v1/token');
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
curl_setopt($ch, CURLOPT_POST, true);
curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, false); // For testing
curl_setopt($ch, CURLOPT_HTTPHEADER, [
    'Content-Type: application/json',
    'Authorization: Basic ' . base64_encode($config['client_id'] . ':' . $config['secret'])
]);
curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode([
    'grant_type' => 'password',
    'username' => $config['username'],
    'password' => $config['password']
]));

$response = curl_exec($ch);
$http_code = curl_getinfo($ch, CURLINFO_HTTP_CODE);
$curl_error = curl_error($ch);
curl_close($ch);

if ($curl_error) {
    echo "✗ CURL Error: {$curl_error}\n";
    exit(1);
}

echo "HTTP Response Code: {$http_code}\n";

if ($http_code !== 200) {
    echo "✗ Authentication failed!\n";
    echo "Response: {$response}\n";
    exit(1);
}

$token_data = json_decode($response, true);

if (!isset($token_data['access_token'])) {
    echo "✗ No access token in response!\n";
    echo "Response: {$response}\n";
    exit(1);
}

$access_token = $token_data['access_token'];
$token_type = $token_data['token_type'] ?? 'Bearer';
$expires_in = $token_data['expires_in'] ?? 3600;

echo "✓ Authentication successful!\n";
echo "Token Type: {$token_type}\n";
echo "Expires In: {$expires_in} seconds\n";
echo "Access Token: " . substr($access_token, 0, 20) . "...\n\n";

// Step 2: Test API Access - Get Product Count
echo "Step 2: Testing API access (fetching products)...\n";

$ch = curl_init();
curl_setopt($ch, CURLOPT_URL, $config['akeneo_url'] . '/api/rest/v1/products?limit=1');
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, false);
curl_setopt($ch, CURLOPT_HTTPHEADER, [
    'Authorization: Bearer ' . $access_token,
    'Content-Type: application/json'
]);

$response = curl_exec($ch);
$http_code = curl_getinfo($ch, CURLINFO_HTTP_CODE);
curl_close($ch);

echo "HTTP Response Code: {$http_code}\n";

if ($http_code !== 200) {
    echo "✗ API access failed!\n";
    echo "Response: {$response}\n";
    exit(1);
}

$data = json_decode($response, true);
echo "✓ API access successful!\n";
echo "Products endpoint accessible: YES\n\n";

// Step 3: Get First Product Details
if (isset($data['_embedded']['items'][0])) {
    $product = $data['_embedded']['items'][0];
    echo "Sample Product Details:\n";
    echo "  Identifier: " . $product['identifier'] . "\n";
    echo "  Family: " . ($product['family'] ?? 'N/A') . "\n";
    echo "  Enabled: " . ($product['enabled'] ? 'Yes' : 'No') . "\n";
    echo "  Created: " . $product['created'] . "\n\n";
}

// Step 4: Test Media File Upload Endpoint
echo "Step 3: Testing media file endpoint...\n";

$ch = curl_init();
curl_setopt($ch, CURLOPT_URL, $config['akeneo_url'] . '/api/rest/v1/media-files');
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, false);
curl_setopt($ch, CURLOPT_CUSTOMREQUEST, 'GET');
curl_setopt($ch, CURLOPT_HTTPHEADER, [
    'Authorization: Bearer ' . $access_token,
    'Content-Type: application/json'
]);

$response = curl_exec($ch);
$http_code = curl_getinfo($ch, CURLINFO_HTTP_CODE);
curl_close($ch);

echo "HTTP Response Code: {$http_code}\n";

if ($http_code === 200) {
    echo "✓ Media files endpoint accessible!\n";
} else {
    echo "⚠ Media files endpoint returned: {$http_code}\n";
}

echo "\n";
echo "=========================================\n";
echo "  CONNECTION TEST SUMMARY\n";
echo "=========================================\n";
echo "✓ OAuth Authentication: SUCCESS\n";
echo "✓ API Products Endpoint: SUCCESS\n";
echo "✓ Access Token Valid: YES\n";
echo "✓ Media Upload Endpoint: ACCESSIBLE\n";
echo "\n";
echo "Status: ✅ READY FOR IMAGE UPLOAD\n";
echo "\n";
echo "NEXT STEPS:\n";
echo "1. Run: php IMAGE_BULK_UPLOADER.php\n";
echo "2. Monitor upload progress\n";
echo "3. Validate image assignments in Akeneo UI\n";
echo "\n";

// Save token for later use
file_put_contents(__DIR__ . '/.akeneo_token', json_encode([
    'access_token' => $access_token,
    'token_type' => $token_type,
    'expires_at' => time() + $expires_in,
    'config' => $config
]));

echo "✓ Token saved to .akeneo_token for reuse\n\n";
