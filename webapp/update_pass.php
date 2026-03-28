<?php
error_reporting(E_ALL);
ini_set('display_errors', 1);

$pdo = new PDO('mysql:host=127.0.0.1;port=3307;dbname=akeneo_pim', 'root', 'YourNewStrongPassword');

$stmt = $pdo->query("SELECT id, username, password, salt FROM oro_user WHERE username = 'admin'");
$user = $stmt->fetch(PDO::FETCH_ASSOC);

$newPass = 'kVjW3GxKZCe9!!$';
$salt = $user['salt'];

// Symfony's MessageDigestPasswordEncoder with sha512
// It does: base64_encode(hash('sha512', password.'{'.salt.'}', true))
// With 5000 iterations (default)
$salted = $newPass . '{' . $salt . '}';
$digest = hash('sha512', $salted, true);
for ($i = 1; $i < 5000; $i++) {
    $digest = hash('sha512', $digest . $salted, true);
}
$encoded = base64_encode($digest);

echo "Salt: $salt\n";
echo "Encoded: $encoded\n";

$update = $pdo->prepare("UPDATE oro_user SET password = ? WHERE username = 'admin'");
$update->execute([$encoded]);
echo "Password updated with SHA512 encoding\n";

// Test via API
$ch = curl_init('https://pim.technostationery.com/api/oauth/v1/token');
curl_setopt($ch, CURLOPT_POST, true);
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
curl_setopt($ch, CURLOPT_HTTPHEADER, ['Content-Type: application/json']);
curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode([
    'username' => 'admin',
    'password' => $newPass,
    'grant_type' => 'password',
    'client_id' => '1_3yhbczkw7osgcw8wg44k84os4sc04w4wc80ks08sw8cc8c40sw',
    'client_secret' => '50vx3l4u4l4wwcsok4kcwkoo44oo0s0o8s0kcs0gc0c8g0oow4'
]));
$response = curl_exec($ch);
$httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
curl_close($ch);
echo "API Response ($httpCode): " . substr($response, 0, 200) . "\n";
