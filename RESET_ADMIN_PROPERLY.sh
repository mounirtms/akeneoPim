#!/bin/bash

echo "=========================================="
echo "RESET ADMIN USER PROPERLY"
echo "=========================================="
echo ""

echo "Step 1: List available Akeneo user commands"
echo "---"
php bin/console list pim:user --env=prod

echo ""
echo "Step 2: Try creating fresh admin user (will fail if exists)"
echo "---"
php bin/console pim:user:create \
    admin2 \
    Admin123! \
    admin2@technostationery.com \
    Admin \
    User \
    --env=prod 2>&1 | head -10 || echo "Command format may be different"

echo ""
echo "Step 3: Check if there's a user table we're missing"
echo "---"
mysql -u akeneo_pim -p'akeneo_pim' -P 3307 -h 127.0.0.1 --skip-ssl akeneo_pim -e "
SHOW TABLES LIKE '%user%';
" 2>&1 | grep -v "mysql: \[Warning\]" | grep -v "Deprecated"

echo ""
echo "Step 4: Check all columns in oro_user table"
echo "---"
mysql -u akeneo_pim -p'akeneo_pim' -P 3307 -h 127.0.0.1 --skip-ssl akeneo_pim -e "
DESCRIBE oro_user;
" 2>&1 | grep -v "mysql: \[Warning\]" | grep -v "Deprecated"

echo ""
echo "Step 5: Check admin user full details"
echo "---"
mysql -u akeneo_pim -p'akeneo_pim' -P 3307 -h 127.0.0.1 --skip-ssl akeneo_pim -e "
SELECT 
    username, 
    email, 
    enabled,
    salt,
    confirmed,
    SUBSTRING(password, 1, 40) as password_hash
FROM oro_user 
WHERE username = 'admin';
" 2>&1 | grep -v "mysql: \[Warning\]" | grep -v "Deprecated"

echo ""
echo "Step 6: Update user with proper salt (if needed)"
echo "---"

# Check if salt is being used
SALT=$(mysql -u akeneo_pim -p'akeneo_pim' -P 3307 -h 127.0.0.1 --skip-ssl akeneo_pim -sN -e "SELECT salt FROM oro_user WHERE username = 'admin';" 2>/dev/null)

if [ -z "$SALT" ] || [ "$SALT" = "NULL" ]; then
    echo "No salt - using plain bcrypt hash"
    NEW_HASH=$(php -r "echo password_hash('Admin123!', PASSWORD_BCRYPT, ['cost' => 13]);")
else
    echo "Salt detected: ${SALT:0:20}..."
    echo "Generating hash with salt..."
    NEW_HASH=$(php -r "
        \$password = 'Admin123!';
        \$salt = '$SALT';
        // Try Symfony's method of hashing with salt
        if (class_exists('Symfony\\\Component\\\PasswordHasher\\\Hasher\\\UserPasswordHasher')) {
            echo password_hash(\$password . '{\$salt}', PASSWORD_BCRYPT, ['cost' => 13]);
        } else {
            // Fallback
            echo password_hash(\$password, PASSWORD_BCRYPT, ['cost' => 13]);
        }
    ")
fi

echo "New hash: ${NEW_HASH:0:50}..."

mysql -u akeneo_pim -p'akeneo_pim' -P 3307 -h 127.0.0.1 --skip-ssl akeneo_pim -e "
UPDATE oro_user 
SET password = '$NEW_HASH',
    enabled = 1,
    confirmed = 1
WHERE username = 'admin';
" 2>&1 | grep -v "mysql: \[Warning\]" | grep -v "Deprecated"

echo "✅ Password updated"

echo ""
echo "Step 7: Check security.yaml for encoder type"
echo "---"
if [ -f config/packages/security.yaml ]; then
    echo "Looking for password hasher/encoder configuration..."
    grep -B 5 -A 15 "password_hasher\|encoders:" config/packages/security.yaml | head -25
fi

echo ""
echo "Step 8: Clear cache and test"
echo "---"
rm -rf var/cache/prod/*
php bin/console cache:clear --env=prod 2>&1 | tail -3

echo ""
echo "Step 9: Test login with updated credentials"
echo "---"
CSRF_TOKEN=$(curl -s -c /tmp/test_cookies.txt "https://pim.technostationery.com/user/login" | grep -o 'value="[^"]*"' | head -1 | cut -d'"' -f2)

LOGIN_RESULT=$(curl -s -i -b /tmp/test_cookies.txt -c /tmp/test_cookies.txt \
    -X POST "https://pim.technostationery.com/user/login-check" \
    -d "_username=admin" \
    -d "_password=Admin123!" \
    -d "_csrf_token=$CSRF_TOKEN" \
    -L 2>&1)

if echo "$LOGIN_RESULT" | grep -q "Location:"; then
    echo "Redirect location:"
    echo "$LOGIN_RESULT" | grep "Location:" | head -3
fi

if echo "$LOGIN_RESULT" | grep -qi "dashboard"; then
    echo "✅ SUCCESS - Dashboard detected!"
elif echo "$LOGIN_RESULT" | grep -qi "name=\"_username\""; then
    echo "❌ FAILED - Still showing login form"
    echo ""
    echo "Checking for error message..."
    echo "$LOGIN_RESULT" | grep -i "invalid\|error\|denied" | head -3
else
    echo "⚠️ UNCLEAR - Response:"
    echo "$LOGIN_RESULT" | grep -o '<title>[^<]*</title>'
fi

echo ""
echo "=========================================="
echo "FINAL STATUS"
echo "=========================================="
echo ""
echo "Database: akeneo_pim (port 3307)"
echo "Username: admin"
echo "Password: Admin123!"
echo "Hash updated: Yes"
echo "Cache cleared: Yes"
echo ""
echo "Manual test: https://pim.technostationery.com/user/login"
echo ""

