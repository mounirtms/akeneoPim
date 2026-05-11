#!/bin/bash

################################################################################
# Phase 1.1: Fix JavaScript Routing Errors
# Purpose: Rebuild frontend assets to fix routing bug
# Date: 2026-04-23
################################################################################

echo "=========================================="
echo "PHASE 1.1: Fixing JavaScript Routing Errors"
echo "=========================================="
echo "Date: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

cd /home/pim/public_html

# Step 1: Clear old assets
echo "Step 1: Clearing old frontend assets..."
rm -rf public/bundles/*
rm -rf public/css/*
rm -rf public/js/*
echo "✓ Old assets cleared"
echo ""

# Step 2: Clear Symfony cache
echo "Step 2: Clearing Symfony cache..."
php bin/console cache:clear --env=prod --no-warmup
echo "✓ Cache cleared"
echo ""

# Step 3: Rebuild frontend assets
echo "Step 3: Rebuilding frontend assets..."
php bin/console pim:installer:assets --symlink --clean --env=prod
echo "✓ Assets rebuilt"
echo ""

# Step 4: Warm up cache
echo "Step 4: Warming up cache..."
php bin/console cache:warmup --env=prod
echo "✓ Cache warmed up"
echo ""

# Step 5: Fix permissions
echo "Step 5: Fixing permissions..."
bash webapp/fix_cache_permissions.sh 2>&1 | tail -5
echo ""

# Step 6: Test website
echo "Step 6: Testing website..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" https://pim.technostationery.com/ 2>&1)
if [ "$HTTP_CODE" == "302" ] || [ "$HTTP_CODE" == "200" ]; then
    echo "✓ Website is responding (HTTP $HTTP_CODE)"
else
    echo "⚠ Website returned HTTP $HTTP_CODE"
fi

echo ""
echo "=========================================="
echo "Phase 1.1 Complete"
echo "=========================================="
echo ""
echo "Next steps:"
echo "1. Test product edit page: https://pim.technostationery.com/enrich/product/"
echo "2. Test import page: https://pim.technostationery.com/collect/import/"
echo "3. Test export page: https://pim.technostationery.com/spread/export/"
echo "4. Check logs for routing errors: tail -f var/logs/prod.log | grep 'function'"
echo ""

exit 0
