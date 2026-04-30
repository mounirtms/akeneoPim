#!/bin/bash
#
# Akeneo PIM Stabilization Script
# Fixes JavaScript loading issues and stabilizes the application
#

set -e

echo "=================================="
echo "Akeneo PIM Stabilization Script"
echo "Date: $(date '+%Y-%m-%d %H:%M:%S')"
echo "=================================="
echo ""

cd /home/pim/public_html

echo "[1/6] Clearing cache..."
rm -rf var/cache/prod/*
bin/console cache:clear --env=prod --no-debug
echo "✓ Cache cleared"
echo ""

echo "[2/6] Installing assets..."
bin/console assets:install --symlink public
echo "✓ Assets installed"
echo ""

echo "[3/6] Dumping assetic assets..."
bin/console pim:installer:assets --env=prod
echo "✓ Assets dumped"
echo ""

echo "[4/6] Fixing file permissions..."
chown -R pim:pim var/cache/prod/
chmod -R 775 var/cache/prod/
chown -R pim:pim var/logs/
chmod -R 775 var/logs/
echo "✓ Permissions fixed"
echo ""

echo "[5/6] Warming up cache..."
bin/console cache:warmup --env=prod
echo "✓ Cache warmed up"
echo ""

echo "[6/6] Verifying critical files..."
CRITICAL_FILES=(
    "public/dist/jquery.min.js"
    "public/dist/underscore.min.js"
    "public/dist/require.min.js"
    "public/dist/vendor.min.js"
    "public/dist/main.min.js"
)

ALL_EXIST=true
for file in "${CRITICAL_FILES[@]}"; do
    if [ -f "$file" ]; then
        echo "  ✓ $file exists"
    else
        echo "  ✗ $file MISSING"
        ALL_EXIST=false
    fi
done
echo ""

if [ "$ALL_EXIST" = true ]; then
    echo "=================================="
    echo "✅ Stabilization Complete!"
    echo "=================================="
    echo ""
    echo "The Akeneo PIM should now be accessible at:"
    echo "https://pim.technostationery.com"
    echo ""
else
    echo "=================================="
    echo "⚠️  Some files are missing"
    echo "=================================="
    echo ""
    echo "You may need to run: yarn run webpack"
    echo ""
fi

echo "Log file: var/logs/prod.log"
echo "Last 10 errors:"
tail -10 var/logs/prod.log 2>/dev/null | grep -i error || echo "No recent errors found"
echo ""
