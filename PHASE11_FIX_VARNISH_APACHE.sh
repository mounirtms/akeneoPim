#!/bin/bash
# PHASE11_FIX_VARNISH_APACHE.sh - Fix Varnish/Apache directory index issue
# Date: 2026-05-06

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔧 PHASE 11: FIX VARNISH/APACHE ROUTING"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Start time: $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo ""

FIXES_APPLIED=0
FIXES_FAILED=0

# Fix 1: Update public/.htaccess with DirectoryIndex
echo "1. Adding DirectoryIndex to public/.htaccess..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check if DirectoryIndex already exists
if ! grep -q "DirectoryIndex" public/.htaccess; then
    # Add DirectoryIndex at the top of public/.htaccess
    sed -i '1i# Force index.php as directory index\nDirectoryIndex index.php index.html\n\n# Disable directory listing\nOptions -Indexes +FollowSymLinks\n' public/.htaccess
    echo "✓ DirectoryIndex added to public/.htaccess"
    ((FIXES_APPLIED++))
else
    echo "✓ DirectoryIndex already present"
    ((FIXES_APPLIED++))
fi
echo ""

# Fix 2: Create .htaccess in root to redirect to public/
echo "2. Updating root .htaccess for proper routing..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

cat > .htaccess << 'HTACCESS_EOF'
# Akeneo PIM Configuration
# Updated: 2026-05-06 - Phase 11 Fixes

RewriteEngine On
RewriteBase /

# Disable directory listing
Options -Indexes

# Prevent direct access to /public directory
RewriteCond %{REQUEST_URI} ^/public/
RewriteRule ^ - [F,L]

# Static files - check in public/ subdirectory and serve directly
RewriteCond %{REQUEST_URI} ^/(bundles|css|js|dist|images|img|media|favicon\.ico|robots\.txt)
RewriteCond %{DOCUMENT_ROOT}/public%{REQUEST_URI} -f [OR]
RewriteCond %{DOCUMENT_ROOT}/public%{REQUEST_URI} -d
RewriteRule ^ public%{REQUEST_URI} [L]

# Everything else goes to public/index.php
RewriteCond %{REQUEST_FILENAME} !-f
RewriteCond %{REQUEST_FILENAME} !-d
RewriteRule ^ public/index.php [QSA,L]

# php -- BEGIN cPanel-generated handler, do not edit
# Set the "ea-php83" package as the default "PHP" programming language.
<IfModule mime_module>
  AddHandler application/x-httpd-ea-php83 .php .php8 .phtml
</IfModule>
# php -- END cPanel-generated handler, do not edit
HTACCESS_EOF

echo "✓ Root .htaccess updated with Options -Indexes"
((FIXES_APPLIED++))
echo ""

# Fix 3: Update public/.htaccess
echo "3. Updating public/.htaccess with proper directives..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

cat > public/.htaccess << 'PUBLIC_HTACCESS_EOF'
# Akeneo PIM public/.htaccess
# Updated: 2026-05-06 - Phase 11 Fixes

# Force index.php as directory index
DirectoryIndex index.php index.html

# Disable directory listing
Options -Indexes +FollowSymLinks

RewriteEngine On

# Serve static files directly
RewriteCond %{REQUEST_URI} ^/(dist|css|js|bundles|media|images|img|favicon\.ico|robots\.txt)
RewriteCond %{REQUEST_FILENAME} -f
RewriteRule ^ - [L]

# Pass Authorization header to PHP (required for API OAuth)
RewriteCond %{HTTP:Authorization} ^(.+)$
RewriteRule .* - [E=HTTP_AUTHORIZATION:%{HTTP:Authorization}]

# Pass PHP_AUTH headers for Basic Auth
SetEnvIf Authorization "(.*)" HTTP_AUTHORIZATION=$1

# Route all other requests to index.php
RewriteCond %{REQUEST_FILENAME} !-f
RewriteRule ^(.*)$ index.php [QSA,L]

# AddHandler for PHP 8.3
AddHandler application/x-httpd-ea-php83 .php

# Security & CORS headers
Header unset Content-Security-Policy
Header unset X-Content-Security-Policy
Header unset X-WebKit-CSP
Header unset Access-Control-Allow-Origin
Header unset Access-Control-Allow-Methods
Header unset Access-Control-Allow-Headers

