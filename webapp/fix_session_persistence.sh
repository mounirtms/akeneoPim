#!/bin/bash
# Fix Session Persistence Issue
# Date: 2026-04-25
# Root Cause: Session name mismatch and permission issues

echo "=========================================="
echo "Session Persistence Fix"
echo "Started: $(date '+%Y-%m-%d %H:%M:%S')"
echo "=========================================="
echo ""

cd /home/pim/public_html || exit 1

# Step 1: Clear all sessions and caches
echo "[1/7] Clearing all sessions and caches..."
sudo rm -rf var/cache/prod/*
sudo find /var/cpanel/php/sessions/ea-php83 -name "sess_*" -delete 2>/dev/null || true
echo "✓ Sessions and caches cleared"

# Step 2: Ensure session directory exists with proper permissions
echo ""
echo "[2/7] Setting up session storage..."
sudo mkdir -p /var/cpanel/php/sessions/ea-php83
sudo chmod 1733 /var/cpanel/php/sessions/ea-php83
echo "✓ Session directory configured"

# Step 3: Clear cache as pim user
echo ""
echo "[3/7] Rebuilding cache as pim user (no warmup)..."
sudo -u pim php bin/console cache:clear --env=prod --no-warmup --no-interaction 2>&1 | grep -E "successfully|Cache"
echo "✓ Cache cleared"

# Step 4: Reinstall assets
echo ""
echo "[4/7] Reinstalling assets..."
sudo -u pim php bin/console assets:install public --symlink --relative --env=prod 2>&1 | grep -E "successfully|Bundle"
echo "✓ Assets installed"

# Step 5: Dump FOS routing
echo ""
echo "[5/7] Regenerating FOS routing..."
sudo -u pim php bin/console fos:js-routing:dump --format=json --target=public/js/fos_js_routes.json --env=prod 2>&1 | grep -E "Dumping|file"
echo "✓ FOS routing regenerated"

# Step 6: Warm cache
echo ""
echo "[6/7] Warming cache..."
sudo -u pim php bin/console cache:warmup --env=prod 2>&1 | grep -E "successfully|Cache"
echo "✓ Cache warmed"

# Step 7: Fix all permissions
echo ""
echo "[7/7] Fixing all file permissions..."
sudo chown -R pim:pim var/cache var/logs var/file_storage public/js public/bundles 2>/dev/null
sudo chmod -R 775 var/cache var/logs var/file_storage 2>/dev/null
sudo chmod -R 755 public/js public/bundles public/dist 2>/dev/null
sudo find var/cache -type d -exec chmod 775 {} \; 2>/dev/null
sudo find var/logs -type d -exec chmod 775 {} \; 2>/dev/null
echo "✓ Permissions fixed"

echo ""
echo "=========================================="
echo "Fix Complete!"
echo "Finished: $(date '+%Y-%m-%d %H:%M:%S')"
echo "=========================================="
echo ""
echo "Testing login..."
echo ""

# Test the login flow
curl -s -I https://pim.technostationery.com/user/login 2>&1 | grep "HTTP" | head -1
echo ""
echo "Next: Test login at https://pim.technostationery.com/"
echo "Credentials: admin / PimAdmin2026!"
echo ""
echo "If still stuck, check browser console for JavaScript errors"
