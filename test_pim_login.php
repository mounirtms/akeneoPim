#!/usr/bin/env php
<?php
/**
 * Test script to check PIM login and routing
 */

$baseUrl = 'https://pim.technostationery.com';
$username = 'admin';
$password = 'PimAdmin2026!';

echo "=== Akeneo PIM Login & Routing Test ===\n\n";

// Step 1: Get the login page to extract CSRF token
echo "Step 1: Fetching login page...\n";
$ch = curl_init();
curl_setopt($ch, CURLOPT_URL, $baseUrl . '/user/login');
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
curl_setopt($ch, CURLOPT_FOLLOWLOCATION, true);
curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, false);
curl_setopt($ch, CURLOPT_COOKIEJAR, '/tmp/pim_cookies.txt');
curl_setopt($ch, CURLOPT_COOKIEFILE, '/tmp/pim_cookies.txt');
curl_setopt($ch, CURLOPT_HEADER, true);

$response = curl_exec($ch);
$headerSize = curl_getinfo($ch, CURLINFO_HEADER_SIZE);
$headers = substr($response, 0, $headerSize);
$body = substr($response, $headerSize);

echo "HTTP Code: " . curl_getinfo($ch, CURLINFO_HTTP_CODE) . "\n";
echo "Final URL: " . curl_getinfo($ch, CURLINFO_EFFECTIVE_URL) . "\n\n";

// Extract CSRF token
if (preg_match('/name="_csrf_token"\s+value="([^"]+)"/', $body, $matches)) {
    $csrfToken = $matches[1];
    echo "CSRF Token found: " . substr($csrfToken, 0, 20) . "...\n\n";
} else {
    echo "WARNING: Could not find CSRF token in login page\n\n";
    $csrfToken = '';
}

// Step 2: Attempt login
echo "Step 2: Attempting login...\n";
curl_setopt($ch, CURLOPT_URL, $baseUrl . '/user/login-check');
curl_setopt($ch, CURLOPT_POST, true);
curl_setopt($ch, CURLOPT_POSTFIELDS, http_build_query([
    '_username' => $username,
    '_password' => $password,
    '_csrf_token' => $csrfToken
]));
curl_setopt($ch, CURLOPT_HEADER, true);

$response = curl_exec($ch);
$httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
$redirectUrl = curl_getinfo($ch, CURLINFO_REDIRECT_URL);
$effectiveUrl = curl_getinfo($ch, CURLINFO_EFFECTIVE_URL);

echo "HTTP Code: $httpCode\n";
echo "Redirect URL: " . ($redirectUrl ?: 'none') . "\n";
echo "Effective URL: $effectiveUrl\n";

// Check if login was successful (should redirect)
if ($httpCode == 301 || $httpCode == 302 || $httpCode == 303) {
    echo "Login appears successful (redirect detected)\n\n";
    
    // Follow the redirect
    curl_setopt($ch, CURLOPT_URL, $baseUrl . '/');
    curl_setopt($ch, CURLOPT_POST, false);
    curl_setopt($ch, CURLOPT_HTTPGET, true);
    curl_setopt($ch, CURLOPT_HEADER, true);
    
    $response = curl_exec($ch);
    $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    
    echo "Step 3: After login redirect to /\n";
    echo "HTTP Code: $httpCode\n";
    echo "Final URL: " . curl_getinfo($ch, CURLINFO_EFFECTIVE_URL) . "\n\n";
    
    // Check the response body
    $headerSize = curl_getinfo($ch, CURLINFO_HEADER_SIZE);
    $body = substr($response, $headerSize);
    
    // Check if SPA shell is loaded
    if (strpos($body, 'Loading...') !== false) {
        echo "SPA shell detected (Loading... page)\n";
    }
    
    // Check if JavaScript bundles are referenced
    if (strpos($body, 'main.min.js') !== false) {
        echo "main.min.js reference found\n";
    }
    if (strpos($body, 'vendor.min.js') !== false) {
        echo "vendor.min.js reference found\n";
    }
    if (strpos($body, 'fos_js_routing_js') !== false || strpos($body, 'fos.Router') !== false) {
        echo "FOS routing reference found\n";
    }
    
    echo "\nResponse length: " . strlen($body) . " bytes\n";
    
} else {
    echo "Login may have failed (no redirect)\n";
    if (strpos($body, 'Invalid') !== false || strpos($body, 'error') !== false) {
        echo "Error message detected in response\n";
    }
}

curl_close($ch);

echo "\n=== Test Complete ===\n";
