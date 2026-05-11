#!/bin/bash

# CloudFlare API credentials
ZONE_ID="4919ad3406fcabba381edbd543814a68"
API_TOKEN="zflwN_9EYIx_UDQ6tcFQJt-4CJOjMxs5mnNncqVj"

echo "======================================="
echo "CloudFlare Cache Purge"
echo "======================================="
echo ""

# Verify API token
echo "1. Verifying API token..."
TOKEN_CHECK=$(curl -s "https://api.cloudflare.com/client/v4/user/tokens/verify" \
  -H "Authorization: Bearer $API_TOKEN")

echo "$TOKEN_CHECK" | jq '.'

if echo "$TOKEN_CHECK" | jq -e '.success == true' > /dev/null; then
  echo "✓ API token is valid"
else
  echo "✗ API token verification failed"
  exit 1
fi

echo ""
echo "2. Purging ALL cache for zone $ZONE_ID..."

PURGE_RESULT=$(curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/purge_cache" \
  -H "Authorization: Bearer $API_TOKEN" \
  -H "Content-Type: application/json" \
  --data '{"purge_everything":true}')

echo "$PURGE_RESULT" | jq '.'

if echo "$PURGE_RESULT" | jq -e '.success == true' > /dev/null; then
  echo ""
  echo "✓ CloudFlare cache purged successfully!"
  echo "✓ Waiting 5 seconds for propagation..."
  sleep 5
  echo ""
  echo "3. Testing CSS file accessibility..."
  echo ""
  
  # Test CSS file
  curl -I https://pim.technostationery.com/css/pim.css
  
  echo ""
  echo "======================================="
  echo "Cache purge completed!"
  echo "======================================="
else
  echo "✗ Cache purge failed"
  exit 1
fi
