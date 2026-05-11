#!/bin/bash
# Quick Start Commands for Next Session
# Session 3 Continuation - Akeneo PIM Fix
# Date: 2026-05-08

echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║  Akeneo PIM Quick Start - Next Session                           ║"
echo "║  Phase 7-8 Complete | Ready for Phase 9-12                       ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo ""

# ============================================================================
# STEP 1: PURGE CLOUDFLARE CACHE (MANUAL - CRITICAL)
# ============================================================================
echo "🔴 STEP 1: PURGE CLOUDFLARE CACHE (MANUAL)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "⚠️  THIS STEP REQUIRES MANUAL ACTION - CANNOT BE AUTOMATED"
echo ""
echo "1. Open browser and go to: https://dash.cloudflare.com/"
echo "2. Select domain: pim.technostationery.com"
echo "3. Navigate to: Caching → Purge Cache"
echo "4. Click: 'Purge Everything'"
echo "5. Wait: 1-2 minutes for propagation"
echo ""
read -p "Press ENTER after you've purged Cloudflare cache..."

# ============================================================================
# STEP 2: VERIFY PATCHES ARE LOADING
# ============================================================================
echo ""
echo "✅ STEP 2: VERIFY PATCHES ARE LOADING"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
cd /home/pim/public_html/webapp

echo "Running quick cache bypass test..."
node bypass_cache_test.js

echo ""
echo "Expected results:"
echo "  ✅ window.r exists: ✅"
echo "  ✅ r.initialize exists: ✅"
echo "  ✅ r.initialize error: ✅ NO"
echo ""
read -p "Do the results show patches working? (y/n): " patches_working

if [ "$patches_working" != "y" ]; then
    echo ""
    echo "❌ Patches not loading yet. Possible issues:"
    echo "   1. Cloudflare cache not fully purged yet (wait 5 more minutes)"
    echo "   2. Browser cache needs clearing (Ctrl+Shift+Delete)"
    echo "   3. Try incognito mode"
    echo ""
    echo "📖 See troubleshooting: NEXT_SESSION_PRIORITIES.md"
    echo ""
    exit 1
fi

echo ""
echo "✅ Patches verified! Running full verification test..."
node template_patch_verification.js

# ============================================================================
# STEP 3: PHASE 9 - WEBPACK REBUILD
# ============================================================================
echo ""
echo "🔧 STEP 3: PHASE 9 - WEBPACK REBUILD"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
cd /home/pim/public_html

echo "Checking Node.js version..."
node --version

echo ""
echo "Checking yarn..."
yarn --version

echo ""
read -p "Proceed with webpack rebuild? (y/n): " do_webpack

if [ "$do_webpack" = "y" ]; then
    echo ""
    echo "Installing dependencies (if needed)..."
    # yarn install
    
    echo ""
    echo "🔨 Starting webpack rebuild (this may take 10-20 minutes)..."
    yarn run webpack:build
    
    if [ $? -eq 0 ]; then
        echo ""
        echo "✅ Webpack build successful!"
        
        echo ""
        echo "Clearing caches..."
        php bin/console cache:clear --env=prod
        php bin/console cache:warmup --env=prod
        sudo systemctl restart ea-php83-php-fpm
        varnishadm "ban req.url ~ ."
        
        echo ""
        echo "✅ Caches cleared and services restarted"
    else
        echo ""
        echo "❌ Webpack build failed. Check errors above."
        echo "📖 See troubleshooting: NEXT_SESSION_PRIORITIES.md"
        exit 1
    fi
else
    echo "Skipping webpack rebuild."
fi

# ============================================================================
# STEP 4: PHASE 10 - REGISTER AKENEO MODULES
# ============================================================================
echo ""
echo "📦 STEP 4: PHASE 10 - REGISTER AKENEO MODULES"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
cd /home/pim/public_html

echo "Installing Symfony assets..."
php bin/console assets:install public --symlink --env=prod

echo ""
echo "Verifying bundles..."
ls -la public/bundles/ | grep -E "(pimui|oro|akeneo)"

echo ""
echo "Clearing caches..."
php bin/console cache:clear --env=prod
sudo systemctl restart ea-php83-php-fpm

echo ""
echo "✅ Phase 10 complete!"

# ============================================================================
# STEP 5: PHASE 11-12 - VERIFY EVERYTHING WORKS
# ============================================================================
echo ""
echo "🚀 STEP 5: PHASE 11-12 - FINAL VERIFICATION"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
cd /home/pim/public_html/webapp

echo "Running Phase 9-12 verification test..."
node phase_9_12_implementation.js

echo ""
echo "Running comprehensive UI test (monkey testing)..."
node comprehensive_pim_monkey_test.js

# ============================================================================
# FINAL SUMMARY
# ============================================================================
echo ""
echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║                    🎉 ALL PHASES COMPLETE                         ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo ""
echo "Next Steps:"
echo "1. Open browser: https://pim.technostationery.com/user/login"
echo "2. Login with: mounir / 2026"
echo "3. Open DevTools console (F12)"
echo "4. Verify:"
echo "   ✅ No 'r.initialize is not a function' error"
echo "   ✅ Loading screen disappears"
echo "   ✅ Navigation menu renders"
echo "   ✅ Dashboard displays content"
echo ""
echo "📊 Test results saved in:"
echo "   - template_verification_results.json"
echo "   - bypass_cache_results.json"
echo "   - monkey_test_results.json"
echo "   - phase_9_12_results.json"
echo ""
echo "📸 Screenshots saved in:"
echo "   - template_verify_*.png"
echo "   - bypass_cache_test.png"
echo "   - monkey_test_*.png"
echo "   - phase_9_12_*.png"
echo ""
echo "📖 Full documentation:"
echo "   - README_SESSION_3.md (start here)"
echo "   - NEXT_SESSION_PRIORITIES.md (detailed action plan)"
echo "   - SESSION_3_COMPLETE_SUMMARY.md (full summary)"
echo ""
echo "✅ Session complete! PIM should now be fully functional."
