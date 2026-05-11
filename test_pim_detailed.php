#!/usr/bin/env php
<?php
/**
 * Comprehensive test for PIM login and routing
 */

$baseUrl = 'https://pim.technostationery.com';
$username = 'admin';
$password = 'PimAdmin2026!';

echo "=== Comprehensive PIM Login Test ===\n\n";

// Clear old cookies
@unlink('/tmp/pim_cookies.txt');

// Step 1: Get login page
echo "1. Getting login page...\n";
$ch = curl_init();
curl_setopt_array($ch, [
    CURLOPT_URL => $baseUrl . '/user/login',
    CURLOPT_RETURNTRANSFER => true,
    CURLOPT_FOLLOWLOCATION => false,
    CURLOPT_SSL_VERIFYPEER => false,
    CURLOPT_COOKIEJAR => '/tmp/pim_cookies.txt',
    CURLOPT_COOKIEFILE => '/tmp/pim_cookies.txt',
    CURLOPT_HEADER => true,
    CURLOPT_VERBOSE => false,
]);

$response = curl_exec($ch);
$headerSize = curl_getinfo($ch, CURLINFO_HEADER_SIZE);
$body = substr($response, $headerSize);

// Extract CSRF token
preg_match('/name="_csrf_token"\s+value="([^"]+)"/', $body, $matches);
$csrfToken = $matches[1] ?? '';
echo "   CSRF Token: " . ($csrfToken ? substr($csrfToken, 0, 30) . '...' : 'NOT FOUND') . "\n";

// Step 2: Submit login form
echo "\n2. Submitting login credentials...\n";
curl_setopt_array($ch, [
    CURLOPT_URL => $baseUrl . '/user/login-check',
    CURLOPT_POST => true,
    CURLOPT_POSTFIELDS => http_build_query([
        '_username' => $username,
        '_password' => $password,
        '_csrf_token' => $csrfToken
    ]),
    CURLOPT_FOLLOWLOCATION => false,
    CURLOPT_HEADER => true,
]);

$response = curl_exec($ch);
$httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
$headers = substr($response, 0, curl_getinfo($ch, CURLINFO_HEADER_SIZE));
$body = substr($response, curl_getinfo($ch, CURLINFO_HEADER_SIZE));

echo "   HTTP Code: $httpCode\n";

// Check for redirect
if (preg_match('/Location:\s*(.+)/', $headers, $locationMatches)) {
    $redirectUrl = trim($locationMatches[1]);
    echo "   Redirect Location: $redirectUrl\n";
    
    // Step 3: Follow redirect to /
    echo "\n3. Following redirect to dashboard...\n";
    curl_setopt_array($ch, [
        CURLOPT_URL => $baseUrl . '/',
        CURLOPT_POST => false,
        CURLOPT_HTTPGET => true,
        CURLOPT_FOLLOWLOCATION => false,
        CURLOPT_HEADER => true,
    ]);
    
    $response = curl_exec($ch);
    $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    $headerSize = curl_getinfo($ch, CURLINFO_HEADER_SIZE);
    $body = substr($response, $headerSize);
    
    echo "   HTTP Code: $httpCode\n";
    echo "   Response Size: " . strlen($body) . " bytes\n";
    
    // Analyze the SPA shell
    echo "\n4. Analyzing SPA shell content:\n";
    
    $checks = [
        'DOCTYPE html' => 'HTML5 DOCTYPE',
        'Loading...' => 'Loading text',
        'main.min.js' => 'Main JS bundle',
        'vendor.min.js' => 'Vendor JS bundle',
        'fos_js_routing_js' => 'FOS routing script',
        'fos.Router' => 'FOS router initialization',
        'pim.css' => 'CSS stylesheet',
        'jquery.min.js' => 'jQuery',
        'react.min.js' => 'React',
        'backbone.min.js' => 'Backbone',
        'app' => 'App container',
    ];
    
    foreach ($checks as $search => $label) {
        $found = strpos($body, $search) !== false;
        echo "   " . ($found ? '✓' : '✗') . " $label\n";
    }
    
    // Extract and show first part of body to see structure
    echo "\n5. SPA Shell Structure (first 1000 chars):\n";
    echo "   " . substr(strip_tags($body), 0, 500) . "\n";
    
    // Check for cache_buster
    if (preg_match('/cache_buster\s*=\s*["\']([^"\']+)["\']/', $body, $cacheMatches)) {
        echo "\n6. Cache buster: " . $cacheMatches[1] . "\n";
    }
    
} else {
    echo "   No redirect found - login may have failed\n";
    echo "   Response snippet: " . substr(strip_tags($body), 0, 200) . "\n";
    
    // Check for error messages
    $errors = ['Invalid', 'invalid', 'error', 'Error', 'Authentication'];
    foreach ($errors as $error) {
        if (strpos($body, $error) !== false) {
            echo "   Found potential error: $error\n";
        }
    }
}

curl_close($ch);

echo "\n=== Test Complete ===\n";
