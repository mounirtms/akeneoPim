#!/bin/bash

################################################################################
# Test Password Reset Email Functionality
# Simulates password reset email with proper URL generation
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
echo -e "${GREEN}   Password Reset Email Test${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Create test PHP script
cat > /tmp/test_password_reset_email.php << 'PHPSCRIPT'
<?php

require_once '/home/pim/public_html/vendor/autoload.php';

use Symfony\Component\Dotenv\Dotenv;

// Load environment variables
$dotenv = new Dotenv();
$dotenv->load('/home/pim/public_html/.env');

echo "Password Reset Email Test\n";
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n";

// Get recipient email
$recipientEmail = $argv[1] ?? 'webmaster@techno-dz.com';

// Simulate a reset token
$testToken = 'test_token_' . bin2hex(random_bytes(16));
$resetUrl = 'https://pim.technostationery.com/user/reset/' . $testToken;

echo "Configuration:\n";
echo "  Recipient: $recipientEmail\n";
echo "  Reset URL: $resetUrl\n\n";

// Create HTML email content
$htmlContent = '
<!DOCTYPE html>
<html>
<head>
    <meta http-equiv="Content-Type" content="text/html; charset=utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Password Reset Request - Akeneo PIM</title>
    <style>
        body {
            font-family: Arial, Helvetica, sans-serif;
            font-size: 14px;
            line-height: 1.6;
            color: #333333;
            background-color: #f4f4f4;
            margin: 0;
            padding: 0;
        }
        .email-container {
            max-width: 600px;
            margin: 20px auto;
            background-color: #ffffff;
            border-radius: 8px;
            overflow: hidden;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        .email-header {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: #ffffff;
            padding: 30px 20px;
            text-align: center;
        }
        .email-header h1 {
            margin: 0;
            font-size: 24px;
            font-weight: 600;
        }
        .email-body {
            padding: 40px 30px;
        }
        .email-body h2 {
            color: #333333;
            font-size: 20px;
            margin-top: 0;
            margin-bottom: 20px;
        }
        .email-body p {
            margin: 15px 0;
            color: #555555;
        }
        .button {
            display: inline-block;
            padding: 14px 32px;
            margin: 20px 0;
            background-color: #667eea;
            color: #ffffff !important;
            text-decoration: none;
            border-radius: 5px;
            font-weight: 600;
            text-align: center;
        }
        .alternative-link {
            margin-top: 20px;
            padding: 15px;
            background-color: #f8f9fa;
            border-left: 4px solid #667eea;
            border-radius: 4px;
        }
        .alternative-link p {
            margin: 5px 0;
            font-size: 12px;
            color: #666666;
        }
        .alternative-link a {
            color: #667eea;
            word-break: break-all;
        }
        .email-footer {
            background-color: #f8f9fa;
            padding: 20px 30px;
            text-align: center;
            color: #666666;
            font-size: 12px;
            border-top: 1px solid #eeeeee;
        }
        .warning-box {
            background-color: #fff3cd;
            border-left: 4px solid #ffc107;
            padding: 15px;
            margin: 20px 0;
            border-radius: 4px;
        }
        .warning-box p {
            margin: 5px 0;
            color: #856404;
        }
    </style>
</head>
<body>
    <div class="email-container">
        <div class="email-header">
            <h1>🔐 Techno Stationery PIM</h1>
        </div>
        <div class="email-body">
            <h2>Hello, Test User!</h2>

            <p>We received a request to reset your password for your Akeneo PIM account at <strong>Techno Stationery</strong>.</p>

            <p>To reset your password, please click the button below:</p>

            <div style="text-align: center;">
                <a href="' . $resetUrl . '" class="button">Reset My Password</a>
            </div>

            <div class="alternative-link">
                <p><strong>Button not working?</strong> Copy and paste this link into your browser:</p>
                <p><a href="' . $resetUrl . '">' . $resetUrl . '</a></p>
            </div>

            <div class="warning-box">
                <p><strong>⏱️ Important:</strong> This password reset link will expire in <strong>24 hours</strong> for security reasons.</p>
                <p><strong>🔒 Security tip:</strong> If you didn\'t request this password reset, please ignore this email or contact your system administrator immediately.</p>
            </div>

            <p style="margin-top: 30px;">If you have any questions or need assistance, please contact your system administrator at <a href="mailto:webmaster@techno-dz.com">webmaster@techno-dz.com</a>.</p>

            <p style="margin-top: 20px;">
                Best regards,<br>
                <strong>The Techno Stationery PIM Team</strong>
            </p>
        </div>
        <div class="email-footer">
            <p><strong>Techno Stationery</strong></p>
            <p>Product Information Management System</p>
            <p style="margin-top: 15px; color: #999999;">
                This is an automated email from your PIM system.<br>
                If you did not request this action, please contact your system administrator.
            </p>
        </div>
    </div>
</body>
</html>
';

// Send email using PHP mail()
$from = 'admin@pim.technostationery.com';
$subject = '🔐 Password Reset Request - Techno Stationery PIM';

$headers = "From: $from\r\n";
$headers .= "Reply-To: $from\r\n";
$headers .= "X-Mailer: PHP/" . phpversion() . "\r\n";
$headers .= "MIME-Version: 1.0\r\n";
$headers .= "Content-Type: text/html; charset=UTF-8\r\n";

echo "Sending password reset test email...\n";

if (mail($recipientEmail, $subject, $htmlContent, $headers)) {
    echo "\n✅ Password reset test email sent successfully!\n\n";
    echo "Email Details:\n";
    echo "  To: $recipientEmail\n";
    echo "  From: $from\n";
    echo "  Subject: $subject\n";
    echo "  Reset Link: $resetUrl\n\n";
    echo "Please check:\n";
    echo "  1. Email inbox (and spam folder)\n";
    echo "  2. Verify the reset URL is properly formatted\n";
    echo "  3. Confirm the link shows: https://pim.technostationery.com/user/reset/...\n";
    echo "  4. Test clicking the reset button\n\n";
    exit(0);
} else {
    echo "\n✗ Failed to send email\n";
    exit(1);
}
PHPSCRIPT

# Run test
cd "$PIM_ROOT"
php /tmp/test_password_reset_email.php "$1"
RESULT=$?

# Cleanup
rm -f /tmp/test_password_reset_email.php

if [ $RESULT -eq 0 ]; then
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}   Test Complete! ✅${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${YELLOW}Now test the actual password reset in PIM:${NC}"
    echo "  1. Go to: https://pim.technostationery.com/user/login"
    echo "  2. Click 'Forgot your password?'"
    echo "  3. Enter your username/email"
    echo "  4. Check email for reset link"
    echo "  5. Verify URL shows: https://pim.technostationery.com/user/reset/..."
    echo ""
else
    echo -e "${RED}Test failed${NC}"
fi

exit $RESULT
