<?php

namespace App\EventSubscriber;

use Akeneo\Pim\Enrichment\Component\Product\Model\ProductInterface;
use Akeneo\Tool\Component\StorageUtils\Event\RemoveEvent;
use Akeneo\Tool\Component\StorageUtils\StorageEvents;
use Symfony\Component\EventDispatcher\EventSubscriberInterface;
use Symfony\Component\EventDispatcher\GenericEvent;
use Symfony\Component\Mailer\MailerInterface;
use Symfony\Component\Mime\Email;
use Psr\Log\LoggerInterface;

class ProductEventSubscriber implements EventSubscriberInterface
{
    private $mailer;
    private $logger;
    private $marketingEmail = 'marketing@techno-dz.com';
    private $webmasterEmail = 'webmaster@techno-dz.com';

    public function __construct(MailerInterface $mailer, LoggerInterface $logger)
    {
        $this->mailer = $mailer;
        $this->logger = $logger;
    }

    public static function getSubscribedEvents(): array
    {
        return [
            StorageEvents::POST_SAVE => 'onProductSave',
            StorageEvents::POST_REMOVE => 'onProductRemove',
            StorageEvents::POST_SAVE_ALL => 'onProductBulkSave',
        ];
    }

    public function onProductSave(GenericEvent $event): void
    {
        $subject = $event->getSubject();
        
        if (!$subject instanceof ProductInterface) {
            return;
        }

        try {
            $isNewProduct = $event->getArgument('is_new');
            $productIdentifier = $subject->getIdentifier();
            
            $action = $isNewProduct ? 'created' : 'updated';
            $this->logger->info(sprintf('Product %s: %s', $action, $productIdentifier));

            // Send email notification to marketing team
            $email = (new Email())
                ->from('no-reply@technostationery.com')
                ->to($this->marketingEmail)
                ->subject(sprintf('Product %s: %s', ucfirst($action), $productIdentifier))
                ->html($this->buildProductEmailHtml($subject, $action));

            $this->mailer->send($email);
            
            $this->logger->info(sprintf('Email sent to %s for product %s', $this->marketingEmail, $action));
        } catch (\Exception $e) {
            $this->logger->error(sprintf('Failed to send product notification email: %s', $e->getMessage()));
        }
    }

    public function onProductRemove(RemoveEvent $event): void
    {
        $subject = $event->getSubject();
        
        if (!$subject instanceof ProductInterface) {
            return;
        }

        try {
            $productIdentifier = $subject->getIdentifier();
            $this->logger->warning(sprintf('Product removed: %s', $productIdentifier));

            // Send email notification to marketing team
            $email = (new Email())
                ->from('no-reply@technostationery.com')
                ->to($this->marketingEmail)
                ->cc($this->webmasterEmail)
                ->subject(sprintf('Product Removed: %s', $productIdentifier))
                ->html($this->buildProductRemovalEmailHtml($subject));

            $this->mailer->send($email);
            
            $this->logger->info(sprintf('Product removal email sent to %s and %s', $this->marketingEmail, $this->webmasterEmail));
        } catch (\Exception $e) {
            $this->logger->error(sprintf('Failed to send product removal email: %s', $e->getMessage()));
        }
    }

    public function onProductBulkSave(GenericEvent $event): void
    {
        try {
            $products = $event->getSubject();
            $count = is_countable($products) ? count($products) : 0;
            
            $this->logger->info(sprintf('Bulk product save: %d products', $count));

            if ($count >= 10) {
                // Only send email for significant bulk operations
                $email = (new Email())
                    ->from('no-reply@technostationery.com')
                    ->to($this->marketingEmail)
                    ->subject(sprintf('Bulk Product Update: %d products', $count))
                    ->html($this->buildBulkUpdateEmailHtml($count));

                $this->mailer->send($email);
                
                $this->logger->info(sprintf('Bulk update email sent to %s', $this->marketingEmail));
            }
        } catch (\Exception $e) {
            $this->logger->error(sprintf('Failed to send bulk update email: %s', $e->getMessage()));
        }
    }

