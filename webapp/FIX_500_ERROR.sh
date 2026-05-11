#!/bin/bash

echo "=========================================="
echo "FIX HTTP 500 INTERNAL SERVER ERROR"
echo "Date: $(date)"
echo "=========================================="
echo ""

echo "=== STEP 1: Check Apache Error Log ==="
echo "Recent errors (last 20 lines):"
tail -20 /usr/local/apache/logs/error_log

echo ""
echo "=== STEP 2: Check if .modsecurity.conf Syntax is Valid ==="
apachectl -t 2>&1 | head -20

echo ""
echo "=== STEP 3: Remove .modsecurity.conf (may have syntax issues) ==="
if [ -f /home/pim/public_html/.modsecurity.conf ]; then
    mv /home/pim/public_html/.modsecurity.conf /home/pim/public_html/.modsecurity.conf.disabled
    echo "✅ Moved .modsecurity.conf to .modsecurity.conf.disabled"
fi

echo ""
echo "=== STEP 4: Fix .htaccess ModSecurity Syntax ==="
# Check if SecRuleEngine directive exists and is valid
if grep -q "SecRuleEngine Off" /home/pim/public_html/.htaccess; then
    echo "ModSecurity directive found in .htaccess - keeping it"
else
    echo "No ModSecurity directive in .htaccess"
fi

echo ""
echo "=== STEP 5: Remove Invalid Custom ModSecurity Config ==="
if [ -f /usr/local/apache/conf/modsec/pim_whitelist.conf ]; then
    mv /usr/local/apache/conf/modsec/pim_whitelist.conf /usr/local/apache/conf/modsec/pim_whitelist.conf.disabled
    echo "✅ Moved pim_whitelist.conf to disabled"
fi

echo ""
echo "=== STEP 6: Restart Apache ==="
/scripts/restartsrv_httpd --graceful
sleep 3

echo ""
echo "=== STEP 7: Test Syntax ==="
apachectl -t 2>&1 | head -10

echo ""
echo "=== STEP 8: Test External IP Access ==="
echo "Testing direct IP:"
curl -I -H "Host: pim.technostationery.com" http://205.134.249.177/ 2>&1 | head -15

echo ""
echo "Testing via Cloudflare (wait 5 seconds for cache)..."
sleep 5
curl -I https://pim.technostationery.com/ 2>&1 | head -20

echo ""
echo "=== STEP 9: Test Localhost (should still work) ==="
curl -I -H "Host: pim.technostationery.com" http://localhost/ 2>&1 | head -10

echo ""
echo "=========================================="
echo "SUMMARY"
echo "=========================================="
echo ""
echo "If still showing 500 error, the issue may be:"
echo "  1. PHP-FPM configuration error"
echo "  2. .htaccess syntax error"
echo "  3. Missing PHP extensions"
echo "  4. File permissions issue"
echo ""
echo "Next diagnostic command:"
echo "  tail -50 /usr/local/apache/logs/error_log | grep -i error"
echo ""
echo "=========================================="

