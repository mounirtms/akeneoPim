#!/bin/bash

echo "=========================================="
echo "FIND WORKING DB CREDENTIALS & FIX LOGIN"
echo "=========================================="
echo ""

echo "Step 1: Find all possible database configurations"
echo "---"
echo "Checking .env.local:"
if [ -f .env.local ]; then
    grep "DATABASE" .env.local | grep -v "#" || echo "No DATABASE vars"
else
    echo "File not found"
fi

echo ""
echo "Checking config/parameters.yml:"
if [ -f config/parameters.yml ]; then
    grep -E "database_|host:|user:|password:" config/parameters.yml | head -10
else
    echo "File not found"
fi

echo ""
echo "Step 2: Try to connect with various credential combinations"
echo "---"

# Try different credential sets
CREDENTIALS=(
    "root::akeneo_pim"
    "pim:cZ8\$9Bqx&2mK#vP4:pim"
    "akeneo_pim:akeneo_pim:akeneo_pim"
    "pim::pim"
)

for cred in "${CREDENTIALS[@]}"; do
    IFS=':' read -r user pass db <<< "$cred"
    if [ -z "$pass" ]; then
        echo -n "Testing $user@localhost (no password) on $db... "
        if mysql -u "$user" "$db" -e "SELECT 1" &>/dev/null; then
            echo "✅ SUCCESS"
            WORKING_USER="$user"
            WORKING_PASS=""
            WORKING_DB="$db"
            break
        else
            echo "❌"
        fi
    else
        echo -n "Testing $user@localhost on $db... "
        if mysql -u "$user" -p"$pass" "$db" -e "SELECT 1" 2>/dev/null; then
            echo "✅ SUCCESS"
            WORKING_USER="$user"
            WORKING_PASS="$pass"
            WORKING_DB="$db"
            break
        else
            echo "❌"
        fi
    fi
done

if [ -z "$WORKING_USER" ]; then
    echo ""
    echo "⚠️ No working credentials found. Trying to find from running processes..."
    ps aux | grep mysql | head -3
    
    echo ""
    echo "Checking my.cnf files:"
    find /home/pim -name "*.cnf" -o -name "my.cnf" 2>/dev/null | head -5
    
    echo ""
    echo "⚠️ Manual database intervention required."
    echo "Please provide correct MySQL credentials."
    exit 1
fi

echo ""
echo "✅ Working credentials found:"
echo "   User: $WORKING_USER"
echo "   Database: $WORKING_DB"

echo ""
echo "Step 3: Check and update admin user"
echo "---"
if [ -z "$WORKING_PASS" ]; then
    mysql -u "$WORKING_USER" "$WORKING_DB" -e "
    SELECT id, username, email, enabled 
    FROM oro_user 
    WHERE username = 'admin';
    " 2>&1 | grep -v "mysql: \[Warning\]"
else
    mysql -u "$WORKING_USER" -p"$WORKING_PASS" "$WORKING_DB" -e "
    SELECT id, username, email, enabled 
    FROM oro_user 
    WHERE username = 'admin';
    " 2>&1 | grep -v "mysql: \[Warning\]"
fi

echo ""
echo "Step 4: Generate and update password"
echo "---"
NEW_PASSWORD="Admin123!"
NEW_HASH=$(php -r "echo password_hash('$NEW_PASSWORD', PASSWORD_BCRYPT, ['cost' => 13]);")

echo "Generated hash: ${NEW_HASH:0:50}..."

if [ -z "$WORKING_PASS" ]; then
    mysql -u "$WORKING_USER" "$WORKING_DB" -e "
    UPDATE oro_user 
    SET password = '$NEW_HASH',
        enabled = 1,
        login_count = 0
    WHERE username = 'admin';
    
    SELECT 'Password updated successfully' as status;
    " 2>&1 | grep -v "mysql: \[Warning\]"
else
    mysql -u "$WORKING_USER" -p"$WORKING_PASS" "$WORKING_DB" -e "
    UPDATE oro_user 
    SET password = '$NEW_HASH',
        enabled = 1,
        login_count = 0
    WHERE username = 'admin';
    
    SELECT 'Password updated successfully' as status;
    " 2>&1 | grep -v "mysql: \[Warning\]"
fi

echo ""
echo "✅ Password updated to: $NEW_PASSWORD"

echo ""
echo "Step 5: Verify database update"
echo "---"
if [ -z "$WORKING_PASS" ]; then
    mysql -u "$WORKING_USER" "$WORKING_DB" -e "
    SELECT username, email, enabled, 
           SUBSTRING(password, 1, 30) as password_hash
    FROM oro_user 
    WHERE username = 'admin';
    " 2>&1 | grep -v "mysql: \[Warning\]"
else
    mysql -u "$WORKING_USER" -p"$WORKING_PASS" "$WORKING_DB" -e "
    SELECT username, email, enabled,
           SUBSTRING(password, 1, 30) as password_hash
    FROM oro_user 
    WHERE username = 'admin';
    " 2>&1 | grep -v "mysql: \[Warning\]"
fi

echo ""
echo "Step 6: Clear all caches"
echo "---"
rm -rf var/cache/prod/* var/cache/dev/*
php bin/console cache:clear --env=prod 2>&1 | tail -3

echo ""
echo "=========================================="
echo "FINAL STATUS"
echo "=========================================="
echo ""
echo "✅ Database: $WORKING_DB"
echo "✅ Admin credentials updated:"
echo "   Username: admin"
echo "   Password: Admin123!"
echo ""
echo "🧪 Ready for manual testing at:"
echo "   https://pim.technostationery.com/user/login"
echo ""

