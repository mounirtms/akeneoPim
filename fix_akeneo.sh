#!/bin/bash
cd /home/pim/public_html

echo "=== Akeneo PIM Maintenance ==="
echo ""

# Step 1: Clear cache and sessions FIRST
echo "[1/4] Clearing cache and sessions..."
rm -rf var/cache/prod/*
rm -rf var/sessions/*

# Step 2: Rebuild cache (this creates files as current user)
echo "[2/4] Rebuilding cache..."
php bin/console cache:clear --env=prod

# Step 3: NOW fix permissions for Apache (nobody user on cPanel)
echo "[3/4] Fixing permissions..."
chown -R nobody:nobody var/
chmod -R 777 var/
chmod -R 777 public/css/ public/js/ public/media/ public/bundles/ public/dist/

# Step 4: Reinstall assets with correct permissions
echo "[4/4] Installing assets..."
php bin/console pim:installer:assets --symlink --clean --env=prod
chown -R nobody:nobody public/bundles/
chmod -R 777 public/bundles/

echo ""
echo "=== Maintenance Complete! ==="
echo ""
echo "IMPORTANT: Clear your browser cache (Ctrl+Shift+Delete)"
echo "Or use Incognito/Private browsing mode"
echo ""
echo "Access: https://pim.technostationery.com"
echo "Login: admin / Admin123!"
