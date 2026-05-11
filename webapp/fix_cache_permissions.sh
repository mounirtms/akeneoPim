#!/bin/bash

################################################################################
# Akeneo Cache Permission Fix Script
# Purpose: Automatically fix cache and log permissions after cache operations
# Usage: Run this script after any cache:clear or cache:warmup operations
# Date: 2026-04-23
################################################################################

AKENEO_ROOT="/home/pim/public_html"
PIM_USER="pim"
PIM_GROUP="pim"

echo "==================================="
echo "Akeneo Cache Permission Fix"
echo "==================================="
echo "Date: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

# Function to fix directory permissions
fix_permissions() {
    local dir=$1
    local desc=$2
    
    echo "Fixing $desc..."
    
    if [ -d "$dir" ]; then
        sudo chown -R ${PIM_USER}:${PIM_GROUP} "$dir" 2>&1
        sudo chmod -R 775 "$dir" 2>&1
        echo "✓ $desc permissions fixed"
    else
        echo "⚠ $desc directory not found: $dir"
    fi
}

# Check if running from correct location
if [ ! -d "$AKENEO_ROOT" ]; then
    echo "ERROR: Akeneo root directory not found: $AKENEO_ROOT"
    exit 1
fi

cd "$AKENEO_ROOT"

# Fix cache directories
fix_permissions "$AKENEO_ROOT/var/cache" "Cache directory"
fix_permissions "$AKENEO_ROOT/var/logs" "Logs directory"
fix_permissions "$AKENEO_ROOT/var/file_storage" "File storage directory"

# Fix specific cache subdirectories that often have issues
if [ -d "$AKENEO_ROOT/var/cache/prod" ]; then
    fix_permissions "$AKENEO_ROOT/var/cache/prod/oro_acl" "ACL cache"
    fix_permissions "$AKENEO_ROOT/var/cache/prod/oro_acl_annotations" "ACL annotations cache"
    fix_permissions "$AKENEO_ROOT/var/cache/prod/pools" "Cache pools"
    fix_permissions "$AKENEO_ROOT/var/cache/prod/twig" "Twig cache"
fi

# Verify permissions
echo ""
echo "==================================="
echo "Verifying Permissions"
echo "==================================="

# Check cache directory
if [ -d "$AKENEO_ROOT/var/cache/prod" ]; then
    CACHE_OWNER=$(stat -c '%U:%G' "$AKENEO_ROOT/var/cache/prod")
    CACHE_PERMS=$(stat -c '%a' "$AKENEO_ROOT/var/cache/prod")
    echo "Cache directory owner: $CACHE_OWNER (expected: pim:pim)"
    echo "Cache directory permissions: $CACHE_PERMS (expected: 775)"
    
    if [ "$CACHE_OWNER" == "pim:pim" ]; then
        echo "✓ Cache ownership correct"
    else
        echo "✗ Cache ownership incorrect"
    fi
fi

# Check for root-owned files
echo ""
echo "Checking for root-owned files in cache..."
ROOT_FILES=$(find "$AKENEO_ROOT/var/cache/prod" -user root 2>/dev/null | wc -l)
if [ "$ROOT_FILES" -eq 0 ]; then
    echo "✓ No root-owned files found in cache"
else
    echo "⚠ Found $ROOT_FILES root-owned files in cache"
    echo "Fixing root-owned files..."
    sudo chown -R ${PIM_USER}:${PIM_GROUP} "$AKENEO_ROOT/var/cache/prod"
    echo "✓ Root-owned files fixed"
fi

echo ""
echo "==================================="
echo "Cache Permission Fix Complete"
echo "==================================="
echo ""

# Test website
echo "Testing website status..."
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" https://pim.technostationery.com/ 2>&1)
if [ "$HTTP_STATUS" == "302" ] || [ "$HTTP_STATUS" == "200" ]; then
    echo "✓ Website is responding (HTTP $HTTP_STATUS)"
else
    echo "⚠ Website returned HTTP $HTTP_STATUS (expected 200 or 302)"
fi

echo ""
echo "IMPORTANT: Add this script to your deployment workflow!"
echo "Run after: php bin/console cache:clear --env=prod"
echo "Run after: php bin/console cache:warmup --env=prod"
echo ""

exit 0
