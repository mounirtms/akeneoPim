#!/bin/bash

echo "=== AKENEO PIM CRITICAL FIXES ==="
echo "Starting at: $(date)"
echo ""

# PHASE 1: Fix File Permissions
echo "### PHASE 1: Fixing File Permissions ###"
echo "Checking current ownership..."
ls -la public/css/pim.css 2>/dev/null || echo "CSS file not found"
ls -la public/bundles/pimui/manifest.json 2>/dev/null || echo "Manifest not found"

echo ""
echo "Fixing ownership to pim:pim..."
chown -R pim:pim public/ 2>&1 | head -5
chown -R pim:pim var/ 2>&1 | head -5
chown -R pim:pim vendor/ 2>&1 | head -5
chown -R pim:pim webapp/ 2>&1 | head -5

echo ""
echo "Setting correct permissions..."
find public/ -type f -exec chmod 644 {} \; 2>&1 | head -3
find public/ -type d -exec chmod 755 {} \; 2>&1 | head -3
find var/ -type f -exec chmod 664 {} \; 2>&1 | head -3
find var/ -type d -exec chmod 775 {} \; 2>&1 | head -3

echo ""
echo "Setting cache/logs permissions..."
chmod -R 777 var/cache/ 2>&1
chmod -R 777 var/logs/ 2>&1

echo ""
echo "Verifying permissions..."
ls -la public/css/pim.css 2>/dev/null
ls -la var/cache/ | head -3

echo ""
echo "✓ Phase 1 Complete"
echo ""

# PHASE 2: Clear Cache
echo "### PHASE 2: Clearing Cache ###"
echo "Removing old cache files..."
rm -rf var/cache/prod/*
rm -rf var/cache/dev/*
echo "✓ Cache cleared"
echo ""

# PHASE 3: Check Database Connection
echo "### PHASE 3: Database Check ###"
php bin/console doctrine:database:connect --env=prod 2>&1 | head -10

echo ""
echo "=== Fix Script Complete at: $(date) ==="
