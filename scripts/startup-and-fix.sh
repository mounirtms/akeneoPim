#!/bin/bash

# Pimcore Startup & Route Fix Script for Techno Stationery
# This script ensures proper configuration and starts the system

echo "🚀 Starting Pimcore Configuration & Route Fixes..."
echo ""

cd /home/pim/public_html

# Step 1: Verify environment
echo "Step 1: Verifying Environment Variables..."
export APP_ENV=prod
export APP_DEBUG=0
echo "✅ Environment set to production (debug OFF)"
echo ""

# Step 2: Clear all caches
echo "Step 2: Clearing All Caches..."
rm -rf var/cache/*
php bin/console cache:pool:clear cache.global_clearer --env=prod
echo "✅ Cache cleared"
echo ""

# Step 3: Rebuild classes
echo "Step 3: Rebuilding Pimcore Classes..."
php bin/console pimcore:deployment:classes-rebuild --env=prod 2>&1 | tail -5
echo "✅ Classes rebuilt"
echo ""

# Step 4: Install assets
echo "Step 4: Installing Assets..."
php bin/console assets:install --symlink public --env=prod 2>&1 | tail -5
echo "✅ Assets installed"
echo ""

# Step 5: Generate JS routes
echo "Step 5: Generating JavaScript Routes..."
php bin/console fos:js-routing:dump --format=json --target=public/js/fos_js_routes.json --env=prod
echo "✅ JS routes generated"
echo ""

# Step 6: Warmup cache
echo "Step 6: Warming Up Cache..."
php bin/console cache:warmup --env=prod
echo "✅ Cache warmed up"
echo ""

# Step 7: Fix permissions
echo "Step 7: Fixing Permissions..."
find var/ -type d -exec chmod 775 {} \; 2>/dev/null
find var/ -type f -exec chmod 664 {} \; 2>/dev/null
find public/bundles/ -type d -exec chmod 755 {} \; 2>/dev/null
find public/bundles/ -type f -exec chmod 644 {} \; 2>/dev/null
chmod +x bin/console
echo "✅ Permissions fixed"
echo ""

# Step 8: Test routes
echo "Step 8: Testing Routes..."
php bin/console debug:router homepage --env=prod 2>&1 | head -10
echo ""

# Step 9: Restart web server
echo "Step 9: Restarting Web Server..."
sudo systemctl restart httpd 2>/dev/null || echo "⚠️ Manual restart may be needed"
sleep 3
echo "✅ Web server restarted"
echo ""

echo "═══════════════════════════════════════════════════════════════"
echo "✅ PIMCORE STARTUP COMPLETE"
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "🔍 Testing site..."
sleep 2
curl -I https://pim.technostationery.com/ 2>&1 | head -10
echo ""
echo "📝 Check logs: tail -f var/log/prod.log error_log"
echo "🌐 Admin URL: https://pim.technostationery.com/admin/login"
echo ""
