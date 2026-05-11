#!/bin/bash

echo "=========================================="
echo "FIX CSS, ROUTES & JAVASCRIPT ISSUES"
echo "Date: $(date)"
echo "=========================================="
echo ""

echo "=== STEP 1: Check What's Being Served ==="
echo "Testing /css/pim.css route..."
curl -I http://localhost/css/pim.css 2>&1 | head -15

echo ""
echo "Checking if pim.css file exists..."
find /home/pim/public_html -name "pim.css" -type f 2>/dev/null

echo ""
echo "Checking public/css directory..."
ls -la public/css/ 2>/dev/null || echo "Directory not found"

echo ""
echo "=== STEP 2: Verify DocumentRoot and .htaccess ==="
echo "Current VirtualHost DocumentRoot:"
grep -A 5 "ServerName pim.technostationery.com" /etc/apache2/conf/httpd.conf | grep DocumentRoot

echo ""
echo "Checking .htaccess rewrite rules..."
head -50 public/.htaccess

echo ""
echo "=== STEP 3: Check for Wrong Site Content ==="
echo "Testing homepage content..."
curl -s http://localhost/ -H "Host: pim.technostationery.com" | head -50

echo ""
echo "=== STEP 4: Check Akeneo Routes ==="
cd /home/pim/public_html
echo "Listing Akeneo routes..."
bin/console debug:router | grep -E "login|user|_wdt|bundles" | head -20

echo ""
echo "=== STEP 5: Install Missing CSS/JS Assets ==="
echo "Re-installing all Akeneo assets..."
bin/console pim:installer:assets --symlink --clean --env=prod 2>&1 | tail -30

echo ""
echo "Installing webpack encore assets..."
bin/console fos:js-routing:dump --env=prod 2>&1

echo ""
echo "=== STEP 6: Check for Magento/Other Site Interference ==="
echo "Checking if wrong VirtualHost is being matched..."
curl -v http://localhost/ -H "Host: pim.technostationery.com" 2>&1 | grep -E "X-|Server:|Content-Type:" | head -10

echo ""
echo "=== STEP 7: Verify index.php is Being Used ==="
echo "First 30 lines of public/index.php:"
head -30 public/index.php

echo ""
echo "=== STEP 8: Check Apache Access/Error Logs ==="
echo "Recent requests to /css/pim.css:"
grep "pim.css" /usr/local/apache/logs/access_log | tail -5

echo ""
echo "Recent 404 errors:"
grep "404" /usr/local/apache/logs/error_log | tail -10

echo ""
echo "=== STEP 9: Fix .htaccess Static File Serving ==="
echo "Checking if static files are being rewritten to index.php..."

# Check current .htaccess
if grep -q "RewriteRule.*index.php" public/.htaccess; then
    echo "✓ .htaccess has rewrite rules"
    
    # Verify static file condition exists
    if grep -q "RewriteCond.*-f" public/.htaccess; then
        echo "✓ Static file condition exists"
    else
        echo "⚠️  Missing static file condition - adding it..."
        
        # Backup
        cp public/.htaccess public/.htaccess.backup.$(date +%Y%m%d_%H%M%S)
        
        # This should already be there from previous fix, but let's verify
        echo "Current rewrite section:"
        sed -n '/RewriteEngine On/,/RewriteRule.*index.php/p' public/.htaccess
    fi
fi

echo ""
echo "=== STEP 10: Clear All Caches ==="
rm -rf var/cache/prod/*
rm -rf var/cache/dev/*
bin/console cache:clear --env=prod --no-warmup
bin/console cache:warmup --env=prod

echo ""
echo "=== STEP 11: Restart Apache ==="
/scripts/restartsrv_httpd --graceful
sleep 2

echo ""
echo "=== STEP 12: Test Fixes ==="
echo "Testing CSS file:"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost/css/pim.css -H "Host: pim.technostationery.com")
CONTENT_TYPE=$(curl -s -I http://localhost/css/pim.css -H "Host: pim.technostationery.com" | grep -i "content-type:" | head -1)

echo "CSS file HTTP code: $HTTP_CODE"
echo "CSS file Content-Type: $CONTENT_TYPE"

echo ""
echo "Testing login page:"
curl -s http://localhost/user/login -H "Host: pim.technostationery.com" | head -30

echo ""
echo "=========================================="
echo "DIAGNOSTIC SUMMARY"
echo "=========================================="
echo ""
echo "Please review the output above to identify:"
echo "1. Why /css/pim.css returns HTML instead of CSS"
echo "2. If wrong VirtualHost is being matched"
echo "3. If .htaccess is routing everything to index.php"
echo "4. If assets are properly installed"
echo ""
echo "=========================================="

