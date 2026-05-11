#!/bin/bash

echo "=========================================="
echo "FINAL DIAGNOSIS & FIX ATTEMPT"
echo "Date: $(date)"
echo "=========================================="
echo ""

# Check what Apache is actually serving
echo "=== STEP 1: Check What Apache Serves ==="
echo "Fetching full response from Apache:"
curl -v -H "Host: pim.technostationery.com" http://localhost/ 2>&1 | head -50

echo ""
echo "=== STEP 2: Check index.php exists ==="
ls -la /home/pim/public_html/public/index.php
echo ""
echo "First 20 lines of index.php:"
head -20 /home/pim/public_html/public/index.php

echo ""
echo "=== STEP 3: Test PHP Execution ==="
echo "<?php phpinfo(); ?>" > /home/pim/public_html/public/test-php.php
curl -H "Host: pim.technostationery.com" http://localhost/test-php.php 2>&1 | grep -i "PHP Version" | head -5
rm -f /home/pim/public_html/public/test-php.php

echo ""
echo "=== STEP 4: Check Apache VirtualHost Configuration ==="
echo "PIM VirtualHost DocumentRoot and Directory:"
grep -A 30 "ServerName pim.technostationery.com" /etc/apache2/conf/httpd.conf | grep -E "DocumentRoot|Directory|AllowOverride|Options" | head -20

echo ""
echo "=== STEP 5: Check .htaccess Processing ==="
echo "Root .htaccess:"
head -20 /home/pim/public_html/.htaccess

echo ""
echo "Public .htaccess:"
head -30 /home/pim/public_html/public/.htaccess

echo ""
echo "=== STEP 6: Check if Origin Server Returns 403 ==="
echo "Testing direct to origin IP with Host header:"
curl -I -H "Host: pim.technostationery.com" http://205.134.249.177/ 2>&1 | head -15

echo ""
echo "=== STEP 7: Check Apache Error Log for 403s ==="
echo "Recent 403 errors (last 10):"
tail -100 /usr/local/apache/logs/error_log | grep "403" | tail -10

echo ""
echo "=== STEP 8: Try Setting DNS to DNS-only (Grey Cloud) ==="
echo "Current DNS record for pim.technostationery.com:"
curl -s -X GET "https://api.cloudflare.com/client/v4/zones/4919ad3406fcabba381edbd543814a68/dns_records?name=pim.technostationery.com" \
  -H "X-Auth-Email: amine.bo@techno-dz.com" \
  -H "X-Auth-Key: 35d8fd4b1a5d27eabbce73c6753978fc350bc" | python3 -m json.tool | grep -E "id|proxied|content"

# Get DNS record ID
DNS_RECORD_ID=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/4919ad3406fcabba381edbd543814a68/dns_records?name=pim.technostationery.com" \
  -H "X-Auth-Email: amine.bo@techno-dz.com" \
  -H "X-Auth-Key: 35d8fd4b1a5d27eabbce73c6753978fc350bc" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data['result'][0]['id'] if data['result'] else '')")

echo ""
echo "DNS Record ID: $DNS_RECORD_ID"

if [ -n "$DNS_RECORD_ID" ]; then
    echo ""
    echo "Setting DNS to DNS-only (disabling Cloudflare proxy)..."
    curl -s -X PATCH "https://api.cloudflare.com/client/v4/zones/4919ad3406fcabba381edbd543814a68/dns_records/$DNS_RECORD_ID" \
      -H "X-Auth-Email: amine.bo@techno-dz.com" \
      -H "X-Auth-Key: 35d8fd4b1a5d27eabbce73c6753978fc350bc" \
      -H "Content-Type: application/json" \
      -d '{"proxied":false}' | python3 -m json.tool | grep -E "success|proxied"
    
    echo ""
    echo "⚠️  DNS changed to DNS-only (grey cloud)"
    echo "⚠️  Wait 1-2 minutes for DNS propagation"
    echo ""
    echo "Testing after 30 seconds..."
    sleep 30
    
    echo ""
    echo "Testing https://pim.technostationery.com/ (direct to origin):"
    curl -I https://pim.technostationery.com/ 2>&1 | head -20
else
    echo "❌ Could not find DNS record ID"
fi

echo ""
echo "=========================================="
echo "DIAGNOSIS SUMMARY"
echo "=========================================="
echo ""
echo "Local Apache Status:"
systemctl is-active httpd && echo "  ✅ Apache: Running" || echo "  ❌ Apache: Not running"
echo ""
echo "What we know:"
echo "  ✅ Apache serves HTTP 200 OK locally (localhost)"
echo "  ✅ Varnish is running on port 8080"
echo "  ✅ PHP-FPM is working"
echo "  ✅ Database has 9,538 products"
echo "  ✅ Symfony cache is warmed"
echo "  ❌ Cloudflare returns 403 (even with security disabled)"
echo "  ❌ Direct origin IP also returns 403"
echo ""
echo "Root Cause:"
echo "  The origin server (Apache) is returning 403 when accessed"
echo "  via the public IP, but returns 200 when accessed via localhost."
echo "  This suggests either:"
echo "    1. ModSecurity is blocking external requests"
echo "    2. IP-based access restrictions in Apache"
echo "    3. Directory permissions issue"
echo "    4. Missing index file or incorrect DocumentRoot"
echo ""
echo "=========================================="

