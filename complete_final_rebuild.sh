#!/bin/bash
echo "=== Complete Frontend Rebuild ==="
echo "Date: $(date)"
echo ""

# Step 1: Copy pre-compiled CSS if available
echo "Step 1: Check for pre-compiled CSS"
if [ -f "vendor/akeneo/pim-community-dev/src/Akeneo/Platform/Bundle/UIBundle/Resources/public/css/pim.css" ]; then
    echo "Found pre-compiled CSS in vendor directory"
    cp vendor/akeneo/pim-community-dev/src/Akeneo/Platform/Bundle/UIBundle/Resources/public/css/pim.css public/css/
    echo "✅ Copied pre-compiled CSS"
else
    echo "No pre-compiled CSS found, will use symlinks"
fi

# Step 2: Ensure public/css directory exists and has proper symlinks
echo ""
echo "Step 2: Setup CSS directory structure"
mkdir -p public/css
cd public/css
if [ ! -L pim.css ]; then
    ln -sf ../../vendor/akeneo/pim-community-dev/src/Akeneo/Platform/Bundle/UIBundle/Resources/public/css/pim.css pim.css 2>/dev/null || true
fi
cd /home/pim/public_html

# Step 3: Check if symlink works
echo ""
echo "Step 3: Verify CSS availability"
ls -lh public/css/pim.css
if [ -f public/css/pim.css ] || [ -L public/css/pim.css ]; then
    SIZE=$(stat -f%z public/css/pim.css 2>/dev/null || stat -c%s public/css/pim.css 2>/dev/null || echo "0")
    echo "CSS file size: $SIZE bytes ($(($SIZE / 1024)) KB)"
else
    echo "⚠️ CSS file not accessible"
fi

# Step 4: Run webpack build if available
echo ""
echo "Step 4: Check for webpack build"
if [ -f "webpack.config.js" ]; then
    echo "Found webpack config, attempting build"
    npm run webpack 2>&1 | tail -10 || echo "Webpack not configured"
fi

# Step 5: Clear cache one more time
echo ""
echo "Step 5: Final cache clear"
rm -rf var/cache/prod/*
php bin/console cache:clear --env=prod 2>&1 | grep -v "Warning\|Deprecated" | tail -3

echo ""
echo "=== Build Complete ==="
