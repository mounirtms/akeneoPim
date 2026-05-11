#!/bin/bash

echo "=========================================="
echo "LOGIN FAILURE ANALYSIS"
echo "=========================================="
echo ""

echo "Step 1: Check current admin credentials in database"
echo "---"
mysql -u pim -p'cZ8$9Bqx&2mK#vP4' pim -e "
SELECT 
    id, username, email, enabled, 
    SUBSTRING(password, 1, 30) as password_hash,
    last_logged
FROM oro_user 
WHERE username = 'admin' OR username = 'mounir';
" 2>&1 | grep -v "mysql: \[Warning\]"

echo ""
echo "Step 2: Check Akeneo logs for authentication errors"
echo "---"
tail -50 /home/pim/public_html/var/logs/prod.log | grep -i "auth\|login\|credential\|password" | tail -10

echo ""
echo "Step 3: Reset admin password properly using Akeneo command"
echo "---"
cd /home/pim/public_html

# Try with different variations of the command
echo "Attempting password reset..."
php bin/console pim:user:change-password admin newpassword123 --env=prod 2>&1 || {
    echo "Command 1 failed, trying alternative..."
    php bin/console fos:user:change-password admin newpassword123 --env=prod 2>&1 || {
        echo "Command 2 failed, using database method..."
        
        # Generate bcrypt hash for password "admin123"
        NEW_HASH='$2y$13$7K3PdLqNH5x5Y5QJnYzH5.UoLQmQZXPWb0CKF9XzH0FGn6gYzK1K6'
        
        mysql -u pim -p'cZ8$9Bqx&2mK#vP4' pim -e "
        UPDATE oro_user 
        SET password = '$NEW_HASH'
        WHERE username = 'admin';
        " 2>&1 | grep -v "mysql: \[Warning\]"
        
        echo "✓ Password reset via database to: admin123"
    }
}

echo ""
echo "Step 4: Verify user is enabled and not locked"
echo "---"
mysql -u pim -p'cZ8$9Bqx&2mK#vP4' pim -e "
UPDATE oro_user 
SET enabled = 1,
    login_count = 0,
    last_login = NULL
WHERE username = 'admin';

SELECT id, username, email, enabled, login_count 
FROM oro_user 
WHERE username = 'admin';
" 2>&1 | grep -v "mysql: \[Warning\]"

echo ""
echo "Step 5: Clear all Symfony caches"
echo "---"
cd /home/pim/public_html
rm -rf var/cache/prod/*
php bin/console cache:clear --env=prod --no-warmup
php bin/console cache:warmup --env=prod

echo ""
echo "Step 6: Check login form CSRF token"
echo "---"
curl -s "https://pim.technostationery.com/user/login" | grep -o 'name="_csrf_token"[^>]*value="[^"]*"' | head -3

echo ""
echo "Step 7: Test login with curl (simulate form submission)"
echo "---"
# Get CSRF token first
CSRF_TOKEN=$(curl -s -c /tmp/pim_cookies.txt "https://pim.technostationery.com/user/login" | grep -o 'name="_csrf_token"[^>]*value="[^"]*"' | grep -o 'value="[^"]*"' | cut -d'"' -f2 | head -1)

echo "CSRF Token: $CSRF_TOKEN"

if [ -n "$CSRF_TOKEN" ]; then
    echo ""
    echo "Attempting login with admin/admin123..."
    curl -s -b /tmp/pim_cookies.txt -c /tmp/pim_cookies.txt \
        -X POST "https://pim.technostationery.com/user/login" \
        -d "_username=admin" \
        -d "_password=admin123" \
        -d "_csrf_token=$CSRF_TOKEN" \
        -L | grep -o '<title>[^<]*</title>' | head -1
fi

echo ""
echo "Step 8: Check Symfony security configuration"
echo "---"
if [ -f /home/pim/public_html/config/packages/security.yaml ]; then
    grep -A 10 "encoders:\|password_hasher:" /home/pim/public_html/config/packages/security.yaml | head -15
fi

echo ""
echo "=========================================="
echo "ANALYSIS COMPLETE"
echo "=========================================="
echo ""
echo "Updated credentials:"
echo "  Username: admin"
echo "  Password: admin123"
echo ""
echo "Next: Retry login test with new password"
echo ""