# Set permissive headers for development
Header set Content-Security-Policy "default-src 'self' 'unsafe-inline' 'unsafe-eval' data: blob: *; script-src 'self' 'unsafe-inline' 'unsafe-eval' *; style-src 'self' 'unsafe-inline' *; img-src 'self' data: blob: *; font-src 'self' data: *; connect-src 'self' *; frame-src *;"
Header set X-Content-Security-Policy "default-src 'self' 'unsafe-inline' 'unsafe-eval' *; script-src 'self' 'unsafe-inline' 'unsafe-eval' *; style-src 'self' 'unsafe-inline' *; img-src 'self' data: *; font-src 'self' data: *; connect-src 'self' *;"
Header set Access-Control-Allow-Origin "*"
Header set Access-Control-Allow-Methods "GET, POST, PUT, DELETE, OPTIONS"
Header set Access-Control-Allow-Headers "Content-Type, Authorization, X-Requested-With"
PUBLIC_HTACCESS_EOF

echo "✓ public/.htaccess updated with DirectoryIndex and Options -Indexes"
((FIXES_APPLIED++))
echo ""

# Fix 4: Clear Symfony cache
echo "4. Clearing Symfony cache..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
php bin/console cache:clear --env=prod --no-warmup 2>&1 | tail -3
php bin/console cache:warmup --env=prod 2>&1 | tail -3
echo "✓ Symfony cache cleared and warmed"
((FIXES_APPLIED++))
echo ""

# Fix 5: Test Apache configuration
echo "5. Testing Apache configuration..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
httpd -t 2>&1 | tail -5
if [ ${PIPESTATUS[0]} -eq 0 ]; then
    echo "✓ Apache configuration valid"
    ((FIXES_APPLIED++))
else
    echo "✗ Apache configuration has errors"
    ((FIXES_FAILED++))
fi
echo ""

# Fix 6: Clear Varnish cache
echo "6. Clearing Varnish cache..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if command -v varnishadm &> /dev/null; then
    varnishadm "ban req.url ~ /" 2>&1
    if [ $? -eq 0 ]; then
        echo "✓ Varnish cache cleared"
        ((FIXES_APPLIED++))
    else
        echo "⚠ Varnish cache clear failed (may need sudo)"
        echo "  Manual command: sudo varnishadm 'ban req.url ~ /'"
    fi
else
    echo "⚠ varnishadm not available (may need sudo)"
    echo "  Manual command: sudo varnishadm 'ban req.url ~ /'"
fi
echo ""

# Fix 7: Test direct PHP execution
echo "7. Testing PHP index.php execution..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
PHP_OUTPUT=$(timeout 3 php public/index.php 2>&1)
if echo "$PHP_OUTPUT" | grep -q "user/login"; then
    echo "✓ PHP index.php returns redirect to /user/login"
    ((FIXES_APPLIED++))
else
    echo "✗ PHP index.php test failed"
    echo "$PHP_OUTPUT" | head -10
    ((FIXES_FAILED++))
fi
echo ""

# Fix 8: Test via localhost (bypassing Varnish)
echo "8. Testing via localhost:8080 (direct Apache)..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
LOCAL_TEST=$(timeout 3 curl -s -H "Host: pim.technostationery.com" http://localhost:8080/ 2>/dev/null)
if echo "$LOCAL_TEST" | grep -q "user/login"; then
    echo "✓ Localhost:8080 returns redirect to /user/login"
    ((FIXES_APPLIED++))
else
    echo "⚠ Localhost:8080 still shows directory index"
    echo "  This will be fixed after Apache restart"
fi
echo ""

# Summary
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 FIX SUMMARY"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Fixes Applied: $FIXES_APPLIED"
echo "Fixes Failed: $FIXES_FAILED"
echo ""
echo "End time: $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo ""

if [ $FIXES_FAILED -eq 0 ]; then
    echo "✅ ALL FIXES APPLIED SUCCESSFULLY"
    echo ""
    echo "🚨 CRITICAL NEXT STEPS:"
    echo "1. Restart Apache: /scripts/restartsrv_httpd"
    echo "2. Clear Cloudflare cache (manual via dashboard)"
    echo "3. Test URL: https://pim.technostationery.com/"
    echo "4. Run: ./PHASE11_VERIFY_FIX.sh"
    exit 0
else
    echo "⚠️ SOME FIXES FAILED"
    echo ""
    echo "Review errors above and retry or manual intervention required"
    exit 1
fi
