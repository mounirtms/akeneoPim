#!/bin/bash

echo "=========================================="
echo "FIX JQUERY LOADING ISSUE"
echo "=========================================="
echo ""

echo "Step 1: Check if jQuery files exist"
echo "---"
find public -name "*jquery*" -type f 2>/dev/null | head -20

echo ""
echo "Step 2: Check vendor.min.js and main.min.js"
echo "---"
ls -lh public/dist/vendor.min.js public/dist/main.min.js 2>/dev/null || echo "Files not in dist/"
ls -lh public/vendor.min.js public/main.min.js 2>/dev/null || echo "Files not in public/"

echo ""
echo "Step 3: Check what's loading the jQuery dependency"
echo "---"
head -5 public/dist/vendor.min.js 2>/dev/null | cat
echo ""
head -5 public/dist/main.min.js 2>/dev/null | cat

echo ""
echo "Step 4: Check index.html or main template for script loading order"
echo "---"
if [ -f public/index.html ]; then
    echo "Found public/index.html:"
    grep -n "script" public/index.html | head -20
fi

if [ -f templates/PimUI/index.html.twig ]; then
    echo "Found PimUI template:"
    grep -n "script" templates/PimUI/index.html.twig | head -20
fi

echo ""
echo "Step 5: Check bundles for jQuery"
echo "---"
find public/bundles -name "*jquery*" -o -name "*jQuery*" 2>/dev/null | head -10

echo ""
echo "Step 6: Look for RequireJS configuration"
echo "---"
if [ -f public/js/require-paths.js ]; then
    echo "Found require-paths.js:"
    head -30 public/js/require-paths.js
fi

echo ""
echo "Step 7: Check if Akeneo uses RequireJS or direct script loading"
echo "---"
grep -r "requirejs\|require\.config" public/*.html public/js/*.js 2>/dev/null | head -10

echo ""
echo "Step 8: Download jQuery if missing"
echo "---"
if [ ! -f public/js/jquery.min.js ]; then
    echo "jQuery not found in public/js/ - downloading..."
    mkdir -p public/js
    curl -sL "https://code.jquery.com/jquery-3.6.0.min.js" -o public/js/jquery.min.js
    echo "✅ jQuery downloaded: $(ls -lh public/js/jquery.min.js)"
else
    echo "✅ jQuery exists: $(ls -lh public/js/jquery.min.js)"
fi

echo ""
echo "Step 9: Check the main Akeneo template"
echo "---"
TEMPLATE_FILE=$(find templates -name "index.html.twig" | grep -i pim | head -1)
if [ -n "$TEMPLATE_FILE" ]; then
    echo "Main template: $TEMPLATE_FILE"
    echo "Script tags:"
    grep -A 2 -B 2 "script" "$TEMPLATE_FILE" | head -40
fi

echo ""
echo "Step 10: Check for webpack or asset manifests"
echo "---"
find public -name "manifest.json" -o -name "entrypoints.json" 2>/dev/null | while read f; do
    echo "Found: $f"
    head -20 "$f"
done

echo ""
echo "=========================================="
echo "ANALYSIS COMPLETE"
echo "=========================================="
echo ""

