#!/bin/bash
# Fix Session and Authentication Issues
# Date: 2026-04-25
# Purpose: Resolve stuck login and session persistence problems

echo "=================================="
echo "Session & Authentication Fix"
echo "Started: $(date '+%Y-%m-%d %H:%M:%S')"
echo "=================================="

cd /home/pim/public_html || exit 1

# Step 1: Create proper session directory
echo ""
echo "[1/8] Creating session directory..."
sudo mkdir -p var/cache/prod/sessions
sudo chown -R pim:pim var/cache/prod/sessions
sudo chmod -R 775 var/cache/prod/sessions
echo "✓ Session directory created and permissions set"

# Step 2: Clear all caches
echo ""
echo "[2/8] Clearing all caches..."
sudo rm -rf var/cache/prod/*
echo "✓ Cache cleared"

# Step 3: Clear sessions
echo ""
echo "[3/8] Clearing old sessions..."
sudo find /var/cpanel/php/sessions/ea-php83 -name "sess_*" -mtime +1 -delete 2>/dev/null || true
echo "✓ Old sessions cleared"

# Step 4: Rebuild cache as pim user
echo ""
echo "[4/8] Rebuilding cache as pim user..."
sudo -u pim php bin/console cache:clear --env=prod --no-warmup
sudo -u pim php bin/console cache:warmup --env=prod
echo "✓ Cache rebuilt"

# Step 5: Reinstall assets
echo ""
echo "[5/8] Reinstalling assets..."
sudo -u pim php bin/console assets:install public --symlink --relative --env=prod
echo "✓ Assets installed"

# Step 6: Dump FOS routing
echo ""
echo "[6/8] Dumping FOS JS routing..."
sudo -u pim php bin/console fos:js-routing:dump --format=json --target=public/js/fos_js_routes.json --env=prod
echo "✓ FOS routing dumped"

# Step 7: Fix all permissions
echo ""
echo "[7/8] Fixing all permissions..."
sudo chown -R pim:pim var/cache var/logs var/file_storage public/js public/bundles 2>/dev/null
sudo chmod -R 775 var/cache var/logs var/file_storage 2>/dev/null
sudo chmod -R 755 public/js public/bundles 2>/dev/null
echo "✓ Permissions fixed"

# Step 8: Clear PHP opcache
echo ""
echo "[8/8] Clearing PHP opcache..."
sudo -u pim php -r "if (function_exists('opcache_reset')) { opcache_reset(); echo 'OPcache cleared'; } else { echo 'OPcache not available'; }"
echo ""
echo "✓ OPcache cleared"

echo ""
echo "=================================="
echo "Fix Complete!"
echo "Finished: $(date '+%Y-%m-%d %H:%M:%S')"
echo "=================================="
echo ""
echo "Next: Test login at https://pim.technostationery.com/user/login"
echo "Credentials: admin / PimAdmin2026!"