    private function buildProductEmailHtml(ProductInterface $product, string $action): string
    {
        $identifier = $product->getIdentifier();
        $family = $product->getFamily() ? $product->getFamily()->getCode() : 'N/A';
        $enabled = $product->isEnabled() ? 'Yes' : 'No';
        
        return sprintf('
            <html>
                <body style="font-family: Arial, sans-serif; color: #333;">
                    <h2 style="color: #4CAF50;">Product %s</h2>
                    <p>A product has been %s in the Akeneo PIM system.</p>
                    <table style="border-collapse: collapse; width: 100%%; max-width: 600px;">
                        <tr>
                            <td style="padding: 10px; border: 1px solid #ddd; font-weight: bold;">Product Identifier:</td>
                            <td style="padding: 10px; border: 1px solid #ddd;">%s</td>
                        </tr>
                        <tr>
                            <td style="padding: 10px; border: 1px solid #ddd; font-weight: bold;">Family:</td>
                            <td style="padding: 10px; border: 1px solid #ddd;">%s</td>
                        </tr>
                        <tr>
                            <td style="padding: 10px; border: 1px solid #ddd; font-weight: bold;">Enabled:</td>
                            <td style="padding: 10px; border: 1px solid #ddd;">%s</td>
                        </tr>
                        <tr>
                            <td style="padding: 10px; border: 1px solid #ddd; font-weight: bold;">Action:</td>
                            <td style="padding: 10px; border: 1px solid #ddd;">%s</td>
                        </tr>
                        <tr>
                            <td style="padding: 10px; border: 1px solid #ddd; font-weight: bold;">Timestamp:</td>
                            <td style="padding: 10px; border: 1px solid #ddd;">%s</td>
                        </tr>
                    </table>
                    <p style="margin-top: 20px;">
                        <a href="https://pim.technostationery.com/enrich/product/%s" 
                           style="background-color: #4CAF50; color: white; padding: 10px 20px; text-decoration: none; border-radius: 5px;">
                            View Product in PIM
                        </a>
                    </p>
                    <p style="color: #666; font-size: 12px; margin-top: 30px;">
                        This is an automated notification from Techno Stationery PIM system.
                    </p>
                </body>
            </html>
        ', ucfirst($action), $action, $identifier, $family, $enabled, ucfirst($action), date('Y-m-d H:i:s'), urlencode($identifier));
    }

    private function buildProductRemovalEmailHtml(ProductInterface $product): string
    {
        $identifier = $product->getIdentifier();
        $family = $product->getFamily() ? $product->getFamily()->getCode() : 'N/A';
        
        return sprintf('
            <html>
                <body style="font-family: Arial, sans-serif; color: #333;">
                    <h2 style="color: #f44336;">Product Removed</h2>
                    <p>A product has been <strong>permanently removed</strong> from the Akeneo PIM system.</p>
                    <table style="border-collapse: collapse; width: 100%%; max-width: 600px;">
                        <tr>
                            <td style="padding: 10px; border: 1px solid #ddd; font-weight: bold;">Product Identifier:</td>
                            <td style="padding: 10px; border: 1px solid #ddd;">%s</td>
                        </tr>
                        <tr>
                            <td style="padding: 10px; border: 1px solid #ddd; font-weight: bold;">Family:</td>
                            <td style="padding: 10px; border: 1px solid #ddd;">%s</td>
                        </tr>
                        <tr>
                            <td style="padding: 10px; border: 1px solid #ddd; font-weight: bold;">Timestamp:</td>
                            <td style="padding: 10px; border: 1px solid #ddd;">%s</td>
                        </tr>
                    </table>
                    <p style="color: #f44336; font-weight: bold; margin-top: 20px;">
                        ⚠️ This product has been removed and may need to be synced with Magento.
                    </p>
                    <p style="color: #666; font-size: 12px; margin-top: 30px;">
                        This is an automated notification from Techno Stationery PIM system.
                    </p>
                </body>
            </html>
        ', $identifier, $family, date('Y-m-d H:i:s'));
    }

    private function buildBulkUpdateEmailHtml(int $count): string
    {
        return sprintf('
            <html>
                <body style="font-family: Arial, sans-serif; color: #333;">
                    <h2 style="color: #2196F3;">Bulk Product Update</h2>
                    <p>A bulk operation has been performed on the product catalog.</p>
                    <table style="border-collapse: collapse; width: 100%%; max-width: 600px;">
                        <tr>
                            <td style="padding: 10px; border: 1px solid #ddd; font-weight: bold;">Number of Products:</td>
                            <td style="padding: 10px; border: 1px solid #ddd;">%d</td>
                        </tr>
                        <tr>
                            <td style="padding: 10px; border: 1px solid #ddd; font-weight: bold;">Timestamp:</td>
                            <td style="padding: 10px; border: 1px solid #ddd;">%s</td>
                        </tr>
                    </table>
                    <p style="margin-top: 20px;">
                        <a href="https://pim.technostationery.com/enrich/product/" 
                           style="background-color: #2196F3; color: white; padding: 10px 20px; text-decoration: none; border-radius: 5px;">
                            View Products in PIM
                        </a>
                    </p>
                    <p style="color: #666; font-size: 12px; margin-top: 30px;">
                        This is an automated notification from Techno Stationery PIM system.
                    </p>
                </body>
            </html>
        ', $count, date('Y-m-d H:i:s'));
    }
}
