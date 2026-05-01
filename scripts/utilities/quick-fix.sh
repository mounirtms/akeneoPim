#!/bin/bash
################################################################################
# Akeneo PIM Quick Fix Script
# Purpose: Quick troubleshooting for common issues
# Usage: ./scripts/utilities/quick-fix.sh
################################################################################

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PROJECT_DIR="/home/pim/public_html"

echo -e "${BLUE}════════════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}   Akeneo PIM Quick Fix${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════════════════${NC}"
echo ""

cd "$PROJECT_DIR" || exit 1

# Fix 1: Clear all caches
echo -e "${YELLOW}1. Clearing all caches...${NC}"
rm -rf var/cache/prod/* var/cache/dev/*
echo -e "${GREEN}✓${NC} Caches cleared"

# Fix 2: Regenerate require paths and extensions
echo -e "${YELLOW}2. Regenerating RequireJS configuration...${NC}"
php bin/console pim:installer:dump-require-paths --env=prod
node vendor/akeneo/pim-community-dev/frontend/build/update-extensions.js 2>/dev/null || echo "Extensions update skipped"
echo -e "${GREEN}✓${NC} RequireJS configuration regenerated"

# Fix 3: Install assets
echo -e "${YELLOW}3. Reinstalling assets...${NC}"
php bin/console assets:install public --symlink --env=prod
echo -e "${GREEN}✓${NC} Assets installed"

# Fix 4: Warmup cache
echo -e "${YELLOW}4. Warming up cache...${NC}"
php bin/console cache:warmup --env=prod
echo -e "${GREEN}✓${NC} Cache warmed"

# Fix 5: Create symlinks if missing
echo -e "${YELLOW}5. Checking symlinks...${NC}"
if [ ! -L "bundles" ]; then
    ln -sf public/bundles bundles
    echo -e "${GREEN}✓${NC} Created bundles symlink"
fi
if [ ! -L "js" ]; then
    ln -sf public/js js
    echo -e "${GREEN}✓${NC} Created js symlink"
fi

echo ""
echo -e "${GREEN}✓ Quick fix completed!${NC}"
echo ""
echo "Next steps:"
echo "  1. Test login: https://pim.technostationery.com/user/login"
echo "  2. Check logs: tail -f var/logs/prod.log"
echo "  3. Run full build if issues persist: ./scripts/utilities/build.sh"
echo ""
