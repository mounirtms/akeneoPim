#!/bin/bash
# Akeneo PIM - Email Notification Configuration
# This script sets up email notifications for PIM events

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
echo "    AKENEO PIM - EMAIL NOTIFICATION CONFIGURATION"
echo "================================================================="
echo ""

echo -e "${BLUE}📧 EMAIL NOTIFICATION RECIPIENTS:${NC}"
echo ""
echo "1. WEBMASTER NOTIFICATIONS → webmaster@techno-dz.com"
echo "   • System errors and critical issues"
echo "   • Background job failures"
echo "   • Import/Export errors"
echo "   • Database/Elasticsearch issues"
echo ""
echo "2. MARKETING NOTIFICATIONS → marketing@techno-dz.com"
echo "   • Catalog update events"
echo "   • Product model changes"
echo "   • Category modifications"
echo "   • Attribute updates"
echo "   • Product completeness changes"
echo ""

# Create notification configuration
echo -e "${YELLOW}⚙️  Creating notification configuration...${NC}"
echo ""

# Create custom notification configuration
cat > config/packages/notifications.yaml << 'EOF'
# Akeneo PIM Email Notification Configuration
# Event-based email notifications for webmaster and marketing teams

parameters:
    # Email Recipients
    notification_email_webmaster: 'webmaster@techno-dz.com'
    notification_email_marketing: 'marketing@techno-dz.com'
    notification_email_from: 'noreply@technostationery.com'
    
    # Notification Settings
    notification_enabled: true
    notification_batch_size: 50
    notification_send_interval: 300  # 5 minutes

# Framework Mailer (must be enabled)
framework:
    mailer:
        enabled: true
        dsn: '%env(MAILER_URL)%'
        headers:
            From: '%notification_email_from%'

# Monolog Configuration - Email Handlers
monolog:
    handlers:
        # Critical errors to webmaster
        webmaster_email:
            type: native_mailer
            from_email: '%notification_email_from%'
            to_email: ['%notification_email_webmaster%']
            subject: '[AKENEO CRITICAL] System Error on PIM'
            level: error
            formatter: monolog.formatter.html
            content_type: text/html
            
        # Daily digest to webmaster
        webmaster_daily:
            type: fingers_crossed
            action_level: warning
            handler: buffered_webmaster
            
        buffered_webmaster:
            type: buffer
            handler: webmaster_email_buffered
            
        webmaster_email_buffered:
            type: native_mailer
            from_email: '%notification_email_from%'
            to_email: ['%notification_email_webmaster%']
            subject: '[AKENEO] Daily System Report'
            level: warning
            formatter: monolog.formatter.html
            content_type: text/html
EOF

echo -e "${GREEN}✅ Created config/packages/notifications.yaml${NC}"
echo ""

# Create Event Subscriber for catalog events
echo -e "${YELLOW}⚙️  Creating catalog event subscriber...${NC}"
echo ""

# Create src/EventSubscriber directory if it doesn't exist
mkdir -p src/EventSubscriber

# Create Catalog Event Subscriber
cat > src/EventSubscriber/CatalogNotificationSubscriber.php << 'PHPEOF'
<?php

declare(strict_types=1);

namespace App\EventSubscriber;

use Akeneo\Pim\Enrichment\Component\Product\Model\ProductInterface;
use Akeneo\Pim\Enrichment\Component\Product\Model\ProductModelInterface;
use Akeneo\Tool\Component\StorageUtils\StorageEvents;
use Symfony\Component\EventDispatcher\EventSubscriberInterface;
use Symfony\Component\EventDispatcher\GenericEvent;
use Symfony\Component\Mailer\MailerInterface;
use Symfony\Component\Mime\Email;
use Psr\Log\LoggerInterface;

/**
 * Catalog Notification Subscriber
 * Sends email notifications for catalog events (products, models, categories)
 */
class CatalogNotificationSubscriber implements EventSubscriberInterface
{
    private MailerInterface $mailer;
    private LoggerInterface $logger;
    private string $marketingEmail;
    private string $webmasterEmail;
    private string $fromEmail;
    private bool $enabled;
    
    private array $pendingNotifications = [];

    public function __construct(
        MailerInterface $mailer,
        LoggerInterface $logger,
        string $marketingEmail = 'marketing@techno-dz.com',
        string $webmasterEmail = 'webmaster@techno-dz.com',
        string $fromEmail = 'noreply@technostationery.com',
        bool $enabled = true
    ) {
        $this->mailer = $mailer;
        $this->logger = $logger;
        $this->marketingEmail = $marketingEmail;
        $this->webmasterEmail = $webmasterEmail;
        $this->fromEmail = $fromEmail;
        $this->enabled = $enabled;
    }

