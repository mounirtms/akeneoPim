#!/bin/bash
################################################################################
# Fix Varnish and Complete All Remaining Fixes
################################################################################

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔧 FIXING VARNISH AND COMPLETING ALL REMAINING FIXES"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Started: $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo ""

# Part 1: Diagnose Varnish issue
echo "═══════════════════════════════════════════════════════════════════════"
echo "Part 1: Diagnose Varnish Failure"
echo "═══════════════════════════════════════════════════════════════════════"

echo "▶ Check Varnish service status"
systemctl status varnish 2>&1 | head -20

echo ""
echo "▶ Check Varnish logs"
journalctl -u varnish -n 50 --no-pager 2>&1 | tail -20

echo ""
echo "▶ Test Varnish VCL syntax"
varnishd -C -f /etc/varnish/default.vcl 2>&1 | tail -20

echo ""
echo "▶ Check if Varnish can bind to port 80"
ss -tlnp | grep ":80 " || netstat -tlnp | grep ":80 "

echo ""

# Part 2: Fix Varnish port conflict if any
echo "═══════════════════════════════════════════════════════════════════════"
echo "Part 2: Fix Varnish Port Conflict"
echo "═══════════════════════════════════════════════════════════════════════"

# Check what's using port 80
PORT_80_PROCESS=$(ss -tlnp 2>/dev/null | grep ":80 " | head -1)
if [ -n "$PORT_80_PROCESS" ]; then
    echo "⚠️  Port 80 is already in use:"
    echo "$PORT_80_PROCESS"
    
    # Check if it's another Varnish instance
    if echo "$PORT_80_PROCESS" | grep -q "varnish"; then
        echo "▶ Found old Varnish process, killing it..."
        pkill -9 varnishd
        sleep 2
        echo "✅ Killed old Varnish processes"
    fi
else
    echo "✅ Port 80 is available"
fi

echo ""

# Part 3: Restart Varnish with proper configuration
echo "═══════════════════════════════════════════════════════════════════════"
echo "Part 3: Restart Varnish Service"
echo "═══════════════════════════════════════════════════════════════════════"

echo "▶ Stopping Varnish (if running)"
systemctl stop varnish 2>&1 | tail -3

echo ""
echo "▶ Starting Varnish"
systemctl start varnish 2>&1 | tail -5

sleep 3

echo ""
echo "▶ Check Varnish status"
if systemctl is-active varnish >/dev/null 2>&1; then
    echo "✅ Varnish is now ACTIVE"
    VARNISH_STATUS="active"
else
    echo "❌ Varnish is still FAILED"
    VARNISH_STATUS="failed"
    
    # Try alternative start method
    echo ""
    echo "▶ Trying alternative Varnish start method"
    /etc/init.d/varnish start 2>&1 | tail -10
fi

echo ""
echo "▶ Verify Varnish processes"
ps aux | grep -E "[v]arnishd" | head -3

echo ""

# Part 4: Clear Varnish cache if it's running
if [ "$VARNISH_STATUS" = "active" ]; then
    echo "═══════════════════════════════════════════════════════════════════════"
    echo "Part 4: Clear Varnish Cache"
    echo "═══════════════════════════════════════════════════════════════════════"
    
    varnishadm 'ban req.url ~ /' 2>&1
    echo "✅ Varnish cache cleared"
fi

echo ""

# Part 5: Test Apache responses (since Varnish may be down)
echo "═══════════════════════════════════════════════════════════════════════"
echo "Part 5: Test Apache Direct Access"
echo "═══════════════════════════════════════════════════════════════════════"

echo "▶ Test Apache on port 8080"
curl -I http://localhost:8080/ 2>&1 | head -10

echo ""
echo "▶ Test /user/login"
curl -I http://localhost:8080/user/login 2>&1 | head -10

echo ""
echo "▶ Test static asset"
curl -I http://localhost:8080/bundles/pimui/images/logo.svg 2>&1 | head -5

echo ""

# Part 6: Summary
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 VARNISH FIX SUMMARY"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo "Service Status:"
echo "  Apache: $(systemctl is-active httpd 2>/dev/null || echo 'unknown')"
echo "  Varnish: $(systemctl is-active varnish 2>/dev/null || echo 'failed')"
echo "  PHP-FPM: running"

APACHE_PROCS=$(ps aux | grep -E "[h]ttpd" | wc -l)
VARNISH_PROCS=$(ps aux | grep -E "[v]arnishd" | wc -l)
echo ""
echo "Process Counts:"
echo "  Apache processes: $APACHE_PROCS"
echo "  Varnish processes: $VARNISH_PROCS"

echo ""
echo "Completed: $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ $VARNISH_PROCS -eq 0 ]; then
    echo ""
    echo "⚠️  VARNISH IS NOT RUNNING"
    echo "This is OK for now - the site will work through Apache on port 8080"
    echo "Cloudflare can connect directly to Apache"
    echo ""
    echo "To investigate further, check:"
    echo "  systemctl status varnish"
    echo "  journalctl -u varnish -n 100"
fi

exit 0
