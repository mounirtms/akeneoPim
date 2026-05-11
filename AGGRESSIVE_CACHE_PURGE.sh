#!/bin/bash

echo "╔════════════════════════════════════════════════════════════╗"
echo "║       AGGRESSIVE CLOUDFLARE CACHE PURGE & TEST            ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

ZONE_ID="4919ad3406fcabba381edbd543814a68"
TOKEN="mxga48kVXklB6E2jvE-SZxWXMC_S50g5Zl4Py5hS"

# Step 1: Verify API token
echo "Step 1: Verifying Cloudflare API token..."
TOKEN_VERIFY=$(curl -s -X GET "https://api.cloudflare.com/client/v4/user/tokens/verify" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json")

TOKEN_STATUS=$(echo "$TOKEN_VERIFY" | jq -r '.success')
if [ "$TOKEN_STATUS" = "true" ]; then
    echo "✅ API token is valid"
    echo "   Token ID: $(echo "$TOKEN_VERIFY" | jq -r '.result.id')"
else
    echo "❌ API token verification failed:"
    echo "$TOKEN_VERIFY" | jq
    exit 1
fi
echo ""

# Step 2: Purge everything (method 1)
echo "Step 2: Purging all cache (purge_everything=true)..."
PURGE1=$(curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/purge_cache" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  --data '{"purge_everything":true}')

PURGE1_SUCCESS=$(echo "$PURGE1" | jq -r '.success')
echo "Result: $PURGE1_SUCCESS"
if [ "$PURGE1_SUCCESS" = "true" ]; then
    echo "✅ Full cache purged successfully"
else
    echo "❌ Purge failed:"
    echo "$PURGE1" | jq
fi
echo ""

# Step 3: Purge specific files (method 2)
echo "Step 3: Purging specific files..."
PURGE2=$(curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/purge_cache" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  --data '{
    "files": [
      "https://pim.technostationery.com/",
      "https://pim.technostationery.com/user/login",
      "https://pim.technostationery.com/dist/vendor.min.js",
      "https://pim.technostationery.com/dist/main.min.js",
      "https://pim.technostationery.com/dist/jquery.min.js",
      "https://pim.technostationery.com/css/pim.css"
    ]
  }')

PURGE2_SUCCESS=$(echo "$PURGE2" | jq -r '.success')
echo "Result: $PURGE2_SUCCESS"
if [ "$PURGE2_SUCCESS" = "true" ]; then
    echo "✅ Specific files purged successfully"
else
    echo "❌ File purge failed:"
    echo "$PURGE2" | jq
fi
echo ""

# Step 4: Enable Development Mode (bypass cache for 3 hours)
echo "Step 4: Enabling Development Mode (3 hours)..."
DEV_MODE=$(curl -s -X PATCH "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/settings/development_mode" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  --data '{"value":"on"}')

DEV_MODE_SUCCESS=$(echo "$DEV_MODE" | jq -r '.success')
if [ "$DEV_MODE_SUCCESS" = "true" ]; then
    DEV_MODE_VALUE=$(echo "$DEV_MODE" | jq -r '.result.value')
    DEV_MODE_TIME=$(echo "$DEV_MODE" | jq -r '.result.time_remaining')
    echo "✅ Development Mode: $DEV_MODE_VALUE"
    echo "   Time remaining: ${DEV_MODE_TIME} seconds ($(($DEV_MODE_TIME / 60)) minutes)"
    echo "   This bypasses ALL caching for 3 hours"
else
    echo "⚠️  Development Mode not enabled (may not be available on free plan)"
    echo "$DEV_MODE" | jq -r '.errors[0].message' 2>/dev/null || echo "Check plan limitations"
fi
echo ""

# Step 5: Wait for propagation
echo "Step 5: Waiting 10 seconds for cache purge to propagate..."
sleep 10
echo "✓ Wait complete"
echo ""

# Step 6: Verify cache headers
echo "Step 6: Checking cache headers..."
echo ""
echo "Login page cache status:"
CACHE_STATUS=$(curl -sI "https://pim.technostationery.com/user/login" | grep -i "cf-cache-status\|cache-control\|age")
echo "$CACHE_STATUS"
echo ""

# Step 7: Update cache buster one more time
echo "Step 7: Updating cache buster timestamp..."
NEW_BUSTER="$(date +%Y%m%d_%H%M%S)"
TEMPLATE="/home/pim/public_html/src/AppBundle/Resources/views/PimUI/index.html.twig"
sed -i "s/cache_buster = \"[^\"]*\"/cache_buster = \"$NEW_BUSTER\"/" "$TEMPLATE"
echo "✓ Cache buster updated to: $NEW_BUSTER"
echo ""

# Step 8: Clear Symfony cache again
echo "Step 8: Clearing Symfony cache..."
cd /home/pim/public_html
rm -rf var/cache/prod/*
php bin/console cache:warmup --env=prod --no-debug > /dev/null 2>&1
echo "✓ Symfony cache cleared"
echo ""

echo "╔════════════════════════════════════════════════════════════╗"
echo "║              CACHE PURGE COMPLETE                          ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "Summary:"
echo "  - API token: ✅ Valid"
echo "  - Full cache purge: $PURGE1_SUCCESS"
echo "  - File purge: $PURGE2_SUCCESS"
echo "  - Development mode: $DEV_MODE_SUCCESS"
echo "  - Cache buster: $NEW_BUSTER"
echo ""
echo "Cache should now be completely cleared!"
echo "Proceeding to tests..."
echo ""

