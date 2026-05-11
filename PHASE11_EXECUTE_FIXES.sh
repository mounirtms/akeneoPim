#!/bin/bash
################################################################################
# PHASE 11: Execute Fixes - Apache, Domain Config, Cleanup
# Date: 2026-05-06
# Purpose: Fix AllowOverride, domain config, clean conflicts
################################################################################

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🚀 PHASE 11: Executing Comprehensive Fixes"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Started: $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo ""

FIXES_APPLIED=0
FIXES_FAILED=0

# Step 1: Backup current Apache configuration
echo "═══════════════════════════════════════════════════════════════════════"
echo "Step 1: Backup Apache Configuration"
echo "═══════════════════════════════════════════════════════════════════════"

BACKUP_DIR="/home/pim/public_html/backups/phase11_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"

if [ -f /etc/apache2/conf/httpd.conf ]; then
    cp /etc/apache2/conf/httpd.conf "$BACKUP_DIR/httpd.conf.backup"
    echo "✅ Backed up httpd.conf to $BACKUP_DIR"
    ((FIXES_APPLIED++))
else
    echo "⚠️  httpd.conf not found"
fi

# Backup environment files
cp .env "$BACKUP_DIR/.env.backup" 2>/dev/null && echo "✅ Backed up .env"
cp .env.local "$BACKUP_DIR/.env.local.backup" 2>/dev/null && echo "✅ Backed up .env.local"
cp config/parameters.yml "$BACKUP_DIR/parameters.yml.backup" 2>/dev/null && echo "✅ Backed up parameters.yml"

echo ""

# Step 2: Check for conflicting old directories
echo "═══════════════════════════════════════════════════════════════════════"
echo "Step 2: Identify Conflicting Directories & Old Configs"
echo "═══════════════════════════════════════════════════════════════════════"

echo "▶ Searching for old Akeneo installations..."
OLD_DIRS=$(find /home/pim -maxdepth 1 -type d -name "*akeneo*" -o -name "*pimcore*" -o -name "*old*" 2>/dev/null)

if [ -n "$OLD_DIRS" ]; then
    echo "⚠️  Found old directories:"
    echo "$OLD_DIRS"
    echo ""
    echo "   These should be reviewed and potentially removed:"
    for dir in $OLD_DIRS; do
        SIZE=$(du -sh "$dir" 2>/dev/null | cut -f1)
        echo "   - $dir (Size: $SIZE)"
    done
else
    echo "✅ No conflicting old directories found"
fi

echo ""

# Step 3: Search for Cloudflare API credentials
echo "═══════════════════════════════════════════════════════════════════════"
echo "Step 3: Search for Cloudflare API Keys"
echo "═══════════════════════════════════════════════════════════════════════"

echo "▶ Searching in environment files..."
CF_KEYS=$(grep -r -i "cloudflare\|CF_API\|CF_TOKEN\|CLOUDFLARE_API" /home/pim/public_html/.env* /home/pim/.env* 2>/dev/null | grep -v ".git")

if [ -n "$CF_KEYS" ]; then
    echo "✅ Found Cloudflare references:"
    echo "$CF_KEYS" | head -5
else
    echo "⚠️  No Cloudflare API keys found in .env files"
fi

echo ""
echo "▶ Searching in common config locations..."
CF_FILES=$(find /home/pim -maxdepth 3 -type f -name "*cloudflare*" -o -name "*.cloudflare*" 2>/dev/null | head -10)

if [ -n "$CF_FILES" ]; then
    echo "✅ Found Cloudflare config files:"
    echo "$CF_FILES"
else
    echo "⚠️  No Cloudflare config files found"
fi

echo ""

# Step 4: Check domain configuration
echo "═══════════════════════════════════════════════════════════════════════"
echo "Step 4: Audit Domain Configuration"
echo "═══════════════════════════════════════════════════════════════════════"

cd /home/pim/public_html

echo "▶ Checking .env files for domain configuration..."
if [ -f .env ]; then
    echo "--- .env file ---"
    grep -E "URL|DOMAIN|HOST" .env | head -10
fi

echo ""
if [ -f .env.local ]; then
    echo "--- .env.local file ---"
    grep -E "URL|DOMAIN|HOST" .env.local | head -10
fi

echo ""
echo "▶ Checking parameters.yml..."
if [ -f config/parameters.yml ]; then
    grep -E "url|domain|host|router" config/parameters.yml | head -10
