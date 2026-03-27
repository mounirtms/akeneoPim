<?php

namespace AppBundle\EventListener;

use Akeneo\Platform\Bundle\UIBundle\Provider\ContentSecurityPolicy\ContentSecurityPolicyProvider;
use Symfony\Component\EventDispatcher\EventSubscriberInterface;
use Symfony\Component\HttpKernel\Event\ResponseEvent;
use Symfony\Component\HttpKernel\KernelEvents;

class EmptyContentSecurityPolicyListener implements EventSubscriberInterface
{
    private ContentSecurityPolicyProvider $contentSecurityPolicyProvider;

    public function __construct(ContentSecurityPolicyProvider $contentSecurityPolicyProvider)
    {
        $this->contentSecurityPolicyProvider = $contentSecurityPolicyProvider;
    }

    public static function getSubscribedEvents(): array
    {
        return [
            KernelEvents::RESPONSE => 'addCspHeaders',
        ];
    }

    public function addCspHeaders(ResponseEvent $event): void
    {
        // Completely disable CSP by not setting any headers
        // Remove any existing CSP headers
        $response = $event->getResponse();
        $response->headers->remove('Content-Security-Policy');
        $response->headers->remove('X-Content-Security-Policy');
        $response->headers->remove('X-WebKit-CSP');
    }
}