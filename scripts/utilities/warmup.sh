#!/bin/bash
################################################################################
# Akeneo PIM Cache Warmup Script
# Purpose: Quick cache warmup for Akeneo PIM
# Usage: ./scripts/utilities/warmup.sh [prod|dev]
################################################################################

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PROJECT_DIR="/home/pim/public_html"
ENV="${1:-prod}"

echo -e "${BLUE}════════════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}   Akeneo PIM Cache Warmup${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════════════════${NC}"
echo ""

cd "$PROJECT_DIR" || exit 1

# Clear cache
echo -e "${YELLOW}Clearing $ENV cache...${NC}"
php bin/console cache:clear --env=$ENV --no-warmup
echo -e "${GREEN}✓${NC} Cache cleared"

# Warmup cache
echo -e "${YELLOW}Warming up cache...${NC}"
php bin/console cache:warmup --env=$ENV
echo -e "${GREEN}✓${NC} Cache warmed up"

# Dump require paths
echo -e "${YELLOW}Dumping RequireJS paths...${NC}"
php bin/console pim:installer:dump-require-paths --env=$ENV
echo -e "${GREEN}✓${NC} RequireJS paths updated"

echo ""
echo -e "${GREEN}✓ Warmup completed successfully!${NC}"
echo ""
