<?php

require_once '/home/pim/public_html/vendor/autoload.php';

use Symfony\Component\Dotenv\Dotenv;
use Symfony\Component\Mailer\Transport;
use Symfony\Component\Mailer\Mailer;
use Symfony\Component\Mime\Email;

// Load environment variables
$dotenv = new Dotenv();
$dotenv->load('/home/pim/public_html/.env');

$mailerDsn = $_ENV['MAILER_URL'] ?? 'null://localhost';

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n";
echo "   Sending Test Emails to All Recipients\n";
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n";

echo "Email Configuration:\n";
echo "  Transport: " . (strpos($mailerDsn, 'sendmail://') === 0 ? 'Sendmail (cPanel)' : $mailerDsn) . "\n";
echo "  From: no-reply@technostationery.com\n\n";

$recipients = [
    'Marketing Team' => 'marketing@techno-dz.com',
    'Webmaster' => 'webmaster@techno-dz.com'
];

$successCount = 0;
$failCount = 0;

try {
    // Create transport and mailer
    $transport = Transport::fromDsn($mailerDsn);
    $mailer = new Mailer($transport);
    
    foreach ($recipients as $name => $recipientEmail) {
        echo "[" . ($successCount + $failCount + 1) . "/" . count($recipients) . "] Sending to $name ($recipientEmail)...\n";
        
        try {
            // Create email
            $email = (new Email())
                ->from('no-reply@technostationery.com')
                ->to($recipientEmail)
                ->subject('✅ Email System Test - ' . $name . ' - ' . date('Y-m-d H:i:s'))
                ->html('
                    <html>
                        <body style="font-family: Arial, sans-serif; color: #333;">
                            <h2 style="color: #4CAF50;">✅ Email System Test Successful!</h2>
                            <p>This is a test email from the Akeneo PIM notification system.</p>
                            
                            <table style="border-collapse: collapse; width: 100%; max-width: 600px; margin-top: 20px;">
                                <tr>
                                    <td style="padding: 10px; border: 1px solid #ddd; font-weight: bold;">Recipient:</td>
                                    <td style="padding: 10px; border: 1px solid #ddd;">' . $name . '</td>
                                </tr>
                                <tr>
                                    <td style="padding: 10px; border: 1px solid #ddd; font-weight: bold;">Email:</td>
                                    <td style="padding: 10px; border: 1px solid #ddd;">' . $recipientEmail . '</td>
                                </tr>
                                <tr>
                                    <td style="padding: 10px; border: 1px solid #ddd; font-weight: bold;">Test Date:</td>
                                    <td style="padding: 10px; border: 1px solid #ddd;">' . date('Y-m-d H:i:s') . '</td>
                                </tr>
                                <tr>
                                    <td style="padding: 10px; border: 1px solid #ddd; font-weight: bold;">Status:</td>
                                    <td style="padding: 10px; border: 1px solid #ddd; color: #4CAF50;"><strong>✓ OPERATIONAL</strong></td>
                                </tr>
                            </table>
                            
                            <p style="margin-top: 30px;">
                                <a href="https://pim.technostationery.com/user/login" 
                                   style="background-color: #4CAF50; color: white; padding: 10px 20px; text-decoration: none; border-radius: 5px;">
                                    Access PIM System
                                </a>
                            </p>
                            
                            <p style="color: #666; font-size: 12px; margin-top: 40px;">
                                This is an automated test email from Techno Stationery PIM system.<br>
                                If you received this email, your notification system is working correctly.
                            </p>
                        </body>
                    </html>
                ');
            
            // Send email
            $mailer->send($email);
            
            echo "  ✓ Sent successfully!\n\n";
            $successCount++;
            
        } catch (Exception $e) {
            echo "  ✗ Failed: " . $e->getMessage() . "\n\n";
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
        echo "\n💡 Also check spam/junk folders\n";
    }
    
    exit($failCount > 0 ? 1 : 0);
    
} catch (Exception $e) {
    echo "✗ Critical error: " . $e->getMessage() . "\n";
    exit(1);
}
