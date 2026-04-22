<?php

namespace App\EventSubscriber;

use Akeneo\Pim\Enrichment\Component\Category\Model\CategoryInterface;
use Akeneo\Tool\Component\StorageUtils\Event\RemoveEvent;
use Akeneo\Tool\Component\StorageUtils\StorageEvents;
use Symfony\Component\EventDispatcher\EventSubscriberInterface;
use Symfony\Component\EventDispatcher\GenericEvent;
use Symfony\Component\Mailer\MailerInterface;
use Symfony\Component\Mime\Email;
use Psr\Log\LoggerInterface;

class CategoryEventSubscriber implements EventSubscriberInterface
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
            StorageEvents::POST_SAVE => 'onCategorySave',
            StorageEvents::POST_REMOVE => 'onCategoryRemove',
        ];
    }

    public function onCategorySave(GenericEvent $event): void
    {
        $subject = $event->getSubject();
        
        if (!$subject instanceof CategoryInterface) {
            return;
        }

        try {
            $isNewCategory = $event->getArgument('is_new') ?? false;
            $categoryCode = $subject->getCode();
            
            $action = $isNewCategory ? 'created' : 'updated';
            $this->logger->info(sprintf('Category %s: %s', $action, $categoryCode));

            // Send email notification to marketing team
            $email = (new Email())
                ->from('no-reply@technostationery.com')
                ->to($this->marketingEmail)
                ->subject(sprintf('Category %s: %s', ucfirst($action), $categoryCode))
                ->html($this->buildCategoryEmailHtml($subject, $action));

            $this->mailer->send($email);
            
            $this->logger->info(sprintf('Email sent to %s for category %s', $this->marketingEmail, $action));
        } catch (\Exception $e) {
            $this->logger->error(sprintf('Failed to send category notification email: %s', $e->getMessage()));
        }
    }

    public function onCategoryRemove(RemoveEvent $event): void
    {
        $subject = $event->getSubject();
        
        if (!$subject instanceof CategoryInterface) {
            return;
        }

        try {
            $categoryCode = $subject->getCode();
            $this->logger->warning(sprintf('Category removed: %s', $categoryCode));

            // Send email notification to marketing and webmaster
            $email = (new Email())
                ->from('no-reply@technostationery.com')
                ->to($this->marketingEmail)
                ->cc($this->webmasterEmail)
                ->subject(sprintf('Category Removed: %s', $categoryCode))
                ->html($this->buildCategoryRemovalEmailHtml($subject));

            $this->mailer->send($email);
            
            $this->logger->info(sprintf('Category removal email sent to %s and %s', $this->marketingEmail, $this->webmasterEmail));
        } catch (\Exception $e) {
            $this->logger->error(sprintf('Failed to send category removal email: %s', $e->getMessage()));
        }
    }

    private function buildCategoryEmailHtml(CategoryInterface $category, string $action): string
    {
        $code = $category->getCode();
        $label = method_exists($category, 'getLabel') ? $category->getLabel() : $code;
        $parent = $category->getParent() ? $category->getParent()->getCode() : 'Root';
        
        return sprintf('
            <html>
                <body style="font-family: Arial, sans-serif; color: #333;">
                    <h2 style="color: #FF9800;">Category %s</h2>
                    <p>A category has been %s in the Akeneo PIM system.</p>
                    <table style="border-collapse: collapse; width: 100%%; max-width: 600px;">
                        <tr>
                            <td style="padding: 10px; border: 1px solid #ddd; font-weight: bold;">Category Code:</td>
                            <td style="padding: 10px; border: 1px solid #ddd;">%s</td>
                        </tr>
                        <tr>
                            <td style="padding: 10px; border: 1px solid #ddd; font-weight: bold;">Label:</td>
                            <td style="padding: 10px; border: 1px solid #ddd;">%s</td>
                        </tr>
                        <tr>
                            <td style="padding: 10px; border: 1px solid #ddd; font-weight: bold;">Parent Category:</td>
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
                        <a href="https://pim.technostationery.com/#/enrich/category-tree/edit/%s" 
                           style="background-color: #FF9800; color: white; padding: 10px 20px; text-decoration: none; border-radius: 5px;">
                            View Category in PIM
                        </a>
                    </p>
                    <p style="color: #666; font-size: 12px; margin-top: 30px;">
                        This is an automated notification from Techno Stationery PIM system.
                    </p>
                </body>
            </html>
        ', ucfirst($action), $action, $code, $label, $parent, ucfirst($action), date('Y-m-d H:i:s'), urlencode($code));
    }

    private function buildCategoryRemovalEmailHtml(CategoryInterface $category): string
    {
        $code = $category->getCode();
        $label = method_exists($category, 'getLabel') ? $category->getLabel() : $code;
        
        return sprintf('
            <html>
                <body style="font-family: Arial, sans-serif; color: #333;">
                    <h2 style="color: #f44336;">Category Removed</h2>
                    <p>A category has been <strong>permanently removed</strong> from the Akeneo PIM system.</p>
                    <table style="border-collapse: collapse; width: 100%%; max-width: 600px;">
                        <tr>
                            <td style="padding: 10px; border: 1px solid #ddd; font-weight: bold;">Category Code:</td>
                            <td style="padding: 10px; border: 1px solid #ddd;">%s</td>
                        </tr>
                        <tr>
                            <td style="padding: 10px; border: 1px solid #ddd; font-weight: bold;">Label:</td>
                            <td style="padding: 10px; border: 1px solid #ddd;">%s</td>
                        </tr>
                        <tr>
                            <td style="padding: 10px; border: 1px solid #ddd; font-weight: bold;">Timestamp:</td>
                            <td style="padding: 10px; border: 1px solid #ddd;">%s</td>
                        </tr>
                    </table>
                    <p style="color: #f44336; font-weight: bold; margin-top: 20px;">
                        ⚠️ This category has been removed and may affect product categorization in Magento.
                    </p>
                    <p style="color: #666; font-size: 12px; margin-top: 30px;">
                        This is an automated notification from Techno Stationery PIM system.
                    </p>
                </body>
            </html>
        ', $code, $label, date('Y-m-d H:i:s'));
    }
}
