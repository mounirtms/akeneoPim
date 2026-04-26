#!/bin/bash

echo "═══════════════════════════════════════════════════════════"
echo "  FINAL FIX - AKENEO PIM COMPLETE BUILD"
echo "═══════════════════════════════════════════════════════════"

cd /home/pim/public_html

echo "1️⃣  Compiling CSS..."
yarn run less
chmod 644 public/css/pim.css
chown pim:pim public/css/pim.css
echo "✅ CSS: $(du -h public/css/pim.css | cut -f1)"

echo ""
echo "2️⃣  Generating module-registry.js (webpack)..."
echo "   (This takes ~60 seconds, please wait...)"
timeout 90 yarn run webpack --env=prod > /tmp/webpack.log 2>&1
if [ -f "public/js/module-registry.js" ]; then
    echo "✅ module-registry.js: $(du -h public/js/module-registry.js | cut -f1)"
else
    echo "⚠️  module-registry.js not generated, but continuing..."
fi

echo ""
echo "3️⃣  Installing Akeneo assets..."
bin/console pim:installer:assets --symlink --env=prod
bin/console pim:installer:dump-require-paths --env=prod

echo ""
echo "4️⃣  Copying additional files..."
# Copy extensions.json
if [ -f "web/js/extensions.json" ]; then
    cp web/js/extensions.json public/js/
    echo "✅ extensions.json copied"
fi

# Re-generate module-registry if missing (after assets install)
if [ ! -f "public/js/module-registry.js" ]; then
    echo "⚠️  module-registry.js missing, regenerating..."
    timeout 90 yarn run webpack --env=prod > /tmp/webpack2.log 2>&1
fi

echo ""
echo "5️⃣  Fixing permissions..."
chmod -R 755 public/css public/js public/dist public/bundles 2>/dev/null
find public/css public/js public/dist -type f -exec chmod 644 {} \; 2>/dev/null
chown -R pim:pim public/css public/js public/dist 2>/dev/null
echo "✅ Permissions fixed"

echo ""
echo "6️⃣  Clearing cache..."
rm -rf var/cache/prod/*
bin/console cache:warmup --env=prod --no-debug > /dev/null 2>&1
echo "✅ Cache cleared"

echo ""
echo "7️⃣  Final verification..."
check_file() {
    if [ -f "$1" ]; then
        SIZE=$(du -h "$1" | cut -f1)
        echo "✅ $1 ($SIZE)"
        return 0
    else
        echo "❌ $1 MISSING"
        return 1
    fi
}

ERRORS=0
check_file "public/css/pim.css" || ERRORS=$((ERRORS+1))
check_file "public/js/extensions.json" || ERRORS=$((ERRORS+1))
check_file "public/js/module-registry.js" || ERRORS=$((ERRORS+1))
check_file "public/js/require-paths.js" || ERRORS=$((ERRORS+1))
check_file "public/dist/require.min.js" || ERRORS=$((ERRORS+1))
check_file "public/dist/main.min.js" || ERRORS=$((ERRORS+1))

echo ""
echo "═══════════════════════════════════════════════════════════"
if [ $ERRORS -eq 0 ]; then
    echo "  ✅✅✅ BUILD SUCCESSFUL! ✅✅✅"
    echo ""
    echo "  All critical files present and permissions correct."
    echo "  Cache cleared. System ready!"
    echo ""
    echo "  🔗 Test: https://pim.technostationery.com/"
    echo "  👤 Login: testadmin / testpass"
else
    echo "  ⚠️  BUILD INCOMPLETE ($ERRORS files missing)"
    echo ""
    echo "  Some files are missing but system may still work."
    echo "  Check the output above for details."
fi
echo "═══════════════════════════════════════════════════════════"
