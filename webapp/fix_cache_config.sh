#!/bin/bash
# Fix Akeneo Cache Configuration Issues
# Date: 2026-05-01

LOG_FILE="logs/cache_fix_$(date +%Y%m%d_%H%M%S).log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "========================================"
echo "FIXING AKENEO CACHE CONFIGURATION"
echo "Date: $(date)"
echo "========================================"
echo ""

cd /home/pim/public_html

# Backup current config
echo "Step 1: Backup current configuration"
if [ -f "config/packages/cache.yaml" ]; then
    cp config/packages/cache.yaml config/packages/cache.yaml.backup.$(date +%Y%m%d_%H%M%S)
    echo "✓ Backed up cache.yaml"
fi

# Check for problematic cache configuration
echo ""
echo "Step 2: Identify problematic cache pools"
grep -n "cache.app\|cache.system" config/packages/*.yaml 2>/dev/null || echo "No explicit cache.app or cache.system found"

# Clear cache completely
echo ""
echo "Step 3: Clear all cache"
rm -rf var/cache/prod/* 2>/dev/null
echo "✓ Removed prod cache"

# Rebuild cache
echo ""
echo "Step 4: Rebuild cache"
php bin/console cache:clear --env=prod --no-warmup 2>&1 | tail -10
php bin/console cache:warmup --env=prod 2>&1 | tail -10

# Test console commands
echo ""
echo "Step 5: Verify console accessibility"
php bin/console --version --env=prod 2>&1
if [ $? -eq 0 ]; then
    echo "✓ Console working"
else
    echo "✗ Console still has issues"
fi

# Test product indexing
echo ""
echo "Step 6: Test product indexing"
php bin/console pim:product:index --all --env=prod 2>&1 | tail -15

echo ""
echo "========================================"
echo "CACHE FIX COMPLETE"
echo "========================================"
echo "Log: $LOG_FILE"
