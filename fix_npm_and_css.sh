#!/bin/bash
echo "=== Fix NPM and Compile CSS ==="
echo "Date: $(date)"
echo ""

# Step 1: Fix npm and node_modules
echo "Step 1: Clean and reinstall npm dependencies"
rm -rf node_modules package-lock.json
npm cache clean --force 2>&1 | tail -3

# Create minimal package.json
cat > package.json << 'PKGJSON'
{
  "name": "akeneo-pim",
  "version": "1.0.0",
  "dependencies": {
    "less": "^4.1.3"
  }
}
PKGJSON

echo "Installing LESS..."
npm install 2>&1 | tail -5

# Step 2: Compile CSS using installed lessc
echo ""
echo "Step 2: Compile CSS"
LESS_SOURCE="vendor/akeneo/pim-community-dev/src/Akeneo/Platform/Bundle/UIBundle/Resources/public/less/index.less"
CSS_OUTPUT="public/css/pim.css"

rm -f $CSS_OUTPUT

if [ -f "node_modules/.bin/lessc" ]; then
    echo "Compiling with lessc..."
    node_modules/.bin/lessc $LESS_SOURCE $CSS_OUTPUT 2>&1
    
    if [ -f $CSS_OUTPUT ]; then
        echo "✅ CSS compiled successfully!"
        ls -lh $CSS_OUTPUT
        SIZE=$(stat -c%s $CSS_OUTPUT)
        echo "Size: $SIZE bytes ($(($SIZE / 1024)) KB)"
        echo "CSS Rules: $(grep -o '{' $CSS_OUTPUT | wc -l)"
        
        # Fix permissions
        chown pim:pim $CSS_OUTPUT
        chmod 644 $CSS_OUTPUT
    else
        echo "❌ Compilation failed"
    fi
else
    echo "❌ lessc not found after installation"
fi

# Step 3: Verify security configuration
echo ""
echo "Step 3: Verify bcrypt encoder in security.yml"
grep "bcrypt" config/packages/security.yml && echo "✅ Bcrypt configured" || echo "⚠️ Bcrypt not configured"

# Step 4: Clear cache
echo ""
echo "Step 4: Final cache clear"
rm -rf var/cache/prod/*
php bin/console cache:clear --env=prod --no-warmup 2>&1 | tail -2

echo ""
echo "=== Setup Complete ==="
