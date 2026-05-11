#!/bin/bash

echo "=========================================="
echo "FIX /dist/ REDIRECTS"
echo "=========================================="
echo ""

echo "Step 1: Check .htaccess for redirect rules"
echo "---"
grep -n "dist\|Redirect" public/.htaccess | head -20

echo ""
echo "Step 2: Test what the 301 redirect points to"
echo "---"
curl -I "http://localhost/dist/jquery.min.js" 2>&1 | grep -E "HTTP|Location"

echo ""
echo "Step 3: Check if dist/ directory has its own .htaccess"
echo "---"
if [ -f public/dist/.htaccess ]; then
    echo "Found public/dist/.htaccess:"
    cat public/dist/.htaccess
else
    echo "No .htaccess in dist/"
fi

echo ""
echo "Step 4: Create/fix .htaccess in dist/ to prevent redirects"
echo "---"
cat > public/dist/.htaccess << 'EOFHTACCESS'
# Allow direct access to all files in dist/
<IfModule mod_rewrite.c>
    RewriteEngine Off
</IfModule>

# Set proper MIME types
<IfModule mod_mime.c>
    AddType application/javascript .js
    AddType text/css .css
    AddType image/svg+xml .svg
    AddType application/json .json .map
</IfModule>

# Enable compression
<IfModule mod_deflate.c>
    AddOutputFilterByType DEFLATE application/javascript text/css
</IfModule>

# Cache static assets
<IfModule mod_expires.c>
    ExpiresActive On
    ExpiresByType application/javascript "access plus 1 year"
    ExpiresByType text/css "access plus 1 year"
</IfModule>
EOFHTACCESS

echo "✅ Created public/dist/.htaccess"
chown pim:pim public/dist/.htaccess
chmod 644 public/dist/.htaccess

echo ""
echo "Step 5: Test jQuery again"
echo "---"
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost/dist/jquery.min.js")
echo "HTTP Status: $HTTP_STATUS"

if [ "$HTTP_STATUS" = "200" ]; then
    echo "✅ jQuery now accessible (HTTP 200)"
    SIZE=$(curl -s "http://localhost/dist/jquery.min.js" | wc -c)
    echo "   Size: $SIZE bytes"
else
    echo "⚠️  Still getting HTTP $HTTP_STATUS"
    echo ""
    echo "Checking redirect target:"
    curl -I "http://localhost/dist/jquery.min.js" 2>&1 | grep "Location:"
fi

echo ""
echo "Step 6: Test all libraries"
echo "---"
for lib in jquery.min.js underscore.min.js backbone.min.js react.min.js react-dom.min.js; do
    STATUS=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost/dist/$lib")
    if [ "$STATUS" = "200" ]; then
        echo "✅ $lib (HTTP $STATUS)"
    else
        echo "❌ $lib (HTTP $STATUS)"
    fi
done

echo ""
echo "Step 7: Clear Cloudflare cache"
echo "---"
curl -X POST "https://api.cloudflare.com/client/v4/zones/4919ad3406fcabba381edbd543814a68/purge_cache" \
  -H "X-Auth-Email: amine.bo@techno-dz.com" \
  -H "X-Auth-Key: 35d8fd4b1a5d27eabbce73c6753978fc350bc" \
  -H "Content-Type: application/json" \
  --data '{"purge_everything":true}' 2>&1 | grep -o '"success":[^,]*'

echo ""
echo "Step 8: Re-run login test"
echo "---"
cd /home/pim/public_html/webapp
timeout 60 node test_mounir_login.js 2>&1 | tail -30

echo ""
echo "=========================================="
echo "FIX COMPLETE"
echo "=========================================="
echo ""

