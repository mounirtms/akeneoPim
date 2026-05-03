#!/bin/bash

echo "=== RESETTING ADMIN PASSWORD ==="
echo ""

# Generate password hash for "admin"
echo "Generating password hash for 'admin'..."
HASH=$(php -r "echo password_hash('admin', PASSWORD_BCRYPT);")

echo "Hash generated: ${HASH:0:20}..."

echo ""
echo "Updating admin password in database..."

php bin/console doctrine:query:sql "
UPDATE oro_user 
SET password = '$HASH' 
WHERE username = 'admin'
" --env=prod 2>&1 | grep -i "affected\|success\|error" || echo "Query executed"

echo ""
echo "Verifying admin user..."
php bin/console doctrine:query:sql "
SELECT username, email, enabled 
FROM oro_user 
WHERE username = 'admin'
" --env=prod 2>&1 | grep -A10 "array"

echo ""
echo "Password has been reset to: admin"
echo "Username: admin"
echo "Password: admin"
echo ""

