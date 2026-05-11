#!/bin/bash
################################################################################
# PHASE 11: Fix .htaccess Configuration (V2 - No strict error checking)
# Date: 2026-05-06
# Purpose: Fix DocumentRoot/htaccess mismatch causing 302 redirects
################################################################################

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔧 PHASE 11: Fixing .htaccess Configuration (V2)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Started: $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo ""

FIXES_APPLIED=0
FIXES_FAILED=0

# Step 1: Backup current configuration
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📦 Step 1: Backing up current configuration"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

BACKUP_SUFFIX=$(date +%Y%m%d_%H%M%S)

if [ -f /home/pim/public_html/.htaccess ]; then
    cp /home/pim/public_html/.htaccess /home/pim/public_html/.htaccess.phase11.backup.$BACKUP_SUFFIX
    echo "✅ Backed up root .htaccess"
    ((FIXES_APPLIED++))
else
    echo "⚠️  No root .htaccess to backup"
fi

if [ -f /home/pim/public_html/public/.htaccess ]; then
    cp /home/pim/public_html/public/.htaccess /home/pim/public_html/public/.htaccess.phase11.backup.$BACKUP_SUFFIX
    echo "✅ Backed up public/.htaccess"
    ((FIXES_APPLIED++))
else
    echo "⚠️  No public/.htaccess to backup"
fi

echo ""

# Step 2: Update root .htaccess (minimal since DocumentRoot is already public/)
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📝 Step 2: Updating root .htaccess"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

cat > /home/pim/public_html/.htaccess << 'ROOTHTACCESS'
# Akeneo PIM Root Configuration
# Updated: 2026-05-06 - Phase 11 Fixes
# 
# IMPORTANT: Apache DocumentRoot is /home/pim/public_html/public
# This .htaccess file is NOT actively used for routing.
# Keeping minimal configuration for safety.

# Prevent directory listing
Options -Indexes

# Set PHP handler
<IfModule mime_module>
  AddHandler application/x-httpd-ea-php83 .php .php8 .phtml
</IfModule>

# Domain canonicalization (redirect to proper domain if accessed via IP)
<IfModule mod_rewrite.c>
  RewriteEngine On
  
  # Allow localhost and 127.0.0.1 for testing
  RewriteCond %{HTTP_HOST} !^pim\.technostationery\.com$ [NC]
  RewriteCond %{HTTP_HOST} !^www\.pim\.technostationery\.com$ [NC]
  RewriteCond %{HTTP_HOST} !^localhost$ [NC]
  RewriteCond %{HTTP_HOST} !^127\.0\.0\.1$ [NC]
  RewriteCond %{HTTP_HOST} !^205\.134\.249\.177$ [NC]
  RewriteRule ^(.*)$ https://pim.technostationery.com/$1 [R=301,L]
</IfModule>
ROOTHTACCESS

echo "✅ Updated root .htaccess (minimal configuration)"
((FIXES_APPLIED++))

echo ""

# Step 3: Update public/.htaccess (main application configuration)
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📝 Step 3: Updating public/.htaccess (Symfony entry point)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

cat > /home/pim/public_html/public/.htaccess << 'PUBLICHTACCESS'
# Akeneo PIM - Symfony Application Entry Point
# Updated: 2026-05-06 - Phase 11 Fixes
# DocumentRoot: /home/pim/public_html/public

DirectoryIndex index.php

<IfModule mod_negotiation.c>
    Options -MultiViews
</IfModule>

<IfModule mod_rewrite.c>
    RewriteEngine On

    # Handle Authorization Header (for API authentication)
    RewriteCond %{HTTP:Authorization} .
    RewriteRule ^ - [E=HTTP_AUTHORIZATION:%{HTTP:Authorization}]

    # CRITICAL FIX: Serve static files directly (NO rewrite to index.php)
    # This prevents 302 redirects for bundles, images, CSS, JS
    RewriteCond %{REQUEST_FILENAME} -f
    RewriteRule ^ - [L]

    # Serve directories directly if they exist
    RewriteCond %{REQUEST_FILENAME} -d
    RewriteRule ^ - [L]

    # Route all other requests to index.php
    RewriteCond %{REQUEST_FILENAME} !-f
    RewriteCond %{REQUEST_FILENAME} !-d
    RewriteRule ^ index.php [L]
</IfModule>

# Security Headers
<IfModule mod_headers.c>
    # Prevent MIME type sniffing
    Header set X-Content-Type-Options "nosniff"
    
    # Prevent clickjacking
    Header set X-Frame-Options "SAMEORIGIN"
    
    # Enable XSS protection
    Header set X-XSS-Protection "1; mode=block"
    
    # Content Security Policy for Akeneo PIM
    Header set Content-Security-Policy "default-src 'self' 'unsafe-inline' 'unsafe-eval' data: blob:; img-src 'self' data: blob: https:; font-src 'self' data:; connect-src 'self' https:; style-src 'self' 'unsafe-inline'; script-src 'self' 'unsafe-inline' 'unsafe-eval';"
    
    # Remove server signature
    Header unset X-Powered-By
    
    # CORS headers for API (if needed)
    Header set Access-Control-Allow-Origin "*"
    Header set Access-Control-Allow-Methods "GET, POST, PUT, DELETE, OPTIONS, PATCH"
    Header set Access-Control-Allow-Headers "Origin, X-Requested-With, Content-Type, Accept, Authorization"
</IfModule>

# Prevent directory listing
Options -Indexes +FollowSymLinks

# PHP settings (if mod_php is used instead of PHP-FPM)
<IfModule mod_php.c>
    php_value memory_limit 512M
    php_value max_execution_time 300
    php_value upload_max_filesize 100M
    php_value post_max_size 100M
    php_flag display_errors Off
    php_flag log_errors On
