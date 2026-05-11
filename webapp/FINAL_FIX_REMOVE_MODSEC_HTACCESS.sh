#!/bin/bash

echo "=========================================="
echo "FINAL FIX - Remove SecRuleEngine from .htaccess"
echo "Date: $(date)"
echo "=========================================="
echo ""

echo "=== STEP 1: Remove ModSecurity Directives from .htaccess ==="
# Backup current .htaccess
cp /home/pim/public_html/.htaccess /home/pim/public_html/.htaccess.backup.$(date +%Y%m%d_%H%M%S)

# Remove ModSecurity lines
sed -i '/# Disable ModSecurity (Phase 11 Fix)/,/<\/IfModule>/d' /home/pim/public_html/.htaccess

echo "✅ Removed SecRuleEngine directives from .htaccess"

echo ""
echo "Current .htaccess content:"
head -30 /home/pim/public_html/.htaccess

echo ""
echo "=== STEP 2: Restart Apache ==="
/scripts/restartsrv_httpd --graceful
sleep 3

echo ""
echo "=== STEP 3: Test External IP Access ==="
echo "Testing direct IP with Host header:"
curl -I -H "Host: pim.technostationery.com" http://205.134.249.177/ 2>&1 | head -15

echo ""
echo "=== STEP 4: Test via Cloudflare ==="
echo "Purging Cloudflare cache..."
curl -s -X POST "https://api.cloudflare.com/client/v4/zones/4919ad3406fcabba381edbd543814a68/purge_cache" \
  -H "X-Auth-Email: amine.bo@techno-dz.com" \
  -H "X-Auth-Key: 35d8fd4b1a5d27eabbce73c6753978fc350bc" \
  -H "Content-Type: application/json" \
  -d '{"purge_everything":true}' | python3 -m json.tool | grep success

echo ""
echo "Waiting 10 seconds for cache purge..."
sleep 10

echo ""
echo "Testing https://pim.technostationery.com/:"
curl -I https://pim.technostationery.com/ 2>&1 | head -20

echo ""
echo "=== STEP 5: Test Localhost (should still work) ==="
curl -I -H "Host: pim.technostationery.com" http://localhost/ 2>&1 | head -10

echo ""
echo "=========================================="
echo "FINAL STATUS CHECK"
echo "=========================================="
echo ""

# Check if we get 200 OK
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -H "Host: pim.technostationery.com" http://205.134.249.177/)
echo "Direct IP HTTP Status Code: $HTTP_CODE"

if [ "$HTTP_CODE" = "200" ]; then
    echo "✅ SUCCESS! Site is accessible from external IP"
elif [ "$HTTP_CODE" = "403" ]; then
    echo "❌ Still getting 403 - ModSecurity may need WHM-level configuration"
elif [ "$HTTP_CODE" = "500" ]; then
    echo "❌ Still getting 500 - Check Apache error log"
else
    echo "⚠️  Unexpected status code: $HTTP_CODE"
fi

echo ""
echo "Services Status:"
echo "  Apache: $(systemctl is-active httpd)"
echo "  Varnish: $(systemctl is-active varnish)"
echo "  PHP-FPM: $(pgrep -c php-fpm) processes"
echo ""
echo "Next Step:"
echo "  Open https://pim.technostationery.com/ in browser"
echo "  Login: admin / Admin123!"
echo ""
echo "=========================================="

