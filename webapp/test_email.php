#!/usr/bin/env php
<?php
/**
 * Test Email Sending from Akeneo PIM
 * 
 * This script tests email configuration and sends test emails
 * to webmaster@techno-dz.com and marketting@techno-dz.com
 */

require __DIR__ . '/../vendor/autoload.php';

use Symfony\Component\Dotenv\Dotenv;
use Symfony\Component\Mime\Email;
use Symfony\Component\Mailer\Mailer;
use Symfony\Component\Mailer\Transport;

// Load environment
$dotenv = new Dotenv();
$dotenv->load(__DIR__ . '/../.env');
if (file_exists(__DIR__ . '/../.env.local')) {
    $dotenv->load(__DIR__ . '/../.env.local');
}

// Get mailer URL from environment
$mailerUrl = $_ENV['MAILER_URL'] ?? 'sendmail://default';

echo "========================================\n";
echo "Akeneo PIM - Email Test\n";
echo "========================================\n\n";

echo "Configuration:\n";
echo "  Mailer URL: $mailerUrl\n";
echo "  Environment: " . ($_ENV['APP_ENV'] ?? 'unknown') . "\n\n";

try {
    // Create transport
    $transport = Transport::fromDsn($mailerUrl);
    $mailer = new Mailer($transport);
    
    echo "✅ Transport created successfully\n\n";
    
    // Test Email 1: Webmaster
    echo "Sending test email to webmaster@techno-dz.com...\n";
    
    $email1 = (new Email())
        ->from('noreply@technostationery.com')
        ->to('webmaster@techno-dz.com')
        ->subject('[Akeneo PIM] Test Email - System Notification')
        ->html('
            <h2>Akeneo PIM Email Test</h2>
            <p>This is a test email from your Akeneo PIM system.</p>
            <p><strong>Purpose:</strong> Technical system notifications</p>
            <p><strong>Sent:</strong> ' . date('Y-m-d H:i:s') . '</p>
            <hr>
            <p><strong>Configuration:</strong></p>
            <ul>
                <li>PIM URL: https://pim.technostationery.com</li>
                <li>Products: 9,538</li>
                <li>Currency: DZD (Algerian Dinar)</li>
                <li>Locale: French (fr_FR)</li>
            </ul>
            <p><em>If you received this email, the Akeneo email system is working correctly.</em></p>
        ');
    
    $mailer->send($email1);
    echo "✅ Email sent to webmaster@techno-dz.com\n\n";
    
    // Test Email 2: Marketing
    echo "Sending test email to marketting@techno-dz.com...\n";
    
    $email2 = (new Email())
        ->from('noreply@technostationery.com')
        ->to('marketting@techno-dz.com')
        ->subject('[Akeneo PIM] Test Email - Product Data Progress')
        ->html('
            <h2>Akeneo PIM Email Test</h2>
            <p>This is a test email from your Akeneo PIM system.</p>
            <p><strong>Purpose:</strong> Product data and enrichment progress notifications</p>
            <p><strong>Sent:</strong> ' . date('Y-m-d H:i:s') . '</p>
            <hr>
            <p><strong>Current Catalog Status:</strong></p>
            <ul>
                <li>Total Products: 9,538</li>
                <li>Products with Prices: 9,538 (100%)</li>
                <li>Products with Categories: 9,538 (100%)</li>
                <li>Products with Names (fr_FR): 8,880 (93.1%)</li>
                <li>Products with Descriptions: 9,163 (96.1%)</li>
            </ul>
            <p><strong>Quality Score:</strong> 99.5/100 ✅</p>
            <p><em>If you received this email, you will receive product enrichment notifications.</em></p>
        ');
    
    $mailer->send($email2);
    echo "✅ Email sent to marketting@techno-dz.com\n\n";
    
    echo "========================================\n";
    echo "✅ All test emails sent successfully!\n";
    echo "========================================\n\n";
    
    echo "Next steps:\n";
    echo "1. Check inbox for both email addresses\n";
    echo "2. Verify emails were received\n";
    echo "3. Configure Akeneo event subscriptions\n";
    echo "4. Setup automated notifications\n\n";
    
    exit(0);
    
} catch (\Exception $e) {
    echo "❌ ERROR: " . $e->getMessage() . "\n\n";
    echo "Troubleshooting:\n";
    echo "1. Check MAILER_URL in .env.local\n";
    echo "2. Verify SMTP service is running: service postfix status\n";
    echo "3. Check firewall allows port 25\n";
    echo "4. Review mail logs: tail -f /var/log/maillog\n\n";
    
    exit(1);
}
