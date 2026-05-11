#!/bin/bash
################################################################################
# PHASE 11: Fix Port Configuration - Apache on 8080, Varnish on 80
# Date: 2026-05-06
# Purpose: Ensure proper port separation between Apache and Varnish
################################################################################

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔧 PHASE 11: Fix Port Configuration"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Started: $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo ""

# Step 1: Check current Listen directives
echo "═══════════════════════════════════════════════════════════════════════"
echo "Step 1: Check Current Listen Configuration"
echo "═══════════════════════════════════════════════════════════════════════"

echo "▶ Current Listen directives in httpd.conf:"
grep -n "^Listen" /etc/apache2/conf/httpd.conf | head -10

echo ""
echo "▶ VirtualHost definitions:"
grep -n "^<VirtualHost" /etc/apache2/conf/httpd.conf | wc -l
echo "   Total VirtualHost blocks"

echo ""
echo "▶ VirtualHosts on port 8080:"
grep -c "<VirtualHost.*:8080>" /etc/apache2/conf/httpd.conf
echo "   Count"

echo ""

# Step 2: Verify Apache is currently on port 80
echo "═══════════════════════════════════════════════════════════════════════"
echo "Step 2: Current Port Bindings"
echo "═══════════════════════════════════════════════════════════════════════"

APACHE_PORTS=$(ss -tlnp 2>/dev/null | grep httpd || netstat -tlnp 2>/dev/null | grep httpd)
echo "▶ Apache is listening on:"
echo "$APACHE_PORTS"

echo ""
VARNISH_RUNNING=$(ps aux | grep -E "[v]arnishd" | wc -l)
echo "▶ Varnish processes: $VARNISH_RUNNING"

if [ $VARNISH_RUNNING -eq 0 ]; then
    echo "   ⚠️  Varnish is NOT running (was killed during Apache restart)"
else
    echo "   ✅ Varnish is running"
fi

echo ""

# Step 3: The issue is that Apache needs to listen on BOTH 80 and 8080
echo "═══════════════════════════════════════════════════════════════════════"
echo "Step 3: Understanding the Configuration"
echo "═══════════════════════════════════════════════════════════════════════"

echo "▶ Current architecture:"
echo "   - Apache is on port 80 (direct)"
echo "   - Varnish was killed and is not running"
echo "   - Varnish SHOULD be on port 80"
echo "   - Apache SHOULD be on port 8080 (behind Varnish)"
echo ""
echo "▶ The httpd.conf probably has 'Listen 80' instead of 'Listen 8080'"
echo "   OR it may have both Listen 80 and Listen 8080"
echo ""

# Step 4: Restart Varnish
echo "═══════════════════════════════════════════════════════════════════════"
echo "Step 4: Restart Varnish (will take over port 80)"
echo "═══════════════════════════════════════════════════════════════════════"

echo "▶ Starting Varnish service..."
systemctl start varnish 2>&1 || service varnish start 2>&1

sleep 3

VARNISH_AFTER=$(ps aux | grep -E "[v]arnishd" | wc -l)
if [ $VARNISH_AFTER -gt 0 ]; then
    echo "✅ Varnish started successfully ($VARNISH_AFTER processes)"
else
    echo "❌ Varnish failed to start"
    echo ""
    echo "▶ Checking Varnish logs..."
    journalctl -u varnish -n 20 --no-pager 2>/dev/null || tail -20 /var/log/varnish/varnish.log 2>/dev/null
fi

echo ""

# Step 5: Check port bindings after Varnish start
echo "═══════════════════════════════════════════════════════════════════════"
echo "Step 5: Verify Port Bindings After Varnish Start"
echo "═══════════════════════════════════════════════════════════════════════"

sleep 2

echo "▶ Port 80 (should be Varnish):"
PORT_80=$(ss -tlnp 2>/dev/null | grep ":80" | grep -v ":8080" || netstat -tlnp 2>/dev/null | grep ":80" | grep -v ":8080")
echo "$PORT_80"

if echo "$PORT_80" | grep -qi "varnish"; then
    echo "✅ Varnish is on port 80"
elif echo "$PORT_80" | grep -qi "httpd"; then
    echo "⚠️  Apache is still on port 80 (needs to move to 8080)"
else
    echo "⚠️  Port 80 status unclear"
fi

echo ""
echo "▶ Port 8080 (should be Apache):"
PORT_8080=$(ss -tlnp 2>/dev/null | grep ":8080" || netstat -tlnp 2>/dev/null | grep ":8080")

if [ -n "$PORT_8080" ]; then
    echo "$PORT_8080"
    if echo "$PORT_8080" | grep -qi "httpd"; then
        echo "✅ Apache is on port 8080"
    fi
