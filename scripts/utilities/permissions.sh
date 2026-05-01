#!/bin/bash
################################################################################
# Akeneo PIM Permissions Script
# Purpose: Fix file and directory permissions for Akeneo PIM
# Usage: ./scripts/utilities/permissions.sh
################################################################################

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

PROJECT_DIR="/home/pim/public_html"
WEB_USER="pim"
WEB_GROUP="pim"

echo -e "${BLUE}════════════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}   Akeneo PIM Permissions Fix${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════════════════${NC}"
echo ""

cd "$PROJECT_DIR" || exit 1

# Check if running as root or with sudo
if [ "$EUID" -ne 0 ]; then 
    echo -e "${YELLOW}⚠ Warning: Not running as root. Some operations may fail.${NC}"
    echo -e "${YELLOW}  Consider running with: sudo $0${NC}"
    echo ""
fi

# Set ownership
echo -e "${YELLOW}Setting ownership to $WEB_USER:$WEB_GROUP...${NC}"
chown -R $WEB_USER:$WEB_GROUP "$PROJECT_DIR" 2>/dev/null || echo -e "${RED}✗${NC} Failed to set ownership (need root)"

# Set directory permissions
echo -e "${YELLOW}Setting directory permissions...${NC}"
find "$PROJECT_DIR" -type d -exec chmod 755 {} \; 2>/dev/null
echo -e "${GREEN}✓${NC} Directory permissions set to 755"

# Set file permissions
echo -e "${YELLOW}Setting file permissions...${NC}"
find "$PROJECT_DIR" -type f -exec chmod 644 {} \; 2>/dev/null
echo -e "${GREEN}✓${NC} File permissions set to 644"

# Make scripts executable
echo -e "${YELLOW}Making scripts executable...${NC}"
find "$PROJECT_DIR/scripts" -type f -name "*.sh" -exec chmod +x {} \; 2>/dev/null
chmod +x "$PROJECT_DIR/bin/console" 2>/dev/null
echo -e "${GREEN}✓${NC} Scripts made executable"

# Set writable permissions for cache and logs
echo -e "${YELLOW}Setting writable permissions for cache and logs...${NC}"
chmod -R 775 "$PROJECT_DIR/var/cache" 2>/dev/null || mkdir -p "$PROJECT_DIR/var/cache"
chmod -R 775 "$PROJECT_DIR/var/logs" 2>/dev/null || mkdir -p "$PROJECT_DIR/var/logs"
chmod -R 775 "$PROJECT_DIR/var/file_storage" 2>/dev/null || mkdir -p "$PROJECT_DIR/var/file_storage"
chmod -R 775 "$PROJECT_DIR/public/media" 2>/dev/null || mkdir -p "$PROJECT_DIR/public/media"
echo -e "${GREEN}✓${NC} Writable directories configured"

# Set SGID on directories to preserve group ownership
echo -e "${YELLOW}Setting SGID on writable directories...${NC}"
find "$PROJECT_DIR/var" -type d -exec chmod g+s {} \; 2>/dev/null
echo -e "${GREEN}✓${NC} SGID set on var directories"

echo ""
echo -e "${GREEN}✓ Permissions fixed successfully!${NC}"
echo ""
echo "Summary:"
echo "  - Owner: $WEB_USER:$WEB_GROUP"
echo "  - Directories: 755 (rwxr-xr-x)"
echo "  - Files: 644 (rw-r--r--)"
echo "  - Cache/Logs: 775 (rwxrwxr-x)"
echo ""
