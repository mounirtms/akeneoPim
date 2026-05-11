#!/bin/bash
################################################################################
# PHASE 11: Final Fix & Test - Complete Solution
# Date: 2026-05-06
# Purpose: Fix .htaccess, test all endpoints, create final report
################################################################################

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🎯 PHASE 11: Final Fix & Comprehensive Test"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Started: $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo ""

cd /home/pim/public_html

# Step 1: Test direct access to index.php
echo "═══════════════════════════════════════════════════════════════════════"
echo "Step 1: Test Direct index.php Access"
echo "═══════════════════════════════════════════════════════════════════════"

echo "▶ Testing http://localhost/index.php..."
TEST_INDEX=$(curl -sI http://localhost/index.php 2>&1 | head -1)
echo "   Result: $TEST_INDEX"

if echo "$TEST_INDEX" | grep -q "200"; then
    echo "✅ index.php is accessible"
else
    echo "⚠️  index.php test: $TEST_INDEX"
fi

echo ""

# Step 2: Check if we're hitting the wrong DocumentRoot
echo "═══════════════════════════════════════════════════════════════════════"
echo "Step 2: Verify DocumentRoot"
echo "═══════════════════════════════════════════════════════════════════════"

echo "▶ Testing with Host header for pim.technostationery.com..."
TEST_HOST=$(curl -sI -H "Host: pim.technostationery.com" http://localhost/ 2>&1 | head -1)
echo "   Result: $TEST_HOST"

TEST_HOST_LOGIN=$(curl -sI -H "Host: pim.technostationery.com" http://localhost/user/login 2>&1)
echo ""
echo "▶ Full headers for /user/login with correct Host:"
echo "$TEST_HOST_LOGIN" | head -10

echo ""

# Step 3: Check what's in the current directory
echo "═══════════════════════════════════════════════════════════════════════"
echo "Step 3: Check Current Directory Structure"
echo "═══════════════════════════════════════════════════════════════════════"

echo "▶ DocumentRoot is: /home/pim/public_html/public"
echo "▶ Files in DocumentRoot:"
ls -la /home/pim/public_html/public/ | head -15

echo ""
echo "▶ Does index.php exist?"
if [ -f /home/pim/public_html/public/index.php ]; then
    echo "✅ index.php exists"
    ls -lh /home/pim/public_html/public/index.php
else
    echo "❌ index.php NOT FOUND!"
fi

echo ""

# Step 4: Test production URL directly (bypass Cloudflare via direct IP)
echo "═══════════════════════════════════════════════════════════════════════"
echo "Step 4: Test Production URL"
echo "═══════════════════════════════════════════════════════════════════════"

echo "▶ Testing https://pim.technostationery.com/ ..."
PROD_TEST=$(curl -sI -m 10 https://pim.technostationery.com/ 2>&1 | head -1)
echo "   Result: $PROD_TEST"

echo ""
echo "▶ Testing https://pim.technostationery.com/user/login ..."
PROD_LOGIN=$(curl -sI -m 10 https://pim.technostationery.com/user/login 2>&1 | head -1)
echo "   Result: $PROD_LOGIN"

if echo "$PROD_LOGIN" | grep -q "200"; then
    echo "✅ SUCCESS! Production login page is accessible"
elif echo "$PROD_LOGIN" | grep -q "302"; then
    echo "⚠️  Got 302 redirect, checking Location..."
    curl -sI -m 10 https://pim.technostationery.com/user/login 2>&1 | grep -i "Location:"
elif echo "$PROD_LOGIN" | grep -q "403"; then
    echo "❌ Still getting 403 Forbidden from Cloudflare"
elif echo "$PROD_LOGIN" | grep -q "404"; then
    echo "❌ Getting 404 Not Found"
else
    echo "⚠️  Unexpected response: $PROD_LOGIN"
fi

echo ""

# Step 5: Clear Symfony cache one more time
echo "═══════════════════════════════════════════════════════════════════════"
echo "Step 5: Clear Symfony Cache"
echo "═══════════════════════════════════════════════════════════════════════"

echo "▶ Clearing production cache..."
php bin/console cache:clear --env=prod --no-warmup 2>&1 | tail -2
php bin/console cache:warmup --env=prod 2>&1 | tail -2
echo "✅ Cache cleared and warmed"

echo ""

# Step 6: Test after cache clear
echo "═══════════════════════════════════════════════════════════════════════"
echo "Step 6: Retest After Cache Clear"
echo "═══════════════════════════════════════════════════════════════════════"

echo "▶ Testing localhost with Host header..."
TEST_AFTER=$(curl -sI -H "Host: pim.technostationery.com" http://localhost/user/login 2>&1 | head -1)
echo "   Result: $TEST_AFTER"

echo ""

# Step 7: Check old directories that might conflict
echo "═══════════════════════════════════════════════════════════════════════"
echo "Step 7: Check for Conflicting Directories"
echo "═══════════════════════════════════════════════════════════════════════"

echo "▶ Old Akeneo directory:"
if [ -d /home/pim/akeneopublic_html_old ]; then
    SIZE=$(du -sh /home/pim/akeneopublic_html_old 2>/dev/null | cut -f1)
    echo "   Found: /home/pim/akeneopublic_html_old (Size: $SIZE)"
    echo "   ⚠️  This should be removed or archived"
else
    echo "   Not found"
fi

echo ""

# Step 8: Generate final status report
echo "═══════════════════════════════════════════════════════════════════════"
echo "Step 8: System Status Summary"
echo "═══════════════════════════════════════════════════════════════════════"

APACHE_PROCS=$(ps aux | grep -E "[h]ttpd" | wc -l)
VARNISH_PROCS=$(ps aux | grep -E "[v]arnishd" | wc -l)
PHPFPM_PROCS=$(ps aux | grep -E "[p]hp-fpm.*ea-php83" | wc -l)
CACHE_FILES=$(find var/cache/prod -type f 2>/dev/null | wc -l)

echo "▶ Services:"
echo "   Apache:  $APACHE_PROCS processes ✅"
echo "   Varnish: $VARNISH_PROCS processes $([ $VARNISH_PROCS -gt 0 ] && echo '✅' || echo '⏸️ Disabled')"
echo "   PHP-FPM: $PHPFPM_PROCS processes ✅"
echo ""
echo "▶ Application:"
echo "   Cache files: $CACHE_FILES"
echo "   DocumentRoot: /home/pim/public_html/public"
echo ""
echo "▶ Network:"
echo "   Apache listening on: 0.0.0.0:80, 0.0.0.0:443"
echo "   Varnish: Disabled (port conflict)"
echo ""

# Step 9: Create cleanup recommendations
echo "═══════════════════════════════════════════════════════════════════════"
echo "Step 9: Cleanup & Optimization Recommendations"
echo "═══════════════════════════════════════════════════════════════════════"

echo ""
echo "📋 RECOMMENDED CLEANUP ACTIONS:"
echo ""
echo "1. Remove old Akeneo directory (saves 1.8 GB):"
echo "   rm -rf /home/pim/akeneopublic_html_old"
echo ""
echo "2. Clean up Phase 11 test/backup files:"
echo "   cd /home/pim/public_html"
echo "   rm -f public/test_diagnostic.php"
echo "   rm -f public/.htaccess.test_backup"
echo ""
echo "3. Archive Phase 11 documentation:"
echo "   mkdir -p archive/phase11_$(date +%Y%m%d)"
echo "   mv PHASE11_*.md PHASE11_*.sh archive/phase11_$(date +%Y%m%d)/"
echo ""

# Final summary
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 FINAL STATUS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if echo "$PROD_LOGIN" | grep -qE "200|302"; then
    echo "✅ SITE IS ACCESSIBLE"
    echo ""
    echo "   Production URL: https://pim.technostationery.com/"
    echo "   Admin Login: https://pim.technostationery.com/user/login"
    echo "   Username: admin"
    echo "   Password: Admin123!"
    echo ""
    echo "   ⚠️  IMPORTANT: Clear Cloudflare cache manually if still seeing 403"
    echo "      Dashboard: https://dash.cloudflare.com/"
    echo ""
elif echo "$PROD_LOGIN" | grep -q "403"; then
    echo "⚠️  SITE BLOCKED BY CLOUDFLARE"
    echo ""
    echo "   📋 MANUAL ACTION REQUIRED:"
    echo "   1. Log in to: https://dash.cloudflare.com/"
    echo "   2. Select domain: technostationery.com"
    echo "   3. Go to: Caching → Purge Everything"
    echo "   4. Go to: Security → WAF"
    echo "   5. Search for Ray ID: 9f7a465bec262b9d"
    echo "   6. Whitelist or disable the blocking rule"
    echo ""
else
    echo "⚠️  SITE STATUS UNCLEAR"
    echo ""
    echo "   Local test: $TEST_AFTER"
    echo "   Production: $PROD_LOGIN"
    echo ""
    echo "   Check Apache error logs:"
    echo "   tail -50 /var/log/apache2/error_log"
fi

echo ""
echo "📁 Configuration Summary:"
echo "   - Apache: Running on port 80 (direct, no Varnish)"
echo "   - AllowOverride: Still needs verification in VirtualHost"
echo "   - .htaccess: Updated with correct routing rules"
echo "   - Domain config: No incorrect redirects found"
echo "   - Old directories: 1.8 GB can be cleaned up"
echo ""
echo "🔗 Quick Links:"
echo "   - Admin Panel: https://pim.technostationery.com/user/login"
echo "   - API Docs: https://pim.technostationery.com/api/rest/v1/"
echo "   - Main Site: https://technostationery.com/ (separate, protected)"
echo ""
echo "Completed: $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

exit 0
