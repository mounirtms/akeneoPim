#!/bin/bash
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║            AKENEO PIM - SYSTEM STATUS CHECK                    ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

echo "=== GIT STATUS ==="
echo "Current Branch: $(git branch --show-current)"
echo "Last Commit: $(git log -1 --oneline)"
echo ""

echo "=== CRITICAL FRONTEND ASSETS ==="
test -f public/js/extensions.json && echo "✓ extensions.json ($(du -h public/js/extensions.json | cut -f1))" || echo "✗ extensions.json MISSING"
test -f public/css/pim.css && echo "✓ pim.css ($(du -h public/css/pim.css | cut -f1))" || echo "✗ pim.css MISSING"
test -f public/js/require-paths.js && echo "✓ require-paths.js ($(du -h public/js/require-paths.js | cut -f1))" || echo "✗ require-paths.js MISSING"
test -f public/bundles/pimui/manifest.json && echo "✓ manifest.json" || echo "✗ manifest.json MISSING"
test -f public/bundles/pimui/js/index.js && echo "✓ pimui/index.js" || echo "✗ pimui/index.js MISSING"
echo ""

echo "=== ENVIRONMENT ==="
grep "APP_ENV" .env
grep "APP_DEBUG" .env
grep "APP_DATABASE_HOST" .env
grep "APP_DATABASE_PORT" .env
echo ""

echo "=== BUNDLE SYMLINKS ==="
ls -l public/bundles/ | grep -c "^l" | xargs echo "Total symlinks:"
echo ""

echo "=== SYMFONY VERSION ==="
php bin/console --version 2>&1 | grep -v "Deprecated"
echo ""

echo "=== ASSET COUNT ==="
echo "CSS files: $(find public/css -name "*.css" 2>/dev/null | wc -l)"
echo "JS files: $(find public/js -name "*.js" 2>/dev/null | wc -l)"
echo "Bundles: $(ls -1 public/bundles/ 2>/dev/null | wc -l)"
echo ""

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║                  STATUS CHECK COMPLETE                         ║"
echo "╚════════════════════════════════════════════════════════════════╝"
