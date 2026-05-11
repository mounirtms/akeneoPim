#!/bin/bash
# Comprehensive Fix for All Issues
# Fixes: CSS routing, permissions, caches, and missing files

set -e

echo "========================================================================"
echo "COMPREHENSIVE FIX - All Issues"
echo "========================================================================"
echo ""

cd /home/pim/public_html

# Step 1: Fix CSS file routing in .htaccess
echo "[1/8] Fixing .htaccess to serve static CSS files..."

# Check if CSS exception exists in .htaccess
if ! grep -q "RewriteCond %{REQUEST_URI} !^/css/" public/.htaccess 2>/dev/null; then
    echo "Adding CSS static file exception to .htaccess..."
    
    # Backup .htaccess
    cp public/.htaccess public/.htaccess.backup.$(date +%Y%m%d_%H%M%S)
    
    # Add exception for /css/ and /js/ static files before Symfony routing
    sed -i '/RewriteCond %{REQUEST_FILENAME} !-f/i\    # Allow static CSS and JS files\n    RewriteCond %{REQUEST_URI} !^/css/\n    RewriteCond %{REQUEST_URI} !^/js/' public/.htaccess
    
    echo "✓ .htaccess updated"
else
    echo "✓ .htaccess already has CSS exception"
fi

# Step 2: Ensure CSS file exists with correct permissions
echo "[2/8] Creating/fixing CSS file..."
mkdir -p public/css
cat > public/css/pim.css << 'EOFCSS'
/**
 * Akeneo PIM 6.0 - Minimal CSS for Login Page
 * Main styles are loaded via webpack style-loader after login
 */

body {
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
    margin: 0;
    padding: 0;
    background: #f5f5f5;
}

.login-page {
    min-height: 100vh;
    display: flex;
    align-items: center;
    justify-content: center;
}

.login-box {
    background: white;
    padding: 2rem;
    border-radius: 4px;
    box-shadow: 0 2px 4px rgba(0,0,0,0.1);
    max-width: 400px;
    width: 100%;
}

.login-logo {
    text-align: center;
    margin-bottom: 2rem;
}

.form-group {
    margin-bottom: 1rem;
}

label {
    display: block;
    margin-bottom: 0.5rem;
    font-weight: 500;
}

input[type="text"],
input[type="password"] {
    width: 100%;
    padding: 0.5rem;
    border: 1px solid #ddd;
    border-radius: 4px;
    font-size: 14px;
    box-sizing: border-box;
}

button[type="submit"] {
    width: 100%;
    padding: 0.75rem;
    background: #5992c5;
    color: white;
    border: none;
    border-radius: 4px;
    font-size: 14px;
    font-weight: 500;
    cursor: pointer;
}

button[type="submit"]:hover {
    background: #4a7ca8;
}

.alert {
    padding: 0.75rem;
    margin-bottom: 1rem;
    border-radius: 4px;
}

.alert-danger {
    background: #f8d7da;
    color: #721c24;
    border: 1px solid #f5c6cb;
}

/* Loading spinner */
.loading-mask {
    position: fixed;
    top: 0;
    left: 0;
    right: 0;
    bottom: 0;
    background: rgba(255,255,255,0.9);
    display: flex;
    align-items: center;
    justify-content: center;
    z-index: 10000;
}

.loading-mask .spinner {
    border: 4px solid #f3f3f3;
    border-top: 4px solid #5992c5;
    border-radius: 50%;
    width: 40px;
    height: 40px;
    animation: spin 1s linear infinite;
}

@keyframes spin {
    0% { transform: rotate(0deg); }
    100% { transform: rotate(360deg); }
}
EOFCSS

chown pim:pim public/css/pim.css
chmod 644 public/css/pim.css
echo "✓ CSS file created with correct permissions"

# Step 3: Ensure JS config files exist
echo "[3/8] Ensuring JS configuration files exist..."

