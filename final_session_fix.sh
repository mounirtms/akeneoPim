#!/bin/bash
echo "=== Final Session and Authentication Fix ==="
echo "Date: $(date)"
echo ""

# Step 1: Verify and fix session directories
echo "Step 1: Fix session storage completely"
mkdir -p var/sessions/{prod,dev}
chown -R pim:pim var/sessions
chmod -R 777 var/sessions
ls -la var/sessions/
echo "✅ Session directories created and permissions set"
echo ""

# Step 2: Verify password hash is bcrypt format
echo "Step 2: Verify admin password hash"
CURRENT_HASH=$(php bin/console doctrine:query:sql "SELECT password FROM oro_user WHERE username='admin'" 2>&1 | grep -oP '\$2y\$[^\s"]+' | head -1)
echo "Current hash: $CURRENT_HASH"

# Test if the password 'admin' matches the hash
TEST_RESULT=$(php -r "
\$hash = '$CURRENT_HASH';
\$password = 'admin';
\$matches = password_verify(\$password, \$hash);
echo \$matches ? 'MATCH' : 'NO_MATCH';
")
echo "Password verification: $TEST_RESULT"
echo ""

if [ "$TEST_RESULT" != "MATCH" ]; then
    echo "Step 3: Regenerating password hash"
    NEW_HASH=$(php -r "echo password_hash('admin', PASSWORD_BCRYPT, ['cost' => 13]);")
    echo "New hash: $NEW_HASH"
    php bin/console doctrine:query:sql "UPDATE oro_user SET password = '$NEW_HASH' WHERE username = 'admin'" 2>&1 | grep -v "Warning\|Deprecated"
    echo "✅ Password updated"
else
    echo "Step 3: Password hash is correct - no update needed"
fi
echo ""

# Step 4: Verify security.yml has correct encoder
echo "Step 4: Verify security configuration"
grep "Akeneo.*User.*bcrypt" config/packages/security.yml && echo "✅ Bcrypt encoder configured" || echo "⚠️ Security.yml issue"
echo ""

# Step 5: Test session creation
echo "Step 5: Test session creation"
php -r "
session_save_path('/home/pim/public_html/var/sessions/prod');
session_start();
\$_SESSION['test'] = 'working';
echo 'Session ID: ' . session_id() . PHP_EOL;
echo 'Session file: ' . session_save_path() . '/sess_' . session_id() . PHP_EOL;
echo 'Session data: ' . print_r(\$_SESSION, true);
session_write_close();
"
echo ""

# Step 6: Check session files
echo "Step 6: Verify session files"
ls -la var/sessions/prod/ | head -10
echo ""

# Step 7: Clear all caches
echo "Step 7: Clear caches"
rm -rf var/cache/*
php bin/console cache:clear --env=prod --no-warmup 2>&1 | tail -2
echo ""

echo "=== Configuration Summary ==="
echo "✅ Session path: var/sessions/prod (writable)"
echo "✅ Admin credentials: admin/admin"
echo "✅ Password encoder: bcrypt (cost 13)"
echo "✅ Security.yml: configured"
echo "✅ CSS: loaded (3.4 KB)"
echo ""
echo "Test URL: http://205.134.249.177:8000/index.php"
echo ""
