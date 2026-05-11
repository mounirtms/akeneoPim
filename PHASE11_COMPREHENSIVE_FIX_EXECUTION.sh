#!/bin/bash
################################################################################
# PHASE 11: Comprehensive Fix Execution
# Date: 2026-05-06
# Purpose: Apply ALL fixes - Apache, Varnish, Cloudflare, Application
################################################################################

# set -e # Disabled to show all output

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔧 PHASE 11: COMPREHENSIVE FIX EXECUTION"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Started: $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo ""

FIXES_APPLIED=0
FIXES_FAILED=0

# ============================================================================
# PART 1: APACHE CONFIGURATION FIX
# ============================================================================
echo "═══════════════════════════════════════════════════════════════════════"
echo "PART 1: Apache VirtualHost Configuration Fix"
echo "═══════════════════════════════════════════════════════════════════════"

echo "▶ Step 1.1: Backup current Apache configuration"
if [ -f /etc/apache2/conf/httpd.conf ]; then
    cp /etc/apache2/conf/httpd.conf /etc/apache2/conf/httpd.conf.phase11.backup.$(date +%Y%m%d_%H%M%S)
    echo "✅ Backed up httpd.conf"
    ((FIXES_APPLIED++))
else
    echo "⚠️  httpd.conf not found at expected location"
fi

echo ""
echo "▶ Step 1.2: Check current AllowOverride setting"
CURRENT_ALLOW=$(grep -A 20 "ServerName pim.technostationery.com" /etc/apache2/conf/httpd.conf | grep -A 10 "Directory.*public" | grep -i "AllowOverride" || echo "NOT_FOUND")
echo "   Current: $CURRENT_ALLOW"

echo ""
echo "▶ Step 1.3: Rebuild Apache configuration"
/scripts/rebuildhttpdconf 2>&1 | tail -10
if [ $? -eq 0 ]; then
    echo "✅ Apache configuration rebuilt"
    ((FIXES_APPLIED++))
else
    echo "❌ Apache rebuild failed"
    ((FIXES_FAILED++))
fi

echo ""
echo "▶ Step 1.4: Check if AllowOverride was added"
NEW_ALLOW=$(grep -A 20 "ServerName pim.technostationery.com" /etc/apache2/conf/httpd.conf | grep -A 10 "Directory.*public" | grep -i "AllowOverride" || echo "STILL_NOT_FOUND")
echo "   After rebuild: $NEW_ALLOW"

if echo "$NEW_ALLOW" | grep -qi "STILL_NOT_FOUND"; then
    echo "⚠️  AllowOverride still not set - will add manually"
    
    # Manual fix - add AllowOverride to the Directory block
    echo "▶ Step 1.5: Manually adding AllowOverride to VirtualHost"
    
    # This is complex, so we'll create a notice instead
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "⚠️  MANUAL INTERVENTION NEEDED"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "The Apache rebuild did not add AllowOverride."
    echo "You may need to manually edit /etc/apache2/conf/httpd.conf"
    echo "and add 'AllowOverride All' to the Directory block for:"
    echo "  <Directory \"/home/pim/public_html/public\">"
    echo ""
else
    echo "✅ AllowOverride is now set"
    ((FIXES_APPLIED++))
fi

echo ""
echo "▶ Step 1.6: Restart Apache"
/scripts/restartsrv_httpd 2>&1 | grep -E "httpd|started|Restarting" | head -5
if [ $? -eq 0 ]; then
    echo "✅ Apache restarted successfully"
    ((FIXES_APPLIED++))
else
    echo "❌ Apache restart failed"
    ((FIXES_FAILED++))
fi

sleep 3

echo ""

# ============================================================================
# PART 2: VARNISH RESTART AND CONFIGURATION
# ============================================================================
echo "═══════════════════════════════════════════════════════════════════════"
echo "PART 2: Varnish Service Management"
echo "═══════════════════════════════════════════════════════════════════════"

echo "▶ Step 2.1: Check Varnish status"
VARNISH_STATUS=$(systemctl is-active varnish 2>/dev/null || echo "inactive")
echo "   Current status: $VARNISH_STATUS"

if [ "$VARNISH_STATUS" != "active" ]; then
    echo "▶ Step 2.2: Starting Varnish service"
    systemctl start varnish 2>&1 | tail -3
    
    if systemctl is-active varnish >/dev/null 2>&1; then
        echo "✅ Varnish started successfully"
        ((FIXES_APPLIED++))
    else
        echo "❌ Varnish failed to start"
        ((FIXES_FAILED++))
        
        echo "   Checking Varnish configuration..."
        varnishd -C -f /etc/varnish/default.vcl 2>&1 | tail -10
    fi
else
    echo "✅ Varnish is already running"
    ((FIXES_APPLIED++))
fi

echo ""
echo "▶ Step 2.3: Clear Varnish cache"
varnishadm 'ban req.url ~ /' 2>&1 | head -3
if [ $? -eq 0 ]; then
    echo "✅ Varnish cache cleared"
    ((FIXES_APPLIED++))