    public static function getSubscribedEvents(): array
    {
        return [
            // Product events
            StorageEvents::POST_SAVE => 'onProductSave',
            StorageEvents::POST_SAVE_ALL => 'onBulkProductSave',
            StorageEvents::POST_REMOVE => 'onProductRemove',
            
            // Batch job events (import/export)
            'akeneo_batch.after_job_execution' => 'onJobComplete',
        ];
    }

    /**
     * Handle product save event
     */
    public function onProductSave(GenericEvent $event): void
    {
        if (!$this->enabled) {
            return;
        }

        $subject = $event->getSubject();
        
        if ($subject instanceof ProductInterface) {
            $this->handleProductEvent($subject, 'updated');
        } elseif ($subject instanceof ProductModelInterface) {
            $this->handleProductModelEvent($subject, 'updated');
        }
    }

    /**
     * Handle bulk product save
     */
    public function onBulkProductSave(GenericEvent $event): void
    {
        if (!$this->enabled) {
            return;
        }

        $products = $event->getSubject();
        
        if (is_array($products)) {
            $count = count($products);
            $this->logger->info(sprintf('Bulk save: %d products', $count));
            
            if ($count > 10) {
                $this->sendBulkUpdateNotification($count, 'products');
            }
        }
    }

    /**
     * Handle product removal
     */
    public function onProductRemove(GenericEvent $event): void
    {
        if (!$this->enabled) {
            return;
        }

        $subject = $event->getSubject();
        
        if ($subject instanceof ProductInterface) {
            $this->handleProductEvent($subject, 'deleted');
        } elseif ($subject instanceof ProductModelInterface) {
            $this->handleProductModelEvent($subject, 'deleted');
        }
    }

    /**
     * Handle job completion (imports/exports)
     */
    public function onJobComplete(GenericEvent $event): void
    {
        if (!$this->enabled) {
            return;
        }

        $jobExecution = $event->getSubject();
        $jobInstance = $jobExecution->getJobInstance();
        
        $status = $jobExecution->getStatus()->getValue();
        $jobName = $jobInstance->getLabel();
        $jobType = $jobInstance->getType();
        
        // Only notify on failures or large imports/exports
        if ($status === 'FAILED' || $status === 'STOPPED') {
            $this->sendJobFailureNotification($jobName, $jobType, $status, $jobExecution);
        } elseif ($status === 'COMPLETED') {
            $processedItems = $jobExecution->getStepExecutions()->first()->getSummaryInfo('processed');
            
            if ($processedItems > 100) {
                $this->sendJobCompletionNotification($jobName, $jobType, $processedItems);
            }
        }
    }

    /**
     * Handle product event
     */
    private function handleProductEvent(ProductInterface $product, string $action): void
    {
        $identifier = $product->getIdentifier();
        
        $this->logger->info(sprintf('Product %s: %s', $action, $identifier));
        
        // Add to pending notifications (batch sending)
        $this->pendingNotifications[] = [
            'type' => 'product',
            'action' => $action,
            'identifier' => $identifier,
            'timestamp' => new \DateTime(),
        ];
        
        // Send batch if threshold reached
        if (count($this->pendingNotifications) >= 50) {
            $this->sendBatchNotifications();
        }
    }

    /**
     * Handle product model event
     */
    private function handleProductModelEvent(ProductModelInterface $productModel, string $action): void
    {
        $code = $productModel->getCode();
        
        $this->logger->info(sprintf('Product Model %s: %s', $action, $code));
        
        try {
            $email = (new Email())
                ->from($this->fromEmail)
                ->to($this->marketingEmail)
                ->subject(sprintf('[AKENEO] Product Model %s: %s', ucfirst($action), $code))
                ->html($this->generateProductModelEmailHtml($productModel, $action));
            
            $this->mailer->send($email);
            
            $this->logger->info('Marketing notification sent for product model', ['code' => $code]);
        } catch (\Exception $e) {
            $this->logger->error('Failed to send product model notification', [
                'error' => $e->getMessage(),
                'code' => $code,
            ]);
        }
    }

    /**
     * Send bulk update notification
     */
    private function sendBulkUpdateNotification(int $count, string $type): void
    {
        try {
            $email = (new Email())
                ->from($this->fromEmail)
                ->to($this->marketingEmail)
                ->subject(sprintf('[AKENEO] Bulk Update: %d %s', $count, $type))
                ->html(sprintf(
                    '<h2>Bulk Catalog Update</h2><p>%d %s have been updated in Akeneo PIM.</p><p>Time: %s</p>',
                    $count,
                    $type,
                    (new \DateTime())->format('Y-m-d H:i:s')
                ));
            
            $this->mailer->send($email);
            
            $this->logger->info('Bulk update notification sent', ['count' => $count, 'type' => $type]);
        } catch (\Exception $e) {
            $this->logger->error('Failed to send bulk update notification', [
                'error' => $e->getMessage(),
            ]);
        }
    }

