#!/bin/bash
################################################################################
# PHASE 11: Fix Critical Apache Issue
# Date: 2026-05-06
# Purpose: Apache not responding after rebuild - emergency fix
################################################################################

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🚨 PHASE 11: Critical Apache Fix"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Started: $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo ""

# Step 1: Check Apache status
echo "═══════════════════════════════════════════════════════════════════════"
echo "Step 1: Diagnose Apache Status"
echo "═══════════════════════════════════════════════════════════════════════"

echo "▶ Checking Apache processes..."
APACHE_PROCS=$(ps aux | grep -E "[h]ttpd" | wc -l)
echo "   Apache processes: $APACHE_PROCS"

if [ $APACHE_PROCS -eq 0 ]; then
    echo "❌ CRITICAL: Apache is not running!"
else
    echo "✅ Apache has $APACHE_PROCS processes"
    ps aux | grep -E "[h]ttpd" | head -5
fi

echo ""
echo "▶ Checking Apache service status..."
systemctl status httpd 2>&1 | head -15 || service httpd status 2>&1 | head -15

echo ""
echo "▶ Checking listening ports..."
ss -tlnp 2>/dev/null | grep -E ":80|:8080|:443" | head -10 || netstat -tlnp 2>/dev/null | grep -E ":80|:8080|:443" | head -10

echo ""

# Step 2: Check Apache error logs
echo "═══════════════════════════════════════════════════════════════════════"
echo "Step 2: Check Apache Error Logs"
echo "═══════════════════════════════════════════════════════════════════════"

echo "▶ Recent Apache error log entries..."
tail -20 /var/log/apache2/error_log 2>/dev/null || tail -20 /usr/local/apache/logs/error_log 2>/dev/null || echo "Error log not found"

echo ""
echo "▶ PIM-specific error log..."
tail -20 /var/log/apache2/domlogs/pim/pim.technostationery.com-error_log 2>/dev/null || echo "PIM error log not found"

echo ""

# Step 3: Test Apache configuration
echo "═══════════════════════════════════════════════════════════════════════"
echo "Step 3: Test Apache Configuration Syntax"
echo "═══════════════════════════════════════════════════════════════════════"

SYNTAX_CHECK=$(httpd -t 2>&1)
echo "$SYNTAX_CHECK"

if echo "$SYNTAX_CHECK" | grep -qi "Syntax OK"; then
    echo "✅ Apache configuration syntax is OK"
else
    echo "❌ Apache configuration has syntax errors!"
fi

echo ""

# Step 4: Check VirtualHost configuration for pim subdomain
echo "═══════════════════════════════════════════════════════════════════════"
echo "Step 4: Check VirtualHost Configuration"
echo "═══════════════════════════════════════════════════════════════════════"

echo "▶ Searching for pim.technostationery.com VirtualHost..."
grep -n "ServerName pim.technostationery.com" /etc/apache2/conf/httpd.conf

echo ""
echo "▶ Full VirtualHost block (first 50 lines)..."
grep -A 50 "ServerName pim.technostationery.com" /etc/apache2/conf/httpd.conf | head -50

echo ""

# Step 5: Try to start Apache if not running
echo "═══════════════════════════════════════════════════════════════════════"
echo "Step 5: Attempt Apache Restart"
echo "═══════════════════════════════════════════════════════════════════════"

if [ $APACHE_PROCS -eq 0 ]; then
    echo "▶ Apache is not running, attempting to start..."
    /scripts/restartsrv_httpd 2>&1
    
    sleep 3
    
    APACHE_PROCS_AFTER=$(ps aux | grep -E "[h]ttpd" | wc -l)
    if [ $APACHE_PROCS_AFTER -gt 0 ]; then
        echo "✅ Apache started successfully ($APACHE_PROCS_AFTER processes)"
    else
        echo "❌ Failed to start Apache"
        echo ""
        echo "▶ Checking systemd/service logs..."
        journalctl -u httpd -n 50 --no-pager 2>/dev/null || echo "journalctl not available"
    fi
else
    echo "▶ Apache is already running, restarting gracefully..."
    /scripts/restartsrv_httpd 2>&1 | tail -10
    sleep 3
    
    APACHE_PROCS_AFTER=$(ps aux | grep -E "[h]ttpd" | wc -l)
    echo "   Apache processes after restart: $APACHE_PROCS_AFTER"
