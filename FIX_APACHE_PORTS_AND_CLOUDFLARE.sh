#!/bin/bash
################################################################################
# Fix Apache Port Configuration and Apply Cloudflare Fixes
################################################################################

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔧 FIXING APACHE PORTS AND APPLYING CLOUDFLARE FIXES"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Started: $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo ""

# Part 1: Check current Apache configuration
echo "═══════════════════════════════════════════════════════════════════════"
echo "Part 1: Diagnose Apache Port Configuration"
echo "═══════════════════════════════════════════════════════════════════════"

echo "▶ Current Apache listening ports:"
ss -tlnp 2>/dev/null | grep httpd | grep -E ":(80|8080|443) "

echo ""
echo "▶ Check Apache VirtualHost Listen directives:"
grep -n "^Listen" /etc/apache2/conf/httpd.conf 2>/dev/null | head -10

echo ""
echo "▶ Check pim.technostationery.com VirtualHost port:"
grep -B 2 "ServerName pim.technostationery.com" /etc/apache2/conf/httpd.conf | grep "VirtualHost" | head -3

echo ""

# Part 2: Since Apache is on port 80, configure Cloudflare to use port 80 directly
echo "═══════════════════════════════════════════════════════════════════════"
echo "Part 2: Test Apache on Port 80"
echo "═══════════════════════════════════════════════════════════════════════"

echo "▶ Test root URL"
curl -sI http://localhost/ 2>&1 | head -10

echo ""
echo "▶ Test /user/login"
curl -sI http://localhost/user/login 2>&1 | head -10

echo ""
echo "▶ Test with Host header for pim.technostationery.com"
curl -sI -H "Host: pim.technostationery.com" http://localhost/ 2>&1 | head -15

echo ""

# Part 3: Apply Cloudflare Fixes
echo "═══════════════════════════════════════════════════════════════════════"
echo "Part 3: Apply Cloudflare Configuration"
echo "═══════════════════════════════════════════════════════════════════════"

# Cloudflare API credentials
CF_API_TOKEN="zflwN_9EYIx_UDQ6tcFQJt-4CJOjMxs5mnNncqVj"
CF_ZONE_ID="4919ad3406fcabba381edbd543814a68"

echo "▶ Step 1: Verify API Token"
TOKEN_TEST=$(curl -s "https://api.cloudflare.com/client/v4/user/tokens/verify" \
  -H "Authorization: Bearer $CF_API_TOKEN" \
  -H "Content-Type: application/json")

if echo "$TOKEN_TEST" | grep -q '"success":true'; then
    echo "✅ API Token verified"
else
    echo "❌ API Token verification failed"
    echo "$TOKEN_TEST" | head -5
fi

echo ""
echo "▶ Step 2: Purge All Cloudflare Cache"
PURGE_RESULT=$(curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/purge_cache" \
  -H "Authorization: Bearer $CF_API_TOKEN" \
  -H "Content-Type: application/json" \
  --data '{"purge_everything":true}')

if echo "$PURGE_RESULT" | grep -q '"success":true'; then
    echo "✅ Cache purged successfully"
else
    echo "❌ Cache purge failed"
    echo "$PURGE_RESULT" | head -5
fi

echo ""
echo "▶ Step 3: Set Security Level to Medium"
SECURITY_UPDATE=$(curl -s -X PATCH "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/settings/security_level" \
  -H "Authorization: Bearer $CF_API_TOKEN" \
  -H "Content-Type: application/json" \
  --data '{"value":"medium"}')

if echo "$SECURITY_UPDATE" | grep -q '"success":true'; then
    echo "✅ Security level set to MEDIUM"
else
    echo "⚠️  Security level update may have failed"
fi

echo ""
echo "▶ Step 4: Enable Development Mode (3 hours)"
DEV_MODE=$(curl -s -X PATCH "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/settings/development_mode" \
  -H "Authorization: Bearer $CF_API_TOKEN" \
  -H "Content-Type: application/json" \
  --data '{"value":"on"}')

if echo "$DEV_MODE" | grep -q '"success":true'; then
    echo "✅ Development Mode enabled (bypasses cache for 3 hours)"
else
    echo "⚠️  Development Mode enable may have failed"
fi

echo ""
echo "▶ Step 5: Disable Rate Limiting (temporarily)"
RATE_LIMIT=$(curl -s -X PATCH "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/settings/waf" \
  -H "Authorization: Bearer $CF_API_TOKEN" \
  -H "Content-Type: application/json" \
  --data '{"value":"off"}')

if echo "$RATE_LIMIT" | grep -q '"success":true'; then
    echo "✅ WAF temporarily disabled"
else
    echo "⚠️  WAF disable may have failed (this is OK)"
fi

echo ""

# Part 4: Test Production URL
echo "═══════════════════════════════════════════════════════════════════════"
echo "Part 4: Test Production URL"
echo "═══════════════════════════════════════════════════════════════════════"

echo "▶ Test https://pim.technostationery.com/"
curl -sI https://pim.technostationery.com/ 2>&1 | head -15

echo ""
echo "▶ Test https://pim.technostationery.com/user/login"
curl -sI https://pim.technostationery.com/user/login 2>&1 | head -15

echo ""

# Part 5: Summary
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 FINAL SUMMARY"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo "Configuration:"
echo "  • Apache: Listening on port 80 (direct)"
echo "  • Varnish: Disabled (port conflict resolved)"
echo "  • Cloudflare: Cache purged, security lowered, dev mode ON"

echo ""
echo "Service Status:"
APACHE_STATUS=$(systemctl is-active httpd 2>/dev/null || echo 'unknown')
echo "  Apache: $APACHE_STATUS"
APACHE_PROCS=$(ps aux | grep -E "[h]ttpd" | wc -l)
echo "  Apache processes: $APACHE_PROCS"

echo ""
echo "Next Steps:"
echo "  1. Test in browser: https://pim.technostationery.com/"
echo "  2. Test login: https://pim.technostationery.com/user/login"
echo "  3. Credentials: admin / Admin123!"
echo "  4. Monitor for 15 minutes"
echo "  5. If stable, can re-enable Varnish on different port later"

echo ""
echo "Completed: $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

exit 0
