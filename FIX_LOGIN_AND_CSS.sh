#!/bin/bash

echo "=========================================="
echo "FIX LOGIN CREDENTIALS & CSS"
echo "Date: $(date)"
echo "=========================================="
echo ""

echo "=== STEP 1: Reset Admin Password ==="
cd /home/pim/public_html

# Reset admin password to Admin123!
bin/console pim:user:create admin admin@example.com Admin Admin --admin -n --env=prod 2>&1 || true

echo ""
echo "Updating admin password..."
bin/console pim:user:create-user admin admin@example.com Admin Admin Admin123! --admin -n --env=prod 2>&1 || true

# Alternative: Direct MySQL update
echo ""
echo "Setting password via MySQL..."
mysql -u root <<EOF
USE akeneo_pim;
UPDATE oro_user SET password = '\$2y\$13\$FqQVXF3pIKQv8vGvZ1KTIuMGdmQQq3d.eTKQVQj5L8YfZL3hLz4Zu', salt = 'abcdefghij' WHERE username = 'admin';
UPDATE oro_user SET enabled = 1 WHERE username = 'admin';
EOF

echo "✅ Admin password reset attempted"

echo ""
echo "=== STEP 2: Find Correct Akeneo CSS Files ==="
echo "Searching for Akeneo CSS files..."

# Find all CSS files in vendor/akeneo
find vendor/akeneo/pim-community-dev -name "*.css" -type f | head -20

echo ""
echo "Looking for main PIM CSS in public/bundles..."
find public/bundles -name "*pim*.css" -type f | head -20

echo ""
echo "=== STEP 3: Install/Update Assets ==="
echo "Installing Akeneo assets..."
bin/console pim:installer:assets --symlink --clean --env=prod 2>&1 | tail -20

echo ""
echo "Installing Fomantic UI assets..."
bin/console fos:js-routing:dump --env=prod 2>&1

echo ""
echo "=== STEP 4: Clear All Caches ==="
rm -rf var/cache/prod/*
bin/console cache:clear --env=prod --no-warmup
bin/console cache:warmup --env=prod

echo ""
echo "=== STEP 5: Check Asset Files ==="
echo "Checking public/bundles/pimui/css..."
ls -lah public/bundles/pimui/css/ 2>/dev/null | head -10

echo ""
echo "Checking public/css..."
ls -lah public/css/ 2>/dev/null | head -10

echo ""
echo "=== STEP 6: Verify Admin User in Database ==="
mysql -u root akeneo_pim -e "SELECT id, username, email, enabled FROM oro_user WHERE username = 'admin';"

echo ""
echo "=========================================="
echo "CREDENTIALS & CSS FIX SUMMARY"
echo "=========================================="
echo ""
echo "Admin credentials should now be:"
echo "  Username: admin"
echo "  Password: Admin123!"
echo ""
echo "Next: Run Playwright tests to verify login and UI"
echo ""
echo "=========================================="

