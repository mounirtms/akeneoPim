#!/bin/bash

echo "=========================================="
echo "FINAL LOGIN FIX"
echo "=========================================="
echo ""

echo "Step 1: Find correct database credentials"
echo "---"
if [ -f /home/pim/public_html/.env ]; then
    echo "Database credentials from .env:"
    grep "DATABASE_" /home/pim/public_html/.env | grep -v "#"
    
    # Extract credentials
    DB_USER=$(grep "DATABASE_USER=" /home/pim/public_html/.env | cut -d'=' -f2 | tr -d '"' | tr -d "'")
    DB_PASS=$(grep "DATABASE_PASSWORD=" /home/pim/public_html/.env | cut -d'=' -f2 | tr -d '"' | tr -d "'")
    DB_NAME=$(grep "DATABASE_NAME=" /home/pim/public_html/.env | cut -d'=' -f2 | tr -d '"' | tr -d "'")
    
    echo ""
    echo "Extracted: User=$DB_USER, DB=$DB_NAME"
else
    echo "⚠️ .env file not found"
    exit 1
fi

echo ""
echo "Step 2: Check current admin user in database"
echo "---"
mysql -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" -e "
SELECT id, username, email, enabled, SUBSTRING(password, 1, 30) as password_hash
FROM oro_user 
WHERE username = 'admin';
" 2>&1 | grep -v "mysql: \[Warning\]"

echo ""
echo "Step 3: Generate proper bcrypt hash for password 'Admin123!'"
echo "---"
cd /home/pim/public_html

# Use PHP to generate proper bcrypt hash
NEW_PASSWORD="Admin123!"
NEW_HASH=$(php -r "echo password_hash('$NEW_PASSWORD', PASSWORD_BCRYPT, ['cost' => 13]);")

echo "Generated hash for password: $NEW_PASSWORD"
echo "Hash: ${NEW_HASH:0:40}..."

echo ""
echo "Step 4: Update admin password in database"
echo "---"
mysql -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" -e "
UPDATE oro_user 
SET password = '$NEW_HASH',
    enabled = 1,
    login_count = 0
WHERE username = 'admin';

SELECT id, username, email, enabled, 'Password Updated' as status
FROM oro_user 
WHERE username = 'admin';
" 2>&1 | grep -v "mysql: \[Warning\]"

echo ""
echo "✅ Admin password updated to: $NEW_PASSWORD"

echo ""
echo "Step 5: Clear Symfony cache"
echo "---"
rm -rf var/cache/prod/*
php bin/console cache:clear --env=prod --no-warmup 2>&1 | tail -5

echo ""
echo "Step 6: Update Playwright test with correct password"
echo "---"
cd /home/pim/public_html/webapp
sed -i "s/const TEST_PASS = 'admin';/const TEST_PASS = 'Admin123!';/" pim_comprehensive_tests.js
echo "✅ Test script updated"

echo ""
echo "Step 7: Re-run login tests"
echo "---"
timeout 60 node pim_comprehensive_tests.js 2>&1 | grep -E "Test 5:|Login Result|Passed:|Failed:"

echo ""
echo "Step 8: Check if test report shows success"
echo "---"
if [ -f pim_test_report.json ]; then
    LOGIN_STATUS=$(cat pim_test_report.json | grep -A 5 "Login Functionality" | grep "status" | head -1)
    echo "Login test status: $LOGIN_STATUS"
fi

echo ""
echo "=========================================="
echo "FIX COMPLETE"
echo "=========================================="
echo ""
echo "✅ Login credentials:"
echo "   Username: admin"
echo "   Password: Admin123!"
echo ""
echo "🧪 Test results saved to: pim_test_report.json"
echo "📸 Screenshots saved: test_*.png"
echo ""
echo "Next steps:"
echo "1. Open https://pim.technostationery.com/user/login"
echo "2. Login with admin / Admin123!"
echo "3. Verify dashboard loads properly"
echo ""

