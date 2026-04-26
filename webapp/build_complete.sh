#!/bin/bash
# Complete Akeneo Frontend Build Script

set -e

echo "=== Akeneo PIM Complete Frontend Build ==="
echo ""

# Step 1: Install dependencies
echo "Step 1: Installing Node dependencies..."
cd /home/pim/public_html
yarn install --frozen-lockfile
echo "✓ Dependencies installed"
echo ""

# Step 2: Install assets
echo "Step 2: Installing Akeneo assets..."
bin/console pim:installer:assets --symlink --clean --env=prod
echo "✓ Assets installed"
echo ""

# Step 3: Compile Less/CSS
echo "Step 3: Compiling CSS..."
yarn run less
echo "✓ CSS compiled"
echo ""

# Step 4: Build webpack bundles
echo "Step 4: Building webpack bundles..."
rm -f public/dist/main.min.js public/dist/vendor.min.js
yarn run webpack
echo "✓ Webpack bundles built"
echo ""

# Step 5: Copy vendor libraries
echo "Step 5: Copying vendor JavaScript libraries..."
mkdir -p public/dist

# Copy libraries
cp node_modules/jquery/dist/jquery.min.js public/dist/
cp node_modules/underscore/underscore-min.js public/dist/underscore.min.js
cp node_modules/backbone/backbone-min.js public/dist/backbone.min.js
cp node_modules/react/umd/react.production.min.js public/dist/react.min.js
cp node_modules/react-dom/umd/react-dom.production.min.js public/dist/react-dom.min.js
cp node_modules/requirejs/require.js public/dist/require.min.js

# Create process polyfill
cat > public/dist/process-polyfill.js << 'EOF'
// Process polyfill for browser
if (typeof process === 'undefined') {
  window.process = {
    env: {
      NODE_ENV: 'production'
    }
  };
}
EOF

echo "✓ Vendor libraries copied"
echo ""

# Step 6: Copy extensions.json
echo "Step 6: Copying extensions.json..."
cp web/js/extensions.json public/js/ || echo "Note: extensions.json not found in web/js"
echo "✓ Extensions file copied"
echo ""

# Step 7: Set proper permissions
echo "Step 7: Setting file permissions..."
chmod 644 public/dist/*.js
chown pim:pim public/dist/*.js
chmod 644 public/js/extensions.json 2>/dev/null || true
chown pim:pim public/js/extensions.json 2>/dev/null || true
echo "✓ Permissions set"
echo ""

# Step 8: Clear and warm cache
echo "Step 8: Clearing and warming cache..."
rm -rf var/cache/prod/*
bin/console cache:warmup --env=prod
chmod -R 775 var/cache var/logs
chown -R pim:pim var/cache var/logs
echo "✓ Cache warmed"
echo ""

# Step 9: Verify build
echo "Step 9: Verifying build..."
echo "Checking for required files:"
ls -lh public/dist/*.min.js public/dist/process-polyfill.js | awk '{print "  ", $9, "-", $5}'
echo ""

echo "=== Build Complete ==="
echo ""
echo "Summary:"
echo "  ✓ Dependencies installed"
echo "  ✓ Assets installed"
echo "  ✓ CSS compiled"
echo "  ✓ Webpack bundles built"
echo "  ✓ Vendor libraries copied"
echo "  ✓ Extensions configured"
echo "  ✓ Permissions set"
echo "  ✓ Cache warmed"
echo ""
echo "Next: Test the application at https://pim.technostationery.com"
