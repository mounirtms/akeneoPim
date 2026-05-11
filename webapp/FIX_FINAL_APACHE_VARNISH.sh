#!/bin/bash

echo "=========================================="
echo "FINAL FIX - Apache DocumentRoot + Varnish"
echo "Date: $(date)"
echo "=========================================="
echo ""

# Fix the double /public/public issue
echo "=== STEP 1: Fix DocumentRoot Double Path ==="
sed -i 's|DocumentRoot /home/pim/public_html/public/public|DocumentRoot /home/pim/public_html/public|g' /etc/apache2/conf/httpd.conf
sed -i 's|<Directory "/home/pim/public_html/public/public">|<Directory "/home/pim/public_html/public">|g' /etc/apache2/conf/httpd.conf

echo "Verifying DocumentRoot fix..."
grep -A 2 "ServerName pim.technostationery.com" /etc/apache2/conf/httpd.conf | grep "DocumentRoot"
echo "✅ DocumentRoot corrected"

# Add AllowOverride All to the Directory block
echo ""
echo "=== STEP 2: Ensure AllowOverride All is Set ==="
# Find the VirtualHost block for pim.technostationery.com and add AllowOverride if missing
awk '
/ServerName pim.technostationery.com/,/^<\/VirtualHost>/ {
    if (/<Directory "\/home\/pim\/public_html\/public">/) {
        print
        getline
        if ($0 !~ /AllowOverride/) {
            print "    AllowOverride All"
        }
    }
    print
    next
}
{print}
' /etc/apache2/conf/httpd.conf > /tmp/httpd.conf.tmp && mv /tmp/httpd.conf.tmp /etc/apache2/conf/httpd.conf

# Restart Apache
echo ""
echo "=== STEP 3: Restart Apache ==="
/scripts/restartsrv_httpd --graceful
sleep 3

# Test Apache
echo ""
echo "=== STEP 4: Test Apache ==="
echo "Testing root:"
curl -I -H "Host: pim.technostationery.com" http://localhost/ 2>&1 | head -10

echo ""
echo "Testing /user/login:"
curl -I -H "Host: pim.technostationery.com" http://localhost/user/login 2>&1 | head -10

# Fix Varnish configuration - remove duplicate address
echo ""
echo "=== STEP 5: Fix Varnish Configuration ==="

cat > /etc/systemd/system/varnish.service.d/override.conf << 'EOFSVC'
[Service]
ExecStart=
ExecStart=/usr/sbin/varnishd \
    -a :8080 \
    -f /etc/varnish/default.vcl \
    -s malloc,6G \
    -T localhost:6082 \
    -p default_ttl=3600 \
    -p default_grace=3600 \
    -p feature=+esi_ignore_https \
    -p feature=+esi_disable_xml_check \
    -p vcc_allow_inline_c=on
EOFSVC

systemctl daemon-reload
systemctl start varnish
sleep 3

echo ""
echo "=== STEP 6: Verify Varnish Status ==="
systemctl status varnish --no-pager | head -15

echo ""
echo "Varnish processes:"
ps aux | grep varnish | grep -v grep | head -5

echo ""
echo "Listening ports:"
netstat -tlnp | grep -E ":(80|8080|6082)" | head -10

# Test Varnish if running
echo ""
echo "=== STEP 7: Test Varnish (if running) ==="
if systemctl is-active --quiet varnish; then
    echo "Testing Varnish on port 8080:"
    curl -I -H "Host: pim.technostationery.com" http://localhost:8080/ 2>&1 | head -15
    
    echo ""
    echo "Testing /user/login through Varnish:"
    curl -I -H "Host: pim.technostationery.com" http://localhost:8080/user/login 2>&1 | head -15
else
    echo "⚠️ Varnish is not running - site working on Apache port 80 only"
fi

# Test production URL
echo ""
echo "=== STEP 8: Test Production URL ==="
echo "Testing https://pim.technostationery.com/"
curl -I https://pim.technostationery.com/ 2>&1 | head -20

echo ""
echo "Testing https://pim.technostationery.com/user/login"
curl -I https://pim.technostationery.com/user/login 2>&1 | head -20

echo ""
echo "=========================================="
echo "FINAL STATUS"
echo "=========================================="
echo ""
echo "Services:"
echo "  Apache: $(systemctl is-active httpd)"
echo "  Varnish: $(systemctl is-active varnish)"
echo "  PHP-FPM: $(ps aux | grep -c 'php-fpm: pool') pools running"
echo ""
echo "Ports:"
netstat -tlnp 2>/dev/null | grep -E ":(80|8080|6082|443)" | awk '{print "  " $4 " - " $7}'
echo ""
echo "=========================================="

