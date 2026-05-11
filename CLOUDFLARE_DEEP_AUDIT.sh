#!/bin/bash
################################################################################
# Deep Cloudflare Audit - Find Real Blocking Issue
################################################################################

CF_EMAIL="amine.bo@techno-dz.com"
CF_KEY="35d8fd4b1a5d27eabbce73c6753978fc350bc"
CF_ZONE="4919ad3406fcabba381edbd543814a68"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "☁️  DEEP CLOUDFLARE AUDIT"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo "▶ Step 1: Check Zone Settings"
curl -s "https://api.cloudflare.com/client/v4/zones/$CF_ZONE/settings" \
  -H "X-Auth-Email: $CF_EMAIL" \
  -H "X-Auth-Key: $CF_KEY" | \
  grep -o '"id":"[^"]*","value":"[^"]*"' | head -20

echo ""
echo "▶ Step 2: Check Firewall Rules"
curl -s "https://api.cloudflare.com/client/v4/zones/$CF_ZONE/firewall/rules" \
  -H "X-Auth-Email: $CF_EMAIL" \
  -H "X-Auth-Key: $CF_KEY" | \
  python3 -m json.tool 2>/dev/null | grep -A 5 -B 5 "description\|action\|expression" | head -50

echo ""
echo "▶ Step 3: Check DNS Records"
curl -s "https://api.cloudflare.com/client/v4/zones/$CF_ZONE/dns_records" \
  -H "X-Auth-Email: $CF_EMAIL" \
  -H "X-Auth-Key: $CF_KEY" | \
  grep -o '"name":"[^"]*","type":"[^"]*","content":"[^"]*","proxied":[^,]*' | grep "pim\|dashboard\|lms"

echo ""
echo "▶ Step 4: Check WAF Managed Rules"
curl -s "https://api.cloudflare.com/client/v4/zones/$CF_ZONE/firewall/waf/packages" \
  -H "X-Auth-Email: $CF_EMAIL" \
  -H "X-Auth-Key: $CF_KEY" | \
  grep -o '"name":"[^"]*","sensitivity":"[^"]*"' | head -10

echo ""
echo "▶ Step 5: Check Security Level"
curl -s "https://api.cloudflare.com/client/v4/zones/$CF_ZONE/settings/security_level" \
  -H "X-Auth-Email: $CF_EMAIL" \
  -H "X-Auth-Key: $CF_KEY" | \
  grep -o '"value":"[^"]*"'

echo ""
echo "▶ Step 6: Check SSL/TLS Mode"
curl -s "https://api.cloudflare.com/client/v4/zones/$CF_ZONE/settings/ssl" \
  -H "X-Auth-Email: $CF_EMAIL" \
  -H "X-Auth-Key: $CF_KEY" | \
  grep -o '"value":"[^"]*"'

echo ""
echo "▶ Step 7: Test Direct Origin Access (Bypass Cloudflare)"
echo "Testing: http://205.134.249.177/ with Host header"
curl -sI -H "Host: pim.technostationery.com" http://205.134.249.177/ | head -10

echo ""
echo "▶ Step 8: Test with Cloudflare"
curl -sI https://pim.technostationery.com/ | head -15

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