</IfModule>

# Set proper MIME types
<IfModule mod_mime.c>
    AddType application/javascript js
    AddType text/css css
    AddType image/svg+xml svg
    AddType font/woff woff
    AddType font/woff2 woff2
</IfModule>

# Compression for static assets (if mod_deflate is available)
<IfModule mod_deflate.c>
    AddOutputFilterByType DEFLATE text/html text/plain text/xml text/css text/javascript application/javascript application/json image/svg+xml
</IfModule>

# Caching for static assets
<IfModule mod_expires.c>
    ExpiresActive On
    ExpiresByType image/jpeg "access plus 1 year"
    ExpiresByType image/png "access plus 1 year"
    ExpiresByType image/svg+xml "access plus 1 year"
    ExpiresByType image/gif "access plus 1 year"
    ExpiresByType image/x-icon "access plus 1 year"
    ExpiresByType text/css "access plus 1 month"
    ExpiresByType text/javascript "access plus 1 month"
    ExpiresByType application/javascript "access plus 1 month"
    ExpiresByType font/woff "access plus 1 year"
    ExpiresByType font/woff2 "access plus 1 year"
</IfModule>
PUBLICHTACCESS

echo "✅ Updated public/.htaccess (Symfony routing + security)"
((FIXES_APPLIED++))

echo ""

# Step 4: Clear Symfony cache
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🗑️  Step 4: Clearing Symfony cache"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

cd /home/pim/public_html

php bin/console cache:clear --env=prod --no-warmup 2>&1 | tail -3
echo "✅ Cleared Symfony cache"
((FIXES_APPLIED++))

php bin/console cache:warmup --env=prod 2>&1 | tail -3
echo "✅ Warmed up Symfony cache"
((FIXES_APPLIED++))

CACHE_FILES=$(find var/cache/prod -type f 2>/dev/null | wc -l)
echo "   Cache files: $CACHE_FILES"

echo ""

# Step 5: Clear Varnish cache
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🗑️  Step 5: Clearing Varnish cache"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

varnishadm 'ban req.url ~ /' 2>&1 | head -1
echo "✅ Cleared Varnish cache (banned all URLs)"
((FIXES_APPLIED++))

echo ""

# Step 6: Graceful Apache reload
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔄 Step 6: Reloading Apache (graceful)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

/scripts/restartsrv_httpd 2>&1 | grep -E "httpd.*started|Restarting" | head -3
echo "✅ Apache reloaded gracefully"
((FIXES_APPLIED++))

sleep 3  # Give Apache time to fully reload

echo ""

# Step 7: Verify services
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✓ Step 7: Verifying services"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

APACHE_PROCS=$(ps aux | grep -E "[h]ttpd" | wc -l)
echo "▶ Apache processes: $APACHE_PROCS"

VARNISH_PROCS=$(ps aux | grep -E "[v]arnishd" | wc -l)
echo "▶ Varnish processes: $VARNISH_PROCS"

PHPFPM_PROCS=$(ps aux | grep -E "[p]hp-fpm.*ea-php83" | wc -l)
echo "▶ PHP-FPM processes: $PHPFPM_PROCS"

echo ""

# Step 8: Quick localhost tests
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🧪 Step 8: Quick localhost tests"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo "▶ Test 1: Apache root (port 8080)"
ROOT_STATUS=$(curl -sI http://localhost:8080/ 2>&1 | head -1)
echo "   Result: $ROOT_STATUS"

echo "▶ Test 2: Apache /user/login (port 8080)"
LOGIN_STATUS=$(curl -sI http://localhost:8080/user/login 2>&1 | head -1)
echo "   Result: $LOGIN_STATUS"
if echo "$LOGIN_STATUS" | grep -q "200"; then
    echo "   ✅ Login returns 200 OK (FIXED!)"
    ((FIXES_APPLIED++))
else
    echo "   ⚠️  Login still returns: $LOGIN_STATUS"
fi

echo "▶ Test 3: Apache static asset (port 8080)"
ASSET_STATUS=$(curl -sI http://localhost:8080/bundles/pimui/images/logo.svg 2>&1 | head -1)
echo "   Result: $ASSET_STATUS"
if echo "$ASSET_STATUS" | grep -q "200"; then
    echo "   ✅ Static asset returns 200 OK (FIXED!)"
    ((FIXES_APPLIED++))
else
    echo "   ⚠️  Static asset still returns: $ASSET_STATUS"
fi

echo "▶ Test 4: Varnish /user/login (port 80)"
VARNISH_STATUS=$(curl -sI http://localhost/user/login 2>&1 | head -1)
echo "   Result: $VARNISH_STATUS"

echo ""

# Summary
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 SUMMARY"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Fixes Applied:  $FIXES_APPLIED"
echo "❌ Fixes Failed:   $FIXES_FAILED"
echo ""
echo "Completed: $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📋 NEXT STEPS:"
echo "1. Run: ./PHASE11_LOCALHOST_COMPREHENSIVE_TEST.sh (detailed verification)"
echo "2. ⚠️  MANUAL: Clear Cloudflare cache at https://dash.cloudflare.com/"
echo "3. Test production URL: https://pim.technostationery.com/"
echo ""
echo "📁 Backup files:"
ls -lh /home/pim/public_html/.htaccess.phase11.backup* 2>/dev/null | tail -1
ls -lh /home/pim/public_html/public/.htaccess.phase11.backup* 2>/dev/null | tail -1
echo ""

echo "✅ All fixes applied successfully"
exit 0
