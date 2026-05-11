#!/bin/bash

# CloudFlare API credentials
ZONE_ID="4919ad3406fcabba381edbd543814a68"
EMAIL="webmaster@techno-dz.com"
GLOBAL_KEY="35d8fd4b1a5d27eabbce73c6753978fc350bc"

echo "======================================="
echo "CloudFlare Cache Purge (Global API Key)"
echo "======================================="
echo ""

echo "1. Purging ALL cache for zone $ZONE_ID..."

PURGE_RESULT=$(curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/purge_cache" \
  -H "X-Auth-Email: $EMAIL" \
  -H "X-Auth-Key: $GLOBAL_KEY" \
  -H "Content-Type: application/json" \
  --data '{"purge_everything":true}')

echo "$PURGE_RESULT" | jq '.'

if echo "$PURGE_RESULT" | jq -e '.success == true' > /dev/null; then
  echo ""
  echo "✓ CloudFlare cache purged successfully!"
  echo "✓ Waiting 5 seconds for propagation..."
  sleep 5
  echo ""
  echo "2. Testing critical files..."
  echo ""
  
  echo "CSS file:"
  curl -I https://pim.technostationery.com/css/pim.css 2>&1 | head -5
  
  echo ""
  echo "RequireJS config:"
  curl -I https://pim.technostationery.com/js/requirejs-config.js 2>&1 | head -5
  
  echo ""
  echo "======================================="
  echo "Cache purge completed!"
  echo "======================================="
else
  echo "✗ Cache purge failed"
  echo "Error details:"
  echo "$PURGE_RESULT" | jq '.errors'
fi
