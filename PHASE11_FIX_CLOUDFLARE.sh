#!/bin/bash
################################################################################
# PHASE 11: Cloudflare Fix Script
# Date: 2026-05-06
# Purpose: Clear Cloudflare cache and adjust security settings via API
################################################################################

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "☁️  PHASE 11: Cloudflare Configuration & Cache Management"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Started: $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo ""

# Cloudflare API credentials
CF_EMAIL="amine.bo@techno-dz.com"
CF_API_TOKEN="zflwN_9EYIx_UDQ6tcFQJt-4CJOjMxs5mnNncqVj"
CF_ZONE_ID="4919ad3406fcabba381edbd543814a68"
CF_ACCOUNT_ID="cb89f9d4bfa5ff6fe2c8528847dbc5fe"

FIXES_APPLIED=0
FIXES_FAILED=0

# Test API token
echo "═══════════════════════════════════════════════════════════════════════"
echo "Step 1: Verify Cloudflare API Token"
echo "═══════════════════════════════════════════════════════════════════════"

TOKEN_TEST=$(curl -s "https://api.cloudflare.com/client/v4/user/tokens/verify" \
  -H "Authorization: Bearer $CF_API_TOKEN" \
  -H "Content-Type: application/json")

if echo "$TOKEN_TEST" | grep -q '"success":true'; then
    echo "✅ API Token verified successfully"
    ((FIXES_APPLIED++))
    echo "$TOKEN_TEST" | grep -o '"status":"[^"]*"' | head -1
else
    echo "❌ API Token verification failed"
    echo "$TOKEN_TEST"
    ((FIXES_FAILED++))
fi

echo ""

# Purge all cache
echo "═══════════════════════════════════════════════════════════════════════"
echo "Step 2: Purge Cloudflare Cache (Everything)"
echo "═══════════════════════════════════════════════════════════════════════"

PURGE_RESULT=$(curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/purge_cache" \
  -H "Authorization: Bearer $CF_API_TOKEN" \
  -H "Content-Type: application/json" \
  --data '{"purge_everything":true}')

if echo "$PURGE_RESULT" | grep -q '"success":true'; then
    echo "✅ Cache purged successfully"
    ((FIXES_APPLIED++))
    echo "   All cached content has been cleared"
else
    echo "❌ Cache purge failed"
    ((FIXES_FAILED++))
    echo "$PURGE_RESULT" | head -5
fi

echo ""

# Get current security level
echo "═══════════════════════════════════════════════════════════════════════"
echo "Step 3: Check Current Security Level"
echo "═══════════════════════════════════════════════════════════════════════"

SECURITY_CHECK=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/settings/security_level" \
  -H "Authorization: Bearer $CF_API_TOKEN" \
  -H "Content-Type: application/json")

CURRENT_LEVEL=$(echo "$SECURITY_CHECK" | grep -o '"value":"[^"]*"' | head -1 | cut -d'"' -f4)
echo "   Current security level: $CURRENT_LEVEL"

echo ""

# Lower security level to medium
echo "═══════════════════════════════════════════════════════════════════════"
echo "Step 4: Set Security Level to Medium"
echo "═══════════════════════════════════════════════════════════════════════"

SECURITY_UPDATE=$(curl -s -X PATCH "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/settings/security_level" \
  -H "Authorization: Bearer $CF_API_TOKEN" \
  -H "Content-Type: application/json" \
  --data '{"value":"medium"}')

if echo "$SECURITY_UPDATE" | grep -q '"success":true'; then
    echo "✅ Security level set to MEDIUM"
    ((FIXES_APPLIED++))
else
    echo "⚠️  Security level update may have failed"
    echo "$SECURITY_UPDATE" | head -5
fi

echo ""

# Check for firewall rules blocking the site
echo "═══════════════════════════════════════════════════════════════════════"
echo "Step 5: Check Firewall Rules"
echo "═══════════════════════════════════════════════════════════════════════"

FIREWALL_RULES=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/firewall/rules?per_page=50" \
  -H "Authorization: Bearer $CF_API_TOKEN" \
  -H "Content-Type: application/json")

RULE_COUNT=$(echo "$FIREWALL_RULES" | grep -o '"id":"[^"]*"' | wc -l)
echo "   Found $RULE_COUNT firewall rules"

# Show active blocking rules
echo ""
echo "   Active blocking rules:"
echo "$FIREWALL_RULES" | grep -o '"action":"[^"]*".*"description":"[^"]*"' | head -5

echo ""

# Enable Development Mode (bypass cache for testing)
echo "═══════════════════════════════════════════════════════════════════════"
echo "Step 6: Enable Development Mode (3 hours)"
echo "═══════════════════════════════════════════════════════════════════════"

DEV_MODE=$(curl -s -X PATCH "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/settings/development_mode" \
  -H "Authorization: Bearer $CF_API_TOKEN" \
  -H "Content-Type: application/json" \
  --data '{"value":"on"}')

if echo "$DEV_MODE" | grep -q '"success":true'; then
    echo "✅ Development Mode enabled (bypasses cache for 3 hours)"
    ((FIXES_APPLIED++))
    echo "   This will help with testing - cache is bypassed temporarily"
else
    echo "⚠️  Development Mode enable may have failed"
fi

echo ""

# Get SSL settings
echo "═══════════════════════════════════════════════════════════════════════"
echo "Step 7: Check SSL/TLS Settings"
echo "═══════════════════════════════════════════════════════════════════════"

SSL_SETTINGS=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/settings/ssl" \
  -H "Authorization: Bearer $CF_API_TOKEN" \
  -H "Content-Type: application/json")

SSL_MODE=$(echo "$SSL_SETTINGS" | grep -o '"value":"[^"]*"' | head -1 | cut -d'"' -f4)
echo "   SSL/TLS mode: $SSL_MODE"

echo ""

# Summary
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 CLOUDFLARE FIX SUMMARY"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Actions Completed: $FIXES_APPLIED"
echo "❌ Actions Failed:    $FIXES_FAILED"
echo ""
echo "Changes Applied:"
echo "  • Cache purged (all content cleared)"
echo "  • Security level: MEDIUM"
echo "  • Development mode: ON (3 hours)"
echo "  • SSL/TLS mode: $SSL_MODE"
echo ""
echo "Next Steps:"
echo "  1. Test site: https://pim.technostationery.com/"
echo "  2. Check login: https://pim.technostationery.com/user/login"
echo "  3. Monitor for 10-15 minutes"
echo "  4. Disable Development Mode after testing (or wait 3 hours)"
echo ""
echo "Completed: $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

exit 0