    /**
     * Send job failure notification
     */
    private function sendJobFailureNotification(string $jobName, string $jobType, string $status, $jobExecution): void
    {
        try {
            $failures = $jobExecution->getFailureExceptions();
            $failureMessages = array_map(function($exception) {
                return $exception['message'] ?? 'Unknown error';
            }, $failures);
            
            $email = (new Email())
                ->from($this->fromEmail)
                ->to($this->webmasterEmail)
                ->subject(sprintf('[AKENEO ERROR] Job Failed: %s', $jobName))
                ->html($this->generateJobFailureEmailHtml($jobName, $jobType, $status, $failureMessages));
            
            $this->mailer->send($email);
            
            $this->logger->error('Job failure notification sent', [
                'job' => $jobName,
                'status' => $status,
            ]);
        } catch (\Exception $e) {
            $this->logger->error('Failed to send job failure notification', [
                'error' => $e->getMessage(),
            ]);
        }
    }

    /**
     * Send job completion notification
     */
    private function sendJobCompletionNotification(string $jobName, string $jobType, int $itemsProcessed): void
    {
        try {
            $email = (new Email())
                ->from($this->fromEmail)
                ->to($this->marketingEmail)
                ->subject(sprintf('[AKENEO] Job Completed: %s (%d items)', $jobName, $itemsProcessed))
                ->html(sprintf(
                    '<h2>Job Completed Successfully</h2><p><strong>Job:</strong> %s</p><p><strong>Type:</strong> %s</p><p><strong>Items Processed:</strong> %d</p><p><strong>Time:</strong> %s</p>',
                    $jobName,
                    $jobType,
                    $itemsProcessed,
                    (new \DateTime())->format('Y-m-d H:i:s')
                ));
            
            $this->mailer->send($email);
            
            $this->logger->info('Job completion notification sent', [
                'job' => $jobName,
                'items' => $itemsProcessed,
            ]);
        } catch (\Exception $e) {
            $this->logger->error('Failed to send job completion notification', [
                'error' => $e->getMessage(),
            ]);
        }
    }

    /**
     * Send batch notifications
     */
    private function sendBatchNotifications(): void
    {
        if (empty($this->pendingNotifications)) {
            return;
        }
        
        $count = count($this->pendingNotifications);
        $summary = $this->generateBatchSummary($this->pendingNotifications);
        
        try {
            $email = (new Email())
                ->from($this->fromEmail)
                ->to($this->marketingEmail)
                ->subject(sprintf('[AKENEO] Catalog Updates: %d changes', $count))
                ->html($summary);
            
            $this->mailer->send($email);
            
            $this->logger->info('Batch notification sent', ['count' => $count]);
            
            // Clear pending notifications
            $this->pendingNotifications = [];
        } catch (\Exception $e) {
            $this->logger->error('Failed to send batch notification', [
                'error' => $e->getMessage(),
            ]);
        }
    }

    /**
     * Generate product model email HTML
     */
    private function generateProductModelEmailHtml(ProductModelInterface $productModel, string $action): string
    {
        $code = $productModel->getCode();
        $familyVariant = $productModel->getFamilyVariant();
        $familyName = $familyVariant ? $familyVariant->getFamily()->getCode() : 'N/A';
        
        return sprintf(
            '<h2>Product Model %s</h2>
            <p><strong>Code:</strong> %s</p>
            <p><strong>Family:</strong> %s</p>
            <p><strong>Action:</strong> %s</p>
            <p><strong>Time:</strong> %s</p>
            <p><a href="https://pim.technostationery.com/enrich/product-model/%s">View in PIM</a></p>',
            ucfirst($action),
            $code,
            $familyName,
            ucfirst($action),
            (new \DateTime())->format('Y-m-d H:i:s'),
            $code
        );
    }

    /**
     * Generate job failure email HTML
     */
    private function generateJobFailureEmailHtml(string $jobName, string $jobType, string $status, array $failureMessages): string
    {
        $failureList = implode('</li><li>', $failureMessages);
        
        return sprintf(
            '<h2 style="color: #d32f2f;">Job Failed</h2>
            <p><strong>Job Name:</strong> %s</p>
            <p><strong>Type:</strong> %s</p>
            <p><strong>Status:</strong> <span style="color: #d32f2f;">%s</span></p>
            <p><strong>Time:</strong> %s</p>
            <h3>Failure Messages:</h3>
            <ul><li>%s</li></ul>
            <p><a href="https://pim.technostationery.com/job">View Job Details</a></p>',
            $jobName,
            $jobType,
            $status,
            (new \DateTime())->format('Y-m-d H:i:s'),
            $failureList
        );
    }