fi

echo ""

# Step 6: Test connectivity
echo "═══════════════════════════════════════════════════════════════════════"
echo "Step 6: Test Apache Connectivity"
echo "═══════════════════════════════════════════════════════════════════════"

echo "▶ Testing localhost:8080..."
TEST_8080=$(curl -v -m 5 http://localhost:8080/ 2>&1)
STATUS_8080=$(echo "$TEST_8080" | grep "< HTTP" | head -1)

echo "   Status: $STATUS_8080"

if [ -z "$STATUS_8080" ]; then
    echo "❌ No response from Apache on port 8080"
    echo "   Connection details:"
    echo "$TEST_8080" | grep -E "connect|Connection|refused|timeout" | head -5
else
    echo "✅ Apache is responding on port 8080"
fi

echo ""
echo "▶ Testing port 80 (should be Varnish)..."
TEST_80=$(curl -I -m 5 http://localhost/ 2>&1 | head -1)
echo "   Status: $TEST_80"

echo ""
echo "▶ Testing /user/login endpoint..."
TEST_LOGIN=$(curl -I -m 5 http://localhost:8080/user/login 2>&1 | head -1)
echo "   Login status: $TEST_LOGIN"

echo ""

# Step 7: Check if port 8080 is actually listening
echo "═══════════════════════════════════════════════════════════════════════"
echo "Step 7: Port Binding Check"
echo "═══════════════════════════════════════════════════════════════════════"

echo "▶ What's listening on port 8080..."
LISTEN_8080=$(ss -tlnp 2>/dev/null | grep ":8080" || netstat -tlnp 2>/dev/null | grep ":8080")

if [ -n "$LISTEN_8080" ]; then
    echo "✅ Port 8080 is bound:"
    echo "$LISTEN_8080"
else
    echo "❌ Nothing is listening on port 8080!"
    echo ""
    echo "   This means Apache is not binding to port 8080"
    echo "   Check VirtualHost Listen directive in httpd.conf"
fi

echo ""
echo "▶ What's listening on port 80..."
LISTEN_80=$(ss -tlnp 2>/dev/null | grep ":80" | grep -v ":8080" || netstat -tlnp 2>/dev/null | grep ":80" | grep -v ":8080")

if [ -n "$LISTEN_80" ]; then
    echo "✅ Port 80 is bound:"
    echo "$LISTEN_80"
else
    echo "⚠️  Nothing is listening on port 80"
fi

echo ""

# Step 8: Check SELinux/AppArmor (if applicable)
echo "═══════════════════════════════════════════════════════════════════════"
echo "Step 8: Security Context Check"
echo "═══════════════════════════════════════════════════════════════════════"

if command -v getenforce &> /dev/null; then
    SELINUX_STATUS=$(getenforce 2>/dev/null)
    echo "▶ SELinux status: $SELINUX_STATUS"
    
    if [ "$SELINUX_STATUS" = "Enforcing" ]; then
        echo "⚠️  SELinux is enforcing - may block Apache"
    fi
else
    echo "✅ SELinux not in use"
fi

echo ""

# Summary
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 DIAGNOSTIC SUMMARY"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ $APACHE_PROCS_AFTER -gt 0 ] && [ -n "$LISTEN_8080" ]; then
    echo "✅ Apache is running and listening on port 8080"
    echo ""
    echo "   If still getting 503 from Varnish:"
    echo "   1. Check Varnish backend configuration"
    echo "   2. Verify Varnish can reach 127.0.0.1:8080"
    echo "   3. Check firewall rules"
elif [ $APACHE_PROCS_AFTER -gt 0 ] && [ -z "$LISTEN_8080" ]; then
    echo "⚠️  Apache is running but NOT listening on port 8080"
    echo ""
    echo "   Action required:"
    echo "   1. Check Listen 8080 directive in httpd.conf"
    echo "   2. Check <VirtualHost *:8080> configuration"
    echo "   3. Run: grep -n 'Listen 8080' /etc/apache2/conf/httpd.conf"
else
    echo "❌ Apache is NOT running"
    echo ""
    echo "   Critical action required:"
    echo "   1. Check error logs above for startup failures"
    echo "   2. Test configuration: httpd -t"
    echo "   3. Try manual start: systemctl start httpd"
    echo "   4. Check for port conflicts"
fi

echo ""
echo "Completed: $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

exit 0
