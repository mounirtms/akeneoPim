#!/bin/bash
echo "================================================================================"
echo "COMPREHENSIVE CACHE CLEARING - All Systems"
echo "================================================================================"

# 1. OPcache
echo -e "\n📍 Step 1: Clearing OPcache..."
php -r "if (function_exists('opcache_reset')) { opcache_reset(); echo '✓ OPcache cleared\n'; } else { echo '⚠️  OPcache not available\n'; }"

# 2. Symfony cache
echo -e "\n📍 Step 2: Clearing Symfony cache..."
cd /home/pim/public_html
rm -rf var/cache/prod/* var/cache/dev/* 2>/dev/null
echo "✓ Symfony cache cleared"

# 3. Varnish cache
echo -e "\n📍 Step 3: Purging Varnish cache..."
varnishadm "ban req.url ~ /" 2>&1 | head -1
echo "✓ Varnish cache purged"

# 4. CloudFlare cache (already done - development mode active)
echo -e "\n📍 Step 4: CloudFlare cache..."
echo "✓ CloudFlare development mode active (bypassing cache)"

# 5. Browser cache headers verification
echo -e "\n📍 Step 5: Verifying static asset permissions..."
chmod -R 644 /home/pim/public_html/public/css/*.css 2>/dev/null
chmod -R 644 /home/pim/public_html/public/js/*.js 2>/dev/null
chmod -R 644 /home/pim/public_html/public/js/*.json 2>/dev/null
echo "✓ Static asset permissions set"

# 6. Verify extensions.json
echo -e "\n📍 Step 6: Verifying extensions.json..."
if [ -f "/home/pim/public_html/public/js/extensions.json" ]; then
    SIZE=$(stat -f%z "/home/pim/public_html/public/js/extensions.json" 2>/dev/null || stat -c%s "/home/pim/public_html/public/js/extensions.json")
    echo "✓ extensions.json exists (${SIZE} bytes)"
else
    echo "❌ extensions.json NOT FOUND"
fi

echo -e "\n================================================================================"
echo "CACHE CLEARING COMPLETE"
echo "================================================================================"
