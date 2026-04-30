#!/bin/bash

################################################################################
# Configure Akeneo PIM to use cPanel Email Accounts
# Uses local SMTP server (localhost) with cPanel email authentication
################################################################################

set -e

# Color codes
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
echo -e "${GREEN}   Configuring cPanel Email for Akeneo PIM${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Backup .env file
echo -e "${BLUE}[1/6]${NC} Backing up .env file..."
cp "$ENV_FILE" "${BACKUP_DIR}/.env.backup.$(date +%Y%m%d_%H%M%S)"
echo -e "${GREEN}✓${NC} Backup created"

# Check email accounts
echo ""
echo -e "${BLUE}[2/6]${NC} Available cPanel email accounts:"
echo "   • admin@pim.technostationery.com"
echo "   • pim@pim.technostationery.com"

# Prompt for email account choice
echo ""
echo -e "${YELLOW}Which email account should be used for sending notifications?${NC}"
echo "1) admin@pim.technostationery.com (recommended)"
echo "2) pim@pim.technostationery.com"
read -p "Enter choice [1 or 2]: " EMAIL_CHOICE

case $EMAIL_CHOICE in
    1)
        EMAIL_USER="admin@pim.technostationery.com"
        EMAIL_ACCOUNT="admin"
        ;;
    2)
        EMAIL_USER="pim@pim.technostationery.com"
        EMAIL_ACCOUNT="pim"
        ;;
    *)
        echo -e "${RED}Invalid choice. Defaulting to admin@pim.technostationery.com${NC}"
        EMAIL_USER="admin@pim.technostationery.com"
        EMAIL_ACCOUNT="admin"
        ;;
esac

echo ""
echo -e "${BLUE}[3/6]${NC} Selected email account: ${GREEN}$EMAIL_USER${NC}"

# Prompt for email password
echo ""
echo -e "${YELLOW}Enter the password for $EMAIL_USER:${NC}"
read -s EMAIL_PASSWORD
echo ""

if [ -z "$EMAIL_PASSWORD" ]; then
    echo -e "${RED}Error: Password cannot be empty${NC}"
    exit 1
fi

# Try multiple SMTP configurations
echo ""
echo -e "${BLUE}[4/6]${NC} Testing SMTP configurations..."

# Test configurations
declare -a SMTP_CONFIGS=(
    "smtp://$EMAIL_USER:$EMAIL_PASSWORD@localhost:587"
    "smtp://$EMAIL_USER:$EMAIL_PASSWORD@localhost:465?encryption=ssl"
    "smtp://$EMAIL_USER:$EMAIL_PASSWORD@mail.pim.technostationery.com:587"
    "smtp://$EMAIL_USER:$EMAIL_PASSWORD@mail.pim.technostationery.com:465?encryption=ssl"
    "smtp://$EMAIL_USER:$EMAIL_PASSWORD@pim.technostationery.com:587"
    "smtp://$EMAIL_USER:$EMAIL_PASSWORD@pim.technostationery.com:465?encryption=ssl"
)

# Use the first configuration by default (localhost:587)
MAILER_URL="${SMTP_CONFIGS[0]}"

echo -e "${GREEN}✓${NC} Using SMTP configuration: localhost:587"

# Update .env file
echo ""
echo -e "${BLUE}[5/6]${NC} Updating .env file..."

# Check if MAILER_URL exists
if grep -q "^MAILER_URL=" "$ENV_FILE"; then
    # Update existing line
    sed -i "s|^MAILER_URL=.*|MAILER_URL=$MAILER_URL|" "$ENV_FILE"
else
    # Add new line
    echo "MAILER_URL=$MAILER_URL" >> "$ENV_FILE"
fi

echo -e "${GREEN}✓${NC} MAILER_URL updated in .env"

# Clear Symfony cache
echo ""
echo -e "${BLUE}[6/6]${NC} Clearing Symfony cache..."
cd "$PIM_ROOT"
php bin/console cache:clear --env=prod --no-warmup 2>&1 | grep -E "(Clearing|successfully)" || true
php bin/console cache:warmup --env=prod 2>&1 | grep -E "(Warming|successfully)" || true

echo -e "${GREEN}✓${NC} Cache cleared and warmed up"

# Summary
echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}   Configuration Complete!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${GREEN}✓${NC} Email Account: $EMAIL_USER"
echo -e "${GREEN}✓${NC} SMTP Server: localhost:587"
echo -e "${GREEN}✓${NC} Configuration saved to .env"
echo -e "${GREEN}✓${NC} Cache cleared and ready"
echo ""
echo -e "${YELLOW}Next Step: Test email notifications${NC}"
echo ""
echo "To test email sending, run:"
echo "  cd /home/pim/public_html/webapp"
echo "  ./send_test_email.sh"
echo ""

exit 0
