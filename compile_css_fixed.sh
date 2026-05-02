#!/bin/bash
set -e

echo "======================================"
echo "Fixed CSS Compilation"
echo "======================================"

# Clear the cache first
echo "Clearing Symfony cache..."
php bin/console cache:clear --env=prod --no-warmup 2>&1 | tail -5

# Regenerate require-paths
echo ""
echo "Regenerating require-paths..."
php bin/console pim:installer:dump-require-paths --env=prod 2>&1 | tail -5

# Use yarn to compile LESS properly
echo ""
echo "Compiling LESS using yarn..."
if [ -f "package.json" ]; then
    # Try yarn first
    if command -v yarn >/dev/null 2>&1; then
        yarn run less 2>&1 | tail -20
    else
        # Fallback to npm
        npm run less 2>&1 | tail -20
    fi
fi

# Check if CSS was generated
echo ""
echo "Checking for generated CSS..."
if [ -f "web/css/pim.css" ]; then
    cp web/css/pim.css public/css/pim.css
    chmod 644 public/css/pim.css
    SIZE=$(du -h public/css/pim.css | cut -f1)
    echo "✓ pim.css copied to public/css/ ($SIZE)"
elif [ -f "public/css/pim.css" ] && [ -s "public/css/pim.css" ]; then
    SIZE=$(du -h public/css/pim.css | cut -f1)
    echo "✓ pim.css already exists ($SIZE)"
else
    echo "⚠ CSS not generated, trying direct node compilation..."
    cd vendor/akeneo/pim-community-dev/frontend/build
    timeout 10 node compile-less.js 2>&1 &
    COMPILE_PID=$!
    sleep 5
    
    # Check if file was created
    if [ -f "public/css/pim.css" ] && [ -s "public/css/pim.css" ]; then
        cd /home/pim/public_html
        cp vendor/akeneo/pim-community-dev/frontend/build/public/css/pim.css public/css/pim.css
        chmod 644 public/css/pim.css
        SIZE=$(du -h public/css/pim.css | cut -f1)
        echo "✓ pim.css compiled and copied ($SIZE)"
    else
        echo "✗ CSS compilation failed"
    fi
fi

echo "======================================"
