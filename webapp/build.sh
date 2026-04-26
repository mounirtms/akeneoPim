#!/bin/bash

# Akeneo PIM - Comprehensive Build Script
# This script ensures all assets are properly compiled and the application is ready

set -e  # Exit on any error

echo "============================================="
echo "  AKENEO PIM - BUILD & DEPLOYMENT SCRIPT"
echo "============================================="
echo ""

# Change to project root
cd "$(dirname "$0")/.."
PROJECT_ROOT=$(pwd)

echo "📍 Project Root: $PROJECT_ROOT"
echo "🌿 Git Branch: $(git branch --show-current)"
echo ""

# Function to print step headers
print_step() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  $1"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# Step 1: Install/Update Node Dependencies
print_step "1️⃣  INSTALLING NODE DEPENDENCIES"
if [ -f "package.json" ]; then
    echo "Installing yarn dependencies..."
    yarn install --non-interactive
    echo "✅ Dependencies installed"
else
    echo "⚠️  No package.json found, skipping"
fi

# Step 2: Compile LESS to CSS
print_step "2️⃣  COMPILING LESS → CSS"
if [ -f "package.json" ] && grep -q "\"less\"" package.json; then
    echo "Compiling LESS files..."
    yarn run less
    
    if [ -f "public/css/pim.css" ]; then
        CSS_SIZE=$(du -h public/css/pim.css | cut -f1)
        echo "✅ CSS compiled successfully: public/css/pim.css ($CSS_SIZE)"
    else
        echo "❌ ERROR: pim.css was not created!"
        exit 1
    fi
else
    echo "⚠️  LESS compilation not configured"
fi

# Step 3: Build JavaScript with Webpack
print_step "3️⃣  BUILDING JAVASCRIPT (Webpack)"
if [ -f "webpack.config.js" ] || [ -f "vendor/akeneo/pim-community-dev/webpack.config.js" ]; then
    echo "Running webpack production build..."
    yarn run webpack --env=prod
    
    if [ -f "public/dist/main.min.js" ]; then
        MAIN_SIZE=$(du -h public/dist/main.min.js | cut -f1)
        echo "✅ main.min.js built: $MAIN_SIZE"
    else
        echo "❌ ERROR: main.min.js was not created!"
        exit 1
    fi
    
    if [ -f "public/dist/vendor.min.js" ]; then
        VENDOR_SIZE=$(du -h public/dist/vendor.min.js | cut -f1)
        echo "✅ vendor.min.js built: $VENDOR_SIZE"
    else
        echo "⚠️  vendor.min.js not found"
    fi
else
    echo "⚠️  Webpack not configured"
fi

# Step 4: Dump Require.js paths
print_step "4️⃣  DUMPING REQUIREJS PATHS"
if bin/console pim:installer:dump-require-paths --help >/dev/null 2>&1; then
    echo "Dumping require paths..."
    bin/console pim:installer:dump-require-paths --env=prod
    
    if [ -f "public/js/require-paths.js" ]; then
        echo "✅ Require paths dumped"
    else
        echo "⚠️  require-paths.js not created"
    fi
else
    echo "⚠️  Command not available"
fi

# Step 5: Install Assets
print_step "5️⃣  INSTALLING ASSETS"
if bin/console pim:installer:assets --help >/dev/null 2>&1; then
    echo "Installing Symfony/Akeneo assets..."
    bin/console pim:installer:assets --symlink --clean --env=prod
    echo "✅ Assets installed"
else
    echo "⚠️  Using fallback: assets:install"
    bin/console assets:install public --symlink --env=prod || echo "⚠️  Assets install failed"
fi

# Step 6: Clear and Warm Cache
print_step "6️⃣  CACHE MANAGEMENT"
echo "Clearing production cache..."
rm -rf var/cache/prod/*
echo "✅ Cache cleared"

echo ""
echo "Warming up cache..."
bin/console cache:warmup --env=prod
echo "✅ Cache warmed"

# Step 7: Fix Permissions
print_step "7️⃣  FIXING PERMISSIONS"
echo "Setting file permissions..."

# CSS
if [ -f "public/css/pim.css" ]; then
    chmod 644 public/css/pim.css
    chown pim:pim public/css/pim.css 2>/dev/null || true
    echo "✅ pim.css permissions fixed"
fi

# JavaScript bundles
if [ -d "public/dist" ]; then
    chmod 644 public/dist/*.min.js 2>/dev/null || true
    chown pim:pim public/dist/*.min.js 2>/dev/null || true
    echo "✅ JavaScript bundle permissions fixed"
fi

# Cache directories
chmod -R 777 var/cache var/logs 2>/dev/null || true
echo "✅ Cache/logs permissions fixed"

# Step 8: Verify Build
print_step "8️⃣  VERIFYING BUILD"
echo "Checking critical files..."

ERRORS=0

# Check CSS
if [ -f "public/css/pim.css" ]; then
    echo "✅ public/css/pim.css exists ($(du -h public/css/pim.css | cut -f1))"
else
    echo "❌ public/css/pim.css MISSING!"
    ERRORS=$((ERRORS + 1))
fi

# Check main.min.js
if [ -f "public/dist/main.min.js" ]; then
    echo "✅ public/dist/main.min.js exists ($(du -h public/dist/main.min.js | cut -f1))"
else
    echo "❌ public/dist/main.min.js MISSING!"
    ERRORS=$((ERRORS + 1))
fi

# Check vendor.min.js
if [ -f "public/dist/vendor.min.js" ]; then
    echo "✅ public/dist/vendor.min.js exists ($(du -h public/dist/vendor.min.js | cut -f1))"
else
    echo "⚠️  public/dist/vendor.min.js missing (not critical)"
fi

# Check require-paths.js
if [ -f "public/js/require-paths.js" ]; then
    echo "✅ public/js/require-paths.js exists"
else
    echo "⚠️  public/js/require-paths.js missing"
fi

# Step 9: Summary
print_step "9️⃣  BUILD SUMMARY"

if [ $ERRORS -eq 0 ]; then
    echo "✅✅✅ BUILD SUCCESSFUL! ✅✅✅"
    echo ""
    echo "All assets compiled and ready for production."
    echo ""
    echo "Next steps:"
    echo "  1. Test the application: https://pim.technostationery.com"
    echo "  2. Login with: testadmin / testpass"
    echo "  3. Run Playwright tests: cd webapp && npm test"
    echo ""
    exit 0
else
    echo "❌❌❌ BUILD FAILED! ❌❌❌"
    echo ""
    echo "$ERRORS critical error(s) found."
    echo "Please review the output above and fix the issues."
    echo ""
    exit 1
fi