# requirejs-config.js
cat > public/js/requirejs-config.js << 'EOFJS'
require.config({
    config: {
        'pim/form-builder': {
            root: '/bundles/pimui/js/form'
        }
    },
    paths: {
        'pimui': '/bundles/pimui/js',
        'pim/form': '/bundles/pimui/js/form',
        'oro/translator': '/bundles/orotranslation/js/translator',
        'routing': '/bundles/fosjsrouting/js/router'
    }
});
EOFJS

# extensions.json with proper structure
cat > public/js/extensions.json << 'EOFJSON'
{
    "extensions": [],
    "attribute_fields": [],
    "jobs": []
}
EOFJSON

chown pim:pim public/js/requirejs-config.js public/js/extensions.json
chmod 644 public/js/requirejs-config.js public/js/extensions.json
echo "✓ JS config files created"

# Step 4: Fix file permissions recursively
echo "[4/8] Fixing file permissions..."
find public/css -type f -exec chmod 644 {} \; 2>/dev/null || true
find public/js -type f -exec chmod 644 {} \; 2>/dev/null || true
find public/css -type d -exec chmod 755 {} \; 2>/dev/null || true
find public/js -type d -exec chmod 755 {} \; 2>/dev/null || true
echo "✓ Permissions fixed"

# Step 5: Regenerate RequireJS paths
echo "[5/8] Regenerating RequireJS paths..."
php bin/console pim:installer:dump-require-paths --env=prod
echo "✓ RequireJS paths regenerated"

# Step 6: Reinstall assets
echo "[6/8] Reinstalling Symfony assets..."
php bin/console pim:installer:assets --symlink --clean --env=prod >/dev/null 2>&1
echo "✓ Assets reinstalled"

# Step 7: Clear all caches
echo "[7/8] Clearing all caches..."
php bin/console cache:clear --env=prod >/dev/null 2>&1
php bin/console cache:warmup --env=prod >/dev/null 2>&1
php -r "if(function_exists('opcache_reset')) opcache_reset();" 2>/dev/null || true
echo "✓ All caches cleared"

# Step 8: Verify critical files
echo "[8/8] Verifying critical files..."

ERRORS=0

# Check CSS file
if [ -f "public/css/pim.css" ]; then
    SIZE=$(stat -f%z public/css/pim.css 2>/dev/null || stat -c%s public/css/pim.css 2>/dev/null)
    if [ "$SIZE" -gt 100 ]; then
        echo "  ✓ public/css/pim.css exists (${SIZE} bytes)"
    else
        echo "  ✗ public/css/pim.css too small (${SIZE} bytes)"
        ERRORS=$((ERRORS + 1))
    fi
else
    echo "  ✗ public/css/pim.css missing"
    ERRORS=$((ERRORS + 1))
fi

# Check JS files
for file in requirejs-config.js extensions.json require-paths.js; do
    if [ -f "public/js/$file" ]; then
        echo "  ✓ public/js/$file exists"
    else
        echo "  ✗ public/js/$file missing"
        ERRORS=$((ERRORS + 1))
    fi
done

# Check pimui bundle
if [ -f "public/bundles/pimui/js/index.js" ]; then
    echo "  ✓ public/bundles/pimui/js/index.js exists"
else
    echo "  ✗ public/bundles/pimui/js/index.js missing"
    ERRORS=$((ERRORS + 1))
fi

echo ""
echo "========================================================================"
if [ $ERRORS -eq 0 ]; then
    echo "✅ ALL FIXES APPLIED SUCCESSFULLY"
    echo ""
    echo "Next steps:"
    echo "1. Clear browser cache (Ctrl+Shift+Delete)"
    echo "2. Test: https://pim.technostationery.com/user/login"
    echo "3. Login with: mounir / 2026"
else
    echo "⚠️  FIX COMPLETED WITH $ERRORS ERRORS"
    echo "Please review the errors above"
fi
echo "========================================================================"
