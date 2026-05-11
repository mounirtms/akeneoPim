#!/bin/bash
################################################################################
# PHASE 11: Deep Diagnostic - Find 302 Redirect Source
# Date: 2026-05-06
# Purpose: Identify why all requests return HTTP 302 redirects
################################################################################

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔍 PHASE 11: Deep Diagnostic - 302 Redirect Investigation"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Started: $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo ""

# Test 1: Check if .htaccess is being read
echo "═══════════════════════════════════════════════════════════════════════"
echo "Test 1: Is .htaccess Being Read?"
echo "═══════════════════════════════════════════════════════════════════════"

# Add a syntax error to .htaccess temporarily to see if Apache reads it
cp /home/pim/public_html/public/.htaccess /home/pim/public_html/public/.htaccess.test_backup
echo "SYNTAX_ERROR_TEST_12345" >> /home/pim/public_html/public/.htaccess

TEST_RESULT=$(curl -sI http://localhost:8080/ 2>&1 | head -1)

# Restore .htaccess
mv /home/pim/public_html/public/.htaccess.test_backup /home/pim/public_html/public/.htaccess

if echo "$TEST_RESULT" | grep -q "500"; then
    echo "✅ .htaccess IS being read by Apache (500 error triggered)"
    HTACCESS_READ="YES"
else
    echo "❌ .htaccess is NOT being read (no 500 error)"
    echo "   This means AllowOverride is likely set to None"
    HTACCESS_READ="NO"
fi
echo ""

# Test 2: Check Apache VirtualHost AllowOverride
echo "═══════════════════════════════════════════════════════════════════════"
echo "Test 2: Apache VirtualHost Configuration"
echo "═══════════════════════════════════════════════════════════════════════"

echo "▶ Checking AllowOverride in VirtualHost config:"
VHOST_CONFIG=$(grep -A 50 "ServerName pim.technostationery.com" /etc/apache2/conf/httpd.conf | grep -A 20 "Directory.*public")
echo "$VHOST_CONFIG" | head -15

ALLOW_OVERRIDE=$(echo "$VHOST_CONFIG" | grep -i "AllowOverride" | head -1)
echo ""
echo "▶ AllowOverride setting: $ALLOW_OVERRIDE"

if echo "$ALLOW_OVERRIDE" | grep -qi "AllowOverride All"; then
    echo "✅ AllowOverride is set to All"
else
    echo "❌ AllowOverride is NOT set to All (this is the problem!)"
fi
echo ""

# Test 3: Check mod_rewrite
echo "═══════════════════════════════════════════════════════════════════════"
echo "Test 3: mod_rewrite Status"
echo "═══════════════════════════════════════════════════════════════════════"

MOD_REWRITE=$(httpd -M 2>&1 | grep rewrite)
if [ -n "$MOD_REWRITE" ]; then
    echo "✅ mod_rewrite is loaded: $MOD_REWRITE"
else
    echo "❌ mod_rewrite is NOT loaded"
fi
echo ""

# Test 4: Test direct PHP file
echo "═══════════════════════════════════════════════════════════════════════"
echo "Test 4: Direct PHP Execution Test"
echo "═══════════════════════════════════════════════════════════════════════"

cat > /home/pim/public_html/public/test_diagnostic.php << 'PHPTEST'
<?php
header('Content-Type: text/plain');
echo "PHP_VERSION: " . PHP_VERSION . "\n";
echo "DOCUMENT_ROOT: " . $_SERVER['DOCUMENT_ROOT'] . "\n";
echo "REQUEST_URI: " . $_SERVER['REQUEST_URI'] . "\n";
echo "SCRIPT_NAME: " . $_SERVER['SCRIPT_NAME'] . "\n";
echo "\nPHP is working correctly!\n";
PHPTEST

PHP_TEST=$(curl -s http://localhost:8080/test_diagnostic.php 2>&1)
PHP_TEST_STATUS=$(curl -sI http://localhost:8080/test_diagnostic.php 2>&1 | head -1)

echo "▶ PHP test file status: $PHP_TEST_STATUS"
echo "▶ PHP test file output:"
echo "$PHP_TEST" | head -10

if echo "$PHP_TEST_STATUS" | grep -q "200"; then
    echo "✅ Direct PHP execution works (returns 200)"
elif echo "$PHP_TEST_STATUS" | grep -q "302"; then
    echo "❌ Direct PHP file also returns 302!"
    echo "   This means the redirect is at Apache VirtualHost level, NOT in PHP code"
else
    echo "⚠️  Unexpected status: $PHP_TEST_STATUS"
fi

# Clean up test file
rm -f /home/pim/public_html/public/test_diagnostic.php
echo ""

# Test 5: Check for HTTP to HTTPS redirects
echo "═══════════════════════════════════════════════════════════════════════"
echo "Test 5: Redirect Location Header Analysis"
echo "═══════════════════════════════════════════════════════════════════════"

FULL_HEADERS=$(curl -sI http://localhost:8080/ 2>&1)
echo "▶ Full headers from localhost:8080/:"
echo "$FULL_HEADERS" | head -15

LOCATION=$(echo "$FULL_HEADERS" | grep -i "Location:")
if [ -n "$LOCATION" ]; then
    echo ""
    echo "▶ Redirect Location found: $LOCATION"
    
    if echo "$LOCATION" | grep -qi "https"; then
        echo "   → Redirecting to HTTPS"
        echo "   This could be a VirtualHost or .htaccess HTTPS redirect"
    fi
else
    echo "   No Location header found"
fi
echo ""

# Test 6: Check index.php for redirects
echo "═══════════════════════════════════════════════════════════════════════"
echo "Test 6: Check index.php for Hardcoded Redirects"
echo "═══════════════════════════════════════════════════════════════════════"

INDEX_REDIRECTS=$(grep -n -E "header.*Location|redirect|301|302" /home/pim/public_html/public/index.php 2>/dev/null | head -10)
if [ -n "$INDEX_REDIRECTS" ]; then
    echo "⚠️  Found potential redirects in index.php:"
    echo "$INDEX_REDIRECTS"
else
    echo "✅ No obvious redirects in index.php"
fi
echo ""

# Test 7: Check static file access
echo "═══════════════════════════════════════════════════════════════════════"
echo "Test 7: Static File Direct Access"
echo "═══════════════════════════════════════════════════════════════════════"

LOGO_EXISTS=$(ls -la /home/pim/public_html/public/bundles/pimui/images/logo.svg 2>&1)
if echo "$LOGO_EXISTS" | grep -q "logo.svg"; then
    echo "✅ Logo file exists:"
    echo "$LOGO_EXISTS"
    
    LOGO_STATUS=$(curl -sI http://localhost:8080/bundles/pimui/images/logo.svg 2>&1 | head -1)
    echo ""
    echo "▶ Logo file HTTP status: $LOGO_STATUS"
    
    if echo "$LOGO_STATUS" | grep -q "200"; then
        echo "✅ Static file returns 200 OK"
    elif echo "$LOGO_STATUS" | grep -q "302"; then
        echo "❌ Static file also returns 302!"
        echo "   This confirms the issue is NOT in Symfony routing"
        echo "   The redirect happens BEFORE .htaccess rules are processed"
    fi
else
    echo "⚠️  Logo file not found"
fi
echo ""

# Test 8: Check .htaccess permissions
echo "═══════════════════════════════════════════════════════════════════════"
echo "Test 8: File Permissions"
echo "═══════════════════════════════════════════════════════════════════════"

echo "▶ Root .htaccess permissions:"
ls -la /home/pim/public_html/.htaccess

echo ""
echo "▶ Public .htaccess permissions:"
ls -la /home/pim/public_html/public/.htaccess

echo ""
echo "▶ Public directory permissions:"
ls -lad /home/pim/public_html/public
echo ""

# Test 9: Check for .htaccess in parent directories
echo "═══════════════════════════════════════════════════════════════════════"
echo "Test 9: Check for Interfering .htaccess Files"
echo "═══════════════════════════════════════════════════════════════════════"

PARENT_HTACCESS=$(find /home/pim -maxdepth 2 -name ".htaccess" 2>/dev/null)
echo "▶ Found .htaccess files:"
echo "$PARENT_HTACCESS"
echo ""

# Test 10: Check Apache error log
echo "═══════════════════════════════════════════════════════════════════════"
echo "Test 10: Recent Apache Error Log"
echo "═══════════════════════════════════════════════════════════════════════"

ERROR_LOG="/var/log/apache2/domlogs/pim/pim.technostationery.com-error_log"
if [ -f "$ERROR_LOG" ]; then
    echo "▶ Last 10 error log entries:"
    tail -10 "$ERROR_LOG" 2>/dev/null
else
    echo "⚠️  Error log not found at $ERROR_LOG"
fi
echo ""

# Summary and Recommendations
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 DIAGNOSTIC SUMMARY"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Determine root cause
if [ "$HTACCESS_READ" = "NO" ]; then
    echo "🔴 ROOT CAUSE IDENTIFIED: .htaccess is NOT being read"
    echo ""
    echo "📋 RECOMMENDED FIX:"
    echo "   1. Check VirtualHost configuration in /etc/apache2/conf/httpd.conf"
    echo "   2. Ensure <Directory> block for /home/pim/public_html/public has:"
    echo "      AllowOverride All"
    echo "   3. Run: /scripts/rebuildhttpdconf"
    echo "   4. Run: /scripts/restartsrv_httpd"
    echo ""
    echo "   OR use the automated fix script: ./PHASE11_FIX_VHOST.sh"
else
    echo "⚠️  .htaccess IS being read, but 302 redirects still occur"
    echo ""
    echo "📋 POSSIBLE CAUSES:"
    echo "   1. HTTP to HTTPS redirect in VirtualHost or .htaccess"
    echo "   2. PHP code in index.php causing redirects"
    echo "   3. Symfony routing configuration issue"
    echo ""
    echo "📋 RECOMMENDED ACTIONS:"
    echo "   1. Check the 'Location' header in Test 5 above"
    echo "   2. Temporarily disable HTTPS redirect in public/.htaccess"
    echo "   3. Test with: curl -v http://localhost:8080/user/login"
fi

echo ""
echo "Completed: $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

exit 0
