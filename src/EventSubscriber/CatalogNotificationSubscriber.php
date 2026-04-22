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
