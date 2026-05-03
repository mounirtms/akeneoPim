#!/bin/bash

echo "=== FIXING ADMIN PASSWORD PROPERLY ==="
echo ""

# Step 1: Generate a fresh bcrypt hash for "admin"
echo "Generating fresh password hash..."
NEW_HASH=$(php -r "echo password_hash('admin', PASSWORD_BCRYPT);")
echo "New hash: ${NEW_HASH:0:30}..."

# Step 2: Get admin user ID
echo ""
echo "Getting admin user ID..."
ADMIN_ID=$(php bin/console doctrine:query:sql "SELECT id FROM oro_user WHERE username = 'admin'" --env=prod 2>&1 | grep -oP '(?<=\[\"id\"\]=>\s+int\()\d+' | head -1)
echo "Admin ID: $ADMIN_ID"

# Step 3: Update password in database
echo ""
echo "Updating password in database..."
php bin/console doctrine:query:sql "UPDATE oro_user SET password = '$NEW_HASH' WHERE username = 'admin'" --env=prod 2>&1 | grep -i "affected\|query" || echo "Update executed"

# Step 4: Verify the update
echo ""
echo "Verifying password update..."
STORED_HASH=$(php bin/console doctrine:query:sql "SELECT password FROM oro_user WHERE username = 'admin'" --env=prod 2>&1 | grep -oP '\$2y\$[^\\"]+' | head -1)
echo "Stored hash: ${STORED_HASH:0:30}..."

# Step 5: Test password verification
echo ""
echo "Testing password verification..."
php -r "
\$stored_hash = '$STORED_HASH';
\$password = 'admin';
if (password_verify(\$password, \$stored_hash)) {
    echo '✓✓✓ Password verification: SUCCESS ✓✓✓' . PHP_EOL;
    exit(0);
} else {
    echo '✗ Password verification: FAILED' . PHP_EOL;
    exit(1);
}
"

VERIFY_RESULT=$?

echo ""
if [ $VERIFY_RESULT -eq 0 ]; then
    echo "=== PASSWORD FIX SUCCESSFUL ==="
    echo "Username: admin"
    echo "Password: admin"
    echo "Ready to test login!"
else
    echo "=== PASSWORD FIX FAILED ==="
    echo "Manual intervention required"
fi

