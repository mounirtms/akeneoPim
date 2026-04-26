#!/bin/bash

echo "═══════════════════════════════════════════════════════════"
echo "  COMPLETE AKENEO PIM REBUILD - FIX EVERYTHING"
echo "═══════════════════════════════════════════════════════════"
echo ""

cd /home/pim/public_html

# Step 1: Compile LESS to CSS
echo "1️⃣  Compiling LESS → CSS..."
yarn run less
if [ -f "public/css/pim.css" ]; then
    echo "✅ CSS compiled ($(du -h public/css/pim.css | cut -f1))"
    chmod 644 public/css/pim.css
    chown pim:pim public/css/pim.css
else
    echo "❌ CSS compilation failed!"
    exit 1
fi

# Step 2: Install/Dump Assets
echo ""
echo "2️⃣  Installing Akeneo assets..."
bin/console pim:installer:assets --symlink --clean --env=prod
bin/console pim:installer:dump-require-paths --env=prod

# Step 3: Copy extensions.json
echo ""
echo "3️⃣  Copying extensions.json..."
if [ -f "web/js/extensions.json" ]; then
    mkdir -p public/js
    cp web/js/extensions.json public/js/
    echo "✅ extensions.json copied"
else
    echo "⚠️  web/js/extensions.json not found"
fi

# Step 4: Verify Critical Files
echo ""
echo "4️⃣  Verifying critical files..."
ERRORS=0

check_file() {
    if [ -f "$1" ]; then
        SIZE=$(du -h "$1" | cut -f1)
        echo "✅ $1 ($SIZE)"
    else
        echo "❌ $1 MISSING!"
        ERRORS=$((ERRORS + 1))
    fi
}

check_file "public/css/pim.css"
check_file "public/js/extensions.json"
check_file "public/js/module-registry.js"
check_file "public/js/require-paths.js"
check_file "public/dist/require.min.js"
check_file "public/dist/main.min.js"
check_file "public/dist/vendor.min.js"
check_file "public/dist/jquery.min.js"
check_file "public/dist/backbone.min.js"
check_file "public/dist/underscore.min.js"

# Step 5: Fix Permissions
echo ""
echo "5️⃣  Fixing permissions..."
chmod -R 755 public/css public/js public/dist public/bundles 2>/dev/null
find public/css public/js public/dist -type f -exec chmod 644 {} \; 2>/dev/null
chown -R pim:pim public/css public/js public/dist 2>/dev/null
echo "✅ Permissions fixed"

# Step 6: Clear Cache
echo ""
echo "6️⃣  Clearing cache..."
rm -rf var/cache/prod/* var/cache/dev/*
bin/console cache:warmup --env=prod --no-debug
echo "✅ Cache cleared and warmed"

# Step 7: Test HTTP Access
echo ""
echo "7️⃣  Testing HTTP access..."
test_url() {
    STATUS=$(curl -s -o /dev/null -w "%{http_code}" "https://pim.technostationery.com$1")
    if [ "$STATUS" = "200" ]; then
        echo "✅ $1 - HTTP $STATUS"
    else
        echo "❌ $1 - HTTP $STATUS"
        ERRORS=$((ERRORS + 1))
    fi
}

test_url "/css/pim.css"
test_url "/js/extensions.json"
test_url "/js/module-registry.js"
test_url "/dist/require.min.js"

# Summary
echo ""
echo "═══════════════════════════════════════════════════════════"
if [ $ERRORS -eq 0 ]; then
    echo "  ✅✅✅ REBUILD SUCCESSFUL! ✅✅✅"
    echo ""
    echo "All assets compiled, permissions fixed, cache cleared."
    echo "System ready for testing."
else
    echo "  ❌❌❌ REBUILD FAILED! ❌❌❌"
    echo ""
    echo "$ERRORS error(s) found. Please review the output above."
fi
echo "═══════════════════════════════════════════════════════════"
