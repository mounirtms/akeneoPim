<?php

namespace AppBundle\Provider\ContentSecurityPolicy;

use Akeneo\Platform\Bundle\UIBundle\Provider\ContentSecurityPolicy\ContentSecurityPolicyProviderInterface;
use Akeneo\Platform\Bundle\UIBundle\EventListener\ScriptNonceGenerator;

class CloudFlareContentSecurityPolicyProvider implements ContentSecurityPolicyProviderInterface
{
    private ScriptNonceGenerator $nonceGenerator;

    public function __construct(ScriptNonceGenerator $nonceGenerator)
    {
        $this->nonceGenerator = $nonceGenerator;
    }

    public function getContentSecurityPolicy(): array
    {
        $generatedNonce = $this->nonceGenerator->getGeneratedNonce();

        return [
            'default-src' => ["'self'", "*.akeneo.com", "'unsafe-inline'", "https://connect.facebook.net", "https://www.clarity.ms", "https://stats.g.doubleclick.net", "https://analytics.google.com", "https://www.google.dz", "https://scripts.clarity.ms", "https://c.clarity.ms", "https://www.facebook.com", "https://v.clarity.ms"],
            'script-src' => ["'self'", "'unsafe-eval'", "'unsafe-inline'", "https://connect.facebook.net", "https://www.clarity.ms", "https://stats.g.doubleclick.net", "https://analytics.google.com", "https://www.google.dz", "https://ff.kes.v2.scr.kaspersky-labs.com", "wss://ff.kes.v2.scr.kaspersky-labs.com", "https://scripts.clarity.ms", "https://c.clarity.ms", "https://v.clarity.ms"],
            'img-src' => ["'self'", "data:", "*.akeneo.com", "https://connect.facebook.net", "https://www.clarity.ms", "https://stats.g.doubleclick.net", "https://analytics.google.com", "https://www.google.dz", "https://c.clarity.ms", "https://www.facebook.com", "https://v.clarity.ms"],
            'frame-src' => ["*"],
            'font-src' => ["'self'", "data:", "https://fonts.gstatic.com"],
            'connect-src'=> ["'self'", "*.akeneo.com", "https://connect.facebook.net", "https://www.clarity.ms", "https://stats.g.doubleclick.net", "https://analytics.google.com", "https://www.google.dz", "wss://ff.kes.v2.scr.kaspersky-labs.com", "https://ff.kes.v2.scr.kaspersky-labs.com", "https://v.clarity.ms", "https://c.clarity.ms"],
        ];
    }
}