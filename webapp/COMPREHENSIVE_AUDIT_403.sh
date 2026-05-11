#!/bin/bash

echo "=========================================="
echo "COMPREHENSIVE 403 AUDIT"
echo "Date: $(date)"
echo "=========================================="
echo ""

# 1. Check if origin server is blocking
echo "=== 1. DIRECT ORIGIN SERVER TEST ==="
echo "Testing direct IP access to all sites..."

# Get server IP
SERVER_IP=$(curl -s ifconfig.me)
echo "Server IP: $SERVER_IP"

# Test each site directly
for site in pim.technostationery.com technostationery.com www.technostationery.com dashboard.technostationery.com lms.technostationery.com; do
    echo ""
    echo "Testing $site on direct IP..."
    curl -I -H "Host: $site" http://$SERVER_IP/ 2>&1 | head -20
done

echo ""
echo "=== 2. APACHE VIRTUALHOST CONFIGURATION ==="
httpd -S 2>&1 | grep -A 5 "technostationery"

echo ""
echo "=== 3. CHECK APACHE ACCESS RESTRICTIONS ==="
echo "Checking .htaccess files for deny/block rules..."
find /home/pim/public_html -name ".htaccess" -exec echo "File: {}" \; -exec grep -i "deny\|forbidden\|403\|require" {} \; 2>/dev/null

echo ""
echo "=== 4. CHECK APACHE ERROR LOGS ==="
echo "Recent 403 errors from Apache:"
tail -50 /usr/local/apache/logs/error_log | grep -i "403\|forbidden" | tail -20

echo ""
echo "=== 5. CHECK DOCUMENT ROOT PERMISSIONS ==="
ls -la /home/pim/public_html/ | head -20
ls -la /home/pim/public_html/public/ 2>/dev/null | head -20

echo ""
echo "=== 6. CHECK PHP-FPM CONFIGURATION ==="
ps aux | grep php-fpm | grep -v grep | head -5
ls -la /opt/cpanel/ea-php*/root/etc/php-fpm.d/ 2>/dev/null | head -10

echo ""
echo "=== 7. CHECK APACHE MODULES ==="
httpd -M 2>&1 | grep -i "rewrite\|access\|authz"

echo ""
echo "=== 8. CHECK CPANEL/WHM SECURITY ==="
echo "Checking for cPanelguard or ModSecurity..."
httpd -M 2>&1 | grep -i "security\|modsec"

echo ""
echo "=== 9. CLOUDFLARE DNS RECORDS ==="
curl -s -X GET "https://api.cloudflare.com/client/v4/zones/4919ad3406fcabba381edbd543814a68/dns_records" \
  -H "X-Auth-Email: amine.bo@techno-dz.com" \
  -H "X-Auth-Key: 35d8fd4b1a5d27eabbce73c6753978fc350bc" \
  -H "Content-Type: application/json" | python3 -m json.tool 2>/dev/null | grep -A 10 "pim.technostationery"

echo ""
echo "=== 10. CLOUDFLARE PAGE RULES ==="
curl -s -X GET "https://api.cloudflare.com/client/v4/zones/4919ad3406fcabba381edbd543814a68/pagerules" \
  -H "X-Auth-Email: amine.bo@techno-dz.com" \
  -H "X-Auth-Key: 35d8fd4b1a5d27eabbce73c6753978fc350bc" \
  -H "Content-Type: application/json" | python3 -m json.tool 2>/dev/null

echo ""
echo "=== 11. CLOUDFLARE FIREWALL RULES DETAILS ==="
curl -s -X GET "https://api.cloudflare.com/client/v4/zones/4919ad3406fcabba381edbd543814a68/firewall/rules" \
  -H "X-Auth-Email: amine.bo@techno-dz.com" \
  -H "X-Auth-Key: 35d8fd4b1a5d27eabbce73c6753978fc350bc" \
  -H "Content-Type: application/json" | python3 -m json.tool 2>/dev/null

echo ""
echo "=== 12. TEST SPECIFIC PATHS ==="
for path in / /user/login /bundles/pimui/js/app.js /favicon.ico; do
    echo ""
    echo "Testing https://pim.technostationery.com$path"
    curl -I -s "https://pim.technostationery.com$path" 2>&1 | head -15
done

echo ""
echo "=========================================="
echo "AUDIT COMPLETE"
echo "=========================================="
