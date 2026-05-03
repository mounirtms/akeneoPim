#!/bin/bash
echo "=== Deep Authentication Debugging ==="
echo "Date: $(date)"
echo ""

# Step 1: Check if authentication provider is properly configured
echo "Step 1: List authentication-related services"
php bin/console debug:container --env=prod | grep -i "auth\|user\|security" | head -20 2>&1 | grep -v "Deprecated\|Warning"
echo ""

# Step 2: Verify user provider configuration
echo "Step 2: Check user provider configuration"
grep -A 5 "pim_user.provider.user" config/packages/security.yml
echo ""

# Step 3: Test password encoding directly
echo "Step 3: Test password encoding"
STORED_HASH='$2y$13$BGgNdgAb.fG7D3ULN8UD.uGbzfRV9zkG8rhwK5QvMBcD8kDkmKscy'
php -r "
\$hash = '$STORED_HASH';
\$password = 'admin';
echo 'Testing password: admin' . PHP_EOL;
echo 'Against hash: ' . \$hash . PHP_EOL;
echo 'Result: ' . (password_verify(\$password, \$hash) ? 'MATCH ✅' : 'NO MATCH ❌') . PHP_EOL;
"
echo ""

# Step 4: Check if ACL provider is causing issues
echo "Step 4: Check ACL-related services"
php bin/console debug:container acl --env=prod 2>&1 | grep -v "Deprecated\|Warning" | head -10
echo ""

# Step 5: Test creating a new session and authentication manually
echo "Step 5: Test session storage with authentication context"
php -r "
// Configure session
ini_set('session.save_path', '/home/pim/public_html/var/sessions/prod');
session_start();

// Store test authentication data
\$_SESSION['_sf2_attributes'] = [
    '_security_main' => 'test_user_data'
];

echo 'Session ID: ' . session_id() . PHP_EOL;
echo 'Session data stored: ' . print_r(\$_SESSION, true);
session_write_close();

// Verify session file was created
\$sessionFile = '/home/pim/public_html/var/sessions/prod/sess_' . session_id();
if (file_exists(\$sessionFile)) {
    echo 'Session file created: ' . \$sessionFile . PHP_EOL;
    echo 'Session file content: ' . file_get_contents(\$sessionFile) . PHP_EOL;
} else {
    echo 'Session file NOT created' . PHP_EOL;
}
"
echo ""

# Step 6: Check security firewall configuration
echo "Step 6: Verify firewall configuration for main firewall"
grep -A 15 "main:" config/packages/security.yml
echo ""

# Step 7: Enable Symfony debug mode for next test
echo "Step 7: Check current environment settings"
grep "APP_ENV\|APP_DEBUG" .env | head -5
echo ""

echo "=== Debug Complete ==="
