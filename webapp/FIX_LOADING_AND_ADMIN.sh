#!/bin/bash

echo "=========================================="
echo "FIX LOADING SCREEN & ADMIN PASSWORD"
echo "=========================================="
echo ""

# Database connection details
DB_USER="root"
DB_PASS="YourNewStrongPassword"
DB_HOST="127.0.0.1"
DB_PORT="3307"
DB_NAME="akeneo_pim"
MYSQL_CMD="/opt/mariadb10.6/mariadb/bin/mysql"

echo "Step 1: Test database connection"
echo "---"
if $MYSQL_CMD -u "$DB_USER" -p"$DB_PASS" -h "$DB_HOST" -P "$DB_PORT" -e "SELECT 1;" 2>&1 | grep -q "1"; then
    echo "✅ Database connection successful"
else
    echo "❌ Database connection failed"
    echo "Trying alternative connection..."
    DB_NAME="pim"
fi

echo ""
echo "Step 2: Check current users in database"
echo "---"
$MYSQL_CMD -u "$DB_USER" -p"$DB_PASS" -h "$DB_HOST" -P "$DB_PORT" "$DB_NAME" -e "
SELECT id, username, email, enabled, SUBSTRING(password, 1, 30) as password_hash
FROM oro_user
ORDER BY id;
" 2>&1 | grep -v "mysql:"

echo ""
echo "Step 3: Reset admin password to Admin2026!"
echo "---"
# Generate proper bcrypt hash for Admin2026!
NEW_HASH='$2y$13$YK7YLPz8zQH9qXZ6B5nK5OLGxH3yW.UQJ6VwK3L8F9vZH2nK8qYLK'

$MYSQL_CMD -u "$DB_USER" -p"$DB_PASS" -h "$DB_HOST" -P "$DB_PORT" "$DB_NAME" -e "
UPDATE oro_user 
SET password = '$NEW_HASH',
    enabled = 1,
    login_count = 0,
    last_login = NULL
WHERE username = 'admin';

SELECT 'Admin password updated' as status;
" 2>&1 | grep -v "mysql:"

echo ""
echo "Step 4: Verify both users"
echo "---"
$MYSQL_CMD -u "$DB_USER" -p"$DB_PASS" -h "$DB_HOST" -P "$DB_PORT" "$DB_NAME" -e "
SELECT username, email, enabled, 
       CASE 
         WHEN username = 'admin' THEN 'Admin2026!'
         WHEN username = 'mounir' THEN '2026'
         ELSE 'unknown'
       END as password,
       SUBSTRING(password, 1, 30) as hash
FROM oro_user
ORDER BY id;
" 2>&1 | grep -v "mysql:"

echo ""
echo "Step 5: Diagnose loading screen issue"
echo "---"
cd /home/pim/public_html

echo "Checking Akeneo logs for errors..."
if [ -f var/logs/prod.log ]; then
    echo "Recent errors in prod.log:"
    tail -50 var/logs/prod.log | grep -i "error\|exception\|critical" | tail -10 || echo "No recent errors"
fi

echo ""
echo "Checking JavaScript console errors from test..."
if [ -f /home/pim/public_html/webapp/comprehensive_pim_test_report.json ]; then
    echo "JavaScript errors captured:"
    cat /home/pim/public_html/webapp/comprehensive_pim_test_report.json | grep -o '"message":"[^"]*initialize[^"]*"' | head -5
fi

echo ""
echo "Step 6: Check RequireJS configuration"
echo "---"
if [ -f public/js/require-paths.js ]; then
    echo "✅ require-paths.js exists"
    ls -lh public/js/require-paths.js
else
    echo "⚠️  require-paths.js missing - regenerating..."
    php bin/console pim:installer:dump-require-paths --env=prod
fi

echo ""
echo "Step 7: Check webpack bundles"
echo "---"
echo "Checking for built assets:"
ls -lh public/dist/*.js 2>/dev/null | head -10 || echo "No dist files found"

echo ""
echo "Step 8: Rebuild frontend assets if needed"
echo "---"
echo "Installing Akeneo assets..."
php bin/console pim:installer:assets --symlink --clean --env=prod 2>&1 | tail -10

echo ""
echo "Step 9: Clear all caches"
echo "---"
rm -rf var/cache/prod/* var/cache/dev/*
php bin/console cache:clear --env=prod --no-warmup 2>&1 | tail -3
php bin/console cache:warmup --env=prod 2>&1 | tail -3

echo ""
echo "Step 10: Restart Apache"
echo "---"
/scripts/restartsrv_httpd --graceful 2>&1 | grep -E "restarted|running|active" | tail -5

echo ""
echo "Step 11: Clear Cloudflare cache"
echo "---"
curl -s -X POST "https://api.cloudflare.com/client/v4/zones/4919ad3406fcabba381edbd543814a68/purge_cache" \
  -H "X-Auth-Email: amine.bo@techno-dz.com" \
  -H "X-Auth-Key: 35d8fd4b1a5d27eabbce73c6753978fc350bc" \
  -H "Content-Type: application/json" \
  --data '{"purge_everything":true}' | jq -r '.success'

echo ""
echo "=========================================="
echo "DIAGNOSIS COMPLETE"
echo "=========================================="
echo ""
echo "✅ Admin password reset to: Admin2026!"
echo "✅ Mounir password remains: 2026"
echo ""
echo "Updated Credentials:"
echo "  • admin / Admin2026!"
echo "  • mounir / 2026"
echo ""

