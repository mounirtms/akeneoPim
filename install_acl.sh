#!/bin/bash

echo "=== Installing ACL Security System ==="
echo ""

echo "Step 1: Check current database schema..."
php bin/console doctrine:schema:validate --env=prod 2>&1 | grep -i "schema\|sync\|drop\|create" | head -10

echo ""
echo "Step 2: Installing ACL tables..."
php bin/console oro:security:acl:load --env=prod 2>&1 | tail -30

echo ""
echo "Step 3: Checking if ACL tables now exist..."
php bin/console doctrine:query:sql "SHOW TABLES" --env=prod 2>&1 | grep -i acl

echo ""
echo "Step 4: Clearing cache after ACL install..."
rm -rf var/cache/*
php bin/console cache:clear --env=prod 2>&1 | tail -5

echo ""
echo "=== ACL Installation Complete ==="
