#!/bin/bash

echo "=== PHASE 2: ACL Security System Fix ==="
echo ""

# Check if database is accessible
echo "Testing database connection..."
php bin/console doctrine:query:sql "SELECT 1" --env=prod 2>&1 | head -5

echo ""
echo "Checking for users..."
php bin/console doctrine:query:sql "SELECT username, email FROM oro_user LIMIT 5" --env=prod 2>&1

echo ""
echo "Checking ACL tables..."
php bin/console doctrine:query:sql "SHOW TABLES LIKE '%acl%'" --env=prod 2>&1 | head -10

echo ""
echo "Clearing Symfony cache..."
php bin/console cache:clear --env=prod 2>&1 | tail -20

echo ""
echo "Warming up cache..."
php bin/console cache:warmup --env=prod 2>&1 | tail -10

echo ""
echo "=== ACL Fix Complete ==="
