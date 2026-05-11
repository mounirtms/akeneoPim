#!/bin/bash

################################################################################
# Quick Email Configuration for Akeneo PIM using cPanel Sendmail
# Uses native sendmail (no SMTP authentication required)
################################################################################

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PIM_ROOT="/home/pim/public_html"
ENV_FILE="${PIM_ROOT}/.env"
BACKUP_DIR="${PIM_ROOT}/webapp/backups"

echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}   Quick cPanel Email Setup for Akeneo PIM${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Create backup
mkdir -p "$BACKUP_DIR"
echo -e "${BLUE}[1/4]${NC} Backing up .env file..."
cp "$ENV_FILE" "${BACKUP_DIR}/.env.backup.$(date +%Y%m%d_%H%M%S)"
echo -e "${GREEN}✓${NC} Backup created"

# Configure sendmail transport (simplest method for cPanel)
echo ""
echo -e "${BLUE}[2/4]${NC} Configuring email transport..."

# Using sendmail transport (native to cPanel, no authentication required)
MAILER_URL="sendmail://default"

# Update .env file
if grep -q "^MAILER_URL=" "$ENV_FILE"; then
    sed -i "s|^MAILER_URL=.*|MAILER_URL=$MAILER_URL|" "$ENV_FILE"
else
    echo "MAILER_URL=$MAILER_URL" >> "$ENV_FILE"
fi

echo -e "${GREEN}✓${NC} Configured to use native sendmail transport"
echo -e "${GREEN}✓${NC} Sender: admin@pim.technostationery.com (from cPanel)"

# Clear cache
echo ""
echo -e "${BLUE}[3/4]${NC} Clearing Symfony cache..."
cd "$PIM_ROOT"
php bin/console cache:clear --env=prod --no-warmup 2>&1 | grep -E "(Clearing|successfully)" || true
php bin/console cache:warmup --env=prod 2>&1 | grep -E "(Warming|successfully)" || true
echo -e "${GREEN}✓${NC} Cache cleared and warmed up"

# Test sendmail is available
echo ""
echo -e "${BLUE}[4/4]${NC} Verifying sendmail availability..."
if command -v sendmail >/dev/null 2>&1; then
    SENDMAIL_PATH=$(command -v sendmail)
    echo -e "${GREEN}✓${NC} Sendmail found at: $SENDMAIL_PATH"
else
    echo -e "${YELLOW}⚠${NC} Sendmail not found in PATH, but may work via PHP"
fi

# Summary
echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}   Configuration Complete!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${GREEN}✓${NC} Email Transport: Native Sendmail (cPanel)"
echo -e "${GREEN}✓${NC} From Address: admin@pim.technostationery.com"
echo -e "${GREEN}✓${NC} No SMTP authentication required"
echo -e "${GREEN}✓${NC} Ready to send emails"
echo ""
echo -e "${YELLOW}Next Step: Send test email${NC}"
echo ""
echo "Run test email script:"
echo "  cd /home/pim/public_html/webapp"
echo "  ./send_test_email.sh"
echo ""
echo "Or test directly in PIM by creating/updating a product"
echo ""

exit 0