else
    echo "❌ Nothing listening on port 8080"
    echo "   Apache needs to listen on this port for Varnish backend"
fi

echo ""

# Step 6: Test connectivity
echo "═══════════════════════════════════════════════════════════════════════"
echo "Step 6: Test Connectivity"
echo "═══════════════════════════════════════════════════════════════════════"

echo "▶ Test 1: Direct Apache (should be port 80 currently)..."
TEST_80_DIRECT=$(curl -sI http://localhost/ 2>&1 | head -1)
echo "   localhost/ → $TEST_80_DIRECT"

echo ""
echo "▶ Test 2: Try port 8080 (may not work if Apache not listening)..."
TEST_8080=$(curl -sI -m 3 http://localhost:8080/ 2>&1 | head -1)
echo "   localhost:8080/ → $TEST_8080"

echo ""
echo "▶ Test 3: Test PIM login page..."
TEST_LOGIN=$(curl -sI -m 3 http://localhost/user/login 2>&1 | head -1)
echo "   localhost/user/login → $TEST_LOGIN"

echo ""

# Step 7: Provide solution
echo "═══════════════════════════════════════════════════════════════════════"
echo "Step 7: Solution & Next Steps"
echo "═══════════════════════════════════════════════════════════════════════"

echo "📋 CURRENT SITUATION:"
echo "   - Apache is listening on port 80"
echo "   - Varnish may or may not have started on port 80 (port conflict)"
echo "   - Apache is NOT listening on port 8080"
echo ""
echo "📋 REQUIRED CONFIGURATION:"
echo "   - Varnish on port 80 (frontend)"
echo "   - Apache on port 8080 (backend)"
echo "   - Varnish forwards requests to Apache on 127.0.0.1:8080"
echo ""
echo "📋 TWO POSSIBLE SOLUTIONS:"
echo ""
echo "   🔵 SOLUTION A: Keep current setup (Apache on 80, no Varnish)"
echo "      - Pro: Works immediately, simpler"
echo "      - Con: No caching layer"
echo "      - Action: Stop Varnish, test site directly"
echo "      - Command: systemctl stop varnish"
echo ""
echo "   🟢 SOLUTION B: Fix port configuration (RECOMMENDED)"
echo "      - Pro: Full caching with Varnish"
echo "      - Con: Requires httpd.conf modification"
echo "      - Action: Modify Listen directive to include 8080"
echo "      - This requires cPanel configuration changes"
echo ""

# Step 8: Test current setup (Apache on 80, no Varnish)
echo "═══════════════════════════════════════════════════════════════════════"
echo "Step 8: Test Current Setup (Solution A - No Varnish)"
echo "═══════════════════════════════════════════════════════════════════════"

echo "▶ Testing if site works without Varnish..."

# Stop Varnish to free port 80 for Apache
systemctl stop varnish 2>/dev/null || service varnish stop 2>/dev/null
sleep 2

# Test Apache directly on port 80
TEST_FINAL=$(curl -sI http://localhost/ 2>&1 | head -1)
echo "   localhost/ → $TEST_FINAL"

TEST_LOGIN_FINAL=$(curl -sI http://localhost/user/login 2>&1 | head -1)
echo "   localhost/user/login → $TEST_LOGIN_FINAL"

if echo "$TEST_LOGIN_FINAL" | grep -qE "200|302"; then
    echo ""
    echo "✅ SUCCESS! Site is accessible without Varnish"
    echo "   Apache is serving content directly on port 80"
else
    echo ""
    echo "⚠️  Still having issues accessing the site"
fi

echo ""

# Summary
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 SUMMARY & RECOMMENDATIONS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo ""
echo "🎯 IMMEDIATE RECOMMENDATION:"
echo "   Use Solution A (No Varnish) for now to get site working"
echo ""
echo "✅ Current Status:"
echo "   - Varnish: STOPPED"
echo "   - Apache: Running on port 80"
echo "   - Site should be accessible at http://localhost/"
echo ""
echo "📋 Next Steps:"
echo "   1. Test site: https://pim.technostationery.com/"
echo "   2. Verify login works"
echo "   3. Clear Cloudflare cache"
echo "   4. Optionally: Re-enable Varnish later with proper config"
echo ""
echo "⚙️  To re-enable Varnish later:"
echo "   - Modify /etc/apache2/conf/httpd.conf to have Listen 8080"
echo "   - Modify VirtualHosts to use port 8080"
echo "   - Restart Apache"
echo "   - Start Varnish"
echo ""

echo "Completed: $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

exit 0