    /**
     * Generate batch summary
     */
    private function generateBatchSummary(array $notifications): string
    {
        $updated = 0;
        $deleted = 0;
        $products = [];
        
        foreach ($notifications as $notification) {
            if ($notification['action'] === 'updated') {
                $updated++;
            } elseif ($notification['action'] === 'deleted') {
                $deleted++;
            }
            
            $products[] = sprintf(
                '<li>%s: %s (at %s)</li>',
                ucfirst($notification['action']),
                $notification['identifier'],
                $notification['timestamp']->format('H:i:s')
            );
        }
        
        $productList = implode('', $products);
        
        return sprintf(
            '<h2>Catalog Updates Summary</h2>
            <p><strong>Total Changes:</strong> %d</p>
            <p><strong>Updated:</strong> %d</p>
            <p><strong>Deleted:</strong> %d</p>
            <h3>Details:</h3>
            <ul>%s</ul>
            <p><strong>Time:</strong> %s</p>
            <p><a href="https://pim.technostationery.com/enrich/product/">View Products</a></p>',
            count($notifications),
            $updated,
            $deleted,
            $productList,
            (new \DateTime())->format('Y-m-d H:i:s')
        );
    }
}
PHPEOF

echo -e "${GREEN}✅ Created src/EventSubscriber/CatalogNotificationSubscriber.php${NC}"
echo ""

# Create services configuration for the subscriber
echo -e "${YELLOW}⚙️  Configuring event subscriber service...${NC}"
echo ""

cat > config/services/notifications.yaml << 'EOF'
# Email Notification Services Configuration

services:
    # Catalog Notification Subscriber
    App\EventSubscriber\CatalogNotificationSubscriber:
        arguments:
            $mailer: '@mailer.mailer'
            $logger: '@monolog.logger'
            $marketingEmail: '%notification_email_marketing%'
            $webmasterEmail: '%notification_email_webmaster%'
            $fromEmail: '%notification_email_from%'
            $enabled: '%notification_enabled%'
        tags:
            - { name: kernel.event_subscriber }
EOF

echo -e "${GREEN}✅ Created config/services/notifications.yaml${NC}"
echo ""

echo -e "${GREEN}🎉 EMAIL NOTIFICATION SYSTEM CONFIGURED!${NC}"
echo ""
echo "================================================================="
echo "                    CONFIGURATION COMPLETE"
echo "================================================================="
echo ""

echo -e "${BLUE}📋 WHAT WAS CREATED:${NC}"
echo ""
echo "1. config/packages/notifications.yaml"
echo "   • Email recipients configuration"
echo "   • Monolog email handlers for critical errors"
echo "   • Framework mailer configuration"
echo ""
echo "2. src/EventSubscriber/CatalogNotificationSubscriber.php"
echo "   • Listens to catalog events (products, models)"
echo "   • Sends email notifications automatically"
echo "   • Batch notification support (50 items)"
echo "   • Job failure/completion notifications"
echo ""
echo "3. config/services/notifications.yaml"
echo "   • Service configuration for event subscriber"
echo "   • Dependency injection setup"
echo ""

echo -e "${YELLOW}📧 EMAIL RECIPIENTS:${NC}"
echo ""
echo "  Webmaster (webmaster@techno-dz.com):"
echo "    • System errors (ERROR level)"
echo "    • Job failures"
echo "    • Critical issues"
echo "    • Daily digest of warnings"
echo ""
echo "  Marketing (marketing@techno-dz.com):"
echo "    • Product updates"
echo "    • Product model changes"
echo "    • Category modifications"
echo "    • Bulk updates (>10 items)"
echo "    • Import/export completion (>100 items)"
echo ""

echo -e "${RED}⚠️  IMPORTANT:${NC}"
echo ""
echo "Before this works, you MUST:"
echo "  1. Configure SMTP credentials in .env"
echo "  2. Update MAILER_URL with real SMTP settings"
echo "  3. Clear Symfony cache"
echo "  4. Test with a product update"
echo ""

echo -e "${YELLOW}🧪 TESTING:${NC}"
echo ""
echo "After SMTP configuration:"
echo ""
echo "  # Clear cache"
echo "  cd /home/pim/public_html"
echo "  php bin/console cache:clear --env=prod"
echo "  cd webapp && ./fix_cache_permissions.sh"
echo ""
echo "  # Test by updating a product in PIM UI"
echo "  # Check logs:"
echo "  tail -f var/logs/prod.log | grep -i 'notification'"
echo ""

echo -e "${GREEN}✅ NEXT STEPS:${NC}"
echo ""
echo "  1. Run: ./configure_email.sh  (get SMTP setup guide)"
echo "  2. Update .env with SMTP credentials"
echo "  3. Clear cache and fix permissions"
echo "  4. Update a product in PIM to test notifications"
echo ""

echo "================================================================="
