#!/bin/bash

echo "=== Creating Test Admin User ==="

# Create a fresh admin user
php bin/console pim:user:create \
  testuser \
  test@example.com \
  Test \
  User \
  testpassword \
  --admin \
  --env=prod 2>&1 | tail -10

echo ""
echo "Username: testuser"
echo "Password: testpassword"
echo ""
