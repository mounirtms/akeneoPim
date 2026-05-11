#!/bin/bash

echo "======================================="
echo "Clearing All Caches"
echo "======================================="
echo ""

# 1. Symfony cache
echo "1. Clearing Symfony cache (prod)..."
rm -rf var/cache/prod/*
bin/console cache:clear --env=prod --no-warmup
bin/console cache:warmup --env=prod
echo "✓ Symfony cache cleared"

# 2. OPcache
echo ""
echo "2. Clearing OPcache..."
echo "<?php opcache_reset(); echo 'OPcache cleared'; ?>" > public/clear_opcache.php
curl -s https://pim.technostationery.com/clear_opcache.php
rm -f public/clear_opcache.php
echo ""
echo "✓ OPcache cleared"

# 3. File permissions
echo ""
echo "3. Fixing file permissions..."
chown -R pim:pim public/js/extensions.json
chmod 644 public/js/extensions.json
echo "✓ Permissions fixed"

# 4. Verify critical files
echo ""
echo "4. Verifying critical files..."
ls -lh public/js/extensions.json | awk '{print "  extensions.json: " $5}'
ls -lh public/js/requirejs-config.js | awk '{print "  requirejs-config.js: " $5}'
ls -lh public/css/pim.css | awk '{print "  pim.css: " $5}'

echo ""
echo "======================================="
echo "Cache clearing completed!"
echo "======================================="
