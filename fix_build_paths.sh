#!/bin/bash
set -e

echo "======================================"
echo "Fixing Build Script Paths"
echo "======================================"

# Create public directory structure in vendor build location
BUILD_DIR="/home/pim/public_html/vendor/akeneo/pim-community-dev/frontend/build"
mkdir -p "$BUILD_DIR/public/js"
mkdir -p "$BUILD_DIR/public/css"

# Create symlinks to actual public directory
if [ -f "/home/pim/public_html/public/js/require-paths.js" ]; then
    ln -sf "/home/pim/public_html/public/js/require-paths.js" "$BUILD_DIR/public/js/require-paths.js"
    echo "✓ Symlinked require-paths.js"
fi

if [ -f "/home/pim/public_html/web/js/require-paths.js" ]; then
    ln -sf "/home/pim/public_html/web/js/require-paths.js" "$BUILD_DIR/public/js/require-paths.js"
    echo "✓ Symlinked require-paths.js from web/"
fi

# Also create web directory structure for backward compatibility
mkdir -p /home/pim/public_html/web/js
mkdir -p /home/pim/public_html/web/css

# Copy require-paths to web directory
if [ -f "/home/pim/public_html/public/js/require-paths.js" ]; then
    cp "/home/pim/public_html/public/js/require-paths.js" "/home/pim/public_html/web/js/require-paths.js"
    echo "✓ Copied require-paths.js to web/js/"
fi

echo ""
echo "Now generating extensions.json..."
cd "$BUILD_DIR"
node update-extensions.js

if [ -f "/home/pim/public_html/web/js/extensions.json" ]; then
    cp "/home/pim/public_html/web/js/extensions.json" "/home/pim/public_html/public/js/extensions.json"
    echo "✓ Copied extensions.json to public/js/"
fi

echo ""
echo "Now compiling LESS to CSS..."
node compile-less.js

# Copy CSS files to public directory
if [ -f "/home/pim/public_html/web/css/pim.css" ]; then
    cp "/home/pim/public_html/web/css/pim.css" "/home/pim/public_html/public/css/pim.css"
    chmod 644 "/home/pim/public_html/public/css/pim.css"
    echo "✓ Copied pim.css to public/css/ ($(du -h /home/pim/public_html/public/css/pim.css | cut -f1))"
fi

echo ""
echo "======================================"
echo "Verification:"
echo "======================================"
for file in "public/js/require-paths.js" "public/js/extensions.json" "public/css/pim.css"; do
    if [ -f "/home/pim/public_html/$file" ]; then
        SIZE=$(du -h "/home/pim/public_html/$file" | cut -f1)
        echo "✓ $file ($SIZE)"
    else
        echo "✗ $file MISSING"
    fi
done
echo "======================================"

