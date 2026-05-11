<?php

namespace AppBundle\EventListener;

use Symfony\Component\EventDispatcher\EventSubscriberInterface;
use Symfony\Component\HttpKernel\Event\ResponseEvent;
use Symfony\Component\HttpKernel\KernelEvents;

/**
 * High-priority listener to remove CSP headers after they're set
 */
class RemoveCspListener implements EventSubscriberInterface
{
    public static function getSubscribedEvents(): array
    {
        // Use very low priority (-1000) to run after CSP listener (priority 0)
        return [
            KernelEvents::RESPONSE => ['removeCspHeaders', -1000],
        ];
    }

    public function removeCspHeaders(ResponseEvent $event): void
    {
        if (!$event->isMainRequest()) {
            return;
        }

        $response = $event->getResponse();
        
        // Remove all CSP headers
        $response->headers->remove('Content-Security-Policy');
        $response->headers->remove('X-Content-Security-Policy');
        $response->headers->remove('X-WebKit-CSP');
        
        // Log for debugging
        error_log('RemoveCspListener: CSP headers removed - ' . date('Y-m-d H:i:s'));
    }
}
