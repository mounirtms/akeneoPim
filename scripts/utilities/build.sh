#!/bin/bash
################################################################################
# Akeneo PIM Build Script
# Purpose: Complete build process for Akeneo PIM
# Usage: ./scripts/utilities/build.sh [--prod|--dev]
################################################################################

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PROJECT_DIR="/home/pim/public_html"
ENV="${1:-prod}"

echo -e "${BLUE}════════════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}   Akeneo PIM Build Script${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════════════════${NC}"
echo ""

# Navigate to project directory
cd "$PROJECT_DIR" || exit 1
echo -e "${GREEN}✓${NC} Changed to project directory: $PROJECT_DIR"

# Step 1: Clear cache
echo ""
echo -e "${YELLOW}Step 1: Clearing cache...${NC}"
rm -rf var/cache/$ENV/*
echo -e "${GREEN}✓${NC} Cache cleared"

# Step 2: Install/Update Composer dependencies
echo ""
echo -e "${YELLOW}Step 2: Installing Composer dependencies...${NC}"
if [ "$ENV" = "prod" ]; then
    composer install --no-dev --optimize-autoloader --no-interaction 2>&1 | tail -5
else
    composer install --no-interaction 2>&1 | tail -5
fi
echo -e "${GREEN}✓${NC} Composer dependencies installed"

# Step 3: Install Node dependencies
echo ""
echo -e "${YELLOW}Step 3: Installing Node dependencies...${NC}"
if [ -f "package.json" ]; then
    npm ci --silent 2>&1 | tail -5
    echo -e "${GREEN}✓${NC} Node dependencies installed"
else
    echo -e "${YELLOW}⚠${NC} No package.json found, skipping npm install"
fi

# Step 4: Build frontend assets
echo ""
echo -e "${YELLOW}Step 4: Building frontend assets...${NC}"
if [ -f "webpack.config.js" ]; then
    npm run webpack 2>&1 | tail -10
    echo -e "${GREEN}✓${NC} Frontend assets built"
else
    echo -e "${YELLOW}⚠${NC} No webpack config found, skipping webpack build"
fi

# Step 5: Dump RequireJS paths
echo ""
echo -e "${YELLOW}Step 5: Dumping RequireJS paths...${NC}"
php bin/console pim:installer:dump-require-paths --env=$ENV
echo -e "${GREEN}✓${NC} RequireJS paths dumped"

# Step 6: Update extensions.json
echo ""
echo -e "${YELLOW}Step 6: Updating extensions.json...${NC}"
if [ -f "vendor/akeneo/pim-community-dev/frontend/build/update-extensions.js" ]; then
    node vendor/akeneo/pim-community-dev/frontend/build/update-extensions.js
    echo -e "${GREEN}✓${NC} Extensions updated"
else
    echo -e "${YELLOW}⚠${NC} update-extensions.js not found"
fi

# Step 7: Install assets
echo ""
echo -e "${YELLOW}Step 7: Installing assets...${NC}"
php bin/console assets:install public --symlink --env=$ENV
echo -e "${GREEN}✓${NC} Assets installed"

# Step 8: Cache warmup
echo ""
echo -e "${YELLOW}Step 8: Warming up cache...${NC}"
php bin/console cache:warmup --env=$ENV
echo -e "${GREEN}✓${NC} Cache warmed up"

# Step 9: Index products
echo ""
echo -e "${YELLOW}Step 9: Indexing products (this may take a while)...${NC}"
php bin/console pim:product:index --all --env=$ENV 2>&1 | tail -5
echo -e "${GREEN}✓${NC} Products indexed"

# Final summary
echo ""
echo -e "${BLUE}════════════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}✓ Build completed successfully!${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════════════════${NC}"
echo ""
echo "Environment: $ENV"
echo "Build completed at: $(date)"
echo ""
