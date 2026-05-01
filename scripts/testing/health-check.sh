#!/bin/bash
#
# Akeneo PIM Quick Health Check
# Fast diagnostic tool for system status
# Version: 2.0 - Optimized
#

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Configuration
BASE_URL="${PIM_URL:-https://pim.technostationery.com}"
PROJECT_ROOT="/home/pim/public_html"

# Quick checks
check_web() {
    echo -n "🌐 Web Interface... "
    if curl -s -o /dev/null -w "%{http_code}" "$BASE_URL" | grep -q "302\|200"; then
        echo -e "${GREEN}✓${NC}"
        return 0
    else
        echo -e "${RED}✗${NC}"
        return 1
    fi
}

check_db() {
    echo -n "💾 Database... "
    if mariadb -h 127.0.0.1 -P 3307 -u akeneo_pim -pakeneo_pim akeneo_pim --ssl=0 -e "SELECT 1" >/dev/null 2>&1; then
        echo -e "${GREEN}✓${NC}"
        return 0
    else
        echo -e "${RED}✗${NC}"
        return 1
    fi
}

check_cache() {
    echo -n "🗄️  Cache... "
    if [[ -d "$PROJECT_ROOT/var/cache/prod" ]] && [[ $(find "$PROJECT_ROOT/var/cache/prod" -type f | head -1) ]]; then
        echo -e "${GREEN}✓${NC}"
        return 0
    else
        echo -e "${YELLOW}⚠${NC}"
        return 1
    fi
}

check_redis() {
    echo -n "🔴 Redis... "
    if systemctl is-active --quiet redis 2>/dev/null; then
        echo -e "${GREEN}✓${NC}"
        return 0
    else
        echo -e "${YELLOW}⚠${NC}"
        return 1
    fi
}

check_nginx() {
    echo -n "🔧 Nginx... "
    if systemctl is-active --quiet nginx 2>/dev/null; then
        echo -e "${GREEN}✓${NC}"
        return 0
    else
        echo -e "${RED}✗${NC}"
        return 1
    fi
}

check_disk() {
    echo -n "💿 Disk Space... "
    local usage=$(df "$PROJECT_ROOT" | awk 'NR==2 {print $5}' | sed 's/%//')
    if [[ $usage -lt 90 ]]; then
        echo -e "${GREEN}✓${NC} (${usage}%)"
        return 0
    else
        echo -e "${RED}✗${NC} (${usage}%)"
        return 1
    fi
}

# Main
echo "╔════════════════════════════════════════════════════╗"
echo "║      AKENEO PIM QUICK HEALTH CHECK                ║"
echo "╚════════════════════════════════════════════════════╝"
echo ""

FAILED=0

check_web || ((FAILED++))
check_db || ((FAILED++))
check_cache || ((FAILED++))
check_redis || ((FAILED++))
check_nginx || ((FAILED++))
check_disk || ((FAILED++))

echo ""
if [[ $FAILED -eq 0 ]]; then
    echo -e "${GREEN}✅ All systems operational${NC}"
    exit 0
else
    echo -e "${RED}⚠️  $FAILED issue(s) detected${NC}"
    echo "Run: bash scripts/testing/stability-test.sh for details"
    exit 1
fi
