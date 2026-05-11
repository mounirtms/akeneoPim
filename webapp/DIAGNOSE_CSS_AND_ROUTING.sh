#!/bin/bash

echo "=========================================="
echo "COMPREHENSIVE CSS & ROUTING DIAGNOSIS"
echo "=========================================="
echo ""

# 1. Check what's actually being served at /css/pim.css
echo "1. Testing /css/pim.css endpoint:"
echo "---"
curl -I "https://pim.technostationery.com/css/pim.css" 2>&1 | head -20
echo ""

# 2. Find all pim.css files in the system
echo "2. Locating pim.css files:"
echo "---"
find /home/pim/public_html -name "pim.css" -type f 2>/dev/null | while read f; do
    echo "Found: $f ($(stat -c%s "$f") bytes)"
done
echo ""

# 3. Check public/css directory structure
echo "3. Public CSS directory structure:"
echo "---"
ls -lah /home/pim/public_html/public/css/ 2>/dev/null || echo "Directory does not exist"
echo ""

# 4. Check if there's a symlink issue
echo "4. Checking for symlinks in public/:"
echo "---"
ls -lah /home/pim/public_html/public/ | grep -E "css|bundles"
echo ""

# 5. Check .htaccess rules that might affect CSS
echo "5. Current .htaccess rewrite rules:"
echo "---"
grep -A 2 -B 2 "RewriteRule\|RewriteCond" /home/pim/public_html/public/.htaccess | head -30
echo ""

# 6. Test direct file access
echo "6. Testing direct file access to index.php:"
echo "---"
curl -I "http://localhost/index.php" -H "Host: pim.technostationery.com" 2>&1 | head -10
echo ""

# 7. Check Apache error log for recent CSS/routing errors
echo "7. Recent Apache errors related to CSS/routing:"
echo "---"
tail -50 /usr/local/apache/logs/error_log | grep -E "css|pim\.css|404|rewrite" | tail -10
echo ""

# 8. Check Akeneo routing configuration
echo "8. Akeneo routing setup:"
echo "---"
if [ -f /home/pim/public_html/config/routes.yaml ]; then
    head -30 /home/pim/public_html/config/routes.yaml
else
    echo "routes.yaml not found"
fi
echo ""

# 9. Test if jQuery/vendor files exist
echo "9. Checking JavaScript vendor files:"
echo "---"
ls -lh /home/pim/public_html/public/js/*.js 2>/dev/null | head -10 || echo "No JS files in public/js/"
find /home/pim/public_html/public -name "vendor*.js" -o -name "main*.js" 2>/dev/null | head -5
echo ""

# 10. Check CSP headers in .htaccess
echo "10. Current CSP configuration:"
echo "---"
grep -i "Content-Security-Policy" /home/pim/public_html/public/.htaccess
echo ""

echo "=========================================="
echo "DIAGNOSIS COMPLETE"
echo "=========================================="

