<?php

namespace App\EventSubscriber;

use Akeneo\Pim\Enrichment\Component\Product\Model\ProductModelInterface;
use Akeneo\Tool\Component\StorageUtils\Event\RemoveEvent;
use Akeneo\Tool\Component\StorageUtils\StorageEvents;
use Symfony\Component\EventDispatcher\EventSubscriberInterface;
use Symfony\Component\EventDispatcher\GenericEvent;
use Symfony\Component\Mailer\MailerInterface;
use Symfony\Component\Mime\Email;
use Psr\Log\LoggerInterface;

class ProductModelEventSubscriber implements EventSubscriberInterface
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
            StorageEvents::POST_SAVE => 'onProductModelSave',
            StorageEvents::POST_REMOVE => 'onProductModelRemove',
        ];
    }

    public function onProductModelSave(GenericEvent $event): void
    {
        $subject = $event->getSubject();
        
        if (!$subject instanceof ProductModelInterface) {
            return;
        }

        try {
            $isNewModel = $event->getArgument('is_new') ?? false;
            $modelCode = $subject->getCode();
            
            $action = $isNewModel ? 'created' : 'updated';
            $this->logger->info(sprintf('Product Model %s: %s', $action, $modelCode));

            // Send email notification to marketing team
            $email = (new Email())
                ->from('no-reply@technostationery.com')
                ->to($this->marketingEmail)
                ->subject(sprintf('Product Model %s: %s', ucfirst($action), $modelCode))
                ->html($this->buildProductModelEmailHtml($subject, $action));

            $this->mailer->send($email);
            
            $this->logger->info(sprintf('Email sent to %s for product model %s', $this->marketingEmail, $action));
        } catch (\Exception $e) {
            $this->logger->error(sprintf('Failed to send product model notification email: %s', $e->getMessage()));
        }
    }

    public function onProductModelRemove(RemoveEvent $event): void
    {
        $subject = $event->getSubject();
        
        if (!$subject instanceof ProductModelInterface) {
            return;
        }

        try {
            $modelCode = $subject->getCode();
            $this->logger->warning(sprintf('Product Model removed: %s', $modelCode));

            // Send email notification to marketing and webmaster
            $email = (new Email())
                ->from('no-reply@technostationery.com')
                ->to($this->marketingEmail)
                ->cc($this->webmasterEmail)
                ->subject(sprintf('Product Model Removed: %s', $modelCode))
                ->html($this->buildProductModelRemovalEmailHtml($subject));

            $this->mailer->send($email);
            
            $this->logger->info(sprintf('Product model removal email sent to %s and %s', $this->marketingEmail, $this->webmasterEmail));
        } catch (\Exception $e) {
            $this->logger->error(sprintf('Failed to send product model removal email: %s', $e->getMessage()));
        }
    }

    private function buildProductModelEmailHtml(ProductModelInterface $model, string $action): string
    {
        $code = $model->getCode();
        $family = $model->getFamilyVariant() ? $model->getFamilyVariant()->getFamily()->getCode() : 'N/A';
        $familyVariant = $model->getFamilyVariant() ? $model->getFamilyVariant()->getCode() : 'N/A';
        
        return sprintf('
            <html>
                <body style="font-family: Arial, sans-serif; color: #333;">
                    <h2 style="color: #9C27B0;">Product Model %s</h2>
                    <p>A product model has been %s in the Akeneo PIM system.</p>
                    <table style="border-collapse: collapse; width: 100%%; max-width: 600px;">
                        <tr>
                            <td style="padding: 10px; border: 1px solid #ddd; font-weight: bold;">Model Code:</td>
                            <td style="padding: 10px; border: 1px solid #ddd;">%s</td>
                        </tr>
                        <tr>
                            <td style="padding: 10px; border: 1px solid #ddd; font-weight: bold;">Family:</td>
                            <td style="padding: 10px; border: 1px solid #ddd;">%s</td>
                        </tr>
                        <tr>
                            <td style="padding: 10px; border: 1px solid #ddd; font-weight: bold;">Family Variant:</td>
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
                        <a href="https://pim.technostationery.com/enrich/product-model/%s" 
                           style="background-color: #9C27B0; color: white; padding: 10px 20px; text-decoration: none; border-radius: 5px;">
                            View Product Model in PIM
                        </a>
                    </p>
                    <p style="color: #666; font-size: 12px; margin-top: 30px;">
                        This is an automated notification from Techno Stationery PIM system.
                    </p>
                </body>
            </html>
        ', ucfirst($action), $action, $code, $family, $familyVariant, ucfirst($action), date('Y-m-d H:i:s'), urlencode($code));
    }

    private function buildProductModelRemovalEmailHtml(ProductModelInterface $model): string
    {
        $code = $model->getCode();
        $family = $model->getFamilyVariant() ? $model->getFamilyVariant()->getFamily()->getCode() : 'N/A';
        
        return sprintf('
            <html>
                <body style="font-family: Arial, sans-serif; color: #333;">
                    <h2 style="color: #f44336;">Product Model Removed</h2>
                    <p>A product model has been <strong>permanently removed</strong> from the Akeneo PIM system.</p>
                    <table style="border-collapse: collapse; width: 100%%; max-width: 600px;">
                        <tr>
                            <td style="padding: 10px; border: 1px solid #ddd; font-weight: bold;">Model Code:</td>
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
                        ⚠️ This product model has been removed and may affect variant products in the catalog.
                    </p>
                    <p style="color: #666; font-size: 12px; margin-top: 30px;">
                        This is an automated notification from Techno Stationery PIM system.
                    </p>
                </body>
            </html>
        ', $code, $family, date('Y-m-d H:i:s'));
    }
}