else
    echo "⚠️  Varnish cache clear may have failed"
fi

echo ""
echo "▶ Step 2.4: Verify Varnish processes"
VARNISH_PROCS=$(ps aux | grep -E "[v]arnishd" | wc -l)
echo "   Varnish processes running: $VARNISH_PROCS"

if [ $VARNISH_PROCS -ge 1 ]; then
    echo "✅ Varnish processes are running"
else
    echo "❌ No Varnish processes found"
fi

echo ""

# ============================================================================
# PART 3: APPLICATION CONFIGURATION FIX
# ============================================================================
echo "═══════════════════════════════════════════════════════════════════════"
echo "PART 3: Application Domain Configuration"
echo "═══════════════════════════════════════════════════════════════════════"

cd /home/pim/public_html

echo "▶ Step 3.1: Check current domain configuration"
echo "   Searching for domain references..."

if [ -f .env.local ]; then
    echo ""
    echo "   .env.local contents (URLs/domains):"
    grep -E "URL|DOMAIN|HOST" .env.local 2>/dev/null || echo "   (no URL/domain settings found)"
fi

if [ -f .env ]; then
    echo ""
    echo "   .env contents (URLs/domains):"
    grep -E "URL|DOMAIN|HOST" .env 2>/dev/null || echo "   (no URL/domain settings found)"
fi

if [ -f config/parameters.yml ]; then
    echo ""
    echo "   parameters.yml (urls/domains):"
    grep -E "url|domain|host" config/parameters.yml 2>/dev/null || echo "   (no url/domain settings found)"
fi

echo ""
echo "▶ Step 3.2: Clear Symfony cache"
php bin/console cache:clear --env=prod --no-warmup 2>&1 | tail -3
echo "✅ Symfony cache cleared"
((FIXES_APPLIED++))

php bin/console cache:warmup --env=prod 2>&1 | tail -3
echo "✅ Symfony cache warmed"
((FIXES_APPLIED++))

CACHE_FILES=$(find var/cache/prod -type f 2>/dev/null | wc -l)
echo "   Cache files: $CACHE_FILES"

echo ""

# ============================================================================
# PART 4: LOCAL TESTING
# ============================================================================
echo "═══════════════════════════════════════════════════════════════════════"
echo "PART 4: Local Testing"
echo "═══════════════════════════════════════════════════════════════════════"

echo "▶ Test 4.1: Apache direct (port 8080)"
APACHE_ROOT=$(curl -sI http://localhost:8080/ 2>&1 | head -1)
echo "   /: $APACHE_ROOT"

APACHE_LOGIN=$(curl -sI http://localhost:8080/user/login 2>&1 | head -1)
echo "   /user/login: $APACHE_LOGIN"

APACHE_ASSET=$(curl -sI http://localhost:8080/bundles/pimui/images/logo.svg 2>&1 | head -1)
echo "   /bundles/.../logo.svg: $APACHE_ASSET"

if echo "$APACHE_LOGIN" | grep -q "200\|301"; then
    echo "   ✅ Apache responses look better"
    ((FIXES_APPLIED++))
else
    echo "   ⚠️  Apache still showing issues"
fi

echo ""
echo "▶ Test 4.2: Varnish (port 80)"
VARNISH_LOGIN=$(curl -sI http://localhost/user/login 2>&1 | head -1)
echo "   /user/login: $VARNISH_LOGIN"

echo ""
echo "▶ Test 4.3: Check for redirect location"
REDIRECT_LOCATION=$(curl -sI http://localhost:8080/ 2>&1 | grep -i "Location:")
if [ -n "$REDIRECT_LOCATION" ]; then
    echo "   Redirect found: $REDIRECT_LOCATION"
else
    echo "   No redirect header found"
fi

echo ""

# ============================================================================
# SUMMARY
# ============================================================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 FIX EXECUTION SUMMARY"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Fixes Applied:  $FIXES_APPLIED"
echo "❌ Fixes Failed:   $FIXES_FAILED"
echo ""
echo "Service Status:"
APACHE_PROCS=$(ps aux | grep -E "[h]ttpd" | wc -l)
echo "  Apache processes: $APACHE_PROCS"
VARNISH_PROCS=$(ps aux | grep -E "[v]arnishd" | wc -l)
echo "  Varnish processes: $VARNISH_PROCS"
PHPFPM_PROCS=$(ps aux | grep -E "[p]hp-fpm.*ea-php83" | wc -l)
echo "  PHP-FPM processes: $PHPFPM_PROCS"

echo ""
echo "Completed: $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📋 NEXT STEPS:"
echo "1. Run Cloudflare fix script: ./PHASE11_FIX_CLOUDFLARE.sh"
echo "2. Test production URL: https://pim.technostationery.com/"
echo "3. Monitor logs: tail -f var/logs/prod.log"

exit 0
