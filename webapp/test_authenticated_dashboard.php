<?php
/**
 * Test Authenticated Dashboard Access with Full Cookie Handling
 */

$baseUrl = 'https://pim.technostationery.com';
$username = 'admin';
$password = 'PimAdmin2026!';

echo "Testing Authenticated Dashboard Access\n";
echo "======================================\n\n";

// Step 1: Login and capture cookies
echo "[1] Logging in...\n";
$ch = curl_init();
curl_setopt_array($ch, [
    CURLOPT_URL => "$baseUrl/user/login",
    CURLOPT_RETURNTRANSFER => true,
    CURLOPT_SSL_VERIFYPEER => false,
    CURLOPT_FOLLOWLOCATION => false,
    CURLOPT_HEADER => true
]);

$response = curl_exec($ch);
preg_match('/name="_csrf_token".*?value="([^"]+)"/', $response, $matches);
$csrfToken = $matches[1] ?? '';
echo "  CSRF Token: " . substr($csrfToken, 0, 20) . "...\n";

// Extract cookies from first request
preg_match_all('/Set-Cookie: ([^;]+)/', $response, $cookieMatches);
$cookies = [];
foreach ($cookieMatches[1] as $cookie) {
    $parts = explode('=', $cookie, 2);
    $cookies[$parts[0]] = $parts[1] ?? '';
}

// Step 2: Submit login
echo "\n[2] Submitting credentials...\n";
$loginData = http_build_query([
    '_username' => $username,
    '_password' => $password,
    '_csrf_token' => $csrfToken,
    '_target_path' => '/dashboard',
    '_remember_me' => 'on'
]);

$cookieString = implode('; ', array_map(
    fn($k, $v) => "$k=$v",
    array_keys($cookies),
    array_values($cookies)
));

curl_setopt_array($ch, [
    CURLOPT_URL => "$baseUrl/user/login-check",
    CURLOPT_POST => true,
    CURLOPT_POSTFIELDS => $loginData,
    CURLOPT_COOKIE => $cookieString,
    CURLOPT_FOLLOWLOCATION => false
]);

$response = curl_exec($ch);
$httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
echo "  Login Response: HTTP $httpCode\n";

// Update cookies
preg_match_all('/Set-Cookie: ([^;]+)/', $response, $cookieMatches);
foreach ($cookieMatches[1] as $cookie) {
    $parts = explode('=', $cookie, 2);
    $cookies[$parts[0]] = $parts[1] ?? '';
}

$cookieString = implode('; ', array_map(
    fn($k, $v) => "$k=$v",
    array_keys($cookies),
    array_values($cookies)
));

echo "  Cookies: " . implode(', ', array_keys($cookies)) . "\n";

// Step 3: Access dashboard with cookies
echo "\n[3] Accessing dashboard with authentication...\n";
curl_setopt_array($ch, [
    CURLOPT_URL => "$baseUrl/dashboard",
    CURLOPT_POST => false,
    CURLOPT_HTTPGET => true,
    CURLOPT_COOKIE => $cookieString,
    CURLOPT_FOLLOWLOCATION => false,
    CURLOPT_HEADER => true
]);

$response = curl_exec($ch);
$httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
$headerSize = curl_getinfo($ch, CURLINFO_HEADER_SIZE);
$headers = substr($response, 0, $headerSize);
$body = substr($response, $headerSize);

echo "  HTTP Status: $httpCode\n";
echo "  Response Size: " . strlen($body) . " bytes\n";

// Check if redirected
if (preg_match('/Location: (.+)/', $headers, $matches)) {
    $redirectUrl = trim($matches[1]);
    echo "  Redirect To: $redirectUrl\n";
    
    if (strpos($redirectUrl, '/user/login') !== false) {
        echo "  ✗ REDIRECTED TO LOGIN - Session not authenticated!\n";
    }
}

// Check response content
echo "\n[4] Analyzing response content...\n";
$isLoginPage = preg_match('/<input[^>]*name="_password"/', $body);
$hasApp = strpos($body, 'id="app"') !== false || strpos($body, 'pim-dashboard') !== false;
$hasMainJs = strpos($body, 'main.min.js') !== false;
$hasLoading = strpos($body, 'loading') !== false;

echo "  Contains login form: " . ($isLoginPage ? "YES (Not authenticated!)" : "NO") . "\n";
echo "  Contains app container: " . ($hasApp ? "YES" : "NO") . "\n";
echo "  Contains main.min.js: " . ($hasMainJs ? "YES" : "NO") . "\n";
echo "  Contains loading text: " . ($hasLoading ? "YES" : "NO") . "\n";

// Show sample of response
echo "\n[5] Response Sample:\n";
echo substr($body, 0, 500) . "\n...\n";

curl_close($ch);

echo "\n======================================\n";
if (!$isLoginPage && $hasMainJs) {
    echo "✓ Dashboard accessible - session working!\n";
} else {
    echo "✗ Dashboard not accessible - session issue persists\n";
    echo "\nDEBUGGING INFO:\n";
    echo "- Check if cookies are being set with Secure flag\n";
    echo "- Verify session.cookie_secure matches HTTPS usage\n";
    echo "- Check var/cache/prod/sessions directory permissions\n";
    echo "- Review var/logs/prod.log for authentication errors\n";
}
