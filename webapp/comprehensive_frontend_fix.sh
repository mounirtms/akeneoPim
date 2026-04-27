#!/bin/bash
# Comprehensive Frontend Fix Script
# Date: 2026-04-27

echo "═══════════════════════════════════════════════════════════════════"
echo "  COMPREHENSIVE FRONTEND DIAGNOSTICS & FIX"
echo "  Date: $(date)"
echo "═══════════════════════════════════════════════════════════════════"
echo ""

# 1. Check Environment
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "1. ENVIRONMENT CHECK"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Node version: $(node --version 2>/dev/null || echo 'Not found')"
echo "Yarn version: $(yarn --version 2>/dev/null || echo 'Not found')"
echo "PHP version: $(php --version | head -1)"
echo "Environment: $(grep APP_ENV .env | cut -d= -f2)"
echo "Debug mode: $(grep APP_DEBUG .env | cut -d= -f2)"
echo ""

# 2. Check Critical Files
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "2. CRITICAL FILES CHECK"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "package.json: $([ -f package.json ] && echo '✓ EXISTS' || echo '✗ MISSING')"
echo "webpack.config.js: $([ -f webpack.config.js ] && echo '✓ EXISTS' || echo '✗ MISSING')"
echo "node_modules/: $([ -d node_modules ] && echo '✓ EXISTS' || echo '✗ MISSING')"
echo "public/js/require-paths.js: $([ -f public/js/require-paths.js ] && echo '✓ EXISTS' || echo '✗ MISSING')"
echo "public/bundles/: $([ -d public/bundles ] && echo '✓ EXISTS' || echo '✗ MISSING')"
echo ""

# 3. Check Public Assets
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "3. PUBLIC ASSETS CHECK"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "JavaScript files in public/js/:"
ls -lh public/js/*.js 2>/dev/null | awk '{print "  " $9 " (" $5 ")"}'
echo ""
echo "Checking for built assets:"
echo "  public/dist/: $([ -d public/dist ] && ls public/dist/*.js 2>/dev/null | wc -l || echo '0') JS files"
echo "  public/css/: $([ -d public/css ] && ls public/css/*.css 2>/dev/null | wc -l || echo '0') CSS files"
echo ""

# 4. Check Cache Directories
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "4. CACHE DIRECTORIES"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "var/cache/ size: $(du -sh var/cache 2>/dev/null | awk '{print $1}')"
echo "node_modules/.cache/ size: $(du -sh node_modules/.cache 2>/dev/null | awk '{print $1}' || echo 'N/A')"
echo "public/cache/ size: $(du -sh public/cache 2>/dev/null | awk '{print $1}')"
echo ""

# 5. Check RequireJS Configuration
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "5. REQUIREJS CONFIGURATION"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [ -f public/js/require-paths.js ]; then
    echo "First line of require-paths.js:"
    head -1 public/js/require-paths.js
    echo "File size: $(wc -c < public/js/require-paths.js) bytes"
else
    echo "✗ require-paths.js NOT FOUND"
fi
echo ""

echo "═══════════════════════════════════════════════════════════════════"
echo "  DIAGNOSTICS COMPLETE"
echo "═══════════════════════════════════════════════════════════════════"
