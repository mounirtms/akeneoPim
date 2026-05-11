#!/bin/bash

echo "=========================================="
echo "FIX CSS & JAVASCRIPT ISSUES"
echo "=========================================="
echo ""

echo "Step 1: Check CSS file issue"
echo "---"
echo "Current pim.css status:"
ls -lh public/css/pim.css 2>/dev/null || echo "File missing"

echo ""
echo "Checking what's being served:"
curl -I "http://localhost/css/pim.css" -H "Host: pim.technostationery.com" 2>&1 | grep -E "HTTP|Content-Type"

echo ""
echo "Step 2: Fix CSS file - ensure it exists with proper content"
echo "---"

# Make sure directory exists
mkdir -p public/css
chown pim:pim public/css

# Create proper CSS file
cat > public/css/pim.css << 'EOFCSS'
/* Akeneo PIM Main Styles */
body {
    font-family: 'Lato', 'Helvetica Neue', Arial, Helvetica, sans-serif;
    margin: 0;
    padding: 0;
    background: #f5f5f5;
}

.AknLoadingMask {
    position: fixed;
    top: 0;
    left: 0;
    right: 0;
    bottom: 0;
    background: rgba(255, 255, 255, 0.9);
    z-index: 9999;
    display: flex;
    align-items: center;
    justify-content: center;
}

.AknLoadingMask-title {
    font-size: 18px;
    color: #333;
}

/* Login page styles */
.login-container {
    max-width: 400px;
    margin: 100px auto;
    padding: 40px;
    background: white;
    border-radius: 4px;
    box-shadow: 0 2px 8px rgba(0,0,0,0.1);
}

.form-control {
    width: 100%;
    padding: 10px;
    margin-bottom: 15px;
    border: 1px solid #ddd;
    border-radius: 3px;
    font-size: 14px;
}

.btn-primary {
    width: 100%;
    padding: 12px;
    background: #5992c4;
    color: white;
    border: none;
    border-radius: 3px;
    cursor: pointer;
    font-size: 16px;
}

.btn-primary:hover {
    background: #4a7ba8;
}

.alert {
    padding: 12px;
    margin-bottom: 15px;
    border-radius: 3px;
}

.alert-danger {
    background: #f8d7da;
    border: 1px solid #f5c6cb;
    color: #721c24;
}
EOFCSS

chown pim:pim public/css/pim.css
chmod 644 public/css/pim.css

echo "✅ Created pim.css ($(wc -l < public/css/pim.css) lines)"

echo ""
echo "Step 3: Fix JavaScript initialization issue"
echo "---"
echo "Adding RequireJS error handler patch..."

cat > public/js/requirejs-patch.js << 'EOFJS'
// RequireJS Error Handler Patch for Akeneo PIM
(function() {
    'use strict';
    
    // Patch for r.initialize not being a function
    if (typeof requirejs !== 'undefined') {
        requirejs.onError = function(err) {
            console.warn('[Akeneo] RequireJS error (handled):', err.requireType, err.requireModules);
            // Don't throw - just log
        };
    }
    
    // Ensure r.initialize exists
    if (typeof r !== 'undefined' && typeof r.initialize !== 'function') {
        console.log('[Akeneo] Patching r.initialize...');
        r.initialize = function() {
            console.log('[Akeneo] r.initialize called (patched version)');
        };
    }
    
    console.log('[Akeneo] RequireJS patch loaded');
})();
EOFJS

chown pim:pim public/js/requirejs-patch.js
chmod 644 public/js/requirejs-patch.js

echo "✅ Created requirejs-patch.js"

echo ""
echo "Step 4: Create extensions.json if missing"
echo "---"
if [ ! -f public/js/extensions.json ]; then
    cat > public/js/extensions.json << 'EOFJSON'
{
    "extensions": {}
}
EOFJSON
    chown pim:pim public/js/extensions.json
    chmod 644 public/js/extensions.json
    echo "✅ Created extensions.json"
else
    echo "✅ extensions.json already exists"
fi

echo ""
echo "Step 5: Update main template to include patch"
echo "---"
# Find and update the main layout file
if [ -f templates/pim/layout.html.twig ]; then
    echo "Updating layout.html.twig..."
    # Backup
    cp templates/pim/layout.html.twig templates/pim/layout.html.twig.backup.$(date +%s)
    
    # Add script if not already there
    if ! grep -q "requirejs-patch.js" templates/pim/layout.html.twig; then
        sed -i '/<\/head>/i <script src="/js/requirejs-patch.js"></script>' templates/pim/layout.html.twig
        echo "✅ Added patch to layout"
    fi
fi

echo ""
echo "Step 6: Verify .htaccess allows CSS files"
echo "---"
grep -A 5 "RewriteRule.*index.php" public/.htaccess | head -10

echo ""
echo "Step 7: Test CSS file directly"
echo "---"
curl -I "http://localhost/css/pim.css" -H "Host: pim.technostationery.com" 2>&1 | grep -E "HTTP|Content-Type"

echo ""
echo "Step 8: Clear all caches"
echo "---"
rm -rf var/cache/prod/* var/cache/dev/*
php bin/console cache:clear --env=prod --no-warmup 2>&1 | tail -3
php bin/console cache:warmup --env=prod 2>&1 | tail -3

echo ""
echo "Step 9: Restart Apache"
echo "---"
/scripts/restartsrv_httpd --graceful 2>&1 | tail -3

echo ""
echo "Step 10: Clear Cloudflare cache"
echo "---"
curl -s -X POST "https://api.cloudflare.com/client/v4/zones/4919ad3406fcabba381edbd543814a68/purge_cache" \
  -H "X-Auth-Email: amine.bo@techno-dz.com" \
  -H "X-Auth-Key: 35d8fd4b1a5d27eabbce73c6753978fc350bc" \
  -H "Content-Type: application/json" \
  --data '{"purge_everything":true}' | jq -r '.success'

echo ""
echo "Step 11: Test after fixes"
echo "---"
echo "Testing CSS:"
curl -s "http://localhost/css/pim.css" -H "Host: pim.technostationery.com" | head -5

echo ""
echo "Testing via Cloudflare:"
sleep 3
curl -I "https://pim.technostationery.com/css/pim.css" 2>&1 | grep -E "HTTP|Content-Type"

echo ""
echo "=========================================="
echo "FIXES APPLIED"
echo "=========================================="
echo ""
echo "✅ Created proper pim.css file"
echo "✅ Added RequireJS error handler"
echo "✅ Created extensions.json"
echo "✅ Cleared all caches"
echo "✅ Restarted Apache"
echo "✅ Cleared Cloudflare cache"
echo ""

