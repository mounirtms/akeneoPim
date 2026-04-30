#!/bin/bash

################################################################################
# Test Email Sending Script for Akeneo PIM
# Sends test emails to verify SMTP configuration is working
################################################################################

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PIM_ROOT="/home/pim/public_html"

echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}   Akeneo PIM - Email Test Script${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Check MAILER_URL configuration
echo -e "${BLUE}[1/3]${NC} Checking MAILER_URL configuration..."
MAILER_URL=$(grep "^MAILER_URL=" "$PIM_ROOT/.env" 2>/dev/null | cut -d'=' -f2-)

if [ -z "$MAILER_URL" ]; then
    echo -e "${RED}✗${NC} MAILER_URL not found in .env file"
    echo "Run ./configure_cpanel_email.sh first"
    exit 1
fi

if [[ "$MAILER_URL" == *"null://"* ]]; then
    echo -e "${RED}✗${NC} MAILER_URL is set to null transport"
    echo "Run ./configure_cpanel_email.sh to configure email"
    exit 1
fi

echo -e "${GREEN}✓${NC} MAILER_URL is configured"

# Get recipient email
echo ""
echo -e "${BLUE}[2/3]${NC} Email sending test"
echo ""
echo -e "${YELLOW}Enter recipient email address for test:${NC}"
echo "  (e.g., marketing@techno-dz.com or webmaster@techno-dz.com)"
read -p "Recipient: " RECIPIENT_EMAIL

if [ -z "$RECIPIENT_EMAIL" ]; then
    echo -e "${RED}Error: Recipient email cannot be empty${NC}"
    exit 1
fi

# Validate email format
if ! [[ "$RECIPIENT_EMAIL" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
    echo -e "${RED}Error: Invalid email format${NC}"
    exit 1
fi

# Create test PHP script
echo ""
echo -e "${BLUE}[3/3]${NC} Sending test email..."

cat > /tmp/pim_test_email.php << 'PHPSCRIPT'
<?php

require_once '/home/pim/public_html/vendor/autoload.php';

use Symfony\Component\Dotenv\Dotenv;
use Symfony\Component\Mailer\Transport;
use Symfony\Component\Mailer\Mailer;
use Symfony\Component\Mime\Email;

// Load environment variables
$dotenv = new Dotenv();
$dotenv->load('/home/pim/public_html/.env');

$recipientEmail = $argv[1] ?? 'test@example.com';
$mailerDsn = $_ENV['MAILER_URL'] ?? 'null://localhost';

echo "Mailer DSN: " . (strpos($mailerDsn, 'smtp://') === 0 ? 'smtp://***:***@' . explode('@', $mailerDsn)[1] : $mailerDsn) . "\n";
echo "Recipient: $recipientEmail\n\n";

try {
    // Create transport and mailer
    $transport = Transport::fromDsn($mailerDsn);
    $mailer = new Mailer($transport);
    
    // Create test email
    $email = (new Email())
        ->from('no-reply@technostationery.com')
        ->to($recipientEmail)
        ->subject('🧪 Akeneo PIM Email Test - ' . date('Y-m-d H:i:s'))
        ->html('
            <html>
                <body style="font-family: Arial, sans-serif; color: #333;">
                    <h2 style="color: #4CAF50;">✅ Email System Test Successful!</h2>
                    <p>This is a test email from the Akeneo PIM email notification system.</p>
                    
                    <table style="border-collapse: collapse; width: 100%; max-width: 600px; margin-top: 20px;">
                        <tr>
                            <td style="padding: 10px; border: 1px solid #ddd; font-weight: bold;">Test Status:</td>
                            <td style="padding: 10px; border: 1px solid #ddd; color: #4CAF50;">✓ SUCCESS</td>
                        </tr>
                        <tr>
                            <td style="padding: 10px; border: 1px solid #ddd; font-weight: bold;">Test Date:</td>
                            <td style="padding: 10px; border: 1px solid #ddd;">' . date('Y-m-d H:i:s') . '</td>
                        </tr>
                        <tr>
                            <td style="padding: 10px; border: 1px solid #ddd; font-weight: bold;">System:</td>
                            <td style="padding: 10px; border: 1px solid #ddd;">Akeneo PIM Email Notification System</td>
                        </tr>
                        <tr>
                            <td style="padding: 10px; border: 1px solid #ddd; font-weight: bold;">Server:</td>
                            <td style="padding: 10px; border: 1px solid #ddd;">pim.technostationery.com</td>
                        </tr>
                    </table>
                    
                    <h3 style="margin-top: 30px;">What does this mean?</h3>
                    <ul>
                        <li>✅ SMTP configuration is correct</li>
                        <li>✅ Email sending is working</li>
                        <li>✅ HTML emails are properly formatted</li>
                        <li>✅ The notification system is ready to use</li>
                    </ul>
                    
                    <h3>Next Steps:</h3>
                    <ol>
                        <li>Create or update a product in the PIM</li>
                        <li>Check your email for automatic notifications</li>
                        <li>Verify notifications are received within seconds</li>
                    </ol>
                    
                    <p style="margin-top: 30px;">
                        <a href="https://pim.technostationery.com/user/login" 
                           style="background-color: #4CAF50; color: white; padding: 10px 20px; text-decoration: none; border-radius: 5px;">
                            Access PIM System
                        </a>
                    </p>
                    
                    <p style="color: #666; font-size: 12px; margin-top: 40px;">
                        This is an automated test email from Techno Stationery PIM system.<br>
                        If you received this email, your email notification system is working correctly.
                    </p>
                </body>
            </html>
        ');
    
    // Send email
    $mailer->send($email);
    
    echo "✓ Test email sent successfully!\n";
    echo "✓ Check inbox at: $recipientEmail\n";
    echo "✓ Also check spam/junk folder if not in inbox\n\n";
    
    exit(0);
    
} catch (Exception $e) {
    echo "✗ Error sending email: " . $e->getMessage() . "\n\n";
    echo "Troubleshooting:\n";
    echo "  1. Verify email password is correct\n";
    echo "  2. Check SMTP server is accessible\n";
    echo "  3. Verify email account exists in cPanel\n";
    echo "  4. Check firewall allows SMTP connections\n\n";
    exit(1);
}
PHPSCRIPT

# Run test email script
cd "$PIM_ROOT"
php /tmp/pim_test_email.php "$RECIPIENT_EMAIL"
TEST_RESULT=$?

# Cleanup
rm -f /tmp/pim_test_email.php

if [ $TEST_RESULT -eq 0 ]; then
    echo ""
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}   Email Test Complete!${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${GREEN}✓${NC} Test email sent successfully"
    echo -e "${GREEN}✓${NC} Email notification system is operational"
    echo -e "${GREEN}✓${NC} Ready to receive automatic notifications"
    echo ""
    echo -e "${YELLOW}Next Steps:${NC}"
    echo "  1. Check inbox at: $RECIPIENT_EMAIL"
    echo "  2. Check spam/junk folder if not in inbox"
    echo "  3. Test automatic notifications by creating a product in PIM"
    echo ""
else
    echo ""
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${RED}   Email Test Failed${NC}"
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo "Please check:"
    echo "  1. Email password is correct"
    echo "  2. SMTP configuration in .env"
    echo "  3. Email account exists in cPanel"
    echo "  4. Server firewall settings"
    echo ""
    echo "Run ./configure_cpanel_email.sh to reconfigure"
    echo ""
fi

exit $TEST_RESULT
