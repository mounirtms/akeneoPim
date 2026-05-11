#!/bin/bash

echo "╔════════════════════════════════════════════════════════════╗"
echo "║    CLOUDFLARE CACHE PURGE & COMPREHENSIVE TEST            ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# Correct Cloudflare credentials
CF_API_TOKEN="zflwN_9EYIx_UDQ6tcFQJt-4CJOjMxs5mnNncqVj"
CF_ZONE_ID="4919ad3406fcabba381edbd543814a68"

# Step 1: Verify API token
echo "Step 1: Verifying Cloudflare API token..."
TOKEN_TEST=$(curl -s "https://api.cloudflare.com/client/v4/user/tokens/verify" \
  -H "Authorization: Bearer $CF_API_TOKEN" \
  -H "Content-Type: application/json")

if echo "$TOKEN_TEST" | grep -q '"success":true'; then
    echo "✅ API Token verified successfully"
else
    echo "❌ API Token verification failed:"
    echo "$TOKEN_TEST" | jq
    exit 1
fi
echo ""

# Step 2: Purge all cache
echo "Step 2: Purging ALL Cloudflare cache..."
PURGE_RESULT=$(curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/purge_cache" \
  -H "Authorization: Bearer $CF_API_TOKEN" \
  -H "Content-Type: application/json" \
  --data '{"purge_everything":true}')

if echo "$PURGE_RESULT" | grep -q '"success":true'; then
    echo "✅ Cache purged successfully"
else
    echo "❌ Cache purge failed:"
    echo "$PURGE_RESULT" | jq
fi
echo ""

# Step 3: Purge specific URLs
echo "Step 3: Purging specific files..."
PURGE_FILES=$(curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/purge_cache" \
  -H "Authorization: Bearer $CF_API_TOKEN" \
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

if echo "$PURGE_FILES" | grep -q '"success":true'; then
    echo "✅ Specific files purged"
else
    echo "⚠️  File purge status:"
    echo "$PURGE_FILES" | jq -r '.success'
fi
echo ""

# Step 4: Try to enable Development Mode
echo "Step 4: Attempting to enable Development Mode..."
DEV_MODE=$(curl -s -X PATCH "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/settings/development_mode" \
  -H "Authorization: Bearer $CF_API_TOKEN" \
  -H "Content-Type: application/json" \
  --data '{"value":"on"}')

if echo "$DEV_MODE" | grep -q '"success":true'; then
    echo "✅ Development Mode enabled (bypasses cache for 3 hours)"
else
    echo "⚠️  Development Mode not available (likely free plan limitation)"
fi
echo ""

# Step 5: Update cache buster
echo "Step 5: Updating cache buster..."
NEW_BUSTER="$(date +%Y%m%d_%H%M%S)"
TEMPLATE="/home/pim/public_html/src/AppBundle/Resources/views/PimUI/index.html.twig"
sed -i "s/cache_buster = \"[^\"]*\"/cache_buster = \"$NEW_BUSTER\"/" "$TEMPLATE"
echo "✓ Cache buster: $NEW_BUSTER"
echo ""

# Step 6: Clear Symfony cache
echo "Step 6: Clearing Symfony cache..."
cd /home/pim/public_html
rm -rf var/cache/prod/*
php bin/console cache:warmup --env=prod --no-debug 2>&1 | tail -3
echo "✓ Symfony cache cleared"
echo ""

# Step 7: Wait for propagation
echo "Step 7: Waiting 15 seconds for cache purge to propagate..."
sleep 15
echo "✓ Wait complete"
echo ""

# Step 8: Check cache headers
echo "Step 8: Verifying cache status..."
HEADERS=$(curl -sI "https://pim.technostationery.com/user/login" | grep -i "cf-cache-status\|age:" | head -2)
echo "$HEADERS"
echo ""

echo "╔════════════════════════════════════════════════════════════╗"
echo "║           CLOUDFLARE CACHE PURGE COMPLETE                  ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "✅ All cache purge operations completed"
echo "✅ Cache buster updated to: $NEW_BUSTER"
echo "✅ Ready for testing"
echo ""

