#!/bin/bash
# Email Configuration Setup Script for Akeneo PIM
# This script helps configure email/SMTP for forgot password functionality

set -e

WORK_DIR="/home/pim/public_html"
cd "$WORK_DIR"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "================================================================="
echo "        AKENEO PIM - EMAIL/MAILER CONFIGURATION"
echo "================================================================="
echo ""

# Check current configuration
echo "📧 Current Mailer Configuration:"
echo "-----------------------------------------------------------------"
CURRENT_MAILER=$(grep "MAILER_URL" .env 2>/dev/null | cut -d'=' -f2 || echo "Not configured")
echo "MAILER_URL: $CURRENT_MAILER"
echo ""

# Explain the issue
echo -e "${RED}❌ CURRENT ISSUE:${NC}"
echo "  • Mailer is set to 'null://localhost' (dummy transport)"
echo "  • Email features are DISABLED:"
echo "    - Forgot password emails"
echo "    - User invitation emails"
echo "    - Notification emails"
echo "    - Export/Import completion emails"
echo ""

# Available options
echo -e "${BLUE}📋 SMTP CONFIGURATION OPTIONS:${NC}"
echo ""
echo "Option 1: USING GMAIL/GOOGLE WORKSPACE"
echo "  • SMTP Host: smtp.gmail.com"
echo "  • SMTP Port: 587 (TLS) or 465 (SSL)"
echo "  • Requires: App-specific password (not regular password)"
echo "  • Format: smtp://username%40gmail.com:app-password@smtp.gmail.com:587"
echo ""

echo "Option 2: USING SENDGRID"
echo "  • SMTP Host: smtp.sendgrid.net"
echo "  • SMTP Port: 587"
echo "  • Username: apikey"
echo "  • Password: Your SendGrid API key"
echo "  • Format: smtp://apikey:YOUR_API_KEY@smtp.sendgrid.net:587"
echo ""

echo "Option 3: USING MAILGUN"
echo "  • SMTP Host: smtp.mailgun.org"
echo "  • SMTP Port: 587"
echo "  • Format: smtp://postmaster@your-domain:password@smtp.mailgun.org:587"
echo ""

echo "Option 4: USING OFFICE 365"
echo "  • SMTP Host: smtp.office365.com"
echo "  • SMTP Port: 587"
echo "  • Format: smtp://user%40domain.com:password@smtp.office365.com:587"
echo ""

echo "Option 5: LOCAL/HOSTING PROVIDER SMTP"
echo "  • Contact your hosting provider for:"
echo "    - SMTP Host"
echo "    - SMTP Port"
echo "    - Username"
echo "    - Password"
echo ""

# Configuration instructions
echo -e "${YELLOW}⚙️  CONFIGURATION STEPS:${NC}"
echo ""
echo "1. Get SMTP credentials from your email provider"
echo ""
echo "2. Update .env file with correct MAILER_URL:"
echo "   cd /home/pim/public_html"
echo "   nano .env"
echo ""
echo "3. Replace the line:"
echo "   MAILER_URL=null://localhost?..."
echo ""
echo "   With your SMTP URL (example with Gmail):"
echo "   MAILER_URL=smtp://youremail%40gmail.com:your-app-password@smtp.gmail.com:587?encryption=tls"
echo ""
echo "4. Enable mailer in framework configuration:"
echo "   This needs to be done by adding config/packages/mailer.yaml"
echo ""

# Offer to create mailer config
echo -e "${BLUE}📝 WOULD YOU LIKE TO CREATE THE MAILER CONFIG FILE?${NC}"
echo ""
read -p "Create config/packages/mailer.yaml? (yes/no): " -r CREATE_CONFIG
echo ""

if [[ $CREATE_CONFIG =~ ^[Yy][Ee][Ss]$ ]]; then
    echo "Creating mailer configuration..."
    
    cat > config/packages/mailer.yaml << 'EOF'
# Akeneo PIM Mailer Configuration
framework:
    mailer:
        enabled: true
        dsn: '%env(MAILER_URL)%'
        headers:
            From: 'no-reply@technostationery.com'
        message_bus: false
EOF

    echo -e "${GREEN}✅ Created config/packages/mailer.yaml${NC}"
    echo ""
else
    echo "Skipping mailer config creation"
    echo ""
fi

# Test configuration
echo -e "${BLUE}🔍 TESTING EMAIL CONFIGURATION${NC}"
echo "-----------------------------------------------------------------"

# Check if mailer.yaml exists
if [ -f "config/packages/mailer.yaml" ]; then
    echo -e "${GREEN}✅ Mailer config file exists${NC}"
else
    echo -e "${RED}❌ Mailer config file missing${NC}"
    echo "   Create: config/packages/mailer.yaml"
fi

# Check .env
if grep -q "^MAILER_URL=smtp://" .env 2>/dev/null; then
    echo -e "${GREEN}✅ SMTP transport configured in .env${NC}"
elif grep -q "^MAILER_URL=null://" .env 2>/dev/null; then
    echo -e "${RED}❌ MAILER_URL still set to null transport${NC}"
else
    echo -e "${YELLOW}⚠️  MAILER_URL not found in .env${NC}"
fi

echo ""
echo -e "${BLUE}📋 VERIFICATION CHECKLIST:${NC}"
echo ""
echo "  [ ] Got SMTP credentials from email provider"
echo "  [ ] Updated MAILER_URL in .env with real SMTP credentials"
echo "  [ ] Created config/packages/mailer.yaml (enable mailer)"
echo "  [ ] Cleared Symfony cache: php bin/console cache:clear --env=prod"
echo "  [ ] Fixed cache permissions: cd webapp && ./fix_cache_permissions.sh"
echo ""

echo -e "${YELLOW}⚡ QUICK TEST COMMAND:${NC}"
echo ""
echo "After configuration, test with:"
echo "  cd /home/pim/public_html"
echo "  php -d allow_url_fopen=1 bin/console debug:config framework mailer --env=prod"
echo ""
echo "Expected output:"
echo "  enabled: true"
echo "  dsn: smtp://..."
echo ""

echo -e "${GREEN}🎯 NEXT STEPS:${NC}"
echo ""
echo "1. Get SMTP credentials"
echo "2. Edit .env and update MAILER_URL"
echo "3. Clear cache and test"
echo "4. Try forgot password feature in PIM UI"
echo ""

echo "================================================================="
echo "Configuration guide completed"
echo "================================================================="