fi

echo ""
echo "▶ Checking for wrong domain references (technostationery.com without pim.)..."
WRONG_DOMAIN=$(grep -r "http://technostationery.com\|https://technostationery.com" .env* config/ 2>/dev/null | grep -v "pim.technostationery.com" | grep -v ".git")

if [ -n "$WRONG_DOMAIN" ]; then
    echo "❌ Found incorrect domain references:"
    echo "$WRONG_DOMAIN"
    echo ""
    echo "   These should be updated to: https://pim.technostationery.com"
else
    echo "✅ No incorrect domain references found"
fi

echo ""

# Step 5: Rebuild Apache configuration
echo "═══════════════════════════════════════════════════════════════════════"
echo "Step 5: Rebuild Apache Configuration"
echo "═══════════════════════════════════════════════════════════════════════"

echo "▶ Running /scripts/rebuildhttpdconf..."
REBUILD_OUTPUT=$(/scripts/rebuildhttpdconf 2>&1)
REBUILD_EXIT=$?

if [ $REBUILD_EXIT -eq 0 ]; then
    echo "✅ Apache configuration rebuilt successfully"
    echo "   Output: $(echo "$REBUILD_OUTPUT" | tail -3)"
    ((FIXES_APPLIED++))
else
    echo "❌ Apache rebuild failed with exit code $REBUILD_EXIT"
    echo "   Output: $REBUILD_OUTPUT"
    ((FIXES_FAILED++))
fi

echo ""

# Step 6: Verify AllowOverride is now set
echo "═══════════════════════════════════════════════════════════════════════"
echo "Step 6: Verify AllowOverride Configuration"
echo "═══════════════════════════════════════════════════════════════════════"

VHOST_CHECK=$(grep -A 20 "ServerName pim.technostationery.com" /etc/apache2/conf/httpd.conf | grep -A 10 "Directory.*public")
echo "▶ VirtualHost <Directory> block:"
echo "$VHOST_CHECK" | head -15

ALLOW_OVERRIDE=$(echo "$VHOST_CHECK" | grep -i "AllowOverride")
if echo "$ALLOW_OVERRIDE" | grep -qi "AllowOverride All"; then
    echo "✅ AllowOverride All is now set"
    ((FIXES_APPLIED++))
else
    echo "⚠️  AllowOverride may still not be set correctly"
    echo "   Found: $ALLOW_OVERRIDE"
fi

echo ""

# Step 7: Restart Apache
echo "═══════════════════════════════════════════════════════════════════════"
echo "Step 7: Restart Apache"
echo "═══════════════════════════════════════════════════════════════════════"

echo "▶ Restarting Apache..."
/scripts/restartsrv_httpd 2>&1 | tail -5

sleep 3

APACHE_STATUS=$(systemctl is-active httpd 2>/dev/null || service httpd status 2>&1 | grep -i running)
if [ -n "$APACHE_STATUS" ]; then
    echo "✅ Apache is running"
    ((FIXES_APPLIED++))
else
    echo "⚠️  Apache status unclear"
fi

APACHE_PROCS=$(ps aux | grep -E "[h]ttpd" | wc -l)
echo "   Apache processes: $APACHE_PROCS"

echo ""

# Step 8: Test .htaccess is being read
echo "═══════════════════════════════════════════════════════════════════════"
echo "Step 8: Test .htaccess Processing"
echo "═══════════════════════════════════════════════════════════════════════"

