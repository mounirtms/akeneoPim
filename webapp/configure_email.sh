#!/bin/bash
#
# Configure Akeneo Email with cPanel SMTP
# This script sets up email notifications for Akeneo PIM
#

set -e

SCRIPT_DIR="/home/pim/public_html"
cd "$SCRIPT_DIR"

echo "========================================="
echo "Akeneo Email Configuration Setup"
echo "========================================="
echo ""

# Backup current .env.local
if [ -f .env.local ]; then
    cp .env.local .env.local.backup.$(date +%Y%m%d_%H%M%S)
    echo "✅ Backed up .env.local"
fi

# Configure SMTP for cPanel
echo ""
echo "Configuring SMTP with cPanel..."
echo ""

# Add MAILER_URL to .env.local (override .env)
cat >> .env.local << 'EOF'

# Email Configuration (cPanel SMTP)
# Using localhost SMTP with no authentication (cPanel handles this)
MAILER_URL=smtp://localhost:25

EOF

echo "✅ Added SMTP configuration to .env.local"

# Check Symfony mailer configuration
echo ""
echo "Current Symfony Mailer Configuration:"
php bin/console debug:config framework mailer --env=prod 2>&1 | grep -A 10 "mailer:" || echo "Mailer config not found in debug"

echo ""
echo "========================================="
echo "Email Configuration Complete!"
echo "========================================="
echo ""
echo "Configuration Summary:"
echo "- Transport: SMTP"
echo "- Host: localhost (cPanel)"
echo "- Port: 25"
echo "- Authentication: None (handled by cPanel)"
echo ""
echo "Next steps:"
echo "1. Clear cache: php bin/console cache:clear --env=prod"
echo "2. Test email sending"
echo "3. Configure event subscriptions"
