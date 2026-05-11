#!/bin/bash
# PHASE11_WEB_ROUTING_AUDIT.sh - Comprehensive web routing audit
# Date: 2026-05-06

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔍 PHASE 11: WEB ROUTING & CACHE AUDIT"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Start time: $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo ""

# Section 1: Apache Configuration
echo "1. APACHE CONFIGURATION AUDIT"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "1.1 VirtualHost Configuration:"
grep -A 30 "ServerName pim.technostationery.com" /etc/apache2/conf/httpd.conf 2>/dev/null | head -40
echo ""

echo "1.2 DocumentRoot Settings:"
grep -i "DocumentRoot" /etc/apache2/conf/httpd.conf 2>/dev/null | grep -i pim | head -5
echo ""

echo "1.3 Directory Block for public/:"
grep -A 20 "<Directory.*public_html/public" /etc/apache2/conf/httpd.conf 2>/dev/null | head -25
echo ""

echo "1.4 AllowOverride Status:"
grep -i "AllowOverride" /etc/apache2/conf/httpd.conf 2>/dev/null | grep -v "^#" | head -10
echo ""

echo "1.5 Loaded Apache Modules:"
httpd -M 2>/dev/null | grep -E "rewrite|headers|deflate|expires|varnish" || echo "httpd -M not available"
echo ""

# Section 2: .htaccess Files
echo "2. .HTACCESS FILES AUDIT"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "2.1 Root .htaccess (first 30 lines):"
head -30 .htaccess
echo ""

echo "2.2 public/.htaccess (first 30 lines):"
head -30 public/.htaccess
echo ""

echo "2.3 .htaccess file permissions:"
ls -lh .htaccess public/.htaccess 2>/dev/null
echo ""

# Section 3: Varnish Detection
echo "3. VARNISH CACHE AUDIT"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "3.1 Varnish Process Status:"
ps aux | grep varnish | grep -v grep || echo "No Varnish process found"
echo ""

echo "3.2 Varnish Port Check:"
netstat -tlnp 2>/dev/null | grep -E ":80|:6081|:6082" | head -10
echo ""

echo "3.3 Varnish Configuration Files:"
find /etc /usr/local/etc -name "*.vcl" 2>/dev/null | head -5
echo ""

if [ -f "/etc/varnish/default.vcl" ]; then
    echo "3.4 Varnish VCL Backend Config:"
    grep -A 10 "backend default" /etc/varnish/default.vcl 2>/dev/null | head -15
fi
echo ""

# Section 4: Cloudflare Detection
echo "4. CLOUDFLARE CDN AUDIT"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "4.1 DNS Resolution:"
host pim.technostationery.com 2>/dev/null || nslookup pim.technostationery.com 2>/dev/null | head -10
echo ""

echo "4.2 Cloudflare Headers Test:"
timeout 5 curl -sI https://pim.technostationery.com 2>/dev/null | grep -E "^(HTTP|Server|CF-|X-|Cache)" | head -15
echo ""

echo "4.3 Origin Server Test (bypassing CDN):"
timeout 5 curl -sI http://localhost/ 2>/dev/null | grep -E "^(HTTP|Server|Content-Type)" | head -10
echo ""

# Section 5: PHP-FPM & OPcache
echo "5. PHP-FPM & OPCACHE AUDIT"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "5.1 PHP-FPM Process:"
ps aux | grep php-fpm | grep -v grep | head -5 || echo "No PHP-FPM found"
echo ""

echo "5.2 OPcache Status:"
php -r "echo 'OPcache Enabled: ' . (function_exists('opcache_get_status') ? 'YES' : 'NO') . PHP_EOL;"
php -r "if(function_exists('opcache_get_status')) { \$s = opcache_get_status(); echo 'Scripts Cached: ' . \$s['opcache_statistics']['num_cached_scripts'] . PHP_EOL; }"
echo ""

echo "5.3 PHP Cache Extensions:"
php -m | grep -E "opcache|apcu|memcache|redis" || echo "No cache extensions found"
echo ""

# Section 6: Directory Index Issue
echo "6. DIRECTORY INDEX INVESTIGATION"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "6.1 What browser sees (curl test):"
timeout 5 curl -s https://pim.technostationery.com 2>/dev/null | head -50
echo ""

echo "6.2 Direct PHP test (should redirect to /user/login):"
timeout 5 php public/index.php 2>&1 | head -20
echo ""

echo "6.3 Apache Access Log (last 10 entries):"
tail -10 /etc/apache2/logs/domlogs/pim.technostationery.com 2>/dev/null || echo "Log file not accessible"
echo ""

echo "6.4 Apache Error Log (last 10 entries):"
tail -10 /etc/apache2/logs/domlogs/pim.technostationery.com-ssl_log 2>/dev/null || echo "SSL log not accessible"
echo ""

# Section 7: Multi-Site Setup Detection
echo "7. MULTI-SITE CONFIGURATION DETECTION"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "7.1 All VirtualHosts on this server:"
grep -E "ServerName|ServerAlias" /etc/apache2/conf/httpd.conf 2>/dev/null | grep -v "^#" | head -20
echo ""

echo "7.2 cPanel Domains:"
ls -1 /var/cpanel/users/ 2>/dev/null | head -10 || echo "Not accessible"
echo ""

# Section 8: Cache Headers Test
echo "8. CACHE HEADERS & RESPONSE AUDIT"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "8.1 Full HTTP Headers from Domain:"
timeout 5 curl -sI https://pim.technostationery.com 2>/dev/null
echo ""

echo "8.2 HTTP Headers from /user/login:"
timeout 5 curl -sI https://pim.technostationery.com/user/login 2>/dev/null | head -20
echo ""

echo "8.3 Static Asset Headers (CSS/JS):"
timeout 5 curl -sI https://pim.technostationery.com/bundles/pimui/images/logo.svg 2>/dev/null | head -15
echo ""

# Section 9: File Ownership & Permissions
echo "9. OWNERSHIP & PERMISSIONS CHECK"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "9.1 Critical File Ownership:"
ls -lh public/index.php public/.htaccess .htaccess 2>/dev/null
echo ""

echo "9.2 public/ Directory Permissions:"
ls -ld public/
echo ""

echo "9.3 Apache Process User:"
ps aux | grep httpd | grep -v grep | head -3 | awk '{print $1}' | sort -u
echo ""

# Section 10: Summary
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 AUDIT SUMMARY"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Audit completed at: $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo ""
echo "Next steps:"
echo "1. Review this audit output"
echo "2. Check PHASE11_DIAGNOSTIC_REPORT.md"
echo "3. Run browser tests with Playwright"
echo "4. Execute PHASE11_FIX_WEB_ROUTING.sh"
echo ""
