<?php
/**
 * CREATE IMPORT PROFILE VIA AKENEO API
 * Creates a CSV import profile for product images
 * Date: 2026-04-29
 */

// API Configuration
$baseUrl = 'https://pim.technostationery.com';
$clientId = '2_ml5f52erhggg0s484gckwgs4kg8gwc4c48ksgko4gkgos4k48';
$clientSecret = '1zniz3jfcmcgg0wckskw8k4c80ccwc4o0cokcwk80cs8cs0cs4';
$username = 'apiconnector';
$password = 'ApiConnector@2026!Secure';

echo "=== AKENEO IMPORT PROFILE CREATOR ===\n";
echo "Date: " . date('Y-m-d H:i:s') . "\n\n";

// Step 1: Get OAuth token
echo "Step 1: Obtaining OAuth token...\n";
$tokenUrl = $baseUrl . '/api/oauth/v1/token';

$tokenData = [
    'grant_type' => 'password',
    'username' => $username,
    'password' => $password
];

$ch = curl_init();
curl_setopt($ch, CURLOPT_URL, $tokenUrl);
curl_setopt($ch, CURLOPT_POST, true);
curl_setopt($ch, CURLOPT_POSTFIELDS, http_build_query($tokenData));
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, true);
curl_setopt($ch, CURLOPT_USERPWD, $clientId . ':' . $clientSecret);
curl_setopt($ch, CURLOPT_HTTPHEADER, [
    'Content-Type: application/x-www-form-urlencoded'
]);

$response = curl_exec($ch);
$httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
curl_close($ch);

if ($httpCode !== 200) {
    die("❌ Failed to obtain token. HTTP $httpCode\nResponse: $response\n");
}

$tokenData = json_decode($response, true);
$accessToken = $tokenData['access_token'];
echo "✓ Token obtained successfully\n\n";

// Step 2: Check if profile exists
echo "Step 2: Checking if import profile exists...\n";
$profileCode = 'product_image_import';
$profileUrl = $baseUrl . '/api/rest/v1/import-profiles/' . $profileCode;

$ch = curl_init();
curl_setopt($ch, CURLOPT_URL, $profileUrl);
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, true);
curl_setopt($ch, CURLOPT_HTTPHEADER, [
    'Authorization: Bearer ' . $accessToken,
    'Content-Type: application/json'
]);

$response = curl_exec($ch);
$httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
curl_close($ch);

if ($httpCode === 200) {
    echo "✓ Import profile already exists\n";
    $existingProfile = json_decode($response, true);
    echo "Profile details:\n";
    echo json_encode($existingProfile, JSON_PRETTY_PRINT) . "\n";
    exit(0);
}

// Step 3: Create import profile
echo "Profile does not exist. Creating new profile...\n\n";

$profileData = [
    'code' => $profileCode,
    'label' => 'Product Image Import',
    'job' => 'csv_product_import',
    'connector' => 'Akeneo CSV Connector',
    'configuration' => [
        'delimiter' => ',',
        'enclosure' => '"',
        'escape' => '\\',
        'enabled' => true,
        'categoriesColumn' => 'categories',
        'familyColumn' => 'family',
        'groupsColumn' => 'groups',
        'enabledComparison' => true,
        'realTimeVersioning' => true,
        'decimalSeparator' => '.',
        'dateFormat' => 'yyyy-MM-dd'
    ]
];

$ch = curl_init();
curl_setopt($ch, CURLOPT_URL, $baseUrl . '/api/rest/v1/import-profiles');
curl_setopt($ch, CURLOPT_POST, true);
curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($profileData));
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, true);
curl_setopt($ch, CURLOPT_HTTPHEADER, [
    'Authorization: Bearer ' . $accessToken,
    'Content-Type: application/json'
]);

$response = curl_exec($ch);
$httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
$curlError = curl_error($ch);
curl_close($ch);

echo "HTTP Code: $httpCode\n";
echo "Response: $response\n";

if ($curlError) {
    echo "CURL Error: $curlError\n";
}

if ($httpCode === 201) {
    echo "\n✓ Import profile created successfully!\n";
} else {
    echo "\n❌ Failed to create import profile\n";
}

echo "\n=== NEXT STEPS ===\n";
echo "1. Copy CSV to import directory:\n";
echo "   cp /home/pim/public_html/webapp/image_import_20260429_151054.csv /home/pim/public_html/var/import/\n\n";
echo "2. Run import via command line:\n";
echo "   cd /home/pim/public_html\n";
echo "   php bin/console akeneo:batch:create-job -c \"product_image_import\" \"Product Image Import\" \"csv_product_import\" \"import\" -v\n";
echo "   php bin/console akeneo:batch:job product_image_import\n\n";
echo "3. Or use Akeneo UI:\n";
echo "   - Go to Imports > Create import\n";
echo "   - Use profile code: $profileCode\n";
echo "   - Upload CSV file\n";
echo "   - Run import\n";
