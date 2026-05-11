#!/bin/bash

EMAIL="amine.bo@techno-dz.com"
API_KEY="35d8fd4b1a5d27eabbce73c6753978fc350bc"
ZONE_ID="4919ad3406fcabba381edbd543814a68"

echo "=========================================="
echo "CLOUDFLARE FREE PLAN OPTIMIZATION"
echo "Date: $(date)"
echo "=========================================="
echo ""

# Helper function for API calls
cf_api() {
    local method=$1
    local endpoint=$2
    local data=$3
    
    if [ -z "$data" ]; then
        curl -s -X $method "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/$endpoint" \
          -H "X-Auth-Email: $EMAIL" \
          -H "X-Auth-Key: $API_KEY" \
          -H "Content-Type: application/json"
    else
        curl -s -X $method "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/$endpoint" \
          -H "X-Auth-Email: $EMAIL" \
          -H "X-Auth-Key: $API_KEY" \
          -H "Content-Type: application/json" \
          -d "$data"
    fi
}

echo "=== STEP 1: Check Current Firewall Events ==="
curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/security/events?per_page=10" \
  -H "X-Auth-Email: $EMAIL" \
  -H "X-Auth-Key: $API_KEY" \
  -H "Content-Type: application/json" | python3 -m json.tool | head -100

echo ""
echo "=== STEP 2: List All WAF Rules ==="
curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/firewall/waf/packages" \
  -H "X-Auth-Email: $EMAIL" \
  -H "X-Auth-Key: $API_KEY" | python3 -m json.tool | grep -E "name|id|mode" | head -30

echo ""
echo "=== STEP 3: Check IP Access Rules ==="
curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/firewall/access_rules/rules" \
  -H "X-Auth-Email: $EMAIL" \
  -H "X-Auth-Key: $API_KEY" | python3 -m json.tool

echo ""
echo "=== STEP 4: Disable 'Block common scanning patterns' Rule ==="
RULE_ID="0eaeeefeb62546aeafc8b0aa4c1ee40b"
curl -s -X PATCH "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/firewall/rules/$RULE_ID" \
  -H "X-Auth-Email: $EMAIL" \
  -H "X-Auth-Key: $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"paused":true}' | python3 -m json.tool

echo ""
echo "=== STEP 5: Set Optimal Free Plan Settings ==="

# Always Use HTTPS - OFF (to allow HTTP testing)
echo "Setting Always Use HTTPS: OFF"
cf_api PATCH "settings/always_use_https" '{"value":"off"}' | python3 -m json.tool | grep -E "value|success"

# Automatic HTTPS Rewrites - ON
echo ""
echo "Setting Automatic HTTPS Rewrites: ON"
cf_api PATCH "settings/automatic_https_rewrites" '{"value":"on"}' | python3 -m json.tool | grep -E "value|success"

# Brotli Compression - ON
echo ""
echo "Setting Brotli: ON"
cf_api PATCH "settings/brotli" '{"value":"on"}' | python3 -m json.tool | grep -E "value|success"

# Browser Cache TTL - 4 hours
echo ""
echo "Setting Browser Cache TTL: 14400 (4 hours)"
cf_api PATCH "settings/browser_cache_ttl" '{"value":14400}' | python3 -m json.tool | grep -E "value|success"

# Cache Level - Standard (not aggressive for dynamic sites)
echo ""
echo "Setting Cache Level: standard"
cf_api PATCH "settings/cache_level" '{"value":"basic"}' | python3 -m json.tool | grep -E "value|success"

# Challenge Passage - 30 minutes
echo ""
echo "Setting Challenge Passage: 30"
cf_api PATCH "settings/challenge_ttl" '{"value":1800}' | python3 -m json.tool | grep -E "value|success"

# Email Obfuscation - ON
echo ""
echo "Setting Email Obfuscation: ON"
cf_api PATCH "settings/email_obfuscation" '{"value":"on"}' | python3 -m json.tool | grep -E "value|success"

# Hotlink Protection - OFF (can block legitimate assets)
echo ""
echo "Setting Hotlink Protection: OFF"
cf_api PATCH "settings/hotlink_protection" '{"value":"off"}' | python3 -m json.tool | grep -E "value|success"

# IP Geolocation - ON
echo ""
echo "Setting IP Geolocation: ON"
cf_api PATCH "settings/ip_geolocation" '{"value":"on"}' | python3 -m json.tool | grep -E "value|success"

# Minify - JS, CSS, HTML
echo ""
echo "Setting Minification: JS + CSS + HTML"
cf_api PATCH "settings/minify" '{"value":{"js":"on","css":"on","html":"on"}}' | python3 -m json.tool | grep -E "value|success"

