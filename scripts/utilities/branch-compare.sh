#!/bin/bash
################################################################################
# Branch Comparison Script
# Purpose: Compare branches and identify working commits to cherry-pick
# Usage: ./scripts/utilities/branch-compare.sh
################################################################################

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}════════════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}   Branch Comparison & Analysis${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════════════════${NC}"
echo ""

# Compare pimAkeno with main
echo -e "${YELLOW}Comparing pimAkeno with main:${NC}"
echo "Commits in pimAkeno not in main:"
git log main..pimAkeno --oneline --no-merges | head -10
echo ""

# Compare oldbranch with main
echo -e "${YELLOW}Comparing oldbranch with main:${NC}"
echo "Commits in oldbranch not in main:"
git log main..oldbranch --oneline --no-merges | head -10
echo ""

# Show divergence
echo -e "${YELLOW}Branch divergence from main:${NC}"
echo "pimAkeno:"
git rev-list --left-right --count main...pimAkeno
echo "oldbranch:"
git rev-list --left-right --count main...oldbranch
echo ""

# Show file differences
echo -e "${YELLOW}Key file differences:${NC}"
echo ""
echo "Files changed in pimAkeno:"
git diff --name-only main pimAkeno | grep -E '\.(php|js|yml|yaml|sh)$' | head -10
echo ""
echo "Files changed in oldbranch:"
git diff --name-only main oldbranch | grep -E '\.(php|js|yml|yaml|sh)$' | head -10
echo ""

echo -e "${BLUE}════════════════════════════════════════════════════════════════════${NC}"
