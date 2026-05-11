<?php

namespace AppBundle\Provider\ContentSecurityPolicy;

use Akeneo\Platform\Bundle\UIBundle\Provider\ContentSecurityPolicy\ContentSecurityPolicyProviderInterface;

class EmptyContentSecurityPolicyProvider implements ContentSecurityPolicyProviderInterface
{
    public function getContentSecurityPolicy(): array
    {
        // Return permissive policy that allows all inline scripts and eval
        return [
            'default-src' => ["'self'", "'unsafe-inline'", "'unsafe-eval'", '*'],
            'script-src' => ["'self'", "'unsafe-inline'", "'unsafe-eval'", '*'],
            'style-src' => ["'self'", "'unsafe-inline'", '*'],
            'img-src' => ["'self'", 'data:', 'https:', '*'],
            'font-src' => ["'self'", 'data:', '*'],
            'connect-src' => ["'self'", '*'],
            'frame-src' => ['*'],
            'object-src' => ["'none'"],
        ];
    }
}
