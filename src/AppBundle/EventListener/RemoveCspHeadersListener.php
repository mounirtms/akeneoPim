<?php

namespace AppBundle\EventListener;

use Symfony\Component\EventDispatcher\EventSubscriberInterface;
use Symfony\Component\HttpKernel\Event\ResponseEvent;
use Symfony\Component\HttpKernel\KernelEvents;

class RemoveCspHeadersListener implements EventSubscriberInterface
{
    public static function getSubscribedEvents(): array
    {
        return [
            KernelEvents::RESPONSE => ['removeCspHeaders', 1000], // High priority to run first
        ];
    }

    public function removeCspHeaders(ResponseEvent $event): void
    {
        // Remove all CSP headers
        $response = $event->getResponse();
        $response->headers->remove('Content-Security-Policy');
        $response->headers->remove('X-Content-Security-Policy');
        $response->headers->remove('X-WebKit-CSP');
    }
}