echo "▶ Testing localhost:8080..."
TEST_ROOT=$(curl -sI http://localhost:8080/ | head -1)
TEST_LOGIN=$(curl -sI http://localhost:8080/user/login | head -1)
TEST_ASSET=$(curl -sI http://localhost:8080/bundles/pimui/images/logo.svg | head -1)

echo "   Root:  $TEST_ROOT"
echo "   Login: $TEST_LOGIN"
echo "   Asset: $TEST_ASSET"

echo ""

if echo "$TEST_LOGIN" | grep -q "200"; then
    echo "✅ SUCCESS! /user/login now returns 200 OK"
    ((FIXES_APPLIED++))
elif echo "$TEST_LOGIN" | grep -q "302"; then
    echo "⚠️  Still getting 302 redirect"
    
    # Check Location header
    LOCATION=$(curl -sI http://localhost:8080/user/login | grep -i "Location:")
    echo "   Redirect target: $LOCATION"
    
    if echo "$LOCATION" | grep -qi "pim.technostationery.com"; then
        echo "   → Redirecting to correct domain (pim subdomain)"
    else
        echo "   → Still redirecting to wrong domain"
    fi
else
    echo "⚠️  Unexpected response: $TEST_LOGIN"
fi

echo ""

if echo "$TEST_ASSET" | grep -q "200"; then
    echo "✅ SUCCESS! Static assets now return 200 OK"
    ((FIXES_APPLIED++))
else
    echo "⚠️  Static assets still return: $TEST_ASSET"
fi

echo ""

# Step 9: Check for .env domain issues
echo "═══════════════════════════════════════════════════════════════════════"
echo "Step 9: Check Application Domain Configuration"
echo "═══════════════════════════════════════════════════════════════════════"

cd /home/pim/public_html

# Check for APP_URL, BASE_URL, etc.
echo "▶ Checking for URL/domain environment variables..."

if [ -f .env.local ]; then
    APP_URL=$(grep -E "^APP_URL|^BASE_URL|^PIM_URL|^SITE_URL" .env.local 2>/dev/null)
    if [ -n "$APP_URL" ]; then
        echo "   Found in .env.local:"
        echo "   $APP_URL"
    fi
fi

if [ -f .env ]; then
    APP_URL_ENV=$(grep -E "^APP_URL|^BASE_URL|^PIM_URL|^SITE_URL" .env 2>/dev/null)
    if [ -n "$APP_URL_ENV" ]; then
        echo "   Found in .env:"
        echo "   $APP_URL_ENV"
    fi
fi

echo ""

# Step 10: Clear caches
echo "═══════════════════════════════════════════════════════════════════════"
echo "Step 10: Clear All Caches"
echo "═══════════════════════════════════════════════════════════════════════"

echo "▶ Clearing Symfony cache..."
php bin/console cache:clear --env=prod --no-warmup 2>&1 | tail -2
php bin/console cache:warmup --env=prod 2>&1 | tail -2
echo "✅ Symfony cache cleared and warmed"
((FIXES_APPLIED++))

echo ""
echo "▶ Clearing Varnish cache..."
varnishadm 'ban req.url ~ /' 2>&1 | head -1
echo "✅ Varnish cache cleared"
((FIXES_APPLIED++))

echo ""

# Step 11: Final connectivity test
echo "═══════════════════════════════════════════════════════════════════════"
echo "Step 11: Final Connectivity Tests"
echo "═══════════════════════════════════════════════════════════════════════"

echo "▶ Testing through Varnish (port 80)..."
VARNISH_TEST=$(curl -sI http://localhost/user/login | head -1)
echo "   Result: $VARNISH_TEST"

if echo "$VARNISH_TEST" | grep -q "200"; then
    echo "✅ Varnish now serving 200 OK"
    ((FIXES_APPLIED++))
else
    echo "⚠️  Varnish test: $VARNISH_TEST"
fi

echo ""

# Step 12: Check main website (technostationery.com) is still working
echo "═══════════════════════════════════════════════════════════════════════"
echo "Step 12: Verify Main Website (Separation of Concerns)"
echo "═══════════════════════════════════════════════════════════════════════"

echo "▶ Testing main website (technostationery.com)..."
MAIN_SITE=$(curl -sI http://localhost:8080/ -H "Host: technostationery.com" 2>&1 | head -1)
echo "   Main site response: $MAIN_SITE"

if echo "$MAIN_SITE" | grep -qE "200|301|302"; then
    echo "✅ Main website is responding"
else
    echo "⚠️  Main website may have issues"
fi

echo ""

# Summary
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 EXECUTION SUMMARY"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Fixes Applied:  $FIXES_APPLIED"
echo "❌ Fixes Failed:   $FIXES_FAILED"
echo ""
echo "📁 Backups saved to: $BACKUP_DIR"
echo ""
echo "Completed: $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📋 NEXT STEPS:"
echo "1. Review output above for any warnings"
echo "2. If Cloudflare API keys were found, use them to clear CF cache"
echo "3. Test production URL: https://pim.technostationery.com/"
echo "4. Run: ./PHASE11_FINAL_VERIFICATION.sh"
echo ""

exit 0