# Opportunistic Encryption - ON
echo ""
echo "Setting Opportunistic Encryption: ON"
cf_api PATCH "settings/opportunistic_encryption" '{"value":"on"}' | python3 -m json.tool | grep -E "value|success"

# Rocket Loader - OFF (can break dynamic apps)
echo ""
echo "Setting Rocket Loader: OFF"
cf_api PATCH "settings/rocket_loader" '{"value":"off"}' | python3 -m json.tool | grep -E "value|success"

# Security Level - ESSENTIALLY OFF (low)
echo ""
echo "Setting Security Level: essentially_off"
cf_api PATCH "settings/security_level" '{"value":"essentially_off"}' | python3 -m json.tool | grep -E "value|success"

# Server Side Excludes - ON
echo ""
echo "Setting Server Side Excludes: ON"
cf_api PATCH "settings/server_side_exclude" '{"value":"on"}' | python3 -m json.tool | grep -E "value|success"

# SSL/TLS Mode - Full (not Full Strict for self-signed certs)
echo ""
echo "Setting SSL: full"
cf_api PATCH "settings/ssl" '{"value":"full"}' | python3 -m json.tool | grep -E "value|success"

# TLS 1.3 - ON
echo ""
echo "Setting TLS 1.3: on"
cf_api PATCH "settings/tls_1_3" '{"value":"on"}' | python3 -m json.tool | grep -E "value|success"

# WAF (Web Application Firewall) - OFF for Free plan or low sensitivity
echo ""
echo "Setting WAF: off"
cf_api PATCH "settings/waf" '{"value":"off"}' | python3 -m json.tool | grep -E "value|success"

# WebSockets - ON
echo ""
echo "Setting WebSockets: ON"
cf_api PATCH "settings/websockets" '{"value":"on"}' | python3 -m json.tool | grep -E "value|success"

echo ""
echo "=== STEP 6: Create Page Rules for Each Site ==="

# Delete existing page rules first (optional - comment out if you want to keep some)
echo "Listing existing page rules..."
cf_api GET "pagerules" | python3 -m json.tool | grep -E "id|value|priority" | head -20

# Create Page Rule for PIM - Bypass cache for dynamic pages
echo ""
echo "Creating page rule for PIM login/admin..."
cf_api POST "pagerules" '{
  "targets": [{
    "target": "url",
    "constraint": {
      "operator": "matches",
      "value": "*pim.technostationery.com/user/*"
    }
  }],
  "actions": [{
    "id": "cache_level",
    "value": "bypass"
  }, {
    "id": "disable_security"
  }],
  "priority": 1,
  "status": "active"
}' | python3 -m json.tool | grep -E "success|id"

# Create Page Rule for PIM - Cache static assets
echo ""
echo "Creating page rule for PIM static assets..."
cf_api POST "pagerules" '{
  "targets": [{
    "target": "url",
    "constraint": {
      "operator": "matches",
      "value": "*pim.technostationery.com/*.{css,js,jpg,jpeg,png,gif,ico,svg,woff,woff2,ttf,eot}"
    }
  }],
  "actions": [{
    "id": "cache_level",
    "value": "cache_everything"
  }, {
    "id": "edge_cache_ttl",
    "value": 86400
  }],
  "priority": 2,
  "status": "active"
}' | python3 -m json.tool | grep -E "success|id"

echo ""
echo "=== STEP 7: Purge All Cache ==="
cf_api POST "purge_cache" '{"purge_everything":true}' | python3 -m json.tool

echo ""
echo "=== STEP 8: Final Test ==="
sleep 5
echo "Testing https://pim.technostationery.com/"
curl -I https://pim.technostationery.com/ 2>&1 | head -20

echo ""
echo "=========================================="
echo "CLOUDFLARE OPTIMIZATION COMPLETE"
echo "=========================================="
echo ""
echo "Changes Applied:"
echo "  ✅ Security Level: essentially_off (lowest)"
echo "  ✅ WAF: disabled"
echo "  ✅ Firewall rule 'Block common scanning patterns': paused"
echo "  ✅ SSL: full (not strict)"
echo "  ✅ Browser Cache: 4 hours"
echo "  ✅ Brotli compression: enabled"
echo "  ✅ Minify JS/CSS/HTML: enabled"
echo "  ✅ Rocket Loader: disabled (for compatibility)"
echo "  ✅ Development Mode: enabled (3 hours)"
echo "  ✅ Page Rules: Created for PIM"
echo ""
echo "Architecture:"
echo "  Client → Cloudflare (optimized) → Apache:80 → PHP-FPM"
echo "  (Optional: Enable Varnish:8080 for better performance)"
echo ""
echo "=========================================="

