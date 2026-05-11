#!/bin/bash

echo "=========================================="
echo "COMPLETE CSS & ROUTING FIX"
echo "=========================================="
echo ""

# Problem 1: pim.css exists but is 0 bytes (empty file)
# Problem 2: CSS should be in public/css/ or public/bundles/
# Problem 3: Routes are serving Twig templates instead of actual login page
# Problem 4: jQuery and vendor JS files exist but aren't loading properly

echo "Step 1: Copy correct CSS files to public directory"
echo "---"

# Create CSS directory if needed
mkdir -p /home/pim/public_html/public/css

# Find and copy actual Akeneo CSS from vendor
if [ -f /home/pim/public_html/public/akeneo_main.css ]; then
    cp /home/pim/public_html/public/akeneo_main.css /home/pim/public_html/public/css/pim.css
    echo "✓ Copied akeneo_main.css to public/css/pim.css"
fi

# Check bundles CSS
echo ""
echo "Step 2: Install and link Akeneo assets properly"
echo "---"
cd /home/pim/public_html
php bin/console pim:installer:assets --symlink --clean --env=prod
php bin/console assets:install public --symlink --env=prod

echo ""
echo "Step 3: Build frontend assets with proper paths"
echo "---"
# Check if we need to rebuild assets
if [ -d /home/pim/public_html/vendor/akeneo/pim-community-dev ]; then
    cd /home/pim/public_html
    php bin/console pim:installer:dump-require-paths
fi

echo ""
echo "Step 4: Fix routes.yaml - remove SPA template routes"
echo "---"
# Backup current routes
cp /home/pim/public_html/config/routes.yaml /home/pim/public_html/config/routes.yaml.backup.$(date +%s)

# Create proper routes.yaml for Akeneo login
cat > /home/pim/public_html/config/routes.yaml << 'EOFROUTES'
# Akeneo PIM Routes Configuration

# Import default Akeneo routes
pim_dashboard_index:
    resource: '@PimDashboardBundle/Controller/'
    type: annotation
    prefix: /

pim_user:
    resource: '@PimUserBundle/Controller/'
    type: annotation

pim_enrich:
    resource: '@PimEnrichBundle/Controller/'
    type: annotation

# API routes
pim_api:
    resource: '@PimApiBundle/Resources/config/routing.yml'

# Locale switching
pim_user_locale:
    resource: '@PimUserBundle/Resources/config/routing/locale.yml'

# Login route - explicit
pim_user_security_login:
    path: /user/login
    defaults:
        _controller: Pim\Bundle\UserBundle\Controller\SecurityController::loginAction

# Root - redirect to dashboard
_root:
    path: /
    defaults:
        _controller: Symfony\Bundle\FrameworkBundle\Controller\RedirectController
        route: pim_dashboard_index
        permanent: false
EOFROUTES

echo "✓ Updated routes.yaml"

echo ""
echo "Step 5: Clear all caches and rebuild"
echo "---"
cd /home/pim/public_html
rm -rf var/cache/*
php bin/console cache:clear --env=prod --no-warmup
php bin/console cache:warmup --env=prod

echo ""
echo "Step 6: Update CSP to allow external scripts"
echo "---"
# Backup .htaccess
cp /home/pim/public_html/public/.htaccess /home/pim/public_html/public/.htaccess.backup.$(date +%s)

# Update CSP header to allow necessary external scripts
cat > /tmp/csp_header.txt << 'EOFCSP'
    # Content Security Policy
    Header always set Content-Security-Policy "default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval' https://static.cloudflareinsights.com https://www.googletagmanager.com https://connect.facebook.net https://www.clarity.ms https://gc.kes.v2.scr.kaspersky-labs.com; style-src 'self' 'unsafe-inline'; img-src 'self' data: https:; font-src 'self' data:; connect-src 'self' https:; media-src 'self'; object-src 'none';"
EOFCSP

# Find and replace CSP header in .htaccess
if grep -q "Content-Security-Policy" /home/pim/public_html/public/.htaccess; then
    # Remove old CSP headers
    sed -i '/Content-Security-Policy/d' /home/pim/public_html/public/.htaccess
fi

# Add new CSP header after <IfModule mod_headers.c>
sed -i '/<IfModule mod_headers.c>/r /tmp/csp_header.txt' /home/pim/public_html/public/.htaccess

echo "✓ Updated CSP headers"

echo ""
echo "Step 7: Ensure jQuery and vendor JS are accessible"
echo "---"
# Check if main.min.js and vendor.min.js exist in dist
if [ -f /home/pim/public_html/public/dist/main.min.js ]; then
    echo "✓ main.min.js exists in dist/"
else
    echo "⚠ main.min.js missing - checking alternate locations"
    if [ -f /home/pim/public_html/public/main.min.js ]; then
        mkdir -p /home/pim/public_html/public/dist
        cp /home/pim/public_html/public/main.min.js /home/pim/public_html/public/dist/
    fi
fi

if [ -f /home/pim/public_html/public/dist/vendor.min.js ]; then
    echo "✓ vendor.min.js exists in dist/"
else
    echo "⚠ vendor.min.js missing - checking alternate locations"
    if [ -f /home/pim/public_html/public/vendor.min.js ]; then
        mkdir -p /home/pim/public_html/public/dist
        cp /home/pim/public_html/public/vendor.min.js /home/pim/public_html/public/dist/
    fi
fi

echo ""
echo "Step 8: Set proper permissions"
echo "---"
chown -R pim:pim /home/pim/public_html/public/css
chown -R pim:pim /home/pim/public_html/public/bundles
chmod -R 755 /home/pim/public_html/public/css
chmod -R 755 /home/pim/public_html/public/bundles
echo "✓ Permissions set"

echo ""
echo "Step 9: Restart Apache"
echo "---"
/scripts/restartsrv_httpd --graceful
sleep 2
systemctl is-active httpd && echo "✓ Apache running" || echo "✗ Apache failed"

echo ""
echo "Step 10: Clear Cloudflare cache"
echo "---"
curl -X POST "https://api.cloudflare.com/client/v4/zones/4919ad3406fcabba381edbd543814a68/purge_cache" \
  -H "X-Auth-Email: amine.bo@techno-dz.com" \
  -H "X-Auth-Key: 35d8fd4b1a5d27eabbce73c6753978fc350bc" \
  -H "Content-Type: application/json" \
  --data '{"purge_everything":true}' 2>&1 | grep -o '"success":[^,]*'

echo ""
echo ""
echo "=========================================="
echo "VERIFICATION"
echo "=========================================="

echo ""
echo "Testing CSS file:"
curl -I "https://pim.technostationery.com/css/pim.css" 2>&1 | grep -E "HTTP|Content-Type"

echo ""
echo "Testing login page:"
curl -I "https://pim.technostationery.com/user/login" 2>&1 | grep -E "HTTP|Content-Type"

echo ""
echo "Checking CSS file size:"
ls -lh /home/pim/public_html/public/css/pim.css 2>/dev/null || echo "File not found"

echo ""
echo "=========================================="
echo "FIX COMPLETE"
echo "=========================================="
echo ""
echo "Next steps:"
echo "1. Open https://pim.technostationery.com/user/login"
echo "2. Login with: admin / admin"
echo "3. Check browser console for remaining errors"
echo ""

