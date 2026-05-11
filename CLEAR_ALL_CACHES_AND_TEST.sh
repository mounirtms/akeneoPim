#!/bin/bash

echo "╔════════════════════════════════════════════════════════════╗"
echo "║   COMPREHENSIVE CACHE CLEAR (ALL LAYERS) & FINAL TEST     ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# Step 1: Clear Varnish cache (if running)
echo "Step 1: Clearing Varnish cache..."
if systemctl is-active --quiet varnish; then
    echo "Varnish is running, clearing cache..."
    systemctl restart varnish
    echo "✅ Varnish restarted (cache cleared)"
else
    echo "ℹ️  Varnish not running or not installed"
fi
echo ""

# Step 2: Ban all cached content from Varnish (alternative method)
echo "Step 2: Attempting Varnish ban command..."
if command -v varnishadm &> /dev/null; then
    varnishadm "ban req.url ~ ." 2>/dev/null && echo "✅ Varnish ban executed" || echo "ℹ️  Varnish ban not available"
else
    echo "ℹ️  varnishadm not available"
fi
echo ""

# Step 3: Clear Apache cache modules
echo "Step 3: Clearing Apache cache..."
if [ -d "/var/cache/httpd" ]; then
    rm -rf /var/cache/httpd/*
    echo "✅ Apache cache cleared"
else
    echo "ℹ️  Apache cache directory not found"
fi
echo ""

# Step 4: Clear Symfony cache (again)
echo "Step 4: Clearing Symfony cache..."
cd /home/pim/public_html
rm -rf var/cache/*
php bin/console cache:clear --env=prod --no-warmup
php bin/console cache:warmup --env=prod --no-debug
echo "✅ Symfony cache cleared and warmed"
echo ""

# Step 5: Restart PHP-FPM to clear OpCache
echo "Step 5: Restarting PHP-FPM..."
systemctl restart ea-php83-php-fpm
echo "✅ PHP-FPM restarted"
echo ""

# Step 6: Reload Apache
echo "Step 6: Reloading Apache..."
systemctl reload httpd
echo "✅ Apache reloaded"
echo ""

# Step 7: Check what's actually being served
echo "Step 7: Checking login page source..."
echo ""
echo "Fetching first 500 characters of login page HTML..."
RESPONSE=$(curl -s "https://pim.technostationery.com/user/login?nocache=$(date +%s)")
echo "$RESPONSE" | head -c 500
echo ""
echo ""

# Check for jQuery verification in the HTML
if echo "$RESPONSE" | grep -q "jQuery loaded successfully"; then
    echo "✅ Template fix is in the HTML (jQuery verification found)"
else
    echo "❌ Template fix NOT in the HTML (jQuery verification missing)"
    echo ""
    echo "Checking template file..."
    if grep -q "jQuery loaded successfully" src/AppBundle/Resources/views/PimUI/index.html.twig; then
        echo "✅ Template file contains the fix"
        echo "⚠️  But it's not being served - possible Varnish/Apache cache issue"
    else
        echo "❌ Template file missing the fix - need to re-apply"
    fi
fi
echo ""

# Step 8: Direct test to confirm server-side is working
echo "Step 8: Testing jQuery direct (bypass all caches)..."
DIRECT_TEST=$(curl -s "https://pim.technostationery.com/test-jquery-direct.html?t=$(date +%s)" | grep -o "jQuery loaded! Version: [0-9.]*")
if [ -n "$DIRECT_TEST" ]; then
    echo "✅ $DIRECT_TEST"
else
    echo "⚠️  Direct test response unclear"
fi
echo ""

echo "╔════════════════════════════════════════════════════════════╗"
echo "║              ALL CACHES CLEARED                            ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "Next: Running automated Playwright test..."
echo ""

