<?php
$pdo = new PDO('mysql:host=127.0.0.1;port=3307;dbname=akeneo_pim', 'root', 'YourNewStrongPassword');
$stmt = $pdo->query("SELECT id, random_id, secret FROM pim_api_client LIMIT 1");
$client = $stmt->fetch(PDO::FETCH_ASSOC);
$clientId = $client['id'] . '_' . $client['random_id'];
$clientSecret = $client['secret'];

// Get token
$ch = curl_init('https://pim.technostationery.com/api/oauth/v1/token');
curl_setopt($ch, CURLOPT_POST, true);
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
curl_setopt($ch, CURLOPT_HTTPHEADER, ['Content-Type: application/json']);
curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode([
    'username' => 'admin',
    'password' => 'kVjW3GxKZCe9!!$',
    'grant_type' => 'password',
    'client_id' => $clientId,
    'client_secret' => $clientSecret
]));
$tokenResp = json_decode(curl_exec($ch), true);
curl_close($ch);

if (!isset($tokenResp['access_token'])) {
    echo "Failed to get token: " . json_encode($tokenResp) . "\n";
    exit(1);
}
echo "Token obtained\n";

// Login via web to get session cookie
$cookieFile = '/tmp/test_cookies.txt';
@unlink($cookieFile);

// Get login page
$ch = curl_init('https://pim.technostationery.com/user/login');
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
curl_setopt($ch, CURLOPT_COOKIEJAR, $cookieFile);
$loginPage = curl_exec($ch);
curl_close($ch);

preg_match('/name="_csrf_token"\s+value="([^"]+)"/', $loginPage, $m);
$csrf = $m[1] ?? '';
echo "CSRF: " . substr($csrf, 0, 20) . "...\n";

// Submit login
$ch = curl_init('https://pim.technostationery.com/user/login-check');
curl_setopt($ch, CURLOPT_POST, true);
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
curl_setopt($ch, CURLOPT_FOLLOWLOCATION, true);
curl_setopt($ch, CURLOPT_COOKIEFILE, $cookieFile);
curl_setopt($ch, CURLOPT_COOKIEJAR, $cookieFile);
curl_setopt($ch, CURLOPT_POSTFIELDS, http_build_query([
    '_username' => 'admin',
    '_password' => 'kVjW3GxKZCe9!!$',
    '_csrf_token' => $csrf,
]));
$resp = curl_exec($ch);
$code = curl_getinfo($ch, CURLINFO_HTTP_CODE);
$url = curl_getinfo($ch, CURLINFO_EFFECTIVE_URL);
curl_close($ch);
echo "Login result: HTTP $code, URL: $url\n";

// Test endpoints
$endpoints = [
    '/rest/announcements',
    '/rest/new_announcements',
    '/rest/user/',
    '/rest/catalogs/locales',
    '/enrich/product/',
];

foreach ($endpoints as $ep) {
    $ch = curl_init('https://pim.technostationery.com' . $ep);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_COOKIEFILE, $cookieFile);
    curl_setopt($ch, CURLOPT_COOKIEJAR, $cookieFile);
    $body = curl_exec($ch);
    $code = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    $ct = curl_getinfo($ch, CURLINFO_CONTENT_TYPE);
    curl_close($ch);
    
    $isJson = str_starts_with(trim($body), '{') || str_starts_with(trim($body), '[');
    echo "$ep: HTTP $code, JSON: " . ($isJson ? 'yes' : 'no') . ", CT: $ct";
    if (!$isJson) {
        echo ", Body: " . substr(strip_tags($body), 0, 100);
    }
    echo "\n";
}

@unlink($cookieFile);
