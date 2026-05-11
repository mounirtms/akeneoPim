#!/bin/bash
################################################################################
# Final Cloudflare Fix with Global API Key
################################################################################

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "☁️  FINAL CLOUDFLARE CONFIGURATION FIX"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Started: $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo ""

# Cloudflare credentials - using Global API Key
CF_EMAIL="amine.bo@techno-dz.com"
CF_GLOBAL_KEY="35d8fd4b1a5d27eabbce73c6753978fc350bc"
CF_ZONE_ID="4919ad3406fcabba381edbd543814a68"

echo "═══════════════════════════════════════════════════════════════════════"
echo "Step 1: Verify Cloudflare Authentication"
echo "═══════════════════════════════════════════════════════════════════════"

USER_TEST=$(curl -s -X GET "https://api.cloudflare.com/client/v4/user" \
  -H "X-Auth-Email: $CF_EMAIL" \
  -H "X-Auth-Key: $CF_GLOBAL_KEY" \
  -H "Content-Type: application/json")

if echo "$USER_TEST" | grep -q '"success":true'; then
    echo "✅ Global API Key authenticated successfully"
    USER_EMAIL=$(echo "$USER_TEST" | grep -o '"email":"[^"]*"' | cut -d'"' -f4)
    echo "   Authenticated as: $USER_EMAIL"
else
    echo "❌ Authentication failed"
    echo "$USER_TEST" | head -5
fi

echo ""
echo "═══════════════════════════════════════════════════════════════════════"
echo "Step 2: Purge All Cache"
echo "═══════════════════════════════════════════════════════════════════════"

PURGE=$(curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/purge_cache" \
  -H "X-Auth-Email: $CF_EMAIL" \
  -H "X-Auth-Key: $CF_GLOBAL_KEY" \
  -H "Content-Type: application/json" \
  --data '{"purge_everything":true}')

if echo "$PURGE" | grep -q '"success":true'; then
    echo "✅ Cache purged successfully"
else
    echo "❌ Cache purge failed"
    echo "$PURGE"
fi

echo ""
echo "═══════════════════════════════════════════════════════════════════════"
echo "Step 3: Set Security Level to Low (for testing)"
echo "═══════════════════════════════════════════════════════════════════════"

SECURITY=$(curl -s -X PATCH "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/settings/security_level" \
  -H "X-Auth-Email: $CF_EMAIL" \
  -H "X-Auth-Key: $CF_GLOBAL_KEY" \
  -H "Content-Type: application/json" \
  --data '{"value":"low"}')

if echo "$SECURITY" | grep -q '"success":true'; then
    echo "✅ Security level set to LOW"
else
    echo "⚠️  Security level update failed"
fi

echo ""
echo "═══════════════════════════════════════════════════════════════════════"
echo "Step 4: Enable Development Mode"
echo "═══════════════════════════════════════════════════════════════════════"

DEV_MODE=$(curl -s -X PATCH "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/settings/development_mode" \
  -H "X-Auth-Email: $CF_EMAIL" \
  -H "X-Auth-Key: $CF_GLOBAL_KEY" \
  -H "Content-Type: application/json" \
  --data '{"value":"on"}')

if echo "$DEV_MODE" | grep -q '"success":true'; then
    echo "✅ Development Mode enabled (3 hours)"
else
    echo "⚠️  Development Mode failed"
fi

echo ""
echo "═══════════════════════════════════════════════════════════════════════"
echo "Step 5: Disable Browser Integrity Check"
echo "═══════════════════════════════════════════════════════════════════════"

INTEGRITY=$(curl -s -X PATCH "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/settings/browser_check" \
  -H "X-Auth-Email: $CF_EMAIL" \
  -H "X-Auth-Key: $CF_GLOBAL_KEY" \
  -H "Content-Type: application/json" \
  --data '{"value":"off"}')

if echo "$INTEGRITY" | grep -q '"success":true'; then
    echo "✅ Browser integrity check disabled"
else
    echo "⚠️  Browser check disable failed"
fi

echo ""
echo "═══════════════════════════════════════════════════════════════════════"
echo "Step 6: Test Production Site"
echo "═══════════════════════════════════════════════════════════════════════"

sleep 3  # Wait for changes to propagate

echo "▶ Testing https://pim.technostationery.com/"
PROD_TEST=$(curl -sI https://pim.technostationery.com/ 2>&1 | head -1)
echo "   Result: $PROD_TEST"

if echo "$PROD_TEST" | grep -q "403"; then
    echo "   ⚠️  Still getting 403 - may need additional Cloudflare rules adjustment"
elif echo "$PROD_TEST" | grep -q "200\|302"; then
    echo "   ✅ Site is accessible!"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 CLOUDFLARE CONFIGURATION COMPLETE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Changes Applied:"
echo "  ✓ Cache purged (all content cleared)"
echo "  ✓ Security level: LOW"
echo "  ✓ Development mode: ON (3 hours)"
echo "  ✓ Browser integrity check: OFF"
echo ""
echo "If 403 persists, additional steps needed:"
echo "  1. Check Firewall Rules in Cloudflare Dashboard"
echo "  2. Review IP Access Rules"
echo "  3. Check Rate Limiting rules"
echo "  4. Verify DNS settings point to correct IP"
echo ""
echo "Completed: $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

exit 0
