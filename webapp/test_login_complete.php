<?php
/**
 * Complete Login Flow Test with Session Verification
 * Tests authentication, session persistence, and dashboard access
 */

$baseUrl = 'https://pim.technostationery.com';
$username = 'admin';
$password = 'PimAdmin2026!';
$cookieFile = '/tmp/akeneo_test_cookies_' . time() . '.txt';

echo "====================================\n";
echo "Complete Login Flow Test\n";
echo "Started: " . date('Y-m-d H:i:s') . "\n";
echo "====================================\n\n";

// Initialize cURL with cookie support
$ch = curl_init();
curl_setopt_array($ch, [
    CURLOPT_RETURNTRANSFER => true,
    CURLOPT_FOLLOWLOCATION => true,
    CURLOPT_MAXREDIRS => 5,
    CURLOPT_SSL_VERIFYPEER => false,
    CURLOPT_SSL_VERIFYHOST => false,
    CURLOPT_COOKIEJAR => $cookieFile,
    CURLOPT_COOKIEFILE => $cookieFile,
    CURLOPT_USERAGENT => 'Mozilla/5.0 (compatible; AkeneoTest/1.0)',
    CURLOPT_HEADER => true,
    CURLOPT_VERBOSE => false
]);

// Step 1: Get login page and CSRF token
echo "[1/6] Fetching login page...\n";
curl_setopt($ch, CURLOPT_URL, "$baseUrl/user/login");
curl_setopt($ch, CURLOPT_HTTPGET, true);
$response = curl_exec($ch);
$httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
echo "  HTTP Status: $httpCode\n";

if ($httpCode !== 200) {
    die("✗ Failed to access login page (HTTP $httpCode)\n");
}

// Extract CSRF token
if (preg_match('/name="_csrf_token".*?value="([^"]+)"/', $response, $matches)) {
    $csrfToken = $matches[1];
    echo "  ✓ CSRF Token: " . substr($csrfToken, 0, 20) . "...\n";
} else {
    die("✗ Failed to extract CSRF token\n");
}

// Step 2: Submit login form
echo "\n[2/6] Submitting login credentials...\n";
$loginData = http_build_query([
    '_username' => $username,
    '_password' => $password,
    '_csrf_token' => $csrfToken,
    '_target_path' => '/dashboard',
    '_remember_me' => 'on'
]);

curl_setopt($ch, CURLOPT_URL, "$baseUrl/user/login-check");
curl_setopt($ch, CURLOPT_POST, true);
curl_setopt($ch, CURLOPT_POSTFIELDS, $loginData);
curl_setopt($ch, CURLOPT_FOLLOWLOCATION, false);
$response = curl_exec($ch);
$httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
$redirectUrl = curl_getinfo($ch, CURLINFO_REDIRECT_URL);

echo "  HTTP Status: $httpCode\n";
echo "  Redirect: " . ($redirectUrl ?: 'None') . "\n";

if ($httpCode !== 302 && $httpCode !== 301) {
    echo "✗ Login failed (expected 302, got $httpCode)\n";
    // Show response body for debugging
    $body = substr($response, curl_getinfo($ch, CURLINFO_HEADER_SIZE));
    if (strpos($body, 'error') !== false || strpos($body, 'invalid') !== false) {
        echo "  Error in response: " . substr($body, 0, 200) . "\n";
    }
    die();
}

// Check for session cookies
if (file_exists($cookieFile)) {
    $cookies = file_get_contents($cookieFile);
    $hasSession = strpos($cookies, 'PHPSESSID') !== false || strpos($cookies, 'BAPRM') !== false;
    echo "  Session Cookies: " . ($hasSession ? '✓ Found' : '✗ Missing') . "\n";
} else {
    echo "  ✗ Cookie file not created\n";
}

// Step 3: Follow redirect to dashboard
echo "\n[3/6] Following redirect to dashboard...\n";
curl_setopt($ch, CURLOPT_URL, "$baseUrl/dashboard");
curl_setopt($ch, CURLOPT_HTTPGET, true);
curl_setopt($ch, CURLOPT_FOLLOWLOCATION, true);
$response = curl_exec($ch);
$httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
$finalUrl = curl_getinfo($ch, CURLINFO_EFFECTIVE_URL);

echo "  HTTP Status: $httpCode\n";
echo "  Final URL: $finalUrl\n";

// Step 4: Analyze response
echo "\n[4/6] Analyzing dashboard response...\n";
$body = substr($response, curl_getinfo($ch, CURLINFO_HEADER_SIZE));
$bodyLength = strlen($body);
echo "  Response Size: " . number_format($bodyLength) . " bytes\n";

// Check if redirected back to login (session not persisting)
if (strpos($finalUrl, '/user/login') !== false) {
    echo "  ✗ REDIRECTED TO LOGIN - Session not persisting!\n";
} else {
    echo "  ✓ Still on dashboard\n";
}

// Check for login form (indicates not authenticated)
if (preg_match('/<form[^>]*action="[^"]*login[^"]*"/', $body)) {
    echo "  ✗ Login form present - NOT AUTHENTICATED\n";
} else {
    echo "  ✓ No login form - appears authenticated\n";
}

// Check for dashboard elements
$dashboardElements = [
    '<!DOCTYPE html>' => 'HTML5 DOCTYPE',
    'pim-dashboard' => 'Dashboard container',
    'main.min.js' => 'Main JS bundle',
    'vendor.min.js' => 'Vendor JS bundle',
    '"currentUser"' => 'Current user data',
    'Dashboard' => 'Dashboard title'
];

echo "  Dashboard Elements:\n";
foreach ($dashboardElements as $pattern => $description) {
    $found = strpos($body, $pattern) !== false;
    echo "    " . ($found ? '✓' : '✗') . " $description\n";
}

// Step 5: Test API endpoint with session
echo "\n[5/6] Testing authenticated API endpoint...\n";
curl_setopt($ch, CURLOPT_URL, "$baseUrl/rest/dashboard/widget");
curl_setopt($ch, CURLOPT_HTTPHEADER, ['Accept: application/json']);
$apiResponse = curl_exec($ch);
$apiCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
echo "  API HTTP Status: $apiCode\n";

if ($apiCode === 200) {
    echo "  ✓ API call successful\n";
} elseif ($apiCode === 404) {
    echo "  ! API endpoint not found (expected)\n";
} elseif ($apiCode === 401 || $apiCode === 403) {
    echo "  ✗ API call unauthorized - session not working\n";
} else {
    echo "  ? Unexpected API response: $apiCode\n";
}

// Step 6: Summary
echo "\n[6/6] Test Summary\n";
echo "====================================\n";

$authenticated = strpos($finalUrl, '/dashboard') !== false && 
                 !preg_match('/<form[^>]*action="[^"]*login[^"]*"/', $body);

if ($authenticated) {
    echo "✓✓✓ LOGIN SUCCESSFUL ✓✓✓\n";
    echo "Session is working correctly\n";
    echo "Dashboard is accessible\n";
} else {
    echo "✗✗✗ LOGIN FAILED ✗✗✗\n";
    echo "Session is not persisting\n";
    echo "User is redirected back to login\n";
    echo "\nPossible Issues:\n";
    echo "  1. Session cookie configuration (secure/httponly)\n";
    echo "  2. Session storage permissions\n";
    echo "  3. PHP session save path issues\n";
    echo "  4. APP_SECRET mismatch in .env\n";
}

echo "====================================\n";
echo "Finished: " . date('Y-m-d H:i:s') . "\n\n";

// Cleanup
curl_close($ch);
@unlink($cookieFile);
