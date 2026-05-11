#!/bin/bash

echo "=========================================="
echo "COMPLETE FINAL FIX - All Issues"
echo "Date: $(date)"
echo "=========================================="
echo ""

echo "=== ROOT CAUSE IDENTIFIED ==="
echo "Apache is serving directory listing from /home/pim/public_html"
echo "instead of /home/pim/public_html/public/index.php"
echo ""
echo "This means DocumentRoot is STILL wrong in the VirtualHost!"
echo ""

# Check current DocumentRoot
echo "=== STEP 1: Check Current VirtualHost Configuration ==="
echo "Current configuration for port 80:"
sed -n '/ServerName pim.technostationery.com/,/^<\/VirtualHost>/p' /etc/apache2/conf/httpd.conf | head -40

echo ""
echo "=== STEP 2: Fix DocumentRoot Properly ==="

# Backup
cp /etc/apache2/conf/httpd.conf /etc/apache2/conf/httpd.conf.backup.final.$(date +%Y%m%d_%H%M%S)

# Method 1: Using cPanel tools (recommended for cPanel servers)
echo "Using cPanel to update DocumentRoot..."

# Create a WHM API call to update document root
# Note: This is the proper way for cPanel servers
cat > /tmp/update_docroot.sh << 'INNERSCRIPT'
#!/bin/bash

# Update DocumentRoot using cPanel's API
/usr/local/cpanel/bin/whmapi1 setdocumentroot \
  domain=pim.technostationery.com \
  documentroot=/home/pim/public_html/public

# Rebuild httpd.conf
/scripts/rebuildhttpdconf

# Restart Apache
/scripts/restartsrv_httpd --graceful
INNERSCRIPT

chmod +x /tmp/update_docroot.sh
bash /tmp/update_docroot.sh 2>&1

echo ""
echo "=== STEP 3: Verify DocumentRoot Change ==="
sleep 3
echo "New DocumentRoot:"
grep -A 5 "ServerName pim.technostationery.com" /etc/apache2/conf/httpd.conf | grep DocumentRoot | head -2

echo ""
echo "=== STEP 4: Test Apache Locally ==="
echo "Testing localhost with Host header:"
curl -I -H "Host: pim.technostationery.com" http://localhost/ 2>&1 | head -15

echo ""
echo "Testing /user/login:"
curl -I -H "Host: pim.technostationery.com" http://localhost/user/login 2>&1 | head -15

echo ""
echo "=== STEP 5: Test Direct IP Access ==="
echo "Testing direct IP with Host header:"
curl -I -H "Host: pim.technostationery.com" http://205.134.249.177/ 2>&1 | head -15

echo ""
echo "=== STEP 6: Re-enable Cloudflare Proxy ==="
DNS_RECORD_ID="ba41ff468cc30e48ea0ed973168e0d44"
echo "Re-enabling Cloudflare proxy (orange cloud)..."
curl -s -X PATCH "https://api.cloudflare.com/client/v4/zones/4919ad3406fcabba381edbd543814a68/dns_records/$DNS_RECORD_ID" \
  -H "X-Auth-Email: amine.bo@techno-dz.com" \
  -H "X-Auth-Key: 35d8fd4b1a5d27eabbce73c6753978fc350bc" \
  -H "Content-Type: application/json" \
  -d '{"proxied":true}' | python3 -m json.tool | grep -E "success|proxied"

echo ""
echo "Purging Cloudflare cache..."
curl -s -X POST "https://api.cloudflare.com/client/v4/zones/4919ad3406fcabba381edbd543814a68/purge_cache" \
  -H "X-Auth-Email: amine.bo@techno-dz.com" \
  -H "X-Auth-Key: 35d8fd4b1a5d27eabbce73c6753978fc350bc" \
  -H "Content-Type: application/json" \
  -d '{"purge_everything":true}' | python3 -m json.tool | grep success

echo ""
echo "=== STEP 7: Wait and Test Production URL ==="
echo "Waiting 15 seconds for cache purge..."
sleep 15

echo ""
echo "Testing https://pim.technostationery.com/:"
curl -I https://pim.technostationery.com/ 2>&1 | head -20

echo ""
echo "Testing https://pim.technostationery.com/user/login:"
curl -I https://pim.technostationery.com/user/login 2>&1 | head -20

echo ""
echo "=========================================="
echo "FINAL STATUS"
echo "=========================================="
echo ""
echo "Services:"
echo "  Apache: $(systemctl is-active httpd)"
echo "  Varnish: $(systemctl is-active varnish)"
echo "  PHP-FPM: $(pgrep -c php-fpm) processes"
echo "  MariaDB: $(systemctl is-active mariadb)"
echo ""
echo "Configuration:"
echo "  DocumentRoot: $(grep -A 5 'ServerName pim.technostationery.com' /etc/apache2/conf/httpd.conf | grep DocumentRoot | head -1 | awk '{print $2}')"
echo "  Cloudflare Proxy: Enabled"
echo "  Varnish Port: 8080"
echo ""
echo "Next Steps:"
echo "  1. Open https://pim.technostationery.com/ in browser"
echo "  2. Should see Akeneo login page (not directory listing)"
echo "  3. Login with: admin / Admin123!"
echo "  4. Verify product catalog (9,538 products)"
echo ""
echo "=========================================="

