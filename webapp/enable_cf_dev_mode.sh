#!/bin/bash

echo "=========================================="
echo "ENABLING CLOUDFLARE DEVELOPMENT MODE"
echo "=========================================="
echo ""

ZONE_ID="4919ad3406fcabba381edbd543814a68"
TOKEN="mxga48kVXklB6E2jvE-SZxWXMC_S50g5Zl4Py5hS"

echo "Enabling Development Mode for 3 hours..."
echo ""

RESULT=$(curl -s -X PATCH "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/settings/development_mode" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  --data '{"value":"on"}')

SUCCESS=$(echo "$RESULT" | jq -r '.success')
VALUE=$(echo "$RESULT" | jq -r '.result.value')
TIME_REMAINING=$(echo "$RESULT" | jq -r '.result.time_remaining')

if [ "$SUCCESS" = "true" ]; then
    echo "✅ Development Mode ENABLED"
    echo "   Status: $VALUE"
    echo "   Time remaining: ${TIME_REMAINING} seconds ($(($TIME_REMAINING / 60)) minutes)"
    echo ""
    echo "This bypasses all Cloudflare caching for 3 hours."
    echo ""
else
    echo "❌ Failed to enable Development Mode"
    echo "$RESULT" | jq
fi

echo ""
echo "=========================================="
echo "READY FOR TESTING"
echo "=========================================="
echo ""
echo "Test URLs (cache bypassed):"
echo "  1. https://pim.technostationery.com/test-jquery-direct.html"
echo "  2. https://pim.technostationery.com/user/login"
echo ""
echo "Credentials: mounir / 2026"
echo ""

