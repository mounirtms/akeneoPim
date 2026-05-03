#!/bin/bash
set -e

echo "======================================"
echo "Resolving Merge Conflicts"
echo "======================================"

# For node_modules conflicts - use remote (we removed node_modules anyway)
echo "Resolving node_modules conflicts (using remote)..."
git status --short | grep "^DU" | grep "webapp/node_modules" | awk '{print $2}' | while read file; do
    if [ -f "$file" ]; then
        git add "$file"
    fi
done

# For deleted/renamed conflicts in node_modules - accept deletion
git status --short | grep "^UD" | grep "webapp/node_modules" | awk '{print $2}' | while read file; do
    git rm "$file" 2>/dev/null || true
done

# For webapp config files - keep ours but resolve conflicts manually
echo ""
echo "Resolving critical config files..."

# .env - keep our database config but merge carefully
if [ -f ".env" ] && git status --short | grep -q "^UU .env"; then
    echo "Resolving .env (keeping our database config)..."
    git checkout --ours .env
    git add .env
fi

# error_log - use ours
if [ -f "error_log" ] && git status --short | grep -q "^UU error_log"; then
    echo "Resolving error_log (keeping ours)..."
    git checkout --ours error_log
    git add error_log
fi

# webapp package files - use remote (more recent)
for file in "webapp/package.json" "webapp/package-lock.json"; do
    if git status --short | grep -q "^UU $file"; then
        echo "Resolving $file (using remote)..."
        git checkout --theirs "$file"
        git add "$file"
    fi
done

# .qoder/settings - use ours
if git status --short | grep -q "^AA .qoder/settings.local.json"; then
    echo "Resolving .qoder/settings.local.json (using ours)..."
    git checkout --ours .qoder/settings.local.json
    git add .qoder/settings.local.json
fi

# src/AppBundle - use remote
if git status --short | grep -q "^UU src/AppBundle"; then
    echo "Resolving src/AppBundle (using remote)..."
    git checkout --theirs src/AppBundle/Resources/views/PimUI/index.html.twig
    git add src/AppBundle/Resources/views/PimUI/index.html.twig
fi

# SESSION_COMPLETE_SUMMARY.md - use ours (our new one)
if git status --short | grep -q "^AA webapp/SESSION_COMPLETE_SUMMARY.md"; then
    echo "Resolving SESSION_COMPLETE_SUMMARY.md (using ours)..."
    git checkout --ours webapp/SESSION_COMPLETE_SUMMARY.md
    git add webapp/SESSION_COMPLETE_SUMMARY.md
fi

# playwright.config.js - use remote
if git status --short | grep -q "^AA webapp/playwright.config.js"; then
    echo "Resolving playwright.config.js (using remote)..."
    git checkout --theirs webapp/playwright.config.js
    git add webapp/playwright.config.js
fi

# Check remaining conflicts
REMAINING=$(git status --short | grep "^[ADU]" | wc -l)
echo ""
echo "Remaining conflicts: $REMAINING"

if [ $REMAINING -gt 0 ]; then
    echo ""
    echo "Listing remaining conflicts:"
    git status --short | grep "^[ADU]" | head -20
fi

echo "======================================"
