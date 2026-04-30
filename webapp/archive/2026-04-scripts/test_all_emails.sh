#!/bin/bash

################################################################################
# Send Test Emails to All Recipients
# Tests email delivery to marketing and webmaster addresses
################################################################################

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PIM_ROOT="/home/pim/public_html"

echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}   Sending Test Emails to All Recipients${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Recipients
MARKETING_EMAIL="marketing@techno-dz.com"
WEBMASTER_EMAIL="webmaster@techno-dz.com"

# Create comprehensive test email script
cat > /tmp/send_all_test_emails.php << 'PHPSCRIPT'
<?php

require_once '/home/pim/public_html/vendor/autoload.php';

use Symfony\Component\Dotenv\Dotenv;
use Symfony\Component\Mailer\Transport;
use Symfony\Component\Mailer\Mailer;
use Symfony\Component\Mime\Email;

// Load environment variables
$dotenv = new Dotenv();
$dotenv->load('/home/pim/public_html/.env');

$recipients = [
    'marketing' => 'marketing@techno-dz.com',
    'webmaster' => 'webmaster@techno-dz.com'
];

$mailerDsn = $_ENV['MAILER_URL'] ?? 'null://localhost';

echo "Email Configuration:\n";
echo "  Transport: " . (strpos($mailerDsn, 'sendmail://') === 0 ? 'Sendmail (cPanel)' : $mailerDsn) . "\n";
echo "  From: no-reply@technostationery.com\n\n";

$successCount = 0;
$failCount = 0;

try {
    // Create transport and mailer
    $transport = Transport::fromDsn($mailerDsn);
    $mailer = new Mailer($transport);
    
    foreach ($recipients as $name => $recipientEmail) {
        echo "Sending test email to $name ($recipientEmail)...\n";
        
        try {
            // Customize email based on recipient type
            if ($name === 'marketing') {
                $subject = '🛍️ Marketing Team - Email Notification Test';
                $message = '
                    <h2 style="color: #4CAF50;">✅ Marketing Team Email Test</h2>
                    <p>This test confirms that marketing-related notifications will be delivered to this address.</p>
                    <h3>You will receive notifications for:</h3>
                    <ul>
                        <li>✉️ <strong>Product created</strong> - When new products are added to the catalog</li>
                        <li>✉️ <strong>Product updated</strong> - When existing products are modified</li>
                        <li>✉️ <strong>Product deleted</strong> - When products are removed</li>
                        <li>✉️ <strong>Category created</strong> - When new categories are added</li>
                        <li>✉️ <strong>Category updated</strong> - When categories are modified</li>
                        <li>✉️ <strong>Category deleted</strong> - When categories are removed</li>
                        <li>✉️ <strong>Product model created</strong> - When new product models are added</li>
                        <li>✉️ <strong>Product model updated</strong> - When models are modified</li>
                        <li>✉️ <strong>Product model deleted</strong> - When models are removed</li>
                        <li>✉️ <strong>Bulk updates</strong> - When 10+ products are updated at once</li>
                    </ul>
                    <p style="background-color: #E8F5E9; padding: 15px; border-left: 4px solid #4CAF50;">
                        <strong>📧 All emails will include:</strong><br>
                        • Complete item details<br>
                        • Direct links to PIM for quick access<br>
                        • Timestamps for audit trail<br>
                        • Professional HTML formatting
                    </p>
                ';
            } else {
                $subject = '🔧 Webmaster - System Error Alert Test';
                $message = '
                    <h2 style="color: #f44336;">⚠️ Webmaster Email Test</h2>
                    <p>This test confirms that system error alerts will be delivered to this address.</p>
                    <h3>You will receive notifications for:</h3>
                    <ul>
                        <li>🚨 <strong>Critical system errors</strong> - 500-level HTTP errors in production</li>
                        <li>⚠️ <strong>Product deletions</strong> (CC) - When products are removed from catalog</li>
                        <li>⚠️ <strong>Category deletions</strong> (CC) - When categories are removed</li>
                        <li>⚠️ <strong>Product model deletions</strong> (CC) - When models are removed</li>
                    </ul>
                    <p style="background-color: #FFEBEE; padding: 15px; border-left: 4px solid #f44336;">
                        <strong>🔧 Error notifications include:</strong><br>
                        • Exception type and message<br>
                        • File path and line number<br>
                        • Stack trace (first 2000 characters)<br>
                        • Request URI, method, and client IP<br>
                        • High priority flag for urgent attention
                    </p>
                ';
            }
            
            // Create email
            $email = (new Email())
                ->from('no-reply@technostationery.com')
                ->to($recipientEmail)
                ->subject($subject . ' - ' . date('Y-m-d H:i:s'))
                ->html('
                    <html>
                        <body style="font-family: Arial, sans-serif; color: #333;">
                            ' . $message . '
                            
                            <h3 style="margin-top: 30px;">Test Details</h3>
                            <table style="border-collapse: collapse; width: 100%; max-width: 600px;">
                                <tr>
                                    <td style="padding: 10px; border: 1px solid #ddd; font-weight: bold;">Test Status:</td>
                                    <td style="padding: 10px; border: 1px solid #ddd; color: #4CAF50;"><strong>✓ SUCCESS</strong></td>
                                </tr>
                                <tr>
                                    <td style="padding: 10px; border: 1px solid #ddd; font-weight: bold;">Test Date:</td>
                                    <td style="padding: 10px; border: 1px solid #ddd;">' . date('Y-m-d H:i:s') . '</td>
                                </tr>
                                <tr>
                                    <td style="padding: 10px; border: 1px solid #ddd; font-weight: bold;">Recipient Type:</td>
                                    <td style="padding: 10px; border: 1px solid #ddd;">' . ucfirst($name) . '</td>
                                </tr>
                                <tr>
                                    <td style="padding: 10px; border: 1px solid #ddd; font-weight: bold;">System:</td>
                                    <td style="padding: 10px; border: 1px solid #ddd;">Akeneo PIM Email Notification System</td>
                                </tr>
                            </table>
                            
                            <h3 style="margin-top: 30px;">Next Steps</h3>
                            <ol>
                                <li>Verify this test email was received</li>
                                <li>Check spam/junk folder if not in inbox</li>
                                <li>Whitelist no-reply@technostationery.com to prevent future emails going to spam</li>
                                <li>Test automatic notifications by creating/updating a product in PIM</li>
                            </ol>
                            
                            <p style="margin-top: 30px;">
                                <a href="https://pim.technostationery.com/user/login" 
                                   style="background-color: #2196F3; color: white; padding: 10px 20px; text-decoration: none; border-radius: 5px;">
                                    Access PIM System
                                </a>
                            </p>
                            
                            <p style="color: #666; font-size: 12px; margin-top: 40px; border-top: 1px solid #ddd; padding-top: 20px;">
                                <strong>Techno Stationery - Akeneo PIM Email Notification System</strong><br>
                                This is an automated test email. If you received this email, your notification system is working correctly.<br>
                                <br>
                                Server: pim.technostationery.com<br>
                                Sent via: cPanel Sendmail
                            </p>
                        </body>
                    </html>
                ');
            
            // Send email
            $mailer->send($email);
            
            echo "  ✓ Sent successfully to $recipientEmail\n\n";
            $successCount++;
            
        } catch (Exception $e) {
            echo "  ✗ Failed to send to $recipientEmail: " . $e->getMessage() . "\n\n";
            $failCount++;
        }
    }
    
    echo "═══════════════════════════════════════════════════════════\n";
    echo "Test Summary:\n";
    echo "  ✓ Successful: $successCount\n";
    echo "  ✗ Failed: $failCount\n";
    echo "═══════════════════════════════════════════════════════════\n\n";
    
    if ($successCount > 0) {
        echo "✓ Email system is operational!\n";
        echo "✓ Check inboxes at:\n";
        echo "  - $recipients[marketing]\n";
        echo "  - $recipients[webmaster]\n\n";
    }
    
    exit($failCount > 0 ? 1 : 0);
    
} catch (Exception $e) {
    echo "✗ Critical error: " . $e->getMessage() . "\n";
    exit(1);
}
PHPSCRIPT

# Run the test email script
cd "$PIM_ROOT"
php /tmp/send_all_test_emails.php
RESULT=$?

# Cleanup
rm -f /tmp/send_all_test_emails.php

if [ $RESULT -eq 0 ]; then
    echo ""
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}   All Test Emails Sent Successfully! ✅${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${YELLOW}Action Required:${NC}"
    echo "  1. Check inbox: $MARKETING_EMAIL"
    echo "  2. Check inbox: $WEBMASTER_EMAIL"
    echo "  3. Check spam/junk folders if emails not in inbox"
    echo "  4. Whitelist: no-reply@technostationery.com"
    echo ""
    echo -e "${GREEN}✓ Email notification system is fully operational!${NC}"
    echo ""
else
    echo ""
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${RED}   Some Emails Failed to Send${NC}"
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo "Check logs for details:"
    echo "  tail -20 /home/pim/public_html/var/logs/prod.log"
    echo ""
fi

exit $RESULT
