#!/bin/bash

echo "=========================================="
echo "FORCING COMPLETE CACHE CLEAR"
echo "=========================================="
echo ""

# Step 1: Update cache buster in template
echo "Step 1: Updating cache buster parameter..."
TEMPLATE="/home/pim/public_html/src/AppBundle/Resources/views/PimUI/index.html.twig"
NEW_CACHE_BUSTER="20260508_$(date +%H%M%S)"
sed -i "s/cache_buster = \"[^\"]*\"/cache_buster = \"$NEW_CACHE_BUSTER\"/" "$TEMPLATE"
echo "✓ Cache buster updated to: $NEW_CACHE_BUSTER"
grep "cache_buster" "$TEMPLATE" | head -1
echo ""

# Step 2: Clear ALL Symfony caches
echo "Step 2: Clearing ALL Symfony caches..."
rm -rf var/cache/prod/* var/cache/dev/* var/cache/test/*
echo "✓ Deleted cache directories"

php bin/console cache:clear --env=prod --no-warmup
php bin/console cache:clear --env=dev --no-warmup
php bin/console cache:warmup --env=prod
echo "✓ Symfony caches cleared and warmed"
echo ""

# Step 3: Clear Twig cache specifically
echo "Step 3: Clearing Twig template cache..."
find var/cache -type f -name "*twig*" -delete
echo "✓ Twig cache cleared"
echo ""

# Step 4: Clear APC/OpCache if available
echo "Step 4: Clearing PHP OpCache..."
php -r "if (function_exists('opcache_reset')) { opcache_reset(); echo 'OpCache cleared\n'; } else { echo 'OpCache not available\n'; }"
echo ""

# Step 5: Restart PHP-FPM
echo "Step 5: Restarting PHP-FPM..."
systemctl restart ea-php83-php-fpm 2>&1 | head -3
echo "✓ PHP-FPM restarted"
echo ""

# Step 6: Graceful Apache reload
echo "Step 6: Reloading Apache..."
systemctl reload httpd
echo "✓ Apache reloaded"
echo ""

# Step 7: Purge Cloudflare cache (multiple methods)
echo "Step 7: Purging Cloudflare cache..."

# Method 1: Purge everything
ZONE_ID="4919ad3406fcabba381edbd543814a68"
TOKEN="mxga48kVXklB6E2jvE-SZxWXMC_S50g5Zl4Py5hS"

RESULT=$(curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/purge_cache" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  --data '{"purge_everything":true}')

echo "Purge all result: $(echo $RESULT | jq -r '.success')"

# Method 2: Purge specific files
curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/purge_cache" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  --data '{
    "files": [
      "https://pim.technostationery.com/",
      "https://pim.technostationery.com/user/login",
      "https://pim.technostationery.com/dist/vendor.min.js",
      "https://pim.technostationery.com/dist/main.min.js",
      "https://pim.technostationery.com/dist/jquery.min.js"
    ]
  }' > /dev/null

echo "✓ Specific files purged"
echo ""

# Step 8: Verify template is correct
echo "Step 8: Verifying template fix..."
if grep -q "jQuery loaded successfully" "$TEMPLATE"; then
    echo "✅ Template contains jQuery verification check"
else
    echo "❌ Template missing jQuery verification check"
fi

if grep -q "window.\$ = window.jQuery = jQuery" "$TEMPLATE"; then
    echo "✅ Template contains global scope assignment"
else
    echo "❌ Template missing global scope assignment"
fi
echo ""

# Step 9: Test jQuery availability directly
echo "Step 9: Testing jQuery file availability..."
JQUERY_STATUS=$(curl -I -s https://pim.technostationery.com/dist/jquery.min.js | grep -i "HTTP" | head -1)
echo "jQuery status: $JQUERY_STATUS"

if echo "$JQUERY_STATUS" | grep -q "200"; then
    echo "✅ jQuery file is accessible"
else
    echo "❌ jQuery file returned non-200 status"
fi
echo ""

# Step 10: Create a direct test page
echo "Step 10: Creating direct jQuery test page..."
cat > public/test-jquery-direct.html << 'EOFHTML'
<!DOCTYPE html>
<html>
<head>
    <title>jQuery Direct Test</title>
    <meta http-equiv="Cache-Control" content="no-cache, no-store, must-revalidate">
    <meta http-equiv="Pragma" content="no-cache">
    <meta http-equiv="Expires" content="0">
</head>
<body>
    <h1>jQuery Loading Test</h1>
    <div id="results"></div>
    
    <script>
        function log(msg) {
            console.log(msg);
            document.getElementById('results').innerHTML += '<p>' + msg + '</p>';
        }
        
        log('1. Starting test...');
        log('2. typeof jQuery before load: ' + typeof jQuery);
    </script>
    
    <script src="/dist/jquery.min.js"></script>
    
    <script>
        log('3. typeof jQuery after load: ' + typeof jQuery);
        
        if (typeof jQuery !== 'undefined') {
            log('✅ SUCCESS: jQuery loaded! Version: ' + jQuery.fn.jquery);
            log('4. typeof $: ' + typeof $);
            log('5. typeof window.jQuery: ' + typeof window.jQuery);
        } else {
            log('❌ FAILED: jQuery not loaded!');
        }
    </script>
</body>
</html>
EOFHTML

chown pim:pim public/test-jquery-direct.html
chmod 644 public/test-jquery-direct.html
echo "✓ Test page created: https://pim.technostationery.com/test-jquery-direct.html"
echo ""

echo "=========================================="
echo "CACHE CLEAR COMPLETE"
echo "=========================================="
echo ""
echo "Next steps:"
echo "1. Wait 60 seconds for caches to settle"
echo "2. Test in browser (use Incognito mode)"
echo "3. URL: https://pim.technostationery.com/test-jquery-direct.html"
echo "4. Then test login: https://pim.technostationery.com/user/login"
echo ""
echo "Browser cache clear (REQUIRED):"
echo "  - Chrome: Ctrl+Shift+Delete → Clear cached images and files"
echo "  - Or use Incognito: Ctrl+Shift+N"
echo ""
echo "Cache buster updated to: $NEW_CACHE_BUSTER"
echo ""

