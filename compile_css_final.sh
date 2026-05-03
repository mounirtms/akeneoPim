#!/bin/bash
echo "=== Final CSS Compilation ==="
echo "Date: $(date)"
echo ""

# Step 1: Install LESS compiler
echo "Step 1: Ensure LESS compiler is installed"
npm list less 2>&1 | grep -q "less@" || npm install less 2>&1 | tail -3

# Step 2: Compile the main LESS file
echo ""
echo "Step 2: Compile index.less to pim.css"
LESS_SOURCE="vendor/akeneo/pim-community-dev/src/Akeneo/Platform/Bundle/UIBundle/Resources/public/less/index.less"
CSS_OUTPUT="public/css/pim.css"

# Remove old symlink if exists
rm -f $CSS_OUTPUT

# Compile LESS to CSS
npx lessc $LESS_SOURCE $CSS_OUTPUT 2>&1

if [ -f $CSS_OUTPUT ]; then
    echo "✅ CSS compiled successfully"
    echo ""
    echo "CSS file details:"
    ls -lh $CSS_OUTPUT
    SIZE=$(stat -c%s $CSS_OUTPUT 2>/dev/null || echo "0")
    echo "Size: $SIZE bytes ($(($SIZE / 1024)) KB)"
    echo "Rules: $(grep -o '{' $CSS_OUTPUT | wc -l)"
else
    echo "❌ CSS compilation failed"
fi

# Step 3: Set proper permissions
echo ""
echo "Step 3: Set permissions"
chown pim:pim $CSS_OUTPUT 2>/dev/null || true
chmod 644 $CSS_OUTPUT 2>/dev/null || true

# Step 4: Clear cache
echo ""
echo "Step 4: Clear cache"
rm -rf var/cache/prod/*
php bin/console cache:clear --env=prod --no-warmup 2>&1 | grep -v "Warning\|Deprecated" | tail -2

echo ""
echo "=== Compilation Complete ==="
