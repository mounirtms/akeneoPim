<?php

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n";
echo "   Testing cPanel Email System (PHP mail function)\n";
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n";

$recipients = [
    'Marketing Team' => 'marketing@techno-dz.com',
    'Webmaster' => 'webmaster@techno-dz.com'
];

$from = 'admin@pim.technostationery.com';
$headers = "From: $from\r\n";
$headers .= "Reply-To: $from\r\n";
$headers .= "X-Mailer: PHP/" . phpversion() . "\r\n";
$headers .= "MIME-Version: 1.0\r\n";
$headers .= "Content-Type: text/html; charset=UTF-8\r\n";

$successCount = 0;
$failCount = 0;

foreach ($recipients as $name => $email) {
    echo "[" . ($successCount + $failCount + 1) . "/" . count($recipients) . "] Sending to $name ($email)...\n";
    
    $subject = "✅ Email System Test - $name - " . date('Y-m-d H:i:s');
    
    $message = '
    <html>
        <body style="font-family: Arial, sans-serif; color: #333;">
            <h2 style="color: #4CAF50;">✅ Email System Test Successful!</h2>
            <p>This is a test email from the Akeneo PIM notification system using cPanel email.</p>
            
            <table style="border-collapse: collapse; width: 100%; max-width: 600px; margin-top: 20px;">
                <tr>
                    <td style="padding: 10px; border: 1px solid #ddd; font-weight: bold;">Recipient:</td>
                    <td style="padding: 10px; border: 1px solid #ddd;">' . $name . '</td>
                </tr>
                <tr>
                    <td style="padding: 10px; border: 1px solid #ddd; font-weight: bold;">Email:</td>
                    <td style="padding: 10px; border: 1px solid #ddd;">' . $email . '</td>
                </tr>
                <tr>
                    <td style="padding: 10px; border: 1px solid #ddd; font-weight: bold;">Test Date:</td>
                    <td style="padding: 10px; border: 1px solid #ddd;">' . date('Y-m-d H:i:s') . '</td>
                </tr>
                <tr>
                    <td style="padding: 10px; border: 1px solid #ddd; font-weight: bold;">From:</td>
                    <td style="padding: 10px; border: 1px solid #ddd;">' . $from . '</td>
                </tr>
                <tr>
                    <td style="padding: 10px; border: 1px solid #ddd; font-weight: bold;">Status:</td>
                    <td style="padding: 10px; border: 1px solid #ddd; color: #4CAF50;"><strong>✓ OPERATIONAL</strong></td>
                </tr>
            </table>
            
            <h3 style="margin-top: 30px;">What this means:</h3>
            <ul>
                <li>✅ cPanel email system is working</li>
                <li>✅ Email sending is configured correctly</li>
                <li>✅ HTML emails are properly formatted</li>
                <li>✅ Automatic notifications are ready</li>
            </ul>
            
            <p style="margin-top: 30px;">
                <a href="https://pim.technostationery.com/user/login" 
                   style="background-color: #4CAF50; color: white; padding: 10px 20px; text-decoration: none; border-radius: 5px;">
                    Access PIM System
                </a>
            </p>
            
            <p style="color: #666; font-size: 12px; margin-top: 40px; border-top: 1px solid #ddd; padding-top: 20px;">
                <strong>Techno Stationery - Akeneo PIM Email Notification System</strong><br>
                This is an automated test email. If you received this email, your notification system is working correctly.<br>
                <br>
                Server: pim.technostationery.com<br>
                Sent via: cPanel Email (sendmail)
            </p>
        </body>
    </html>
    ';
    
    if (mail($email, $subject, $message, $headers)) {
        echo "  ✓ Sent successfully!\n\n";
        $successCount++;
    } else {
        echo "  ✗ Failed to send\n\n";
        $failCount++;
    }
}

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n";
echo "Test Summary:\n";
echo "  ✓ Successful: $successCount\n";
echo "  ✗ Failed: $failCount\n";
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n";

if ($successCount > 0) {
    echo "✅ Email system is operational!\n";
    echo "📧 Check inboxes:\n";
    foreach ($recipients as $name => $email) {
        echo "   - $email ($name)\n";
    }
    echo "\n💡 Tips:\n";
    echo "   - Check spam/junk folders if emails not in inbox\n";
    echo "   - Whitelist: $from\n";
    echo "   - Add to contacts to ensure future delivery\n\n";
    
    echo "🧪 Test automatic notifications:\n";
    echo "   1. Log in to PIM: https://pim.technostationery.com/user/login\n";
    echo "   2. Create or update a product\n";
    echo "   3. Check email within seconds\n\n";
}

exit($failCount > 0 ? 1 : 0);
