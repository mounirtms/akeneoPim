<?php

namespace AppBundle\Provider\ContentSecurityPolicy;

use Akeneo\Platform\Bundle\UIBundle\Provider\ContentSecurityPolicy\ContentSecurityPolicyProviderInterface;

class CustomContentSecurityPolicyProvider implements ContentSecurityPolicyProviderInterface
{
    public function getContentSecurityPolicy(): array
    {
        // Allow everything for testing
        return [
            'default-src' => ["*"],
            'script-src' => ["*", "'unsafe-inline'", "'unsafe-eval'"],
            'img-src' => ["*", "data:"],
            'frame-src' => ["*"],
            'font-src' => ["*", "data:"],
            'connect-src'=> ["*"],
            'style-src' => ["*", "'unsafe-inline'"],
        ];
    }
}
