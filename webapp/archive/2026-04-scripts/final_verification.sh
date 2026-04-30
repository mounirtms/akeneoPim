#!/bin/bash
# Final Comprehensive Verification
# Date: 2026-04-27

echo "=============================================="
echo "FINAL FRONTEND VERIFICATION"
echo "=============================================="
echo ""

echo "Step 1: Clear ALL caches..."
# Symfony cache
rm -rf var/cache/prod/*
php bin/console cache:clear --env=prod --no-warmup --no-optional-warmers
php bin/console cache:warmup --env=prod

echo ""
echo "Step 2: Verify all fixed files..."
echo ""
echo "✓ require-paths.js:"
if grep -q "require.config" public/js/require-paths.js; then
    echo "  ✅ Has RequireJS configuration (no module.exports)"
else
    echo "  ❌ Still has issues"
fi

echo ""
echo "✓ jquery.js symlink:"
if [ -L "public/jquery.js" ]; then
    echo "  ✅ Symlink exists: $(readlink public/jquery.js)"
else
    echo "  ❌ Missing symlink"
fi

echo ""
echo "✓ process-polyfill.js:"
if [ -f "public/dist/process-polyfill.js" ]; then
    echo "  ✅ Polyfill exists ($(stat -c%s public/dist/process-polyfill.js) bytes)"
else
    echo "  ❌ Missing polyfill"
fi

echo ""
echo "✓ Template includes process polyfill:"
if grep -q "process-polyfill" vendor/akeneo/pim-community-dev/src/Akeneo/Platform/Bundle/UIBundle/Resources/views/index.html.twig; then
    echo "  ✅ Template updated with polyfill"
else
    echo "  ❌ Template not updated"
fi

echo ""
echo "✓ Analytics disabled:"
if grep -q "is_enabled: false" config/packages/akeneo_analytics.yaml 2>/dev/null; then
    echo "  ✅ Analytics disabled in config"
else
    echo "  ⚠️  Analytics config not found"
fi

echo ""
echo "✓ Cache buster version:"
grep "cache_buster" vendor/akeneo/pim-community-dev/src/Akeneo/Platform/Bundle/UIBundle/Resources/views/index.html.twig | head -1

echo ""
echo "Step 3: Check translation files..."
TRANS_COUNT=$(ls -1 public/js/translation/*.js 2>/dev/null | wc -l)
echo "  Translation files: $TRANS_COUNT"
if [ -f "public/js/translation/en_US.js" ]; then
    SIZE=$(stat -c%s public/js/translation/en_US.js)
    echo "  ✅ en_US.js exists ($SIZE bytes)"
else
    echo "  ❌ en_US.js missing"
fi

echo ""
echo "Step 4: Verify bundle assets..."
BUNDLE_COUNT=$(ls -d public/bundles/*/ 2>/dev/null | wc -l)
echo "  Bundle directories: $BUNDLE_COUNT"

echo ""
echo "Step 5: Check webpack dist files..."
echo "  Webpack bundles:"
ls -lh public/dist/*.js | awk '{print "    " $9 " - " $5}'

echo ""
echo "Step 6: System health check..."
php webapp/system_health_check.php 2>&1 | tail -15

echo ""
echo "=============================================="
echo "VERIFICATION COMPLETE"
echo "=============================================="
echo ""
echo "Next steps:"
echo "1. Clear browser cache (Ctrl+F5 or Cmd+Shift+R)"
echo "2. Open: https://pim.technostationery.com"
echo "3. Open browser console (F12)"
echo "4. Check for errors"
echo ""
echo "Expected result: No console errors related to:"
echo "  - module is not defined"
echo "  - jquery.js 404"
echo "  - pim/form-builder.js 404  "
echo "  - process is not defined"
echo "  - analytics/collect_data 500"
echo ""

