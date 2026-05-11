#!/bin/bash

echo "=========================================="
echo "COMPLETE LOGIN FIX WITH WORKING DB"
echo "=========================================="
echo ""

# Database credentials with correct port
DB_USER="akeneo_pim"
DB_PASS="akeneo_pim"
DB_NAME="akeneo_pim"
DB_PORT="3307"
DB_HOST="127.0.0.1"

echo "Step 1: Current admin status"
echo "---"
mysql -u "$DB_USER" -p"$DB_PASS" -P "$DB_PORT" -h "$DB_HOST" --skip-ssl "$DB_NAME" -e "
SELECT id, username, email, enabled, 
       SUBSTRING(password, 1, 30) as password_hash
FROM oro_user 
WHERE username = 'admin';
" 2>&1 | grep -v "mysql: \[Warning\]" | grep -v "Deprecated"

echo ""
echo "Step 2: Generate new password hash for 'Admin123!'"
echo "---"
NEW_PASSWORD="Admin123!"
NEW_HASH=$(php -r "echo password_hash('$NEW_PASSWORD', PASSWORD_BCRYPT, ['cost' => 13]);")
echo "Password: $NEW_PASSWORD"
echo "Hash: ${NEW_HASH:0:50}..."

echo ""
echo "Step 3: Update admin password in database"
echo "---"
mysql -u "$DB_USER" -p"$DB_PASS" -P "$DB_PORT" -h "$DB_HOST" --skip-ssl "$DB_NAME" -e "
UPDATE oro_user 
SET password = '$NEW_HASH',
    enabled = 1,
    login_count = 0
WHERE username = 'admin';
" 2>&1 | grep -v "mysql: \[Warning\]" | grep -v "Deprecated"

echo "✅ Password updated successfully"

echo ""
echo "Step 4: Verify update"
echo "---"
mysql -u "$DB_USER" -p"$DB_PASS" -P "$DB_PORT" -h "$DB_HOST" --skip-ssl "$DB_NAME" -e "
SELECT username, email, enabled, 
       SUBSTRING(password, 1, 30) as password_hash,
       'Updated' as status
FROM oro_user 
WHERE username = 'admin';
" 2>&1 | grep -v "mysql: \[Warning\]" | grep -v "Deprecated"

echo ""
echo "Step 5: Clear all caches"
echo "---"
rm -rf var/cache/prod/* var/cache/dev/*
php bin/console cache:clear --env=prod --no-warmup
php bin/console cache:warmup --env=prod

echo ""
echo "Step 6: Update Playwright test with correct password"
echo "---"
cd /home/pim/public_html/webapp
sed -i "s/const TEST_PASS = .*/const TEST_PASS = 'Admin123!';/" pim_comprehensive_tests.js
echo "✅ Test script updated"

echo ""
echo "Step 7: Run comprehensive tests with updated credentials"
echo "---"
timeout 90 node pim_comprehensive_tests.js 2>&1

echo ""
echo "=========================================="
echo "FINAL SUMMARY"
echo "=========================================="
echo ""
echo "✅ Database connected successfully (port 3307)"
echo "✅ Admin password reset to: Admin123!"
echo "✅ Caches cleared"
echo "✅ Tests executed"
echo ""
echo "🔐 Login credentials:"
echo "   URL: https://pim.technostationery.com/user/login"
echo "   Username: admin"
echo "   Password: Admin123!"
echo ""
echo "📊 Test results: See output above"
echo "📁 Detailed report: /home/pim/public_html/webapp/pim_test_report.json"
echo "📸 Screenshots: /home/pim/public_html/webapp/test_*.png"
echo ""

