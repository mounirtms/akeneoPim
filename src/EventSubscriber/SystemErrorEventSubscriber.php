<?php

namespace App\EventSubscriber;

use Symfony\Component\EventDispatcher\EventSubscriberInterface;
use Symfony\Component\HttpKernel\Event\ExceptionEvent;
use Symfony\Component\HttpKernel\KernelEvents;
use Symfony\Component\Mailer\MailerInterface;
use Symfony\Component\Mime\Email;
use Psr\Log\LoggerInterface;

class SystemErrorEventSubscriber implements EventSubscriberInterface
{
    private $mailer;
    private $logger;
    private $webmasterEmail = 'webmaster@techno-dz.com';
    private $environment;

    public function __construct(MailerInterface $mailer, LoggerInterface $logger, string $environment)
    {
        $this->mailer = $mailer;
        $this->logger = $logger;
        $this->environment = $environment;
    }

    public static function getSubscribedEvents(): array
    {
        return [
            KernelEvents::EXCEPTION => 'onKernelException',
        ];
    }

    public function onKernelException(ExceptionEvent $event): void
    {
        // Only send emails for production errors
        if ($this->environment !== 'prod') {
            return;
        }

        $exception = $event->getThrowable();
        
        // Only notify for critical errors (500 level)
        $statusCode = method_exists($exception, 'getStatusCode') ? $exception->getStatusCode() : 500;
        
        if ($statusCode >= 500) {
            try {
                $this->logger->critical(sprintf(
                    'Critical error: %s in %s:%d',
                    $exception->getMessage(),
                    $exception->getFile(),
                    $exception->getLine()
                ));

                // Send email notification to webmaster
                $email = (new Email())
                    ->from('no-reply@technostationery.com')
                    ->to($this->webmasterEmail)
                    ->priority(Email::PRIORITY_HIGH)
                    ->subject(sprintf('🚨 Critical Error on PIM: %s', $exception->getMessage()))
                    ->html($this->buildErrorEmailHtml($exception, $event->getRequest()));

                $this->mailer->send($email);
                
                $this->logger->info(sprintf('Critical error email sent to %s', $this->webmasterEmail));
            } catch (\Exception $e) {
                $this->logger->error(sprintf('Failed to send error notification email: %s', $e->getMessage()));
            }
        }
    }

    private function buildErrorEmailHtml(\Throwable $exception, $request): string
    {
        $errorClass = get_class($exception);
        $errorMessage = $exception->getMessage();
        $errorFile = $exception->getFile();
        $errorLine = $exception->getLine();
        $errorTrace = htmlspecialchars(substr($exception->getTraceAsString(), 0, 2000));
        $requestUri = method_exists($request, 'getRequestUri') ? $request->getRequestUri() : 'N/A';
        $requestMethod = method_exists($request, 'getMethod') ? $request->getMethod() : 'N/A';
        $userIp = method_exists($request, 'getClientIp') ? $request->getClientIp() : 'N/A';
        
        return sprintf('
            <html>
                <body style="font-family: Arial, sans-serif; color: #333;">
                    <h2 style="color: #f44336;">🚨 Critical System Error</h2>
                    <p>A critical error has occurred on the Akeneo PIM system.</p>
                    
                    <h3 style="color: #f44336;">Error Details</h3>
                    <table style="border-collapse: collapse; width: 100%%; max-width: 800px;">
                        <tr>
                            <td style="padding: 10px; border: 1px solid #ddd; font-weight: bold; width: 180px;">Exception Type:</td>
                            <td style="padding: 10px; border: 1px solid #ddd;">%s</td>
                        </tr>
                        <tr>
                            <td style="padding: 10px; border: 1px solid #ddd; font-weight: bold;">Message:</td>
                            <td style="padding: 10px; border: 1px solid #ddd; color: #f44336;">%s</td>
                        </tr>
                        <tr>
                            <td style="padding: 10px; border: 1px solid #ddd; font-weight: bold;">File:</td>
                            <td style="padding: 10px; border: 1px solid #ddd;">%s</td>
                        </tr>
                        <tr>
                            <td style="padding: 10px; border: 1px solid #ddd; font-weight: bold;">Line:</td>
                            <td style="padding: 10px; border: 1px solid #ddd;">%d</td>
                        </tr>
                        <tr>
                            <td style="padding: 10px; border: 1px solid #ddd; font-weight: bold;">Timestamp:</td>
                            <td style="padding: 10px; border: 1px solid #ddd;">%s</td>
                        </tr>
                    </table>
                    
                    <h3 style="color: #2196F3; margin-top: 30px;">Request Information</h3>
                    <table style="border-collapse: collapse; width: 100%%; max-width: 800px;">
                        <tr>
                            <td style="padding: 10px; border: 1px solid #ddd; font-weight: bold; width: 180px;">Request URI:</td>
                            <td style="padding: 10px; border: 1px solid #ddd;">%s</td>
                        </tr>
                        <tr>
                            <td style="padding: 10px; border: 1px solid #ddd; font-weight: bold;">Method:</td>
                            <td style="padding: 10px; border: 1px solid #ddd;">%s</td>
                        </tr>
                        <tr>
                            <td style="padding: 10px; border: 1px solid #ddd; font-weight: bold;">Client IP:</td>
                            <td style="padding: 10px; border: 1px solid #ddd;">%s</td>
                        </tr>
                    </table>
                    
                    <h3 style="color: #666; margin-top: 30px;">Stack Trace (First 2000 chars)</h3>
                    <pre style="background-color: #f5f5f5; padding: 15px; border: 1px solid #ddd; overflow-x: auto; font-size: 12px;">%s</pre>
                    
                    <p style="margin-top: 30px;">
                        <a href="https://pim.technostationery.com/user/login" 
                           style="background-color: #f44336; color: white; padding: 10px 20px; text-decoration: none; border-radius: 5px;">
                            Access PIM System
                        </a>
                    </p>
                    
                    <p style="color: #666; font-size: 12px; margin-top: 30px;">
                        This is an automated critical error notification from Techno Stationery PIM system.<br>
                        Please investigate and resolve this issue as soon as possible.
                    </p>
                </body>
            </html>
        ', $errorClass, htmlspecialchars($errorMessage), htmlspecialchars($errorFile), $errorLine, date('Y-m-d H:i:s'), 
           htmlspecialchars($requestUri), htmlspecialchars($requestMethod), htmlspecialchars($userIp), $errorTrace);
    }
}
